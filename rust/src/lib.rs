use mimalloc::MiMalloc;
use once_cell::sync::Lazy;
use futures_util::stream::StreamExt;
use std::sync::Arc;
use tokio::runtime::Runtime;

// FAST channel
use crossbeam_channel::{unbounded, Sender, Receiver};
use std::thread;

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

// ---------- Runtime / client singletons ----------
static RUNTIME: Lazy<Arc<Runtime>> = Lazy::new(|| {
    let cpu_count = num_cpus::get();
    let worker_threads = match cpu_count {
        1..=2 => cpu_count,
        3..=4 => cpu_count - 1,
        5..=6 => cpu_count - 1,
        _ => cpu_count - 2,
    };

    Arc::new(
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(worker_threads)
            .thread_stack_size(1024 * 1024)
            .thread_name("http-mobile-fast")
            .enable_all()
            .thread_keep_alive(std::time::Duration::from_secs(30))
            .max_blocking_threads(32)
            .build()
            .expect("Failed to create mobile-fast runtime"),
    )
});

static CLIENT: Lazy<Arc<HttpClient>> = Lazy::new(|| Arc::new(HttpClient::shared()));

// ---------- Buffer pool for small responses ----------
static RESPONSE_BUFFER_POOL: Lazy<Arc<std::sync::Mutex<Vec<Vec<u8>>>>> = Lazy::new(|| {
    let mut pool = Vec::with_capacity(20);
    for _ in 0..20 {
        pool.push(Vec::with_capacity(2048));
    }
    Arc::new(std::sync::Mutex::new(pool))
});

#[repr(C)]
pub struct Buffer {
    pub ptr: *mut u8,
    pub len: usize,
}

// When doing zero-copy, we must also know capacity to free safely.
#[repr(C)]
pub struct BufferCap {
    pub ptr: *mut u8,
    pub len: usize,
    pub cap: usize,
}



#[inline(always)]
fn get_buffer() -> Vec<u8> {
    if let Ok(mut pool) = RESPONSE_BUFFER_POOL.try_lock() {
        pool.pop().unwrap_or_else(|| Vec::with_capacity(2048))
    } else {
        Vec::with_capacity(2048)
    }
}

#[inline(always)]
fn return_buffer(mut buf: Vec<u8>) {
    buf.clear();
    if buf.capacity() <= 8192 {
        if let Ok(mut pool) = RESPONSE_BUFFER_POOL.try_lock() {
            if pool.len() < 20 {
                pool.push(buf);
            }
        }
    }
}

// ---------- Jobs ----------
enum Job {
    SingleOwned {
        // owns a Vec<u8> containing JSON for one request
        request_bytes: Vec<u8>,
        reply: Sender<Option<Vec<u8>>>,
    },
    BatchOwned {
        requests_bytes: Vec<u8>,
        reply: Sender<Option<Vec<u8>>>,
    },
    // Back-compat path (if you keep the old API that copies)
    SingleCopy {
        // immutable slice that we must copy to parse with simd_json
        request_bytes: Vec<u8>,
        reply: Sender<Option<Vec<u8>>>,
    },
    BatchCopy {
        requests_bytes: Vec<u8>,
        reply: Sender<Option<Vec<u8>>>,
    },
}

// Single global sender to the background worker.
static WORKER_SENDER: Lazy<Sender<Job>> = Lazy::new(|| {
    let (tx, rx) = unbounded::<Job>();
    spawn_worker(rx);
    tx
});

