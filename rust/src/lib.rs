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

static CLIENT: OnceCell<Arc<http_client::HttpClient>> = OnceCell::new();
static INIT: std::sync::Once = std::sync::Once::new();

// Thread pool for CPU-intensive JSON parsing
//static PARSER_POOL: Lazy<rayon::ThreadPool> = Lazy::new(|| {
//    rayon::ThreadPoolBuilder::new()
//        .num_threads(2) // Limited threads for parsing
//        .thread_name(|i| format!("json-parser-{}", i))
//        .build()
//        .unwrap()
//});

// Global Tokio runtime (multi-threaded)
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
pub extern "C" fn execute_request(request_json: *const c_char) -> *mut c_char {
    let request_str = unsafe {
        if request_json.is_null() {
            return create_error_response("Null pointer provided for request");
        }
        match CStr::from_ptr(request_json).to_str() {
            Ok(s) => s,
            Err(_) => return create_error_response("Invalid UTF-8 in request JSON"),
        }
    };

    // Use simd-json for faster parsing if available
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

    // Run inside global runtime
    let result = RUNTIME.block_on(async {
        client.execute_enhanced_request(request).await
    });

    match result {
        Ok(response) => {
            // Use faster serialization
            match parser::serialize_response(&response) {
                Ok(json) => match CString::new(json) {
                    Ok(c_string) => c_string.into_raw(),
                    Err(_) => create_error_response("Failed to create C string from response"),
                },
                Err(e) => {
                    error!("Failed to serialize response: {}", e);
                    create_error_response(&format!("Failed to serialize response: {}", e))
                }
            }
        }
        Err(e) => {
            error!("Request failed: {}", e);
            create_error_response(&format!("Request failed: {}", e))
        }
    }
}

#[no_mangle]
pub extern "C" fn execute_batch_requests(requests_json: *const c_char) -> *mut c_char {
    let requests_str = unsafe {
        if requests_json.is_null() {
            return create_error_response("Null pointer provided for batch requests");
        }
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

    // Execute all requests concurrently
    let results = RUNTIME.block_on(async {
        let futures: Vec<_> = requests
            .into_iter()
            .map(|req| {
                let client = client.clone();
                async move {
                    match client.execute_enhanced_request(req).await {
                        Ok(response) => serde_json::to_value(response).ok(),
                        Err(e) => {
                            error!("Request failed in batch: {}", e);
                            None
                        }
                    }
                }
            })
            .collect();

        futures::future::join_all(futures).await
    });

    // Filter out None values and serialize
    let successful_results: Vec<_> = results.into_iter().filter_map(|r| r).collect();

    match serde_json::to_string(&successful_results) {
        Ok(json) => match CString::new(json) {
            Ok(c_string) => c_string.into_raw(),
            Err(_) => create_error_response("Failed to create C string from batch response"),
        },
        Err(e) => {
            error!("Failed to serialize batch results: {}", e);
            create_error_response(&format!("Failed to serialize batch results: {}", e))
        }
    }
}

#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}