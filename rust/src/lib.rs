mod http_client;
mod models;
mod utils;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic;
use std::ptr;
use std::sync::Once;

use anyhow::Result;
use log::{error, info};
use models::{HttpRequest, HttpResponse};
use parking_lot::Mutex;

static INIT: Once = Once::new();
static mut CLIENT: Option<Mutex<http_client::HttpClient>> = None;

#[no_mangle]
pub extern "C" fn init_http_client() -> bool {
    INIT.call_once(|| {
        env_logger::init();
        panic::set_hook(Box::new(|panic_info| {
            error!("Panic occurred: {:?}", panic_info);
        }));

        unsafe {
            CLIENT = Some(Mutex::new(http_client::HttpClient::new()));
        }

        info!("HTTP client initialized successfully");
    });

    true
}

#[no_mangle]
pub extern "C" fn execute_request(request_json: *const c_char) -> *mut c_char {
    let request_str = unsafe {
        if request_json.is_null() {
            return ptr::null_mut();
        }
        match CStr::from_ptr(request_json).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    let request: HttpRequest = match serde_json::from_str(request_str) {
        Ok(req) => req,
        Err(e) => {
            error!("Failed to parse request: {}", e);
            return ptr::null_mut();
        }
    };

    let client = unsafe {
        match &CLIENT {
            Some(c) => c,
            None => {
                error!("HTTP client not initialized");
                return ptr::null_mut();
            }
        }
    };

    let result = client.lock().execute_request(request);

    match result {
        Ok(response) => {
            match serde_json::to_string(&response) {
                Ok(json) => {
                    match CString::new(json) {
                        Ok(c_string) => c_string.into_raw(),
                        Err(_) => ptr::null_mut(),
                    }
                }
                Err(e) => {
                    error!("Failed to serialize response: {}", e);
                    ptr::null_mut()
                }
            }
        }
        Err(e) => {
            error!("Request failed: {}", e);
            ptr::null_mut()
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