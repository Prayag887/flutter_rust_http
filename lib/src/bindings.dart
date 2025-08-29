import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:ffi/ffi.dart';

// Optimized library loading with platform-specific paths
final DynamicLibrary _lib = (() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open("libflutter_rust_http.so");
  } else if (Platform.isIOS) {
    return DynamicLibrary.process();
  } else if (Platform.isLinux) {
    return DynamicLibrary.open("libflutter_rust_http.so");
  } else if (Platform.isWindows) {
    return DynamicLibrary.open("flutter_rust_http.dll");
  } else if (Platform.isMacOS) {
    return DynamicLibrary.open("libflutter_rust_http.dylib");
  } else {
    return DynamicLibrary.process();
  }
})();

/// Rust Buffer struct - optimized with packed layout
class Buffer extends Struct {
  external Pointer<Uint8> ptr;

  @Uint64()
  external int len;
}

/// FFI bindings - C function signatures
typedef init_http_client_c = Int8 Function();
typedef execute_request_binary_c = Buffer Function(Pointer<Uint8> ptr, Uint64 len);
typedef execute_requests_batch_binary_c = Buffer Function(Pointer<Uint8> ptr, Uint64 len);
typedef free_buffer_c = Void Function(Pointer<Uint8> ptr, Uint64 len);
typedef shutdown_http_client_c = Void Function();

/// Dart-friendly typedefs - optimized for performance
typedef InitHttpClient = bool Function();
typedef ExecuteRequestBinary = Buffer Function(Pointer<Uint8> ptr, int len);
typedef ExecuteRequestsBatchBinary = Buffer Function(Pointer<Uint8> ptr, int len);
typedef FreeBuffer = void Function(Pointer<Uint8> ptr, int len);
typedef ShutdownHttpClient = void Function();

/// Pre-cached function pointers for maximum performance
class _FFICache {
  static late final int Function() _initHttpClientRaw;
  static late final ExecuteRequestBinary _executeRequestBinary;
  static late final ExecuteRequestsBatchBinary _executeRequestsBatchBinary;
  static late final FreeBuffer _freeBuffer;
  static late final ShutdownHttpClient _shutdownHttpClient;

  static bool _initialized = false;

  static void _ensureInitialized() {
    if (!_initialized) {
      _initHttpClientRaw = _lib.lookupFunction<init_http_client_c, int Function()>('init_http_client');
      _executeRequestBinary = _lib.lookupFunction<execute_request_binary_c, ExecuteRequestBinary>('execute_request_binary');
      _executeRequestsBatchBinary = _lib.lookupFunction<execute_requests_batch_binary_c, ExecuteRequestsBatchBinary>('execute_requests_batch_binary');
      _freeBuffer = _lib.lookupFunction<free_buffer_c, FreeBuffer>('free_buffer');
      _shutdownHttpClient = _lib.lookupFunction<shutdown_http_client_c, ShutdownHttpClient>('shutdown_http_client');
      _initialized = true;
    }
  }
}

/// Optimized function wrappers with inline pragmas and caching
@pragma('vm:prefer-inline')
bool initHttpClient() {
  _FFICache._ensureInitialized();
  return _FFICache._initHttpClientRaw() != 0;
}

@pragma('vm:prefer-inline')
Buffer executeRequestBinary(Pointer<Uint8> ptr, int len) {
  _FFICache._ensureInitialized();
  return _FFICache._executeRequestBinary(ptr, len);
}

@pragma('vm:prefer-inline')
Buffer executeRequestsBatchBinary(Pointer<Uint8> ptr, int len) {
  _FFICache._ensureInitialized();
  return _FFICache._executeRequestsBatchBinary(ptr, len);
}

@pragma('vm:prefer-inline')
void freeBuffer(Pointer<Uint8> ptr, int len) {
  _FFICache._ensureInitialized();
  _FFICache._freeBuffer(ptr, len);
}

@pragma('vm:prefer-inline')
void shutdownHttpClient() {
  _FFICache._ensureInitialized();
  _FFICache._shutdownHttpClient();
}