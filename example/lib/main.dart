import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PerformanceMetrics {
  final Map<int, TestResult> testResults;
  final DateTime timestamp;
  final TestConfiguration config;

  PerformanceMetrics({
    required this.testResults,
    required this.timestamp,
    required this.config,
  });
}

class TestResult {
  final List<int> latencies; // ms per request
  final double mean;
  final double median;
  final double p50;
  final double p90;
  final double p95;
  final double p99;
  final double min;
  final double max;
  final double stdDev;
  final double throughput; // requests per second
  final int totalRequests;
  final int errorCount;
  final double errorRate;
  final ResourceUtilization resources;

  TestResult({
    required this.latencies,
    required this.mean,
    required this.median,
    required this.p50,
    required this.p90,
    required this.p95,
    required this.p99,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.throughput,
    required this.totalRequests,
    required this.errorCount,
    required this.errorRate,
    required this.resources,
  });
}

class ResourceUtilization {
  final double cpuUsage; // percentage
  final double memoryUsage; // MB
  final double networkIO; // MB/s

  ResourceUtilization({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.networkIO,
  });
}

class TestConfiguration {
  final int payloadSize; // bytes
  final int concurrentUsers;
  final Duration testDuration;
  final String networkCondition;

  TestConfiguration({
    required this.payloadSize,
    required this.concurrentUsers,
    required this.testDuration,
    required this.networkCondition,
  });
}

class BenchmarkOutcome {
  final PerformanceMetrics dioPerformance;
  final PerformanceMetrics rustPerformance;
  final ComparisonAnalysis comparison;

  BenchmarkOutcome({
    required this.dioPerformance,
    required this.rustPerformance,
    required this.comparison,
  });
}

class ComparisonAnalysis {
  final double latencyImprovement; // percentage
  final double throughputImprovement; // percentage
  final String recommendation;
  final bool isSignificant;
  final double confidenceLevel;

  ComparisonAnalysis({
    required this.latencyImprovement,
    required this.throughputImprovement,
    required this.recommendation,
    required this.isSignificant,
    required this.confidenceLevel,
  });
}

/// ---------------------------
/// Enhanced Dashboard
/// ---------------------------
class BenchmarkDashboard extends StatefulWidget {
  const BenchmarkDashboard({super.key});

  @override
  State<BenchmarkDashboard> createState() => _BenchmarkDashboardState();
}

class _BenchmarkDashboardState extends State<BenchmarkDashboard> {
  final StreamController<BenchmarkOutcome> _controller =
  StreamController.broadcast();

  Timer? _timer;
  int counter = 0;
  final List<BenchmarkOutcome> _history = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Simulated benchmark stream
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      counter++;

      final config = TestConfiguration(
        payloadSize: 1024 + _random.nextInt(2048),
        concurrentUsers: 10 + _random.nextInt(20),
        testDuration: const Duration(seconds: 10),
        networkCondition: ["WiFi", "4G", "5G"][_random.nextInt(3)],
      );

      final dioResults = {
        0: _generateTestResult("dio", config),
      };

      final rustResults = {
        0: _generateTestResult("rust", config),
      };

      final dioMetrics = PerformanceMetrics(
        testResults: dioResults,
        timestamp: DateTime.now(),
        config: config,
      );

      final rustMetrics = PerformanceMetrics(
        testResults: rustResults,
        timestamp: DateTime.now(),
        config: config,
      );

      final comparison = _generateComparison(
        dioResults[0]!,
        rustResults[0]!,
      );

      final outcome = BenchmarkOutcome(
        dioPerformance: dioMetrics,
        rustPerformance: rustMetrics,
        comparison: comparison,
      );

      _history.add(outcome);
      if (_history.length > 100) {
        _history.removeAt(0);
      }

