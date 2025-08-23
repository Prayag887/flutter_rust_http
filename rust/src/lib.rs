mod http_client;
mod models;
mod parser;

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};
use std::panic;
use std::ptr;
use std::sync::Arc;
use std::mem::{size_of, ManuallyDrop};

use log::{error, info, warn};
use models::EnhancedHttpRequest;
use once_cell::sync::{Lazy, OnceCell};
use parking_lot::Mutex;
// extern crate env_logger;

static CLIENT: OnceCell<Arc<http_client::HttpClient>> = OnceCell::new();
static INIT: std::sync::Once = std::sync::Once::new();

// Memory-safe buffer structure for sharing data between Rust and Dart
#[repr(C)]
pub struct SharedBuffer {
    data: *mut u8,
    len: usize,
    capacity: usize,
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

#[no_mangle]
pub extern "C" fn init_http_client() -> bool {
    INIT.call_once(|| {
        // Initialize logging only in debug mode

        panic::set_hook(Box::new(|panic_info| {
            error!("Panic occurred: {:?}", panic_info);
        }));

        let client = Arc::new(http_client::HttpClient::new());
        CLIENT.set(client).unwrap();

        info!("HTTP client initialized successfully");
    });

    true
}

// Allocate memory that can be shared with Dart
#[no_mangle]
pub extern "C" fn allocate_buffer(size: usize) -> *mut SharedBuffer {
    let buffer = SharedBuffer {
        data: unsafe { libc::malloc(size) } as *mut u8,
        len: 0,
        capacity: size,
    };

    let boxed = Box::new(buffer);
    Box::into_raw(boxed)
}

// Free memory allocated by Rust
#[no_mangle]
pub extern "C" fn free_buffer(ptr: *mut SharedBuffer) {
    if !ptr.is_null() {
        unsafe {
            let buffer = Box::from_raw(ptr);
            if !buffer.data.is_null() {
                libc::free(buffer.data as *mut c_void);
            }
        }
    }
}

// High-performance request execution with direct memory access
#[no_mangle]
pub extern "C" fn execute_request_direct(
    request_json: *const c_char,
    response_buffer: *mut SharedBuffer,
) -> i32 {
    // Validate input pointers
    if request_json.is_null() || response_buffer.is_null() {
        return -1; // Error code for null pointer
    }

    // Convert C string to Rust string with safety checks
    let request_str = unsafe {
        match CStr::from_ptr(request_json).to_str() {
            Ok(s) => s,
            Err(_) => return -2, // Error code for invalid UTF-8
        }
    };

    // Parse request
    let request: EnhancedHttpRequest = match parser::parse_request(request_str) {
        Ok(req) => req,
        Err(e) => {
            error!("Failed to parse request: {}", e);
            return -3; // Error code for parse failure
        }
    };

    let client = match CLIENT.get() {
        Some(c) => c.clone(),
        None => {
            error!("HTTP client not initialized");
            return -4; // Error code for client not initialized
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
            // Serialize response to JSON
            match parser::serialize_response(&response) {
                Ok(json) => {
                    // Write directly to the shared buffer
                    unsafe {
                        let buffer = &mut *response_buffer;
                        let bytes = json.as_bytes();

                        if bytes.len() > buffer.capacity {
                            error!("Response too large for buffer");
                            return -5; // Error code for buffer too small
                        }

                        std::ptr::copy_nonoverlapping(
                            bytes.as_ptr(),
                            buffer.data,
                            bytes.len()
                        );
                        buffer.len = bytes.len();
                    }
                    0 // Success
                },
                Err(e) => {
                    error!("Failed to serialize response: {}", e);
                    -6 // Error code for serialization failure
                }
            }
        }
        Ok(Err(e)) => {
            error!("Request failed: {}", e);
            -7 // Error code for request failure
        }
        Err(_) => {
            error!("Request timeout");
            -8 // Error code for timeout
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