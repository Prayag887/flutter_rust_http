import 'package:flutter/material.dart';
import 'package:flutter_rust_http/flutter_rust_http.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'providers/benchmark_provider.dart';
import 'config/app_theme.dart';

void main() {
  FlutterRustHttp.initialize(isolatePoolSize: 2);
  runApp(HTTPBenchmarkApp());
}

class HTTPBenchmarkApp extends StatelessWidget {
  const HTTPBenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BenchmarkProvider(),
      child: MaterialApp(
        title: 'HTTP Benchmark Suite',
        theme: AppTheme.darkTheme,
        home: DashboardScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}