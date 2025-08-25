mod http_client;
mod models;
mod utils;
mod parser;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic;
use std::sync::{atomic::{AtomicUsize, Ordering}, Arc};

use anyhow::anyhow;
use futures::stream::{FuturesUnordered, StreamExt};
use log::{error, info};
use models::EnhancedHttpRequest;
use once_cell::sync::{Lazy, OnceCell};

// Mobile-optimized constants
const MAX_CONCURRENT: usize = 16; // hard cap enforced via lock-free atomics
const MAX_BATCH: usize = 8;

static CLIENT: OnceCell<Arc<http_client::HttpClient>> = OnceCell::new();
static INIT: std::sync::Once = std::sync::Once::new();

// Lock-free in-flight counter (no semaphore, no locks)
static INFLIGHT: Lazy<AtomicUsize> = Lazy::new(|| AtomicUsize::new(0));

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

#[inline(always)]
fn error_response(msg: &str) -> ByteBuffer {
    let mut json = Vec::with_capacity(msg.len() + 12);
    json.extend_from_slice(b"{\"error\":\"");
    json.extend_from_slice(msg.as_bytes());
    json.push(b'"');
    json.push(b'}');
    ByteBuffer::from_vec(json)
}

#[no_mangle]
pub extern "C" fn init_http_client() -> bool {
    INIT.call_once(|| {
        env_logger::init();
        panic::set_hook(Box::new(|info| error!("Panic: {}", info)));

        CLIENT.set(Arc::new(http_client::HttpClient::new())).unwrap();
        info!("Mobile HTTP client initialized (lock-free)");
    });
    true
}

// RAII guard: increments INFLIGHT on creation, decrements on drop.
struct InFlightGuard;
impl InFlightGuard {
    #[inline(always)]
    fn try_acquire() -> Option<Self> {
        // Lock-free cap using CAS loop
        loop {
            let cur = INFLIGHT.load(Ordering::Relaxed);
            if cur >= MAX_CONCURRENT { return None; }
            if INFLIGHT
                .compare_exchange_weak(cur, cur + 1, Ordering::AcqRel, Ordering::Relaxed)
                .is_ok()
            { return Some(InFlightGuard); }
        }
    }
}
impl Drop for InFlightGuard {
    fn drop(&mut self) {
        INFLIGHT.fetch_sub(1, Ordering::AcqRel);
    }
}

#[no_mangle]
pub extern "C" fn execute_request_bytes(request_json: *const c_char) -> ByteBuffer {
    if request_json.is_null() { return error_response("Null pointer"); }

    // simd_json requires &mut [u8]; we must copy the C string once.
    let mut bytes = unsafe { CStr::from_ptr(request_json) }.to_bytes().to_vec();

    let request: EnhancedHttpRequest = match simd_json::from_slice(&mut bytes) {
        Ok(req) => req,
        Err(_) => return error_response("Parse error"),
    };

    let client = match CLIENT.get() {
        Some(c) => Arc::clone(c),
        None => return error_response("Not initialized"),
    };

    // Hard, lock-free cap without awaiting
    let Some(_guard) = InFlightGuard::try_acquire() else {
        return error_response("Rate limit");
    };

    let (tx, rx) = tokio::sync::oneshot::channel();

    RUNTIME.spawn(async move {
        let result = client.execute_enhanced_request(request).await;
        let _ = tx.send(result);
    });

    let result = rx.blocking_recv().unwrap_or_else(|_| Err(anyhow!("Channel closed")));

    match result {
        Ok(resp) => {
            let mut buf = Vec::with_capacity(256);
            if simd_json::to_writer(&mut buf, &resp).is_ok() {
                ByteBuffer::from_vec(buf)
            } else {
                error_response("Serialize error")
            }
        }
        Err(_) => error_response("Request failed"),
    }
}

#[no_mangle]
pub extern "C" fn execute_batch_requests_bytes(requests_json: *const c_char) -> ByteBuffer {
    if requests_json.is_null() { return error_response("Null pointer"); }

    let mut bytes = unsafe { CStr::from_ptr(requests_json) }.to_bytes().to_vec();

    let requests: Vec<EnhancedHttpRequest> = match simd_json::from_slice(&mut bytes) {
        Ok(reqs) => reqs,
        Err(_) => return error_response("Parse error"),
    };

    if requests.len() > MAX_BATCH {
        return error_response("Batch too large");
    }

    let client = match CLIENT.get() {
        Some(c) => Arc::clone(c),
        None => return error_response("Not initialized"),
    };

    let handle = RUNTIME.spawn(async move {
        let mut futs = FuturesUnordered::new();

        for req in requests {
            let c = Arc::clone(&client); // clone for this async block

            futs.push(async move {
                if let Some(_guard) = InFlightGuard::try_acquire() {
                    // _guard keeps INFLIGHT counter incremented for the duration
                    c.execute_enhanced_request(req).await.map_err(|e| e)
                } else {
                    Err(anyhow!("Rate limit"))
                }
            });
        }


        let mut results = Vec::with_capacity(MAX_BATCH);
        while let Some(res) = futs.next().await {
            results.push(res);
        }
        results
    });

    let results = RUNTIME.block_on(handle).unwrap_or_default();

    let mut json = Vec::with_capacity(results.len() * 256);
    json.push(b'[');

    for (i, result) in results.into_iter().enumerate() {
        if i > 0 { json.push(b','); }
        match result {
            Ok(resp) => {
                if simd_json::to_writer(&mut json, &resp).is_err() {
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
    let current = INFLIGHT.load(Ordering::Relaxed);
    let mut buf = Vec::with_capacity(32);
    buf.extend_from_slice(b"{\"in_flight\":");

    let mut itoa_buffer = itoa::Buffer::new();
    let formatted = itoa_buffer.format(current);
    buf.extend_from_slice(formatted.as_bytes());

    buf.extend_from_slice(b",\"max\":");
    let formatted = itoa_buffer.format(MAX_CONCURRENT);
    buf.extend_from_slice(formatted.as_bytes());

    buf.push(b'}');
    ByteBuffer::from_vec(buf)
}
