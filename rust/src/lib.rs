mod http_client;
mod models;
mod utils;
mod parser;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic;
use std::ptr;
use std::sync::Arc;

use log::{error, info};
use models::EnhancedHttpRequest;
use once_cell::sync::{Lazy, OnceCell};
use futures::stream::{FuturesOrdered, StreamExt};

static CLIENT: OnceCell<Arc<http_client::HttpClient>> = OnceCell::new();
static INIT: std::sync::Once = std::sync::Once::new();

static RUNTIME: Lazy<tokio::runtime::Runtime> = Lazy::new(|| {
    let thread_count = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .min(8);

    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(thread_count)
        .enable_all()
        .build()
        .expect("Failed to create Tokio runtime")
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

fn create_error_response_bytes(message: &str) -> ByteBuffer {
    let error_json = format!("{{\"error\": \"{}\"}}", message);
    ByteBuffer::from_vec(error_json.into_bytes())
}

#[no_mangle]
pub extern "C" fn init_http_client() -> bool {
    INIT.call_once(|| {
        env_logger::init();
        panic::set_hook(Box::new(|panic_info| {
            error!("Panic occurred: {:?}", panic_info);
        }));

        let client = Arc::new(http_client::HttpClient::new());
        CLIENT.set(client).unwrap();

        info!("HTTP client initialized successfully");
    });

    true
}

#[no_mangle]
pub extern "C" fn execute_request_bytes(request_json: *const c_char) -> ByteBuffer {
    let request_cstr = unsafe {
        if request_json.is_null() {
            return create_error_response_bytes("Null pointer provided for request");
        }
        CStr::from_ptr(request_json)
    };

    let request_bytes = request_cstr.to_bytes();
    let mut request_copy = request_bytes.to_vec();

    let request: EnhancedHttpRequest = match simd_json::from_slice(&mut request_copy) {
        Ok(req) => req,
        Err(e) => {
            error!("Failed to parse request: {}", e);
            return create_error_response_bytes(&format!("Failed to parse request: {}", e));
        }
    };

    let client = match CLIENT.get() {
        Some(c) => c.clone(),
        None => {
            error!("HTTP client not initialized");
            return create_error_response_bytes("HTTP client not initialized");
        }
    };

    let result = RUNTIME.block_on(async {
        client.execute_enhanced_request(request).await
    });

    match result {
        Ok(response) => {
            match simd_json::to_vec(&response) {
                Ok(bytes) => ByteBuffer::from_vec(bytes),
                Err(e) => {
                    error!("Failed to serialize response: {}", e);
                    create_error_response_bytes(&format!("Failed to serialize response: {}", e))
                }
            }
        }
        Err(e) => {
            error!("Request failed: {}", e);
            create_error_response_bytes(&format!("Request failed: {}", e))
        }
    }
}

#[no_mangle]
pub extern "C" fn execute_batch_requests_bytes(requests_json: *const c_char) -> ByteBuffer {
    let requests_cstr = unsafe {
        if requests_json.is_null() {
            return create_error_response_bytes("Null pointer provided for batch requests");
        }
        CStr::from_ptr(requests_json)
    };

    let requests_bytes = requests_cstr.to_bytes();
    let mut requests_copy = requests_bytes.to_vec();

    let requests: Vec<EnhancedHttpRequest> = match simd_json::from_slice(&mut requests_copy) {
        Ok(reqs) => reqs,
        Err(e) => {
            error!("Failed to parse batch requests: {}", e);
            return create_error_response_bytes(&format!("Failed to parse batch requests: {}", e));
        }
    };

    let client = match CLIENT.get() {
        Some(c) => c.clone(),
        None => {
            error!("HTTP client not initialized");
            return create_error_response_bytes("HTTP client not initialized");
        }
    };

    let results = RUNTIME.block_on(async {
        let mut futures = FuturesOrdered::new();
        for req in requests {
            let client = client.clone();
            futures.push(async move {
                client.execute_enhanced_request(req).await
            });
        }

        let mut collected = Vec::new();
        while let Some(result) = futures.next().await {
            collected.push(result);
        }
        collected
    });

    let mut json_bytes = b"[".to_vec();
    let mut first = true;

    for result in results {
        if !first {
            json_bytes.push(b',');
        }
        first = false;

        match result {
            Ok(response) => {
                match simd_json::to_vec(&response) {
                    Ok(bytes) => json_bytes.extend(bytes),
                    Err(e) => {
                        error!("Failed to serialize response: {}", e);
                        let error_json = format!("{{\"error\": \"{}\"}}", e);
                        json_bytes.extend(error_json.bytes());
                    }
                }
            }
            Err(e) => {
                error!("Request failed: {}", e);
                let error_json = format!("{{\"error\": \"{}\"}}", e);
                json_bytes.extend(error_json.bytes());
            }
        }
    }
    json_bytes.push(b']');

    ByteBuffer::from_vec(json_bytes)
}

#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}