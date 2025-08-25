// NEW: Dart DL API (minimal subset)
// Put near your other `use` lines
use std::os::raw::{c_int, c_void};
use std::sync::atomic::{AtomicI64, AtomicUsize, Ordering};

// ---- Dart DL FFI ----
#[repr(C)]
#[derive(Copy, Clone)]
pub enum Dart_CObject_Type {
    Dart_CObject_kNull = 0,
    Dart_CObject_kBool = 1,
    Dart_CObject_kInt32 = 2,
    Dart_CObject_kInt64 = 3,
    Dart_CObject_kDouble = 4,
    Dart_CObject_kString = 5,
    Dart_CObject_kArray = 6,
    Dart_CObject_kTypedData = 7,
    Dart_CObject_kExternalTypedData = 8,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub enum Dart_TypedData_Type {
    Dart_TypedData_kInt8 = 0,
    Dart_TypedData_kUint8 = 1,
    // (add more if you need them)
}

#[repr(C)]
pub struct Dart_CObject {
    pub type_: Dart_CObject_Type,
    pub value: Dart_CObject_Value,
}

#[repr(C)]
pub union Dart_CObject_Value {
    pub as_int64: i64,
    pub as_array: Dart_CObject_Array,
    pub as_typed_data: Dart_CObject_TypedData,
}

#[repr(C)]
pub struct Dart_CObject_Array {
    pub length: isize,
    pub values: *mut *mut Dart_CObject,
}

#[repr(C)]
pub struct Dart_CObject_TypedData {
    pub type_: Dart_TypedData_Type,
    pub length: isize,
    pub values: *mut u8,
}

// Signatures provided by the Dart VM (via DL)
extern "C" {
    fn Dart_InitializeApiDL(data: *mut c_void) -> isize;
    fn Dart_PostCObject_DL(port_id: i64, message: *const Dart_CObject) -> bool;
}

// Global SendPort for posting results back to Dart.
// Relaxed is fine; we only need atomic set/get.
static DART_PORT: AtomicI64 = AtomicI64::new(0);

// NEW: Called from Dart once on startup
#[no_mangle]
pub extern "C" fn register_dart_api_dl(init_data: *mut c_void) -> bool {
    unsafe { Dart_InitializeApiDL(init_data) == 0 }
}

// NEW: Called from Dart to give us the SendPort (as int64)
#[no_mangle]
pub extern "C" fn register_send_port(port: i64) {
    DART_PORT.store(port, Ordering::Relaxed);
}
