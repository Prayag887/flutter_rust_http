import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'providers/benchmark_provider.dart';
import 'config/app_theme.dart';

void main() {
  runApp(HTTPBenchmarkApp());
}

class HTTPBenchmarkApp extends StatelessWidget {
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