mod http_client;
mod models;
mod utils;
mod parser;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic;
use std::sync::Arc;
use anyhow::anyhow;

use log::{error, info};
use models::EnhancedHttpRequest;
use once_cell::sync::{Lazy, OnceCell};
use futures::stream::{FuturesUnordered, StreamExt};
use tokio::sync::Semaphore;

// Mobile-optimized constants
const MAX_CONCURRENT: usize = 16;
const MAX_BATCH: usize = 8;

static CLIENT: OnceCell<Arc<http_client::HttpClient>> = OnceCell::new();
static SEMAPHORE: OnceCell<Arc<Semaphore>> = OnceCell::new();
static INIT: std::sync::Once = std::sync::Once::new();

// Simple mobile runtime
static RUNTIME: Lazy<tokio::runtime::Runtime> = Lazy::new(|| {
    let threads = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .min(6);

    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(threads)
        .enable_io()
        .enable_time()
        .build()
        .expect("Failed to create runtime")
});

#[repr(C)]
pub struct ByteBuffer {
    ptr: *mut u8,
    length: usize,
    capacity: usize,
}

impl ByteBuffer {
    pub fn from_vec(mut vec: Vec<u8>) -> Self {
        let ptr = vec.as_mut_ptr();
        let length = vec.len();
        let capacity = vec.capacity();
        std::mem::forget(vec);
        ByteBuffer { ptr, length, capacity }
    }

    pub fn into_vec(self) -> Vec<u8> {
        unsafe { Vec::from_raw_parts(self.ptr, self.length, self.capacity) }
    }
}

#[no_mangle]
pub extern "C" fn free_byte_buffer(buffer: ByteBuffer) {
    drop(buffer.into_vec());
}

fn error_response(msg: &str) -> ByteBuffer {
    let json = format!("{{\"error\":\"{}\"}}", msg);
    ByteBuffer::from_vec(json.into_bytes())
}

#[no_mangle]
pub extern "C" fn init_http_client() -> bool {
    INIT.call_once(|| {
        env_logger::init();
        panic::set_hook(Box::new(|info| error!("Panic: {}", info)));

        let client = Arc::new(http_client::HttpClient::new());
        CLIENT.set(client).unwrap();

        let semaphore = Arc::new(Semaphore::new(MAX_CONCURRENT));
        SEMAPHORE.set(semaphore).unwrap();

        info!("Mobile HTTP client initialized");
    });
    true
}

#[no_mangle]
pub extern "C" fn execute_request_bytes(request_json: *const c_char) -> ByteBuffer {
    if request_json.is_null() {
        return error_response("Null pointer");
    }

    let request_str = unsafe { CStr::from_ptr(request_json) }.to_bytes();
    let mut request_copy = request_str.to_vec();

    let request: EnhancedHttpRequest = match simd_json::from_slice(&mut request_copy) {
        Ok(req) => req,
        Err(_) => return error_response("Parse error"),
    };

    let client = match CLIENT.get() {
        Some(c) => c.clone(),
        None => return error_response("Not initialized"),
    };

    let semaphore = match SEMAPHORE.get() {
        Some(s) => s.clone(),
        None => return error_response("Not initialized"),
    };

    let result = RUNTIME.block_on(async {
        if let Ok(_permit) = semaphore.acquire().await {
            client.execute_enhanced_request(request).await
        } else {
            Err(anyhow::Error::msg("Rate limit"))
        }
    });

    match result {
        Ok(response) => match simd_json::to_vec(&response) {
            Ok(bytes) => ByteBuffer::from_vec(bytes),
            Err(_) => error_response("Serialize error"),
        },
        Err(_) => error_response("Request failed"),
    }
}

#[no_mangle]
pub extern "C" fn execute_batch_requests_bytes(requests_json: *const c_char) -> ByteBuffer {
    if requests_json.is_null() {
        return error_response("Null pointer");
    }

    let requests_str = unsafe { CStr::from_ptr(requests_json) }.to_bytes();
    let mut requests_copy = requests_str.to_vec();

    let requests: Vec<EnhancedHttpRequest> = match simd_json::from_slice(&mut requests_copy) {
        Ok(reqs) => reqs,
        Err(_) => return error_response("Parse error"),
    };

    if requests.len() > MAX_BATCH {
        return error_response("Batch too large");
    }

    let client = match CLIENT.get() {
        Some(c) => c.clone(),
        None => return error_response("Not initialized"),
    };

    let semaphore = match SEMAPHORE.get() {
        Some(s) => s.clone(),
        None => return error_response("Not initialized"),
    };

    let results = RUNTIME.block_on(async {
        let mut futures = FuturesUnordered::new();

        for req in requests {
            let client = client.clone();
            let semaphore = semaphore.clone();

            futures.push(async move {
                if let Ok(_permit) = semaphore.acquire().await {
                    client.execute_enhanced_request(req).await
                } else {
                    Err(anyhow::Error::msg("Rate limit"))
                }
            });
        }

        let mut collected = Vec::new();
        while let Some(result) = futures.next().await {
            collected.push(result);
        }
        collected
    });

    let mut json = Vec::with_capacity(results.len() * 256);
    json.push(b'[');

    for (i, result) in results.into_iter().enumerate() {
        if i > 0 { json.push(b','); }

        match result {
            Ok(response) => {
                if simd_json::to_writer(&mut json, &response).is_err() {
                    json.extend_from_slice(b"{\"error\":\"Serialize\"}");
                }
            }
            Err(_) => json.extend_from_slice(b"{\"error\":\"Failed\"}"),
        }
    }
    json.push(b']');

    ByteBuffer::from_vec(json)
}

#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { let _ = CString::from_raw(ptr); }
    }
}

#[no_mangle]
pub extern "C" fn get_stats() -> ByteBuffer {
    let available = SEMAPHORE.get().map(|s| s.available_permits()).unwrap_or(0);
    let stats = format!("{{\"available\":{},\"max\":{}}}", available, MAX_CONCURRENT);
    ByteBuffer::from_vec(stats.into_bytes())
}