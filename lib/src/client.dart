import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_rust_http/flutter_rust_http.dart';
import 'package:http/http.dart' as http;
import 'bindings.dart';
import 'isolate_pool.dart';
import 'models.dart';

// FFI bindings for direct memory access
final DynamicLibrary nativeLib = DynamicLibrary.open("libflutter_rust_http.so");

final Pointer<SharedBuffer> Function(int size) allocateBuffer = nativeLib
    .lookup<NativeFunction<Pointer<SharedBuffer> Function(IntPtr)>>('allocate_buffer')
    .asFunction();

final void Function(Pointer<SharedBuffer> buffer) freeBuffer = nativeLib
    .lookup<NativeFunction<Void Function(Pointer<SharedBuffer>)>>('free_buffer')
    .asFunction();

final int Function(Pointer<Utf8> requestJson, Pointer<SharedBuffer> responseBuffer)
executeRequestDirect = nativeLib
    .lookup<NativeFunction<Int32 Function(Pointer<Utf8>, Pointer<SharedBuffer>)>>(
    'execute_request_direct')
    .asFunction();

// SharedBuffer structure for FFI - Updated syntax
class SharedBuffer extends Struct {
  external Pointer<Uint8> data;

  @IntPtr()
  external int len;

  @IntPtr()
  external int capacity;

  Uint8List toUint8List() {
    return data.asTypedList(len);
  }
}

// Generic response wrapper
class TypedResponse<T> {
  final int statusCode;
  final Map<String, String> headers;
  final T? data;
  final String rawBody;
  final String version;
  final String url;
  final int elapsedMs;

  TypedResponse({
    required this.statusCode,
    required this.headers,
    this.data,
    required this.rawBody,
    required this.version,
    required this.url,
    required this.elapsedMs,
  });
}

class TypeRegistry {
  static final Map<Type, String> _typeSchemas = {};
  static final Map<Type, Function> _deserializers = {};

  static void register<T>(String schema, T Function(Map<String, dynamic>) deserializer) {
    _typeSchemas[T] = schema;
    _deserializers[T] = deserializer;
  }

  static String? getSchema(Type type) => _typeSchemas[type];
  static Function? getDeserializer(Type type) => _deserializers[type];
}


// Missing utility functions
class NativeLibrary {
  static Future<bool> verifyLibrary() async {
    try {
      // Try to load the library - basic verification
      DynamicLibrary.open("libflutter_rust_http.so");
      return true;
    } catch (e) {
      return false;
    }
  }
}

String isolateHttpRequest(String requestJson) {
  // This should be implemented in your bindings
  throw UnimplementedError('isolateHttpRequest must be implemented');
}

// Enhanced HTTP client with direct memory access
class FlutterRustHttp {
  static final FlutterRustHttp _instance = FlutterRustHttp._internal();
  static IsolatePool? _isolatePool;
  static bool _isInitialized = false;

  FlutterRustHttp._internal();

  factory FlutterRustHttp() => _instance;

  static Future<void> initialize({int isolatePoolSize = 4}) async {
    if (_isInitialized) return;

    try {
      final canLoadLibrary = await NativeLibrary.verifyLibrary();
      if (!canLoadLibrary) {
        throw Exception('Failed to verify native library');
      }

      _isolatePool = IsolatePool(isolatePoolSize);
      await _isolatePool!.initialize();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  static void ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('FlutterRustHttp must be initialized first');
    }
    if (_isolatePool == null) {
      throw Exception('Isolate pool not initialized');
    }
  }

