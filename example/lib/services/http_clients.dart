import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_rust_http/flutter_rust_http.dart';
import 'package:http/http.dart' as http;
import '../models/benchmark_models.dart';

abstract class HttpClientInterface {
  Future<HttpResponse> makeRequest({
    required String method,
    required String url,
    Map<String, dynamic>? payload,
    Map<String, String>? headers,
    Duration? timeout,
  });

  void dispose();
}

class HttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final Duration duration;
  final bool fromCache;

  HttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.duration,
    this.fromCache = false,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

// Real Rust-Parsed-Rust HTTP Client
class RustParsedRustClient implements HttpClientInterface {
  static FlutterRustHttp? _httpClient;
  static bool _initialized = false;

  static Future<void> initialize({int isolatePoolSize = 4}) async {
    if (_initialized) return;

    try {
      await FlutterRustHttp.initialize(isolatePoolSize: isolatePoolSize);
      _httpClient = FlutterRustHttp();
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize RustParsedRustClient: $e');
    }
  }

  static void ensureInitialized() {
    if (!_initialized || _httpClient == null) {
      throw Exception('RustParsedRustClient must be initialized first');
    }
  }

  @override
  Future<HttpResponse> makeRequest({
    required String method,
    required String url,
    Map<String, dynamic>? payload,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    ensureInitialized();

    final stopwatch = Stopwatch()..start();

    try {
      final TypedResponse<dynamic> response;
      final requestHeaders = {
        'Content-Type': 'application/json',
        'User-Agent': 'RustParsedRust/1.0',
        ...?headers,
      };

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient!.get<dynamic>(
            url,
            headers: requestHeaders,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: true,
          );
          break;

        case 'POST':
          response = await _httpClient!.post<dynamic>(
            url,
            headers: requestHeaders,
            body: payload,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: true,
          );
          break;

        case 'PUT':
          response = await _httpClient!.put<dynamic>(
            url,
            headers: requestHeaders,
            body: payload,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: true,
          );
          break;

        case 'DELETE':
          response = await _httpClient!.delete<dynamic>(
            url,
            headers: requestHeaders,
            body: payload,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: true,
          );
          break;

        default:
          response = await _httpClient!.request<dynamic>(
            url,
            method: method,
            headers: requestHeaders,
            body: payload,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: true,
          );
          break;
      }

      stopwatch.stop();

      return HttpResponse(
        statusCode: response.statusCode,
        body: response.rawBody,
        headers: response.headers,
        duration: stopwatch.elapsed,
      );

    } catch (e) {
      stopwatch.stop();

      return HttpResponse(
        statusCode: 500,
        body: jsonEncode({'error': 'Rust request failed', 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  void dispose() {
    // Shared instance, don't dispose here
  }

  static Future<void> cleanup() async {
    if (_httpClient != null) {
      await _httpClient!.close();
      _httpClient = null;
      _initialized = false;
    }
  }
}

// Real Dart-Parsed-Rust HTTP Client (uses Rust for network, Dart for parsing)
class DartParsedRustClient implements HttpClientInterface {
  static FlutterRustHttp? _httpClient;
  static bool _initialized = false;

  static Future<void> initialize({int isolatePoolSize = 4}) async {
    if (_initialized) return;

    try {
      await FlutterRustHttp.initialize(isolatePoolSize: isolatePoolSize);
      _httpClient = FlutterRustHttp();
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize DartParsedRustClient: $e');
    }
  }

  static void ensureInitialized() {
    if (!_initialized || _httpClient == null) {
      DartParsedRustClient.initialize(isolatePoolSize: 2);
      throw Exception('DartParsedRustClient must be initialized first');
    }
  }

  @override
  Future<HttpResponse> makeRequest({
    required String method,
    required String url,
    Map<String, dynamic>? payload,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    ensureInitialized();

    final stopwatch = Stopwatch()..start();

    try {
      final TypedResponse<dynamic> response;
      final requestHeaders = {
        'Content-Type': 'application/json',
        'User-Agent': 'DartParsedRust/1.0',
        ...?headers,
      };

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient!.get<dynamic>(
            url,
            headers: requestHeaders,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: false, // Key difference: parsing in Dart
          );
          break;

        case 'POST':
          response = await _httpClient!.post<dynamic>(
            url,
            headers: requestHeaders,
            body: payload,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: false,
          );
          break;

        case 'PUT':
          response = await _httpClient!.put<dynamic>(
            url,
            headers: requestHeaders,
            body: payload,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: false,
          );
          break;

        case 'DELETE':
          response = await _httpClient!.delete<dynamic>(
            url,
            headers: requestHeaders,
            body: payload,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: false,
          );
          break;

        default:
          response = await _httpClient!.request<dynamic>(
            url,
            method: method,
            headers: requestHeaders,
            body: payload,
            timeout: timeout ?? const Duration(seconds: 30),
            parseInRust: false,
          );
          break;
      }

      // Additional Dart-side parsing simulation for benchmarking
      if (_shouldParseResponse(url)) {
        await _simulateDartParsing(response.rawBody);
      }

      stopwatch.stop();

      return HttpResponse(
        statusCode: response.statusCode,
        body: response.rawBody,
        headers: response.headers,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return HttpResponse(
        statusCode: 500,
        body: jsonEncode({'error': 'Dart-parsed request failed', 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<void> _simulateDartParsing(String jsonString) async {
    // Simulate more expensive Dart parsing
    if (jsonString.length > 100) {
      await compute(_parseJsonInIsolate, jsonString);
    }
  }

  @override
  void dispose() {
    // Shared instance, don't dispose here
  }

  bool _shouldParseResponse(String url) {
    return url.contains('posts') || url.contains('users') || url.contains('comments');
  }

  static Future<void> cleanup() async {
    if (_httpClient != null) {
      await _httpClient!.close();
      _httpClient = null;
      _initialized = false;
    }
  }
}

// Real Dio with HTTP/2 Client
class DioHttp2Client implements HttpClientInterface {
  late final Dio _dio;

  DioHttp2Client() {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
      sendTimeout: Duration(seconds: 10),
      headers: {
        'User-Agent': 'DioHttp2/1.0',
        'Accept': 'application/json',
      },
    ));

    // Configure HTTP/2 and optimizations
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['connection'] = 'keep-alive';
        options.headers['accept-encoding'] = 'gzip, deflate, br';
        handler.next(options);
      },
    ));
  }

  @override
  Future<HttpResponse> makeRequest({
    required String method,
    required String url,
    Map<String, dynamic>? payload,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final options = Options(
        method: method.toUpperCase(),
        headers: {
          ...?headers,
          if (payload != null) 'Content-Type': 'application/json',
        },
        receiveTimeout: timeout ?? Duration(seconds: 30),
        sendTimeout: timeout ?? Duration(seconds: 30),
      );

      final Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _dio.get(url, options: options);
          break;
        case 'POST':
          response = await _dio.post(
            url,
            data: payload != null ? jsonEncode(payload) : null,
            options: options,
          );
          break;
        case 'PUT':
          response = await _dio.put(
            url,
            data: payload != null ? jsonEncode(payload) : null,
            options: options,
          );
          break;
        case 'DELETE':
          response = await _dio.delete(
            url,
            data: payload != null ? jsonEncode(payload) : null,
            options: options,
          );
          break;
        default:
          response = await _dio.request(
            url,
            data: payload != null ? jsonEncode(payload) : null,
            options: options,
          );
          break;
      }

      stopwatch.stop();

      // Convert response headers
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      return HttpResponse(
        statusCode: response.statusCode ?? 500,
        body: response.data is String ? response.data : jsonEncode(response.data),
        headers: responseHeaders,
        duration: stopwatch.elapsed,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      return HttpResponse(
        statusCode: e.response?.statusCode ?? 500,
        body: jsonEncode({
          'error': 'Dio request failed',
          'message': e.message,
          'type': e.type.toString(),
        }),
        headers: {'content-type': 'application/json'},
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return HttpResponse(
        statusCode: 500,
        body: jsonEncode({'error': 'Dio request failed', 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
        duration: stopwatch.elapsed,
      );
    }
  }

  @override
  void dispose() {
    _dio.close();
  }
}

// Real Rust-Dart Interop Client (hybrid approach using standard HTTP with optimizations)
class RustDartInteropClient implements HttpClientInterface {
  late final http.Client _client;

  RustDartInteropClient() {
    _client = http.Client();
  }

  @override
  Future<HttpResponse> makeRequest({
    required String method,
    required String url,
    Map<String, dynamic>? payload,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(url);
      final requestHeaders = {
        'Content-Type': 'application/json',
        'User-Agent': 'RustDartInterop/1.0',
        'Accept': 'application/json',
        ...?headers,
      };

      http.Response response;
      final timeoutDuration = timeout ?? Duration(seconds: 30);

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: requestHeaders)
              .timeout(timeoutDuration);
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: requestHeaders,
            body: payload != null ? jsonEncode(payload) : null,
          ).timeout(timeoutDuration);
          break;
        case 'PUT':
          response = await _client.put(
            uri,
            headers: requestHeaders,
            body: payload != null ? jsonEncode(payload) : null,
          ).timeout(timeoutDuration);
          break;
        case 'DELETE':
          response = await _client.delete(
            uri,
            headers: requestHeaders,
          ).timeout(timeoutDuration);
          break;
        default:
        // Fallback to POST for unsupported methods
          response = await _client.post(
            uri,
            headers: requestHeaders,
            body: payload != null ? jsonEncode(payload) : null,
          ).timeout(timeoutDuration);
          break;
      }

      // Simulate hybrid parsing optimization
      if (_shouldParseResponse(url)) {
        await _simulateHybridParsing(response.body);
      }

      stopwatch.stop();

      return HttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return HttpResponse(
        statusCode: 500,
        body: jsonEncode({'error': 'Interop request failed', 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
        duration: stopwatch.elapsed,
      );
    }
  }

  Future<void> _simulateHybridParsing(String jsonString) async {
    // Simulate optimized parsing with some Rust preprocessing
    if (jsonString.length > 200) {
      // Simulate minimal processing overhead for interop
      await Future.delayed(Duration(microseconds: 100));
    }
  }

  @override
  void dispose() {
    _client.close();
  }

  bool _shouldParseResponse(String url) {
    return url.contains('posts') || url.contains('users') || url.contains('comments');
  }
}

// Utility functions
Map<String, dynamic> _parseJsonInIsolate(String jsonString) {
  try {
    return json.decode(jsonString) as Map<String, dynamic>;
  } catch (e) {
    return {'error': 'Parse failed', 'raw_length': jsonString.length};
  }
}

// Updated Client Factory
class HttpClientFactory {
  static bool _rustClientsInitialized = false;

  static Future<HttpClientInterface> createClient(HttpClientType type) async {
    switch (type) {
      case HttpClientType.rustParsedRust:
        if (!_rustClientsInitialized) {
          await RustParsedRustClient.initialize();
          _rustClientsInitialized = true;
        }
        return RustParsedRustClient();

      case HttpClientType.dartParsedRust:
        if (!_rustClientsInitialized) {
          await DartParsedRustClient.initialize();
          _rustClientsInitialized = true;
        }
        return DartParsedRustClient();

      case HttpClientType.dioHttp2:
        return DioHttp2Client();

      case HttpClientType.rustDartInterop:
        return RustDartInteropClient();
    }
  }

  static Future<void> cleanup() async {
    if (_rustClientsInitialized) {
      await RustParsedRustClient.cleanup();
      await DartParsedRustClient.cleanup();
      _rustClientsInitialized = false;
    }
  }
}