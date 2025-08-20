# flutter_rust_http

A Rust-based HTTP client for Flutter, matching all DIO features with better performance based on Reqwest. Benchmarks will be provided later, this is just a initial release for now.

## Features
- All DIO features (see pub.dev/packages/dio for list).
- HTTP/3 support: Set `httpVersion: '3'` in BaseOptions.
- Usage example:

```dart
import 'package:flutter_rust_http/flutter_rust_http.dart';

final dio = RustHttp(baseUrl: 'https://api.example.com');
dio.interceptors.add(LogInterceptor());

final response = await dio.get('/endpoint');