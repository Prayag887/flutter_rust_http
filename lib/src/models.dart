import 'dart:convert';

class HttpRequest {
  final String url;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final Map<String, String> queryParams;
  final int timeoutMs;
  final bool followRedirects;
  final int maxRedirects;
  final int connectTimeoutMs;
  final int readTimeoutMs;
  final int writeTimeoutMs;
  final bool autoReferer;
  final bool decompress;
  final bool http3Only;

  HttpRequest({
    required this.url,
    required this.method,
    this.headers = const {},
    this.body,
    this.queryParams = const {},
    this.timeoutMs = 30000,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.connectTimeoutMs = 10000,
    this.readTimeoutMs = 30000,
    this.writeTimeoutMs = 30000,
    this.autoReferer = true,
    this.decompress = true,
    this.http3Only = false,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'method': method,
    'headers': headers,
    'body': body,
    'query_params': queryParams,
    'timeout_ms': timeoutMs,
    'follow_redirects': followRedirects,
    'max_redirects': maxRedirects,
    'connect_timeout_ms': connectTimeoutMs,
    'read_timeout_ms': readTimeoutMs,
    'write_timeout_ms': writeTimeoutMs,
    'auto_referer': autoReferer,
    'decompress': decompress,
    'http3_only': http3Only,
  };
}

class HttpResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final String version;
  final String url;
  final int elapsedMs;

  HttpResponse({
    required this.statusCode,
    this.headers = const {},
    this.body = '',
    this.version = '1.1',
    this.url = '',
    this.elapsedMs = 0,
  });

  factory HttpResponse.fromJson(Map<String, dynamic> json) => HttpResponse(
    statusCode: json['status_code'] ?? 0,
    headers: Map<String, String>.from(json['headers'] ?? {}),
    body: json['body'] ?? '',
    version: json['version'] ?? '1.1',
    url: json['url'] ?? '',
    elapsedMs: json['elapsed_ms'] ?? 0,
  );

  dynamic get json {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

class HttpError {
  final String code;
  final String message;
  final dynamic details;

  HttpError({
    required this.code,
    required this.message,
    this.details,
  });

  factory HttpError.fromJson(Map<String, dynamic> json) => HttpError(
    code: json['code'] ?? '',
    message: json['message'] ?? '',
    details: json['details'],
  );
}
