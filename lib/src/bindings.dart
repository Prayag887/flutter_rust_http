import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert'; // Add this import
import 'package:ffi/ffi.dart';

// Add this custom exception class
class RustHttpException implements Exception {
  final String message;

  RustHttpException(this.message);

  @override
  String toString() => 'RustHttpException: $message';
}

typedef InitHttpClientFunc = Bool Function();
typedef ExecuteRequestFunc = Pointer<Utf8> Function(Pointer<Utf8>);
typedef ExecuteBatchRequestsFunc = Pointer<Utf8> Function(Pointer<Utf8>); // Add this
typedef FreeStringFunc = Void Function(Pointer<Utf8>);

typedef InitHttpClient = bool Function();
typedef ExecuteRequest = Pointer<Utf8> Function(Pointer<Utf8>);
typedef ExecuteBatchRequests = Pointer<Utf8> Function(Pointer<Utf8>); // Add this
typedef FreeString = void Function(Pointer<Utf8>);

class NativeLibrary {
  late DynamicLibrary _lib;
  late InitHttpClient _initHttpClient;
  late ExecuteRequest _executeRequest;
  late ExecuteBatchRequests _executeBatchRequests; // Add this
  late FreeString _freeString;

  NativeLibrary._();

  static NativeLibrary createForIsolate() {
    final instance = NativeLibrary._();
    instance._lib = _loadLibrary();
    instance._initHttpClient = instance._lib
        .lookup<NativeFunction<InitHttpClientFunc>>('init_http_client')
        .asFunction();
    instance._executeRequest = instance._lib
        .lookup<NativeFunction<ExecuteRequestFunc>>('execute_request')
        .asFunction();
    instance._executeBatchRequests = instance._lib // Add this
        .lookup<NativeFunction<ExecuteBatchRequestsFunc>>('execute_batch_requests')
        .asFunction();
    instance._freeString = instance._lib
        .lookup<NativeFunction<FreeStringFunc>>('free_string')
        .asFunction();

    instance._initHttpClient();
    return instance;
  }

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

      // Check if response is an error
      final responseMap = jsonDecode(response);
      if (responseMap is Map<String, dynamic> && responseMap.containsKey('error')) {
        throw RustHttpException(responseMap['error']);
      }

      return response;
    } finally {
      calloc.free(requestPtr);
    }
  }

  // Add this method for batch requests
  String executeBatchRequests(String requestsJson) {
    final requestPtr = requestsJson.toNativeUtf8();
    try {
      final responsePtr = _executeBatchRequests(requestPtr);
      final response = responsePtr.toDartString();
      _freeString(responsePtr);

      // Check if response is an error
      final responseMap = jsonDecode(response);
      if (responseMap is Map<String, dynamic> && responseMap.containsKey('error')) {
        throw RustHttpException(responseMap['error']);
      }

      return response;
    } finally {
      calloc.free(requestPtr);
    }
  }
}

String isolateHttpRequest(String requestJson) {
  final nativeLib = NativeLibrary.createForIsolate();
  return nativeLib.executeRequest(requestJson);
}

// Add this function for batch requests
String isolateBatchRequests(String requestsJson) {
  final nativeLib = NativeLibrary.createForIsolate();
  return nativeLib.executeBatchRequests(requestsJson);
}