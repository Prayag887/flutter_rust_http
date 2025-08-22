import 'package:flutter/material.dart';

enum HttpClientType {
  rustParsedRust,
  dartParsedRust,
  dioHttp2,
  rustDartInterop,
}

extension HttpClientTypeExtension on HttpClientType {
  String get name {
    switch (this) {
      case HttpClientType.rustParsedRust:
        return 'R -> R';
      case HttpClientType.dartParsedRust:
        return 'R -> D';
      case HttpClientType.dioHttp2:
        return 'D-H2';
      case HttpClientType.rustDartInterop:
        return 'RD-op';
    }
  }

  String get description {
    switch (this) {
      case HttpClientType.rustParsedRust:
        return 'Pure Rust HTTP with Rust-side JSON parsing';
      case HttpClientType.dartParsedRust:
        return 'Rust HTTP with Dart-side JSON parsing';
      case HttpClientType.dioHttp2:
        return 'Dio with HTTP/2 multiplexing';
      case HttpClientType.rustDartInterop:
        return 'Rust HTTP with optimized Dart interop';
    }
  }

  Color get color {
    switch (this) {
      case HttpClientType.rustParsedRust:
        return Colors.green;
      case HttpClientType.dartParsedRust:
        return Colors.lightGreen;
      case HttpClientType.dioHttp2:
        return Colors.blue;
      case HttpClientType.rustDartInterop:
        return Colors.orange;
    }
  }

  IconData get icon {
    switch (this) {
      case HttpClientType.rustParsedRust:
        return Icons.rocket_launch;
      case HttpClientType.dartParsedRust:
        return Icons.speed;
      case HttpClientType.dioHttp2:
        return Icons.network_check;
      case HttpClientType.rustDartInterop:
        return Icons.sync;
    }
  }
}

class BenchmarkMetrics {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final double averageLatency;
  final double p95Latency;
  final double p99Latency;
  final double throughput;
  final double cpuUsage;
  final double memoryUsageMB;
  final List<double> latencyHistory;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, dynamic> additionalMetrics;

  BenchmarkMetrics({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageLatency,
    required this.p95Latency,
    required this.p99Latency,
    required this.throughput,
    required this.cpuUsage,
    required this.memoryUsageMB,
    required this.latencyHistory,
    required this.startTime,
    this.endTime,
    this.additionalMetrics = const {},
  });

  double get successRate => totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0;

  double get errorRate => totalRequests > 0 ? (failedRequests / totalRequests) * 100 : 0;

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  String get grade {
    final score = _calculateScore();
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';
    return 'F';
  }

  Color get gradeColor {
    switch (grade) {
      case 'A+': return Colors.green;
      case 'A': return Colors.lightGreen;
      case 'B': return Colors.yellow;
      case 'C': return Colors.orange;
      case 'D': return Colors.deepOrange;
      default: return Colors.red;
    }
  }

  double _calculateScore() {
    final successWeight = successRate * 0.3;
    final latencyWeight = (1000 / (averageLatency + 1)) * 0.3;
    final throughputWeight = (throughput / 100) * 0.2;
    final cpuWeight = (100 - cpuUsage) * 0.1;
    final memoryWeight = (100 - memoryUsageMB) * 0.1;

    return successWeight + latencyWeight + throughputWeight + cpuWeight + memoryWeight;
  }

  BenchmarkMetrics copyWith({
    int? totalRequests,
    int? successfulRequests,
    int? failedRequests,
    double? averageLatency,
    double? p95Latency,
    double? p99Latency,
    double? throughput,
    double? cpuUsage,
    double? memoryUsageMB,
    List<double>? latencyHistory,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, dynamic>? additionalMetrics,
  }) {
    return BenchmarkMetrics(
      totalRequests: totalRequests ?? this.totalRequests,
      successfulRequests: successfulRequests ?? this.successfulRequests,
      failedRequests: failedRequests ?? this.failedRequests,
      averageLatency: averageLatency ?? this.averageLatency,
      p95Latency: p95Latency ?? this.p95Latency,
      p99Latency: p99Latency ?? this.p99Latency,
      throughput: throughput ?? this.throughput,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memoryUsageMB: memoryUsageMB ?? this.memoryUsageMB,
      latencyHistory: latencyHistory ?? this.latencyHistory,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      additionalMetrics: additionalMetrics ?? this.additionalMetrics,
    );
  }
}

class BenchmarkScenario {
  final String name;
  final String description;
  final IconData icon;
  final String method;
  final String endpoint;
  final Map<String, dynamic>? payload;
  final Map<String, String>? headers;
  final int concurrentRequests;
  final int totalRequests;
  final Duration timeout;
  final bool enableCacheBusting;
  final bool enableComplexParsing;

  const BenchmarkScenario({
    required this.name,
    required this.description,
    required this.icon,
    required this.method,
    required this.endpoint,
    this.payload,
    this.headers,
    required this.concurrentRequests,
    required this.totalRequests,
    this.timeout = const Duration(seconds: 10),
    this.enableCacheBusting = true,
    this.enableComplexParsing = false,
  });
}

class LiveBenchmarkData {
  final HttpClientType clientType;
  final BenchmarkScenario scenario;
  final BenchmarkMetrics currentMetrics;
  final double progress;
  final bool isRunning;
  final String? currentStatus;
  final List<double> realtimeLatencies;
  final List<double> realtimeThroughput;

  LiveBenchmarkData({
    required this.clientType,
    required this.scenario,
    required this.currentMetrics,
    required this.progress,
    required this.isRunning,
    this.currentStatus,
    this.realtimeLatencies = const [],
    this.realtimeThroughput = const [],
  });

  LiveBenchmarkData copyWith({
    HttpClientType? clientType,
    BenchmarkScenario? scenario,
    BenchmarkMetrics? currentMetrics,
    double? progress,
    bool? isRunning,
    String? currentStatus,
    List<double>? realtimeLatencies,
    List<double>? realtimeThroughput,
  }) {
    return LiveBenchmarkData(
      clientType: clientType ?? this.clientType,
      scenario: scenario ?? this.scenario,
      currentMetrics: currentMetrics ?? this.currentMetrics,
      progress: progress ?? this.progress,
      isRunning: isRunning ?? this.isRunning,
      currentStatus: currentStatus ?? this.currentStatus,
      realtimeLatencies: realtimeLatencies ?? this.realtimeLatencies,
      realtimeThroughput: realtimeThroughput ?? this.realtimeThroughput,
    );
  }
}

class BenchmarkAnalysis {
  final List<BenchmarkMetrics> allResults;
  final HttpClientType winner;
  final Map<String, String> comparisons;
  final Map<String, double> rankings;
  final String recommendation;
  final Map<String, List<double>> performanceMatrix;

  BenchmarkAnalysis({
    required this.allResults,
    required this.winner,
    required this.comparisons,
    required this.rankings,
    required this.recommendation,
    required this.performanceMatrix,
  });
}