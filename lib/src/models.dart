import 'dart:convert';

enum RequestPriority {
  high,
  normal,
  low,
}

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
  final bool parseInRust;
  final RequestPriority priority;

  HttpRequest({
    required this.url,
    required this.method,
    required this.headers,
    this.body,
    required this.queryParams,
    required this.timeoutMs,
    required this.followRedirects,
    required this.maxRedirects,
    required this.connectTimeoutMs,
    required this.readTimeoutMs,
    required this.writeTimeoutMs,
    required this.autoReferer,
    required this.decompress,
    required this.http3Only,
    required this.parseInRust,
    this.priority = RequestPriority.normal,
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
    'parse_response': parseInRust,
    'http3_only': http3Only,
    'priority': _priorityToRustString(priority),
  };

  String _priorityToRustString(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.high:
        return "High";
      case RequestPriority.normal:
        return "Normal";
      case RequestPriority.low:
        return "Low";
    }
  }
}

class HttpResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final String version;
  final String url;
  final int elapsedMs;
  final dynamic parsedData;

  HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.version,
    required this.url,
    required this.elapsedMs,
    required this.parsedData,
  });

  factory HttpResponse.fromJson(Map<String, dynamic> json) => HttpResponse(
    statusCode: json['status_code'],
    headers: Map<String, String>.from(json['headers']),
    body: json['body'],
    version: json['version'],
    url: json['url'],
    elapsedMs: json['elapsed_ms'],
    parsedData: json['parsedData'],
  );

  dynamic get json => jsonDecode(body);
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
    code: json['code'],
    message: json['message'],
    details: json['details'],
  );
}
