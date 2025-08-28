use mimalloc::MiMalloc;
use once_cell::sync::Lazy;
use futures_util::stream::StreamExt;
use std::sync::Arc;
use tokio::runtime::Runtime;
use std::hint::black_box;

pub mod http_client;
pub mod models;
pub mod client_config;
pub mod header_utils;
pub mod method_utils;
pub mod shared_client;

pub use http_client::HttpClient;
pub use models::{HttpRequest, HttpResponse};

#[global_allocator]
static GLOBAL: MiMalloc = MiMalloc;

// Balanced mobile-fast runtime configuration
static RUNTIME: Lazy<Arc<Runtime>> = Lazy::new(|| {
    let cpu_count = num_cpus::get();
    // Android 10+ typically has 6-8 cores, use most but leave 1-2 for system
    let worker_threads = match cpu_count {
        1..=2 => cpu_count,
        3..=4 => cpu_count - 1,
        5..=6 => cpu_count - 1,
        _ => cpu_count - 2, // Leave 2 cores for Android system on 8+ core devices
    };

    Arc::new(
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(worker_threads)
            .thread_stack_size(1024 * 1024) // 1MB - balanced between speed and mobile memory
            .thread_name("http-mobile-fast")
            .enable_all()
            .thread_keep_alive(std::time::Duration::from_secs(30)) // Moderate keep-alive
            .max_blocking_threads(32) // Reasonable for Android 10+
            .build()
            .expect("Failed to create mobile-fast runtime")
    )
});

static CLIENT: Lazy<Arc<HttpClient>> = Lazy::new(|| Arc::new(HttpClient::shared()));

// Smaller buffer pool optimized for mobile memory constraints
static RESPONSE_BUFFER_POOL: Lazy<Arc<std::sync::Mutex<Vec<Vec<u8>>>>> = Lazy::new(|| {
    let mut pool = Vec::with_capacity(20); // Smaller pool for mobile
    for _ in 0..20 {
        pool.push(Vec::with_capacity(2048)); // Smaller initial capacity
    }
    Arc::new(std::sync::Mutex::new(pool))
});

#[repr(C)]
pub struct Buffer {
    pub ptr: *mut u8,
    pub len: usize,
}

#[inline(always)]
fn get_buffer() -> Vec<u8> {
    if let Ok(mut pool) = RESPONSE_BUFFER_POOL.try_lock() {
        pool.pop().unwrap_or_else(|| Vec::with_capacity(2048))
    } else {
        Vec::with_capacity(2048) // Fallback if pool is contended
    }
}

