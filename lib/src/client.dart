import 'dart:async';
import 'dart:convert';
import 'bindings.dart';
import 'models.dart';

// Type registry for mapping Dart types to Rust schema
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

// Enhanced HTTP client with generic support
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

  // Generic request method with type parameter
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
        bool parseInRust = true, // New flag for Rust-side parsing
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
      parseInRust: parseInRust,
    );

    try {
      final isolatePool = _isolatePool;
      if (isolatePool == null) {
        throw Exception('Isolate pool is not initialized. Call FlutterRustHttp.initialize() first.');
      }

      final responseJson = await isolatePool.run<String, String>(
        jsonEncode(request.toJson()),
        isBatch: false,
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
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  // Convenience methods with generic support
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
      parseInRust: parseInRust,
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
      parseInRust: parseInRust,
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
      parseInRust: parseInRust,
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
      parseInRust: parseInRust,
    );
  }

  // Batch request support for multiple concurrent requests
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

// Extension for easy type registration
extension TypeRegistration on FlutterRustHttp {
  static void registerType<T>({
    required String schema,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    TypeRegistry.register<T>(schema, fromJson);
  }
}
