import 'dart:async';
import 'dart:convert';
import 'package:meta/meta.dart';
import 'bindings.dart';
import 'isolate_pool.dart';
import 'models.dart';
import 'exceptions.dart';

class FlutterRustHttp {
  static final FlutterRustHttp _instance = FlutterRustHttp._internal();
  static IsolatePool? _isolatePool;
  static bool _isInitialized = false;

  FlutterRustHttp._internal();

  factory FlutterRustHttp() => _instance;

  static Future<void> initialize({int isolatePoolSize = 4}) async {
    if (_isInitialized) return;

    try {
      // Verify the library can be loaded (but don't actually load it in main isolate, it block ui)
      final canLoadLibrary = await NativeLibrary.verifyLibrary();
      if (!canLoadLibrary) {
        throw Exception('Failed to verify native library');
      }

      // Create isolate pool that will load the library in each worker isolate
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

  Future<HttpResponse> request(
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
    );

    try {
      final isolatePool = _isolatePool!;

      // Use the isolate entry point function that creates its own NativeLibrary
      final responseJson = await isolatePool.run<String, String>(
        isolateHttpRequest, // Use the global function from bindings.dart
        jsonEncode(request.toJson()),
      );

      if (responseJson.isEmpty) {
        throw Exception('Empty response from native library');
      }

      final responseMap = jsonDecode(responseJson);
      return HttpResponse.fromJson(responseMap);
    } catch (e) {
      throw HttpException('Request failed: $e');
    }
  }

  Future<HttpResponse> get(
      String url, {
        Map<String, String> headers = const {},
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
      }) async {
    return request(
      url,
      method: 'GET',
      headers: headers,
      queryParameters: queryParameters,
      timeout: timeout,
    );
  }

  Future<HttpResponse> post(
      String url, {
        Map<String, String> headers = const {},
        dynamic body,
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
      }) async {
    return request(
      url,
      method: 'POST',
      headers: headers,
      body: body,
      queryParameters: queryParameters,
      timeout: timeout,
    );
  }

  Future<HttpResponse> put(
      String url, {
        Map<String, String> headers = const {},
        dynamic body,
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
      }) async {
    return request(
      url,
      method: 'PUT',
      headers: headers,
      body: body,
      queryParameters: queryParameters,
      timeout: timeout,
    );
  }

  Future<HttpResponse> delete(
      String url, {
        Map<String, String> headers = const {},
        dynamic body,
        Map<String, dynamic> queryParameters = const {},
        Duration? timeout,
      }) async {
    return request(
      url,
      method: 'DELETE',
      headers: headers,
      body: body,
      queryParameters: queryParameters,
      timeout: timeout,
    );
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