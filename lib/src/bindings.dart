import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

typedef InitHttpClientFunc = Bool Function();
typedef ExecuteRequestFunc = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FreeStringFunc = Void Function(Pointer<Utf8>);

typedef InitHttpClient = bool Function();
typedef ExecuteRequest = Pointer<Utf8> Function(Pointer<Utf8>);
typedef FreeString = void Function(Pointer<Utf8>);

class NativeLibrary {
  late DynamicLibrary _lib;
  late InitHttpClient _initHttpClient;
  late ExecuteRequest _executeRequest;
  late FreeString _freeString;

  NativeLibrary._();

  // Factory constructor for creating instances in isolates
  static NativeLibrary createForIsolate() {
    final instance = NativeLibrary._();
    instance._lib = _loadLibrary();
    instance._initHttpClient = instance._lib
        .lookup<NativeFunction<InitHttpClientFunc>>('init_http_client')
        .asFunction();
    instance._executeRequest = instance._lib
        .lookup<NativeFunction<ExecuteRequestFunc>>('execute_request')
        .asFunction();
    instance._freeString = instance._lib
        .lookup<NativeFunction<FreeStringFunc>>('free_string')
        .asFunction();

    instance._initHttpClient();
    return instance;
  }

  // Static method for main isolate verification (doesn't actually load the library)
  static Future<bool> verifyLibrary() async {
    try {
      _loadLibrary();
      return true;
    } catch (e) {
      return false;
    }
  }

  static DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libflutter_rust_http.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libflutter_rust_http.so');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libflutter_rust_http.dylib');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('flutter_rust_http.dll');
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  String executeRequest(String requestJson) {
    final requestPtr = requestJson.toNativeUtf8();
    try {
      final responsePtr = _executeRequest(requestPtr);
      final response = responsePtr.toDartString();
      _freeString(responsePtr);
      return response;
    } finally {
      calloc.free(requestPtr);
    }
  }
}

// Isolate entry point function
String isolateHttpRequest(String requestJson) {
  // Each isolate creates its own NativeLibrary instance
  final nativeLib = NativeLibrary.createForIsolate();
  return nativeLib.executeRequest(requestJson);
}