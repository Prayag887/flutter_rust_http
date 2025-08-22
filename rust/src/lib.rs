mod http_client;
mod models;
mod utils;
mod parser;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic;
use std::ptr;
use std::sync::Arc;
use std::mem::ManuallyDrop;

use log::{error, info, warn};
use models::EnhancedHttpRequest;
use once_cell::sync::{Lazy, OnceCell};
use parking_lot::Mutex;

static CLIENT: OnceCell<Arc<http_client::HttpClient>> = OnceCell::new();
static INIT: std::sync::Once = std::sync::Once::new();

// Thread-local SIMD JSON parser
thread_local! {
    static SIMD_PARSER: Mutex<Option<simd_json::OwnedValue>> = Mutex::new(None);
}

// Global Tokio runtime (optimized)
static RUNTIME: Lazy<tokio::runtime::Runtime> = Lazy::new(|| {
    let thread_count = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .min(8);

    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(thread_count)
        .enable_io()
        .enable_time()
        .build()
        .expect("Failed to create Tokio runtime")
});

// Memory-safe error response creation
fn create_error_response(message: &str) -> *mut c_char {
    let error_json = format!("{{\"error\": \"{}\"}}", message);
    match CString::new(error_json) {
        Ok(c_string) => c_string.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn init_http_client() -> bool {
    INIT.call_once(|| {
        // Initialize logging only in debug mode
        if cfg!(debug_assertions) {
            env_logger::init();
        }

        panic::set_hook(Box::new(|panic_info| {
            error!("Panic occurred: {:?}", panic_info);
        }));

        let client = Arc::new(http_client::HttpClient::new());
        CLIENT.set(client).unwrap();

        info!("HTTP client initialized successfully");
    });

    true
}

// High-performance request execution with SIMD JSON parsing
#[no_mangle]
pub extern "C" fn execute_request(request_json: *const c_char) -> *mut c_char {
    // Validate input pointer
    if request_json.is_null() {
        return create_error_response("Null pointer provided for request");
    }

    // Convert C string to Rust string with safety checks
    let request_str = unsafe {
        match CStr::from_ptr(request_json).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_response("Invalid UTF-8 in request JSON"),
        }
    };

    // Parse request with SIMD JSON when available
    let request: EnhancedHttpRequest = match parser::parse_request(request_str) {
        Ok(req) => req,
        Err(e) => {
            error!("Failed to parse request: {}", e);
            return create_error_response(&format!("Failed to parse request: {}", e));
        }
    };

    let client = match CLIENT.get() {
        Some(c) => c.clone(),
        None => {
            error!("HTTP client not initialized");
            return create_error_response("HTTP client not initialized");
        }
    };

    // Execute request with timeout protection
    let result = RUNTIME.block_on(async {
        tokio::time::timeout(
            std::time::Duration::from_millis(request.base.timeout_ms),
            client.execute_enhanced_request(request)
        ).await
    });

    match result {
        Ok(Ok(response)) => {
            // Use SIMD JSON for serialization when available
            match parser::serialize_response(&response) {
                Ok(json) => {
                    // Manually manage memory to prevent extra copies
                    let c_string = ManuallyDrop::new(
                        CString::new(json).unwrap_or_else(|_|
                            CString::new("{\"error\": \"Serialization failed\"}").unwrap()
                        )
                    );
                    c_string.into_raw()
                },
                Err(e) => {
                    error!("Failed to serialize response: {}", e);
                    create_error_response(&format!("Failed to serialize response: {}", e))
                }
            }
        }
        Ok(Err(e)) => {
            error!("Request failed: {}", e);
            create_error_response(&format!("Request failed: {}", e))
        }
        Err(_) => {
            error!("Request timeout");
            create_error_response("Request timeout")
        }
    }
}

// Optimized batch requests with parallel execution
#[no_mangle]
pub extern "C" fn execute_batch_requests(requests_json: *const c_char) -> *mut c_char {
    if requests_json.is_null() {
        return create_error_response("Null pointer provided for batch requests");
    }

    let requests_str = unsafe {
        match CStr::from_ptr(requests_json).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_response("Invalid UTF-8 in batch requests JSON"),
        }
    };

    let requests: Vec<EnhancedHttpRequest> = match parser::parse_batch_requests(requests_str) {
        Ok(reqs) => reqs,
        Err(e) => {
            error!("Failed to parse batch requests: {}", e);
            return create_error_response(&format!("Failed to parse batch requests: {}", e));
        }
    };

    let client = match CLIENT.get() {
        Some(c) => c.clone(),
        None => {
            error!("HTTP client not initialized");
            return create_error_response("HTTP client not initialized");
        }
    };

    // Execute requests in parallel with controlled concurrency
    let results = RUNTIME.block_on(async {
        use futures::stream::StreamExt;

        futures::stream::iter(requests)
            .map(|req| {
                let client = client.clone();
                async move {
                    match client.execute_enhanced_request(req).await {
                        Ok(response) => Some(serde_json::to_value(response).unwrap_or_default()),
                        Err(e) => {
                            error!("Request failed in batch: {}", e);
                            None
                        }
                    }
                }
            })
            .buffer_unordered(10) // Limit concurrent requests
            .collect::<Vec<_>>()
            .await
    });

    // Filter successful results and serialize
    let successful_results: Vec<_> = results.into_iter().flatten().collect();

    match simd_json::to_string(&successful_results) {
        Ok(json) => {
            let c_string = ManuallyDrop::new(
                CString::new(json).unwrap_or_else(|_|
                    CString::new("[]").unwrap()
                )
            );
            c_string.into_raw()
        },
        Err(e) => {
            error!("Failed to serialize batch results: {}", e);
            create_error_response(&format!("Failed to serialize batch results: {}", e))
        }
    }
}

// Memory-safe string deallocation
#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}