#[inline(always)]
fn return_buffer(mut buf: Vec<u8>) {
    buf.clear();
    if buf.capacity() <= 8192 { // Return reasonable-sized buffers
        if let Ok(mut pool) = RESPONSE_BUFFER_POOL.try_lock() {
            if pool.len() < 20 {
                pool.push(buf);
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn init_http_client() -> bool {
    // Smart initialization - pre-warm but don't overdo it
    Lazy::force(&RUNTIME);
    Lazy::force(&CLIENT);

    // Light pre-warming - just ensure runtime is ready
    RUNTIME.spawn(async { black_box(()); });

    true
}

#[inline(always)]
fn parse_request_from_slice(request_slice: &mut [u8]) -> Option<HttpRequest<'_>> {
    simd_json::from_slice(request_slice).ok()
}

#[no_mangle]
pub extern "C" fn execute_request_binary(request_ptr: *mut u8, request_len: usize) -> Buffer {
    if request_ptr.is_null() || request_len == 0 {
        return Buffer { ptr: std::ptr::null_mut(), len: 0 };
    }

    let slice = unsafe { std::slice::from_raw_parts_mut(request_ptr, request_len) };

    let request: HttpRequest<'_> = match parse_request_from_slice(slice) {
        Some(r) => r,
        None => return Buffer { ptr: std::ptr::null_mut(), len: 0 },
    };

    let response = match RUNTIME.block_on(CLIENT.execute_request(request)) {
        Ok(r) => r,
        Err(_) => return Buffer { ptr: std::ptr::null_mut(), len: 0 },
    };

    // Try buffer pool first, fallback to direct allocation
    let mut buf = get_buffer();
    match simd_json::to_writer(&mut buf, &response) {
        Ok(_) => {
            // Mobile optimization: shrink if buffer grew too large
            if buf.capacity() > buf.len() * 2 {
                buf.shrink_to_fit();
            }
            let ptr = buf.as_mut_ptr();
            let len = buf.len();
            std::mem::forget(buf);
            Buffer { ptr, len }
        }
        Err(_) => {
            return_buffer(buf);
            // Fallback to direct serialization
            match simd_json::to_vec(&response) {
                Ok(mut vec) => {
                    vec.shrink_to_fit();
                    let ptr = vec.as_mut_ptr();
                    let len = vec.len();
                    std::mem::forget(vec);
                    Buffer { ptr, len }
                }
                Err(_) => Buffer { ptr: std::ptr::null_mut(), len: 0 },
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn execute_requests_batch_binary(requests_ptr: *mut u8, requests_len: usize) -> Buffer {
    if requests_ptr.is_null() || requests_len == 0 {
        return Buffer { ptr: std::ptr::null_mut(), len: 0 };
    }

    let slice = unsafe { std::slice::from_raw_parts_mut(requests_ptr, requests_len) };

    let requests: Vec<HttpRequest<'_>> = match simd_json::from_slice(slice) {
        Ok(r) => r,
        Err(_) => return Buffer { ptr: std::ptr::null_mut(), len: 0 },
    };

    if requests.is_empty() {
        return match simd_json::to_vec(&Vec::<HttpResponse>::new()) {
            Ok(mut vec) => {
                let ptr = vec.as_mut_ptr();
                let len = vec.len();
                std::mem::forget(vec);
                Buffer { ptr, len }
            }
            Err(_) => Buffer { ptr: std::ptr::null_mut(), len: 0 },
        };
    }

    // Mobile-aware adaptive concurrency - fast but not overwhelming
    let cpu_count = num_cpus::get();
    let concurrency = match requests.len() {
        1..=5 => requests.len(),                    // Very small: no limit
        6..=15 => (cpu_count * 2).min(12),         // Small: 2x cores, max 12
        16..=50 => (cpu_count * 4).min(24),        // Medium: 4x cores, max 24
        51..=200 => (cpu_count * 6).min(48),       // Large: 6x cores, max 48
        _ => (cpu_count * 8).min(64),              // Very large: 8x cores, max 64
    };

    let responses = RUNTIME.block_on(async {
        futures_util::stream::iter(requests)
            .map(|req| CLIENT.execute_request(req))
            .buffer_unordered(concurrency)
            .collect::<Vec<_>>()
            .await
    });

    // Smart pre-allocation based on success rate estimation
    let estimated_success = (responses.len() * 9) / 10; // Assume 90% success rate
    let mut successful_responses = Vec::with_capacity(estimated_success);

    for response in responses {
        if let Ok(resp) = response {
            successful_responses.push(resp);
        }
    }

    // Mobile memory management: shrink if we over-allocated significantly
    if successful_responses.capacity() > successful_responses.len() * 2 {
        successful_responses.shrink_to_fit();
    }

    // Try buffer pool for large responses
    if successful_responses.len() > 10 {
        let mut buf = get_buffer();
        buf.reserve(successful_responses.len() * 256); // Estimate response size

        match simd_json::to_writer(&mut buf, &successful_responses) {
            Ok(_) => {
                // Mobile: shrink oversized buffers
                if buf.capacity() > buf.len() * 2 {
                    buf.shrink_to_fit();
                }
                let ptr = buf.as_mut_ptr();
                let len = buf.len();
                std::mem::forget(buf);
                return Buffer { ptr, len };
            }
            Err(_) => {
                return_buffer(buf);
            }
        }
    }

    // Fallback to direct serialization
    match simd_json::to_vec(&successful_responses) {
        Ok(mut vec) => {
            vec.shrink_to_fit(); // Always shrink on mobile
            let ptr = vec.as_mut_ptr();
            let len = vec.len();
            std::mem::forget(vec);
            Buffer { ptr, len }
        }
        Err(_) => Buffer { ptr: std::ptr::null_mut(), len: 0 },
    }
}

#[no_mangle]
pub extern "C" fn free_buffer(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        unsafe {
            let buf = Vec::from_raw_parts(ptr, len, len);
            // Try to return reasonable buffers to pool
            return_buffer(buf);
        }
    }
}

#[no_mangle]
pub extern "C" fn shutdown_http_client() {
    // Clean shutdown - clear buffer pool
    if let Ok(mut pool) = RESPONSE_BUFFER_POOL.try_lock() {
        pool.clear();
        pool.shrink_to_fit();
    }
}