      _controller.add(outcome);
    });
  }

  TestResult _generateTestResult(String client, TestConfiguration config) {
    final random = Random();

    // Generate more realistic latencies based on client
    final baseLatency = client == "dio" ? 180 + random.nextInt(80) : 100 + random.nextInt(60);
    final latencies = List<int>.generate(50, (_) {
      // Add some outliers occasionally
      if (random.nextDouble() < 0.05) {
        return baseLatency + random.nextInt(500) + 200; // Outlier
      }
      return baseLatency + random.nextInt(100);
    });

    final sorted = List<int>.from(latencies)..sort();
    final mean = latencies.reduce((a, b) => a + b) / latencies.length;
    final median = sorted[sorted.length ~/ 2].toDouble();

    // Calculate percentiles
    final p50 = sorted[(sorted.length * 0.5).floor()].toDouble();
    final p90 = sorted[(sorted.length * 0.9).floor()].toDouble();
    final p95 = sorted[(sorted.length * 0.95).floor()].toDouble();
    final p99 = sorted[(sorted.length * 0.99).floor()].toDouble();

    final min = sorted.first.toDouble();
    final max = sorted.last.toDouble();

    final variance = latencies.map((l) => pow(l - mean, 2)).reduce((a, b) => a + b) / latencies.length;
    final stdDev = sqrt(variance);

    // Calculate throughput (requests per second)
    final avgLatencySeconds = mean / 1000;
    final throughput = config.concurrentUsers / avgLatencySeconds;

    // Simulate errors
    final errorCount = random.nextInt(3);
    final errorRate = errorCount / latencies.length * 100;

    // Simulate resource usage
    final resources = ResourceUtilization(
      cpuUsage: 20 + random.nextDouble() * 60,
      memoryUsage: 50 + random.nextDouble() * 200,
      networkIO: 1 + random.nextDouble() * 10,
    );

    return TestResult(
      latencies: latencies,
      mean: mean,
      median: median,
      p50: p50,
      p90: p90,
      p95: p95,
      p99: p99,
      min: min,
      max: max,
      stdDev: stdDev,
      throughput: throughput,
      totalRequests: latencies.length,
      errorCount: errorCount,
      errorRate: errorRate,
      resources: resources,
    );
  }

  ComparisonAnalysis _generateComparison(TestResult dio, TestResult rust) {
    final latencyImprovement = ((dio.mean - rust.mean) / dio.mean * 100);
    final throughputImprovement = ((rust.throughput - dio.throughput) / dio.throughput * 100);

    String recommendation;
    if (latencyImprovement > 15 && throughputImprovement > 10) {
      recommendation = "Rust shows significant performance advantage";
    } else if (latencyImprovement > 5) {
      recommendation = "Rust has moderate latency advantage";
    } else if (latencyImprovement < -5) {
      recommendation = "Dio performing better in current test";
    } else {
      recommendation = "Performance is comparable between clients";
    }

    final isSignificant = latencyImprovement.abs() > 10;
    final confidenceLevel = 85 + _random.nextDouble() * 10;

    return ComparisonAnalysis(
      latencyImprovement: latencyImprovement,
      throughputImprovement: throughputImprovement,
      recommendation: recommendation,
      isSignificant: isSignificant,
      confidenceLevel: confidenceLevel,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enhanced Benchmark Dashboard"),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<BenchmarkOutcome>(
        stream: _controller.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final result = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Performance Overview Cards
                PerformanceOverviewCards(outcome: result),

                // Historical Performance Chart
                SizedBox(
                  height: 300,
                  child: HistoricalPerformanceChart(history: _history),
                ),

                // Latency Distribution Histogram
                SizedBox(
                  height: 250,
                  child: LatencyHistogramChart(outcome: result),
                ),

                // Live Latency Line Chart
                SizedBox(
                  height: 300,
                  child: LatencyLineChart(
                    dioMetrics: result.dioPerformance,
                    rustMetrics: result.rustPerformance,
                  ),
                ),

                // Resource Utilization Chart
                SizedBox(
                  height: 200,
                  child: ResourceUtilizationChart(outcome: result),
                ),

                // Enhanced Performance Summary
                EnhancedPerformanceSummaryCard(
                  outcome: result,
                  runNumber: counter,
                ),

                // Test Configuration Card
                TestConfigurationCard(config: result.dioPerformance.config),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ---------------------------
/// Performance Overview Cards
/// ---------------------------
class PerformanceOverviewCards extends StatelessWidget {
  final BenchmarkOutcome outcome;

  const PerformanceOverviewCards({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final dio = outcome.dioPerformance.testResults[0]!;
    final rust = outcome.rustPerformance.testResults[0]!;
    final comparison = outcome.comparison;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              "Latency Improvement",
              "${comparison.latencyImprovement.toStringAsFixed(1)}%",
              comparison.latencyImprovement > 0 ? Colors.green : Colors.red,
              Icons.speed,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              "Throughput",
              "${rust.throughput.toStringAsFixed(0)} req/s",
              Colors.blue,
              Icons.trending_up,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricCard(
              "Error Rate",
              "${rust.errorRate.toStringAsFixed(1)}%",
              rust.errorRate < dio.errorRate ? Colors.green : Colors.orange,
              Icons.error_outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------
/// Historical Performance Chart
/// ---------------------------
class HistoricalPerformanceChart extends StatelessWidget {
  final List<BenchmarkOutcome> history;

  const HistoricalPerformanceChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox();

    final dioSpots = <FlSpot>[];
    final rustSpots = <FlSpot>[];

    for (int i = 0; i < history.length; i++) {
      final dio = history[i].dioPerformance.testResults[0]!;
      final rust = history[i].rustPerformance.testResults[0]!;

      dioSpots.add(FlSpot(i.toDouble(), dio.mean));
      rustSpots.add(FlSpot(i.toDouble(), rust.mean));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Historical Performance Trends",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}ms');
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: dioSpots,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: rustSpots,
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 3,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  const Text("Dio"),
                  const SizedBox(width: 16),
                  Container(
                    width: 16,
                    height: 3,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  const Text("Rust"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Latency Histogram Chart
/// ---------------------------
class LatencyHistogramChart extends StatelessWidget {
  final BenchmarkOutcome outcome;

  const LatencyHistogramChart({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final dio = outcome.dioPerformance.testResults[0]!;
    final rust = outcome.rustPerformance.testResults[0]!;

    // Create histogram bins
    final allLatencies = [...dio.latencies, ...rust.latencies];
    final minLat = allLatencies.reduce(min);
    final maxLat = allLatencies.reduce(max);
    final binCount = 10;
    final binSize = (maxLat - minLat) / binCount;

    final dioBins = List<int>.filled(binCount, 0);
    final rustBins = List<int>.filled(binCount, 0);

    for (final lat in dio.latencies) {
      final binIndex = ((lat - minLat) / binSize).floor().clamp(0, binCount - 1);
      dioBins[binIndex]++;
    }

    for (final lat in rust.latencies) {
      final binIndex = ((lat - minLat) / binSize).floor().clamp(0, binCount - 1);
      rustBins[binIndex]++;
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < binCount; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dioBins[i].toDouble(),
              color: Colors.blue.withOpacity(0.7),
              width: 12,
            ),
            BarChartRodData(
              toY: rustBins[i].toDouble(),
              color: Colors.orange.withOpacity(0.7),
              width: 12,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Latency Distribution",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    barGroups: barGroups,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final binStart = minLat + (value * binSize);
                            return Text('${binStart.toInt()}');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Enhanced Line Chart
/// ---------------------------
class LatencyLineChart extends StatelessWidget {
  final PerformanceMetrics dioMetrics;
  final PerformanceMetrics rustMetrics;
  final int windowSize;

  const LatencyLineChart({
    super.key,
    required this.dioMetrics,
    required this.rustMetrics,
    this.windowSize = 50,
  });

  @override
  Widget build(BuildContext context) {
    final dioPoints = <FlSpot>[];
    final rustPoints = <FlSpot>[];

    int i = 0;
    for (final res in dioMetrics.testResults.values) {
      for (final lat in res.latencies) {
        dioPoints.add(FlSpot(i.toDouble(), lat.toDouble()));
        i++;
      }
    }

    i = 0;
    for (final res in rustMetrics.testResults.values) {
      for (final lat in res.latencies) {
        rustPoints.add(FlSpot(i.toDouble(), lat.toDouble()));
        i++;
      }
    }

    final maxY = [
      ...dioPoints.map((p) => p.y),
      ...rustPoints.map((p) => p.y),
    ].fold<double>(0, max);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Live Latency Measurements",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 20),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}');
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    minY: 0,
                    maxY: maxY * 1.1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: dioPoints,
                        isCurved: false,
                        color: Colors.blueAccent,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: rustPoints,
                        isCurved: false,
                        color: Colors.deepOrange,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                    lineTouchData: LineTouchData(enabled: false),
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Resource Utilization Chart
/// ---------------------------
class ResourceUtilizationChart extends StatelessWidget {
  final BenchmarkOutcome outcome;

  const ResourceUtilizationChart({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final dioResources = outcome.dioPerformance.testResults[0]!.resources;
    final rustResources = outcome.rustPerformance.testResults[0]!.resources;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Resource Utilization",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text("CPU Usage"),
                          const SizedBox(height: 8),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  BarChartGroupData(
                                    x: 0,
                                    barRods: [
                                      BarChartRodData(
                                        toY: dioResources.cpuUsage,
                                        color: Colors.blue,
                                        width: 30,
                                      ),
                                    ],
                                  ),
                                  BarChartGroupData(
                                    x: 1,
                                    barRods: [
                                      BarChartRodData(
                                        toY: rustResources.cpuUsage,
                                        color: Colors.orange,
                                        width: 30,
                                      ),
                                    ],
                                  ),
                                ],
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(value == 0 ? 'Dio' : 'Rust');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                maxY: 100,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Memory (MB)"),
                          const SizedBox(height: 8),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  BarChartGroupData(
                                    x: 0,
                                    barRods: [
                                      BarChartRodData(
                                        toY: dioResources.memoryUsage,
                                        color: Colors.blue,
                                        width: 30,
                                      ),
                                    ],
                                  ),
                                  BarChartGroupData(
                                    x: 1,
                                    barRods: [
                                      BarChartRodData(
                                        toY: rustResources.memoryUsage,
                                        color: Colors.orange,
                                        width: 30,
                                      ),
                                    ],
                                  ),
                                ],
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(value == 0 ? 'Dio' : 'Rust');
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                maxY: 300,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Enhanced Summary Card
/// ---------------------------
class EnhancedPerformanceSummaryCard extends StatelessWidget {
  final BenchmarkOutcome outcome;
  final int runNumber;

  const EnhancedPerformanceSummaryCard({
    super.key,
    required this.outcome,
    required this.runNumber,
  });

  @override
  Widget build(BuildContext context) {
    final dio = outcome.dioPerformance.testResults[0]!;
    final rust = outcome.rustPerformance.testResults[0]!;
    final comparison = outcome.comparison;

    return Card(
      margin: const EdgeInsets.all(16),
      child: ExpansionTile(
        title: Text("Run #$runNumber - Detailed Analysis"),
        subtitle: Text(
          comparison.recommendation,
          style: TextStyle(
            color: comparison.isSignificant ? Colors.green : Colors.orange,
          ),
        ),
        children: [
          // Percentiles Comparison
          _buildSectionHeader("Latency Percentiles"),
          _buildComparisonRow("Mean", "${dio.mean.toStringAsFixed(1)} ms", "${rust.mean.toStringAsFixed(1)} ms"),
          _buildComparisonRow("Median", "${dio.median.toStringAsFixed(1)} ms", "${rust.median.toStringAsFixed(1)} ms"),
          _buildComparisonRow("P90", "${dio.p90.toStringAsFixed(1)} ms", "${rust.p90.toStringAsFixed(1)} ms"),
          _buildComparisonRow("P95", "${dio.p95.toStringAsFixed(1)} ms", "${rust.p95.toStringAsFixed(1)} ms"),
          _buildComparisonRow("P99", "${dio.p99.toStringAsFixed(1)} ms", "${rust.p99.toStringAsFixed(1)} ms"),
          _buildComparisonRow("Min/Max", "${dio.min.toStringAsFixed(0)}-${dio.max.toStringAsFixed(0)} ms",
              "${rust.min.toStringAsFixed(0)}-${rust.max.toStringAsFixed(0)} ms"),

          // Throughput & Reliability
          _buildSectionHeader("Throughput & Reliability"),
          _buildComparisonRow("Throughput", "${dio.throughput.toStringAsFixed(1)} req/s", "${rust.throughput.toStringAsFixed(1)} req/s"),
          _buildComparisonRow("Total Requests", "${dio.totalRequests}", "${rust.totalRequests}"),
          _buildComparisonRow("Error Count", "${dio.errorCount}", "${rust.errorCount}"),
          _buildComparisonRow("Error Rate", "${dio.errorRate.toStringAsFixed(2)}%", "${rust.errorRate.toStringAsFixed(2)}%"),

          // Variability
          _buildSectionHeader("Variability"),
          _buildComparisonRow("Std Deviation", "${dio.stdDev.toStringAsFixed(1)} ms", "${rust.stdDev.toStringAsFixed(1)} ms"),

          // Statistical Analysis
          _buildSectionHeader("Statistical Analysis"),
          ListTile(
            title: const Text("Latency Improvement"),
            trailing: Text(
              "${comparison.latencyImprovement.toStringAsFixed(1)}%",
              style: TextStyle(
                color: comparison.latencyImprovement > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text("Throughput Improvement"),
            trailing: Text(
              "${comparison.throughputImprovement.toStringAsFixed(1)}%",
              style: TextStyle(
                color: comparison.throughputImprovement > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text("Statistical Significance"),
            trailing: Text(
              comparison.isSignificant ? "Significant" : "Not Significant",
              style: TextStyle(
                color: comparison.isSignificant ? Colors.green : Colors.orange,
              ),
            ),
          ),
          ListTile(
            title: const Text("Confidence Level"),
            trailing: Text("${comparison.confidenceLevel.toStringAsFixed(1)}%"),
          ),

          // Resource Usage
          _buildSectionHeader("Resource Utilization"),
          _buildComparisonRow("CPU Usage", "${dio.resources.cpuUsage.toStringAsFixed(1)}%", "${rust.resources.cpuUsage.toStringAsFixed(1)}%"),
          _buildComparisonRow("Memory Usage", "${dio.resources.memoryUsage.toStringAsFixed(1)} MB", "${rust.resources.memoryUsage.toStringAsFixed(1)} MB"),
          _buildComparisonRow("Network I/O", "${dio.resources.networkIO.toStringAsFixed(1)} MB/s", "${rust.resources.networkIO.toStringAsFixed(1)} MB/s"),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String metric, String dioValue, String rustValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(metric),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dioValue,
              style: const TextStyle(color: Colors.blue),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              rustValue,
              style: const TextStyle(color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------
/// Test Configuration Card
/// ---------------------------
class TestConfigurationCard extends StatelessWidget {
  final TestConfiguration config;

  const TestConfigurationCard({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Test Configuration",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildConfigItem(
                    Icons.data_usage,
                    "Payload Size",
                    "${(config.payloadSize / 1024).toStringAsFixed(1)} KB",
                  ),
                ),
                Expanded(
                  child: _buildConfigItem(
                    Icons.people,
                    "Concurrent Users",
                    "${config.concurrentUsers}",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildConfigItem(
                    Icons.timer,
                    "Test Duration",
                    "${config.testDuration.inSeconds}s",
                  ),
                ),
                Expanded(
                  child: _buildConfigItem(
                    Icons.network_cell,
                    "Network",
                    config.networkCondition,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ---------------------------
/// Main Entry
/// ---------------------------
void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blueGrey,
      cardTheme: const CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
      ),
    ),
    home: const BenchmarkDashboard(),
  ));
}