  // Generic request method with direct memory access
  Future<TypedResponse<T>> request<T>(
      String url, {
        String method = 'GET',
        Map<String, String> headers = const {},
        dynamic body,
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
        bool followRedirects = true,
        int maxRedirects = 5,
        Duration? connectTimeout,
        Duration? readTimeout,
        Duration? writeTimeout,
        bool autoReferer = true,
        bool decompress = true,
        bool http3Only = false,
        bool useDirectMemory = true,
        bool parseInRust = true
      }) async {
    ensureInitialized();

    final request = HttpRequest(
        url: url,
        method: method,
        headers: headers,
        body: body is String ? body : body != null ? jsonEncode(body) : null,
        queryParams: queryParameters.map((key, value) => MapEntry(key, value.toString())),
        timeoutMs: timeout?.inMilliseconds ?? 30000,
        followRedirects: followRedirects,
        maxRedirects: maxRedirects,
        connectTimeoutMs: connectTimeout?.inMilliseconds ?? 10000,
        readTimeoutMs: readTimeout?.inMilliseconds ?? 30000,
        writeTimeoutMs: writeTimeout?.inMilliseconds ?? 30000,
        autoReferer: autoReferer,
        decompress: decompress,
        http3Only: http3Only,
        parseInRust: parseInRust
    );

    try {
      final isolatePool = _isolatePool;
      if (isolatePool == null) {
        throw Exception('Isolate pool is not initialized. Call FlutterRustHttp.initialize() first.');
      }

      if (useDirectMemory) {
        // Use direct memory access for maximum performance
        return await _executeRequestDirect<T>(request);
      } else {
        // Fallback to traditional JSON approach
        return await _executeRequestJson<T>(request);
      }
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  // Direct memory access implementation
  Future<TypedResponse<T>> _executeRequestDirect<T>(HttpRequest request) async {
    final requestJson = jsonEncode(request.toJson());
    final requestPtr = requestJson.toNativeUtf8();

    // Allocate buffer for response (64KB initial size, can be adjusted)
    const initialBufferSize = 64 * 1024;
    final bufferPtr = allocateBuffer(initialBufferSize);

    try {
      // Execute request with direct memory access
      final result = executeRequestDirect(requestPtr, bufferPtr);

      if (result != 0) {
        throw Exception('Request failed with error code: $result');
      }

      // Read response from shared memory
      final buffer = bufferPtr.ref;
      final responseData = buffer.toUint8List();
      final responseJson = utf8.decode(responseData);

      // Parse response
      final responseMap = jsonDecode(responseJson);
      final response = HttpResponse.fromJson(responseMap);

      // Parse the typed data if available
      T? typedData;
      if (response.parsedData != null && T != dynamic && T != Null) {
        final deserializer = TypeRegistry.getDeserializer(T);
        if (deserializer != null) {
          typedData = deserializer(response.parsedData) as T;
        }
      }

      return TypedResponse<T>(
        statusCode: response.statusCode,
        headers: response.headers,
        data: typedData,
        rawBody: response.body,
        version: response.version,
        url: response.url,
        elapsedMs: response.elapsedMs,
      );
    } finally {
      // Always free allocated memory
      malloc.free(requestPtr);
      freeBuffer(bufferPtr);
    }
  }

  // Traditional JSON implementation (fallback)
  Future<TypedResponse<T>> _executeRequestJson<T>(HttpRequest request) async {
    final isolatePool = _isolatePool!;
    final responseJson = await isolatePool.run<String, String>(
      isolateHttpRequest,
      jsonEncode(request.toJson()),
    );

    if (responseJson.isEmpty) {
      throw Exception('Empty response from native library');
    }

    final responseMap = jsonDecode(responseJson);
    final response = HttpResponse.fromJson(responseMap);

    // Parse the typed data if available
    T? typedData;
    if (response.parsedData != null && T != dynamic && T != Null) {
      final deserializer = TypeRegistry.getDeserializer(T);
      if (deserializer != null) {
        typedData = deserializer(response.parsedData) as T;
      }
    }

    return TypedResponse<T>(
      statusCode: response.statusCode,
      headers: response.headers,
      data: typedData,
      rawBody: response.body,
      version: response.version,
      url: response.url,
      elapsedMs: response.elapsedMs,
    );
  }

  // Convenience methods (unchanged, but will use direct memory by default)
  Future<TypedResponse<T>> get<T>(
      String url, {
        Map<String, String> headers = const {},
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
        bool parseInRust = true,
      }) async {
    return request<T>(
      url,
      method: 'GET',
      headers: headers,
      queryParameters: queryParameters,
      timeout: timeout,
      useDirectMemory: parseInRust,
    );
  }

  Future<TypedResponse<T>> post<T>(
      String url, {
        Map<String, String> headers = const {},
        dynamic body,
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
        bool parseInRust = true,
      }) async {
    return request<T>(
      url,
      method: 'POST',
      headers: headers,
      body: body,
      queryParameters: queryParameters,
      timeout: timeout,
      useDirectMemory: parseInRust,
    );
  }

  Future<TypedResponse<T>> put<T>(
      String url, {
        Map<String, String> headers = const {},
        dynamic body,
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
        bool parseInRust = true,
      }) async {
    return request<T>(
      url,
      method: 'PUT',
      headers: headers,
      body: body,
      queryParameters: queryParameters,
      timeout: timeout,
      useDirectMemory: parseInRust,
    );
  }

  Future<TypedResponse<T>> delete<T>(
      String url, {
        Map<String, String> headers = const {},
        dynamic body,
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
        bool parseInRust = true,
      }) async {
    return request<T>(
      url,
      method: 'DELETE',
      headers: headers,
      body: body,
      queryParameters: queryParameters,
      timeout: timeout,
      useDirectMemory: parseInRust,
    );
  }

  // Batch request support with direct memory access
  Future<List<TypedResponse<T>>> batchGet<T>(
      List<String> urls, {
        Map<String, String> headers = const {},
        Duration? timeout,
        bool parseInRust = true,
      }) async {
    final futures = urls.map((url) => get<T>(
      url,
      headers: headers,
      timeout: timeout,
      parseInRust: parseInRust,
    ));

    return Future.wait(futures);
  }

  Future<void> close() async {
    final isolatePool = _isolatePool;
    if (isolatePool != null) {
      await isolatePool.close();
      _isolatePool = null;
    }
    _isInitialized = false;
  }
}