// Worker loop (unchanged structure, faster channel)
fn spawn_worker(rx: Receiver<Job>) {
    let runtime = Lazy::force(&RUNTIME).clone();
    let client = Lazy::force(&CLIENT).clone();

    thread::Builder::new()
        .name("http-ffi-worker".into())
        .spawn(move || {
            for job in rx {
                match job {
                    Job::SingleOwned { mut request_bytes, reply } => {
                        let runtime = runtime.clone();
                        let client = client.clone();
                        let res = runtime.block_on(async move {
                            // simd-json needs &mut [u8]
                            let parsed: Result<HttpRequest<'_>, _> =
                                simd_json::from_slice(&mut request_bytes);
                            match parsed {
                                Ok(req) => match client.execute_request(req).await {
                                    Ok(resp) => simd_json::to_vec(&resp).ok(),
                                    Err(_) => None,
                                },
                                Err(_) => None,
                            }
                        });
                        let _ = reply.send(res);
                    }
                    Job::BatchOwned { mut requests_bytes, reply } => {
                        let runtime = runtime.clone();
                        let client = client.clone();
                        let res = runtime.block_on(async move {
                            let parsed: Result<Vec<HttpRequest<'_>>, _> =
                                simd_json::from_slice(&mut requests_bytes);
                            match parsed {
                                Ok(requests) => {
                                    if requests.is_empty() {
                                        return simd_json::to_vec(&Vec::<HttpResponse>::new()).ok();
                                    }
                                    let cpu_count = num_cpus::get();
                                    let concurrency = match requests.len() {
                                        1..=5 => requests.len(),
                                        6..=15 => (cpu_count * 2).min(12),
                                        16..=50 => (cpu_count * 4).min(24),
                                        51..=200 => (cpu_count * 6).min(48),
                                        _ => (cpu_count * 8).min(64),
                                    };

                                    let responses = futures_util::stream::iter(requests)
                                        .map(|req| client.execute_request(req))
                                        .buffer_unordered(concurrency)
                                        .collect::<Vec<_>>()
                                        .await;

                                    let mut ok_resps = Vec::with_capacity(responses.len());
                                    for r in responses {
                                        if let Ok(resp) = r {
                                            ok_resps.push(resp);
                                        }
                                    }
                                    simd_json::to_vec(&ok_resps).ok()
                                }
                                Err(_) => None,
                            }
                        });
                        let _ = reply.send(res);
                    }
                    Job::SingleCopy { request_bytes, reply } => {
                        // (compat path just forwards to SingleOwned)
                        let _ = WORKER_SENDER.send(Job::SingleOwned { request_bytes, reply });
                    }
                    Job::BatchCopy { requests_bytes, reply } => {
                        let _ = WORKER_SENDER.send(Job::BatchOwned { requests_bytes, reply });
                    }
                }
            }
        })
        .expect("failed to spawn http-ffi-worker");
}

// ---------- Exported FFI ----------

#[no_mangle]
pub extern "C" fn init_http_client() -> bool {
    Lazy::force(&RUNTIME);
    Lazy::force(&CLIENT);
    Lazy::force(&WORKER_SENDER);
    true
}

// --- Zero-copy helpers ---

/// Allocate a writable buffer in Rust and return pointer+capacity.
/// Dart will write UTF-8 JSON bytes into it.
#[no_mangle]
pub extern "C" fn allocate_request_buffer(capacity: usize) -> BufferCap {
    let mut v = Vec::<u8>::with_capacity(capacity.max(1));
    let ptr = v.as_mut_ptr();
    let cap = v.capacity();
    std::mem::forget(v);
    BufferCap { ptr, len: 0, cap }
}

/// After Dart writes into the buffer, call this to set the actual length.
/// You can skip this and pass `len` directly to execute if you track it on Dart side.
#[no_mangle]
pub extern "C" fn set_buffer_len(ptr: *mut u8, len: usize, cap: usize) {
    if ptr.is_null() || len > cap { return; }
    // SAFETY: we reconstruct then immediately forget to just adjust length.
    unsafe {
        let mut v = Vec::from_raw_parts(ptr, 0, cap);
        v.set_len(len);
        std::mem::forget(v);
    }
}

/// Execute a single request taking ownership of the buffer (NO COPY).
#[no_mangle]
pub extern "C" fn execute_request_binary_from_owned(ptr: *mut u8, len: usize, cap: usize) -> Buffer {
    if ptr.is_null() || len == 0 || cap < len { return Buffer { ptr: std::ptr::null_mut(), len: 0 }; }

    // SAFETY: take ownership of the Vec<u8>
    let request_bytes = unsafe { Vec::from_raw_parts(ptr, len, cap) };

    let (reply_tx, reply_rx) = unbounded();
    if WORKER_SENDER.send(Job::SingleOwned { request_bytes, reply: reply_tx }).is_err() {
        return Buffer { ptr: std::ptr::null_mut(), len: 0 };
    }

    match reply_rx.recv() {
        Ok(Some(mut vec)) => {
            // DO NOT shrink_to_fit to avoid realloc; pass as-is
            let ptr = vec.as_mut_ptr();
            let len = vec.len();
            std::mem::forget(vec);
            Buffer { ptr, len }
        }
        _ => Buffer { ptr: std::ptr::null_mut(), len: 0 },
    }
}

