import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_rust_http/flutter_rust_http.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:convert';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterRustHttp.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTTP Performance Benchmark',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BenchmarkPage(),
    );
  }
}

class BenchmarkPage extends StatefulWidget {
  @override
  _BenchmarkPageState createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage>
    with TickerProviderStateMixin {
  final List<BenchmarkResult> results = [];
  final List<DetailedBenchmarkResult> detailedResults = [];
  bool isRunning = false;
  double progress = 0.0;
  String currentTest = '';

  late Dio dio;
  late FlutterRustHttp rustClient;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeClients();
  }

  void _initializeClients() {
    // Configure Dio with optimized settings
    dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
      sendTimeout: Duration(seconds: 30),
    ));

    // Add interceptors for better performance measurement
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) {}, // Disable logging for benchmarks
    ));

    rustClient = FlutterRustHttp();
  }

  @override
  void dispose() {
    _tabController.dispose();
    dio.close();
    super.dispose();
  }

  Future<BenchmarkResult> runQuickBenchmark() async {
    final scenarios = [
      BenchmarkScenario('Small JSON', 'https://jsonplaceholder.typicode.com/posts/1', 50),
      BenchmarkScenario('Large JSON', 'https://jsonplaceholder.typicode.com/posts', 20),
      BenchmarkScenario('Image', 'https://picsum.photos/800/600', 10),
    ];

    final results = <String, List<int>>{};
    results['dio'] = [];
    results['rust'] = [];

    int totalOperations = scenarios.fold(0, (sum, s) => sum + s.iterations * 2);
    int currentOperation = 0;

    for (final scenario in scenarios) {
      setState(() {
        currentTest = 'Testing: ${scenario.name}';
      });

      for (int i = 0; i < scenario.iterations; i++) {
        // Benchmark Dio
        final dioStopwatch = Stopwatch()..start();
        try {
          await dio.get(scenario.url);
          results['dio']!.add(dioStopwatch.elapsedMicroseconds);
        } catch (e) {
          results['dio']!.add(-1); // Error marker
        }
        dioStopwatch.stop();

        currentOperation++;
        setState(() {
          progress = currentOperation / totalOperations;
        });

        // Benchmark Rust HTTP
        final rustStopwatch = Stopwatch()..start();
        try {
          await rustClient.get(scenario.url);
          results['rust']!.add(rustStopwatch.elapsedMicroseconds);
        } catch (e) {
          results['rust']!.add(-1); // Error marker
        }
        rustStopwatch.stop();

        currentOperation++;
        setState(() {
          progress = currentOperation / totalOperations;
        });
      }
    }

    // Filter out errors and calculate statistics
    final dioValidTimes = results['dio']!.where((t) => t > 0).toList();
    final rustValidTimes = results['rust']!.where((t) => t > 0).toList();

    return BenchmarkResult(
      dioAverage: _calculateAverage(dioValidTimes),
      rustAverage: _calculateAverage(rustValidTimes),
      dioMedian: _calculateMedian(dioValidTimes),
      rustMedian: _calculateMedian(rustValidTimes),
      dioMin: dioValidTimes.isEmpty ? 0 : dioValidTimes.reduce(min),
      rustMin: rustValidTimes.isEmpty ? 0 : rustValidTimes.reduce(min),
      dioMax: dioValidTimes.isEmpty ? 0 : dioValidTimes.reduce(max),
      rustMax: rustValidTimes.isEmpty ? 0 : rustValidTimes.reduce(max),
      dioErrors: results['dio']!.where((t) => t < 0).length,
      rustErrors: results['rust']!.where((t) => t < 0).length,
      dioTimes: dioValidTimes,
      rustTimes: rustValidTimes,
    );
  }

  Future<DetailedBenchmarkResult> runComprehensiveBenchmark() async {
    final scenarios = [
      DetailedScenario('Tiny Response', 'https://httpbin.org/json', 'GET', null, 100),
      DetailedScenario('Small POST', 'https://httpbin.org/post', 'POST', {'test': 'data'}, 50),
      DetailedScenario('Medium JSON', 'https://jsonplaceholder.typicode.com/posts', 'GET', null, 30),
      DetailedScenario('Large Image', 'https://picsum.photos/1200/800', 'GET', null, 15),
      DetailedScenario('Headers Test', 'https://httpbin.org/headers', 'GET', null, 25),
      DetailedScenario('Timeout Test', 'https://httpbin.org/delay/2', 'GET', null, 10),
    ];

    final scenarioResults = <DetailedScenarioResult>[];
    int totalOperations = scenarios.fold(0, (sum, s) => sum + s.iterations * 2);
    int currentOperation = 0;

    for (final scenario in scenarios) {
      setState(() {
        currentTest = 'Comprehensive Test: ${scenario.name}';
      });

      final dioTimes = <int>[];
      final rustTimes = <int>[];
      int dioErrors = 0;
      int rustErrors = 0;

      for (int i = 0; i < scenario.iterations; i++) {
        // Test Dio
        final dioStopwatch = Stopwatch()..start();
        try {
          if (scenario.method == 'GET') {
            await dio.get(scenario.url);
          } else if (scenario.method == 'POST') {
            await dio.post(scenario.url, data: scenario.body);
          }
          dioTimes.add(dioStopwatch.elapsedMicroseconds);
        } catch (e) {
          dioErrors++;
        }
        dioStopwatch.stop();

        currentOperation++;
        setState(() {
          progress = currentOperation / totalOperations;
        });

        // Test Rust HTTP
        final rustStopwatch = Stopwatch()..start();
        try {
          if (scenario.method == 'GET') {
            await rustClient.get(scenario.url);
          } else if (scenario.method == 'POST') {
            await rustClient.post(scenario.url, body: scenario.body);
          }
          rustTimes.add(rustStopwatch.elapsedMicroseconds);
        } catch (e) {
          rustErrors++;
        }
        rustStopwatch.stop();

        currentOperation++;
        setState(() {
          progress = currentOperation / totalOperations;
        });
      }

      scenarioResults.add(DetailedScenarioResult(
        scenario: scenario,
        dioTimes: dioTimes,
        rustTimes: rustTimes,
        dioErrors: dioErrors,
        rustErrors: rustErrors,
      ));
    }

    return DetailedBenchmarkResult(
      scenarioResults: scenarioResults,
      timestamp: DateTime.now(),
    );
  }

  int _calculateAverage(List<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) ~/ values.length;
  }

  int _calculateMedian(List<int> values) {
    if (values.isEmpty) return 0;
    values.sort();
    int middle = values.length ~/ 2;
    if (values.length % 2 == 1) {
      return values[middle];
    } else {
      return (values[middle - 1] + values[middle]) ~/ 2;
    }
  }

  void runQuickBenchmarks() async {
    setState(() {
      isRunning = true;
      progress = 0.0;
      currentTest = 'Starting benchmark...';
    });

    try {
      final result = await runQuickBenchmark();
      setState(() {
        results.add(result);
        isRunning = false;
        progress = 0.0;
        currentTest = '';
      });
    } catch (e) {
      setState(() {
        isRunning = false;
        progress = 0.0;
        currentTest = 'Error: $e';
      });
    }
  }

  void runComprehensiveBenchmarks() async {
    setState(() {
      isRunning = true;
      progress = 0.0;
      currentTest = 'Starting comprehensive benchmark...';
    });

    try {
      final result = await runComprehensiveBenchmark();
      setState(() {
        detailedResults.add(result);
        isRunning = false;
        progress = 0.0;
        currentTest = '';
      });
    } catch (e) {
      setState(() {
        isRunning = false;
        progress = 0.0;
        currentTest = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HTTP Performance Benchmark'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Quick Test'),
            Tab(text: 'Comprehensive'),
            Tab(text: 'Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickTestTab(),
          _buildComprehensiveTab(),
          _buildAnalysisTab(),
        ],
      ),
    );
  }

  Widget _buildQuickTestTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: isRunning ? null : runQuickBenchmarks,
                icon: Icon(Icons.speed),
                label: Text('Run Quick Benchmark'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              if (isRunning) ...[
                SizedBox(height: 16),
                LinearProgressIndicator(value: progress),
                SizedBox(height: 8),
                Text(currentTest, style: TextStyle(fontSize: 14)),
              ],
            ],
          ),
        ),
        if (results.isNotEmpty) ...[
          Container(
            height: 300,
            child: QuickResultsChart(result: results.last),
          ),
          SizedBox(height: 16),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[results.length - 1 - index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Run ${results.length - index}',
                          style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard('Dio Average',
                                '${(result.dioAverage / 1000).toStringAsFixed(1)} ms',
                                Colors.blue),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard('Rust Average',
                                '${(result.rustAverage / 1000).toStringAsFixed(1)} ms',
                                Colors.orange),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Dio Errors: ${result.dioErrors}',
                                style: TextStyle(color: result.dioErrors > 0 ? Colors.red : Colors.green)),
                          ),
                          Expanded(
                            child: Text('Rust Errors: ${result.rustErrors}',
                                style: TextStyle(color: result.rustErrors > 0 ? Colors.red : Colors.green)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComprehensiveTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: isRunning ? null : runComprehensiveBenchmarks,
                icon: Icon(Icons.analytics),
                label: Text('Run Comprehensive Benchmark'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              if (isRunning) ...[
                SizedBox(height: 16),
                LinearProgressIndicator(value: progress),
                SizedBox(height: 8),
                Text(currentTest, style: TextStyle(fontSize: 14)),
              ],
            ],
          ),
        ),
        Expanded(
          child: detailedResults.isEmpty
              ? Center(child: Text('No comprehensive results yet'))
              : ListView.builder(
            itemCount: detailedResults.length,
            itemBuilder: (context, index) {
              final result = detailedResults[detailedResults.length - 1 - index];
              return Card(
                margin: EdgeInsets.all(16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Comprehensive Test ${detailedResults.length - index}',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('Run at: ${result.timestamp.toString().split('.')[0]}',
                          style: Theme.of(context).textTheme.bodySmall),
                      SizedBox(height: 16),
                      ...result.scenarioResults.map((sr) => _buildScenarioResultCard(sr)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisTab() {
    if (results.isEmpty && detailedResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No data to analyze yet', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            Text('Run some benchmarks to see the analysis'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance Analysis & Recommendations',
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          if (results.isNotEmpty) _buildQuickAnalysis(),
          SizedBox(height: 16),
          if (detailedResults.isNotEmpty) _buildDetailedAnalysis(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScenarioResultCard(DetailedScenarioResult sr) {
    final dioAvg = sr.dioTimes.isEmpty ? 0 : sr.dioTimes.reduce((a, b) => a + b) / sr.dioTimes.length;
    final rustAvg = sr.rustTimes.isEmpty ? 0 : sr.rustTimes.reduce((a, b) => a + b) / sr.rustTimes.length;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sr.scenario.name, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('Dio: ${(dioAvg / 1000).toStringAsFixed(1)} ms (${sr.dioErrors} errors)'),
              ),
              Expanded(
                child: Text('Rust: ${(rustAvg / 1000).toStringAsFixed(1)} ms (${sr.rustErrors} errors)'),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildQuickAnalysis() {
    if (results.isEmpty) return SizedBox.shrink();

    final latestResult = results.last;
    final dioFaster = latestResult.dioAverage < latestResult.rustAverage;
    final performanceDiff = ((latestResult.dioAverage - latestResult.rustAverage).abs() /
        (dioFaster ? latestResult.dioAverage : latestResult.rustAverage) * 100);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Analysis', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            Text('${dioFaster ? "Dio" : "Rust"} performed ${performanceDiff.toStringAsFixed(1)}% better on average',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Reliability: Dio (${((latestResult.dioTimes.length / (latestResult.dioTimes.length + latestResult.dioErrors)) * 100).toStringAsFixed(1)}%) vs Rust (${((latestResult.rustTimes.length / (latestResult.rustTimes.length + latestResult.rustErrors)) * 100).toStringAsFixed(1)}%)'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedAnalysis() {
    if (detailedResults.isEmpty) return SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detailed Analysis', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            Text('Based on comprehensive testing across multiple scenarios, both clients show different strengths:'),
            SizedBox(height: 8),
            Text('• Dio excels in development productivity and ecosystem integration'),
            Text('• Rust HTTP shows potential for lower-level performance optimization'),
            Text('• Network conditions and payload size significantly impact relative performance'),
            Text('• Error handling and reliability vary by scenario'),
          ],
        ),
      ),
    );
  }
}

class QuickResultsChart extends StatelessWidget {
  final BenchmarkResult result;

  QuickResultsChart({required this.result});

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      title: ChartTitle(text: 'Performance Comparison (μs)'),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Time (microseconds)'),
      ),
      series: <CartesianSeries<ChartData, String>>[
        ColumnSeries<ChartData, String>(
          name: 'Average',
          dataSource: [
            ChartData('Dio Avg', result.dioAverage.toDouble()),
            ChartData('Rust Avg', result.rustAverage.toDouble()),
            ChartData('Dio Median', result.dioMedian.toDouble()),
            ChartData('Rust Median', result.rustMedian.toDouble()),
          ],
          xValueMapper: (ChartData data, _) => data.label,
          yValueMapper: (ChartData data, _) => data.value,
          dataLabelSettings: DataLabelSettings(isVisible: true),
          color: Colors.blue,
        ),
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }
}

// Data Models
class BenchmarkResult {
  final int dioAverage, rustAverage;
  final int dioMedian, rustMedian;
  final int dioMin, rustMin;
  final int dioMax, rustMax;
  final int dioErrors, rustErrors;
  final List<int> dioTimes, rustTimes;

  BenchmarkResult({
    required this.dioAverage,
    required this.rustAverage,
    required this.dioMedian,
    required this.rustMedian,
    required this.dioMin,
    required this.rustMin,
    required this.dioMax,
    required this.rustMax,
    required this.dioErrors,
    required this.rustErrors,
    required this.dioTimes,
    required this.rustTimes,
  });
}

class DetailedBenchmarkResult {
  final List<DetailedScenarioResult> scenarioResults;
  final DateTime timestamp;

  DetailedBenchmarkResult({
    required this.scenarioResults,
    required this.timestamp,
  });
}

class DetailedScenarioResult {
  final DetailedScenario scenario;
  final List<int> dioTimes;
  final List<int> rustTimes;
  final int dioErrors;
  final int rustErrors;

  DetailedScenarioResult({
    required this.scenario,
    required this.dioTimes,
    required this.rustTimes,
    required this.dioErrors,
    required this.rustErrors,
  });
}

class BenchmarkScenario {
  final String name;
  final String url;
  final int iterations;

  BenchmarkScenario(this.name, this.url, this.iterations);
}

class DetailedScenario {
  final String name;
  final String url;
  final String method;
  final dynamic body;
  final int iterations;

  DetailedScenario(this.name, this.url, this.method, this.body, this.iterations);
}

class ChartData {
  final String label;
  final double value;

  ChartData(this.label, this.value);
}