/// Execute a batch taking ownership of the buffer (NO COPY).
#[no_mangle]
pub extern "C" fn execute_requests_batch_binary_from_owned(ptr: *mut u8, len: usize, cap: usize) -> Buffer {
    if ptr.is_null() || len == 0 || cap < len { return Buffer { ptr: std::ptr::null_mut(), len: 0 }; }

    let requests_bytes = unsafe { Vec::from_raw_parts(ptr, len, cap) };

    let (reply_tx, reply_rx) = unbounded();
    if WORKER_SENDER.send(Job::BatchOwned { requests_bytes, reply: reply_tx }).is_err() {
        return Buffer { ptr: std::ptr::null_mut(), len: 0 };
    }

    match reply_rx.recv() {
        Ok(Some(mut vec)) => {
            let ptr = vec.as_mut_ptr();
            let len = vec.len();
            std::mem::forget(vec);
            Buffer { ptr, len }
        }
        _ => Buffer { ptr: std::ptr::null_mut(), len: 0 },
    }
}

// --- Back-compat functions (old names/signatures). These still perform one copy. ---

#[no_mangle]
pub extern "C" fn execute_request_binary(request_ptr: *const u8, request_len: usize) -> Buffer {
    if request_ptr.is_null() || request_len == 0 {
        return Buffer { ptr: std::ptr::null_mut(), len: 0 };
    }
    let slice = unsafe { std::slice::from_raw_parts(request_ptr, request_len) };
    let mut request_bytes = Vec::with_capacity(request_len);
    request_bytes.extend_from_slice(slice);

    let (reply_tx, reply_rx) = unbounded();
    if WORKER_SENDER.send(Job::SingleCopy { request_bytes, reply: reply_tx }).is_err() {
        return Buffer { ptr: std::ptr::null_mut(), len: 0 };
    }
    match reply_rx.recv() {
        Ok(Some(mut vec)) => {
            let ptr = vec.as_mut_ptr();
            let len = vec.len();
            std::mem::forget(vec);
            Buffer { ptr, len }
        }
        _ => Buffer { ptr: std::ptr::null_mut(), len: 0 },
    }
}

#[no_mangle]
pub extern "C" fn execute_requests_batch_binary(requests_ptr: *const u8, requests_len: usize) -> Buffer {
    if requests_ptr.is_null() || requests_len == 0 {
        return Buffer { ptr: std::ptr::null_mut(), len: 0 };
    }
    let slice = unsafe { std::slice::from_raw_parts(requests_ptr, requests_len) };
    let mut requests_bytes = Vec::with_capacity(requests_len);
    requests_bytes.extend_from_slice(slice);

    let (reply_tx, reply_rx) = unbounded();
    if WORKER_SENDER.send(Job::BatchCopy { requests_bytes, reply: reply_tx }).is_err() {
        return Buffer { ptr: std::ptr::null_mut(), len: 0 };
    }
    match reply_rx.recv() {
        Ok(Some(mut vec)) => {
            let ptr = vec.as_mut_ptr();
            let len = vec.len();
            std::mem::forget(vec);
            Buffer { ptr, len }
        }
        _ => Buffer { ptr: std::ptr::null_mut(), len: 0 },
    }
}

// Free with known capacity (for buffers you allocated via Rust)
#[no_mangle]
pub extern "C" fn free_buffer_with_capacity(ptr: *mut u8, len: usize, cap: usize) {
    if !ptr.is_null() && cap >= len {
        unsafe {
            let buf = Vec::from_raw_parts(ptr, len, cap);
            return_buffer(buf);
        }
    }
}

// Back-compat free (assumes cap == len, safe but loses pooling benefit on big buffers)
#[no_mangle]
pub extern "C" fn free_buffer(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        unsafe {
            let buf = Vec::from_raw_parts(ptr, len, len);
            return_buffer(buf);
        }
    }
}

#[no_mangle]
pub extern "C" fn shutdown_http_client() {
    if let Ok(mut pool) = RESPONSE_BUFFER_POOL.try_lock() {
        pool.clear();
        pool.shrink_to_fit();
    }
}
