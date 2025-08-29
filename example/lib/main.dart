import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_rust_http/flutter_rust_http.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the Rust HTTP client
  await FlutterRustHttp.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTTP Performance Benchmark',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BenchmarkPage(),
    );
  }
}

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Flutter-Performance-Benchmark/1.0',
      'Accept': 'application/json',
    },
  ));

  // Get the singleton instance
  FlutterRustHttp get rustClient => FlutterRustHttp.instance;

  bool running = false;
  double progress = 0;
  String currentTest = '';
  final List<TestResult> results = [];

  final scenarios = [
    TestScenario('Single Request', 'https://jsonplaceholder.typicode.com/posts/1', 1, 50),
    TestScenario('Small Batch (5)', 'https://jsonplaceholder.typicode.com/posts', 5, 20),
    TestScenario('Medium Batch (20)', 'https://jsonplaceholder.typicode.com/posts', 20, 10),
    TestScenario('Large Batch (50)', 'https://jsonplaceholder.typicode.com/posts', 50, 5),
    TestScenario('High Concurrency (100)', 'https://jsonplaceholder.typicode.com/posts', 100, 3),
    TestScenario('Mixed Endpoints (20)', 'mixed', 20, 18),
    TestScenario('Image Downloads (10)', 'https://picsum.photos/400/300', 10, 5),
    TestScenario('Large JSON (30)', 'https://jsonplaceholder.typicode.com/photos', 30, 5),
  ];

  // Helper method to create complete request objects
  Map<String, dynamic> _createCompleteRequest(String url, {String method = 'GET'}) {
    return {
      'url': url,
      'method': method,
      'headers': <String, String>{}, // Empty map instead of dynamic
      'body': null,
      'query_params': <String, String>{}, // Empty map
      'timeout_ms': 30000,
      'follow_redirects': true,
      'max_redirects': 5,
      'connect_timeout_ms': 15000,
      'read_timeout_ms': 30000,
      'write_timeout_ms': 30000,
      'auto_referer': true,
      'decompress': true,
      'http3_only': false,
    };
  }


  Future<void> runBenchmarkSuite() async {
    setState(() {
      running = true;
      results.clear();
      progress = 0;
    });

    int totalTests = scenarios.length;

    for (int i = 0; i < scenarios.length; i++) {
      final scenario = scenarios[i];
      setState(() {
        currentTest = '${scenario.name} (${scenario.concurrent}x concurrent, ${scenario.iterations} rounds)';
        progress = i / totalTests;
      });

      final result = await _runScenario(scenario);
      setState(() => results.add(result));
    }

    setState(() {
      running = false;
      progress = 1.0;
      currentTest = 'Completed';
    });
  }

  Future<TestResult> _runScenario(TestScenario scenario) async {
    final dioStats = BenchmarkStats();
    final rustStats = BenchmarkStats();

    // Warmup request
    try {
      final warmupUrl = scenario.url == 'mixed'
          ? 'https://jsonplaceholder.typicode.com/posts/1'
          : scenario.url;
      final warmupRequest = _createCompleteRequest(warmupUrl);
      await rustClient.request(warmupRequest);
    } catch (_) {}

    // Run RUST tests first (all iterations)
    setState(() {
      currentTest = '${scenario.name} - Running Rust HTTP tests...';
    });

    for (int round = 0; round < scenario.iterations; round++) {
      await _testRustConcurrent(scenario, rustStats);
    }

    // Then run DART/DIO tests (all iterations)
    setState(() {
      currentTest = '${scenario.name} - Running Dart/Dio tests...';
    });

    for (int round = 0; round < scenario.iterations; round++) {
      await _testDioConcurrent(scenario, dioStats);
    }

    return TestResult(
      name: scenario.name,
      dioStats: dioStats.finalize(),
      rustStats: rustStats.finalize(),
    );
  }

  Future<void> _testRustConcurrent(TestScenario scenario, BenchmarkStats stats) async {
    final stopwatch = Stopwatch()..start();
    try {
      List<Map<String, dynamic>> requests;
      if (scenario.url == 'mixed') {
        final baseUrls = [
          'https://jsonplaceholder.typicode.com/posts',
          'https://jsonplaceholder.typicode.com/users',
          'https://jsonplaceholder.typicode.com/albums',
          'https://jsonplaceholder.typicode.com/todos',
        ];
        requests = List.generate(scenario.concurrent, (i) =>
            _createCompleteRequest(baseUrls[i % baseUrls.length]));
      } else {
        requests = List.generate(scenario.concurrent, (_) =>
            _createCompleteRequest(scenario.url));
      }

      // Use the existing requestBatch method from your client
      final responses = await rustClient.requestBatch(requests);

      stopwatch.stop();

      int totalBytes = 0;
      int successCount = 0;
      for (final response in responses) {
        final statusCode = response['status_code'] ?? 0;
        if (statusCode >= 200 && statusCode < 300) successCount++;
        final body = response['body'] ?? '';
        totalBytes += utf8.encode(body.toString()).length;
      }

      stats.addBatchResult(stopwatch.elapsedMicroseconds, totalBytes, successCount, scenario.concurrent);
    } catch (e) {
      stopwatch.stop();
      stats.addBatchResult(stopwatch.elapsedMicroseconds, 0, 0, scenario.concurrent);
      print('Rust HTTP error: $e'); // Debug logging
    }
  }

  Future<void> _testDioConcurrent(TestScenario scenario, BenchmarkStats stats) async {
    final stopwatch = Stopwatch()..start();
    try {
      List<Future<Response>> futures;
      if (scenario.url == 'mixed') {
        final urls = [
          'https://jsonplaceholder.typicode.com/posts',
          'https://jsonplaceholder.typicode.com/users',
          'https://jsonplaceholder.typicode.com/albums',
          'https://jsonplaceholder.typicode.com/todos',
        ];
        futures = List.generate(scenario.concurrent, (i) => dio.get(urls[i % urls.length]));
      } else {
        futures = List.generate(scenario.concurrent, (_) => dio.get(scenario.url));
      }
      final responses = await Future.wait(futures);

      // ADD: Simulate the same parsing overhead as Rust to make benchmark fair
      final List<Map<String, dynamic>> processedResponses = [];
      for (final response in responses) {
        // Create response structure similar to Rust HttpResponse
        final responseMap = {
          'status_code': response.statusCode ?? 0,
          'headers': response.headers.map.map((key, value) => MapEntry(key, value.join(', '))),
          'body': response.data is String ? response.data : jsonEncode(response.data),
          'version': '2.0',
          'url': response.requestOptions.uri.toString(),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        };

        // Serialize to JSON (like Rust does)
        final jsonString = jsonEncode(responseMap);

        // Parse it back (like Dart does with Rust response)
        final parsedResponse = jsonDecode(jsonString) as Map<String, dynamic>;
        processedResponses.add(parsedResponse);
      }

      stopwatch.stop();

      // Calculate stats using processed responses (fair comparison)
      int totalBytes = 0;
      int successCount = 0;
      for (final response in processedResponses) {
        final statusCode = response['status_code'] as int;
        if (statusCode >= 200 && statusCode < 300) successCount++;
        final body = response['body'] as String;
        totalBytes += utf8.encode(body).length;
      }

      stats.addBatchResult(stopwatch.elapsedMicroseconds, totalBytes, successCount, scenario.concurrent);
    } catch (e) {
      stopwatch.stop();
      stats.addBatchResult(stopwatch.elapsedMicroseconds, 0, 0, scenario.concurrent);
      print('Dio error: $e'); // Debug logging
    }
  }

  @override
  void dispose() {
    // Optional: Close the client when the widget is disposed
    // rustClient.shutdown(); // Use shutdown instead of close
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HTTP Performance Benchmark - Fair Comparison'), elevation: 2),
      body: Column(
        children: [
          _buildControls(),
          if (running) _buildProgress(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: running ? null : runBenchmarkSuite,
                child: Text(running ? 'Running...' : 'Start Fair Benchmark'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Fair comparison: Both Dio and Rust do HTTP + JSON serialization/parsing\n'
                'This measures pure HTTP performance differences',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text('Running: $currentTest'),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (results.isEmpty) {
      return const Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No results yet'),
                Text('Run the fair benchmark to see accurate performance comparisons')
              ]
          )
      );
    }

    return ListView(
        children: [
          _buildSummaryCard(),
          _buildSummaryChart(),
          _buildThroughputChart(),
          ...results.map((r) => _buildResultCard(r))
        ]
    );
  }

  Widget _buildSummaryCard() {
    if (results.isEmpty) return const SizedBox.shrink();

    double totalRustWins = 0;
    double totalDioWins = 0;
    double totalTies = 0;

    for (final result in results) {
      final throughputSpeedup = result.rustStats.requestsPerSecond / result.dioStats.requestsPerSecond;
      if (throughputSpeedup > 1.1) {
        totalRustWins++;
      } else if (throughputSpeedup < 0.9) {
        totalDioWins++;
      } else {
        totalTies++;
      }
    }

    final avgRustLatency = results.map((r) => r.rustStats.avgLatency / 1000).reduce((a, b) => a + b) / results.length;
    final avgDioLatency = results.map((r) => r.dioStats.avgLatency / 1000).reduce((a, b) => a + b) / results.length;
    final avgRustThroughput = results.map((r) => r.rustStats.requestsPerSecond).reduce((a, b) => a + b) / results.length;
    final avgDioThroughput = results.map((r) => r.dioStats.requestsPerSecond).reduce((a, b) => a + b) / results.length;

    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Benchmark Summary', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryMetric('Rust Wins', totalRustWins.toInt().toString(), Colors.orange),
                _buildSummaryMetric('Dio Wins', totalDioWins.toInt().toString(), Colors.blue),
                _buildSummaryMetric('Ties', totalTies.toInt().toString(), Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Average Latency:', style: Theme.of(context).textTheme.titleSmall),
                      Text('Rust: ${avgRustLatency.toStringAsFixed(1)}ms', style: const TextStyle(color: Colors.orange)),
                      Text('Dio: ${avgDioLatency.toStringAsFixed(1)}ms', style: const TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Average Throughput:', style: Theme.of(context).textTheme.titleSmall),
                      Text('Rust: ${avgRustThroughput.toStringAsFixed(1)} req/s', style: const TextStyle(color: Colors.orange)),
                      Text('Dio: ${avgDioThroughput.toStringAsFixed(1)} req/s', style: const TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSummaryChart() {
    final chartData = results.map((r) => ChartDataPoint(
        r.name.split(' ').first,
        r.dioStats.avgLatency / 1000,
        r.rustStats.avgLatency / 1000
    )).toList();

    return Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: SfCartesianChart(
            title: ChartTitle(text: 'Response Time Comparison (ms) - Lower is Better'),
            primaryXAxis: CategoryAxis(),
            primaryYAxis: NumericAxis(title: AxisTitle(text: 'Milliseconds')),
            legend: Legend(isVisible: true),
            series: [
              ColumnSeries<ChartDataPoint, String>(
                  name: 'Dio',
                  dataSource: chartData,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.dioValue,
                  color: Colors.blue
              ),
              ColumnSeries<ChartDataPoint, String>(
                  name: 'Rust HTTP',
                  dataSource: chartData,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.rustValue,
                  color: Colors.orange
              )
            ]
        )
    );
  }

  Widget _buildThroughputChart() {
    final chartData = results.map((r) => ChartDataPoint(
        r.name.split(' ').first,
        r.dioStats.requestsPerSecond,
        r.rustStats.requestsPerSecond
    )).toList();

    return Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: SfCartesianChart(
            title: ChartTitle(text: 'Throughput Comparison (requests/sec) - Higher is Better'),
            primaryXAxis: CategoryAxis(),
            primaryYAxis: NumericAxis(title: AxisTitle(text: 'Requests/sec')),
            legend: Legend(isVisible: true),
            series: [
              ColumnSeries<ChartDataPoint, String>(
                  name: 'Dio',
                  dataSource: chartData,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.dioValue,
                  color: Colors.blue
              ),
              ColumnSeries<ChartDataPoint, String>(
                  name: 'Rust HTTP',
                  dataSource: chartData,
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.rustValue,
                  color: Colors.orange
              )
            ]
        )
    );
  }

  Widget _buildResultCard(TestResult result) {
    final latencySpeedup = result.dioStats.avgLatency / result.rustStats.avgLatency;
    final throughputSpeedup = result.rustStats.requestsPerSecond / result.dioStats.requestsPerSecond;
    final winner = throughputSpeedup > 1.1 ? 'Rust' : throughputSpeedup < 0.9 ? 'Dio' : 'Tie';
    final winnerColor = winner == 'Rust' ? Colors.orange : winner == 'Dio' ? Colors.blue : Colors.grey;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(result.name, style: Theme.of(context).textTheme.titleLarge)),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: winnerColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: winnerColor.withOpacity(0.3))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            winner == 'Rust' ? Icons.rocket_launch :
                            winner == 'Dio' ? Icons.flash_on : Icons.remove,
                            color: winnerColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(winner, style: TextStyle(color: winnerColor, fontWeight: FontWeight.bold)),
                        ],
                      )
                  ),
                ]
            ),
            const SizedBox(height: 16),
            Row(
                children: [
                  Expanded(child: _buildClientStats('Dio', result.dioStats, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildClientStats('Rust', result.rustStats, Colors.orange))
                ]
            ),
            const SizedBox(height: 12),
            _buildPerformanceMetrics(latencySpeedup, throughputSpeedup),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetrics(double latencySpeedup, double throughputSpeedup) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8)
      ),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetric('Latency Improvement', '${latencySpeedup.toStringAsFixed(2)}x',
                latencySpeedup > 1.1 ? Colors.green : latencySpeedup < 0.9 ? Colors.red : Colors.grey),
            _buildMetric('Throughput Improvement', '${throughputSpeedup.toStringAsFixed(2)}x',
                throughputSpeedup > 1.1 ? Colors.green : throughputSpeedup < 0.9 ? Colors.red : Colors.grey),
          ]
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) => Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))
      ]
  );

  Widget _buildClientStats(String name, ClientStats stats, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8)
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text('Avg: ${(stats.avgLatency / 1000).toStringAsFixed(1)}ms'),
            Text('Min: ${(stats.minLatency / 1000).toStringAsFixed(1)}ms'),
            Text('Max: ${(stats.maxLatency / 1000).toStringAsFixed(1)}ms'),
            Text('Throughput: ${stats.requestsPerSecond.toStringAsFixed(1)} req/s'),
            Text('Success: ${(stats.successRate * 100).toStringAsFixed(1)}%'),
            if (stats.avgThroughput > 0) Text('Data: ${_formatThroughput(stats.avgThroughput)}'),
          ]
      ),
    );
  }

  String _formatThroughput(double bytesPerSec) {
    if (bytesPerSec >= 1024 * 1024) return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    if (bytesPerSec >= 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }
}

class TestScenario {
  final String name;
  final String url;
  final int concurrent;
  final int iterations;

  TestScenario(this.name, this.url, this.concurrent, this.iterations);
}

class TestResult {
  final String name;
  final ClientStats dioStats;
  final ClientStats rustStats;

  TestResult({required this.name, required this.dioStats, required this.rustStats});
}

class ClientStats {
  final double avgLatency;
  final int minLatency;
  final int maxLatency;
  final double successRate;
  final double avgThroughput;
  final double requestsPerSecond;

  ClientStats({
    required this.avgLatency,
    required this.minLatency,
    required this.maxLatency,
    required this.successRate,
    required this.avgThroughput,
    required this.requestsPerSecond
  });
}

class BenchmarkStats {
  final List<int> batchLatencies = [];
  final List<double> throughputs = [];
  final List<double> requestsPerSecond = [];
  int totalSuccesses = 0;
  int totalRequests = 0;

  void addBatchResult(int batchLatencyMicros, int totalBytes, int successCount, int requestCount) {
    batchLatencies.add(batchLatencyMicros);
    throughputs.add(totalBytes / (batchLatencyMicros / 1e6));
    requestsPerSecond.add(requestCount / (batchLatencyMicros / 1e6));
    totalSuccesses += successCount;
    totalRequests += requestCount;
  }

  ClientStats finalize() {
    if (batchLatencies.isEmpty) {
      return ClientStats(
          avgLatency: 0,
          minLatency: 0,
          maxLatency: 0,
          successRate: 0,
          avgThroughput: 0,
          requestsPerSecond: 0
      );
    }
    return ClientStats(
      avgLatency: batchLatencies.reduce((a, b) => a + b) / batchLatencies.length,
      minLatency: batchLatencies.reduce((a, b) => a < b ? a : b),
      maxLatency: batchLatencies.reduce((a, b) => a > b ? a : b),
      successRate: totalSuccesses / totalRequests,
      avgThroughput: throughputs.reduce((a, b) => a + b) / throughputs.length,
      requestsPerSecond: requestsPerSecond.reduce((a, b) => a + b) / requestsPerSecond.length,
    );
  }
}

class ChartDataPoint {
  final String label;
  final double dioValue;
  final double rustValue;

  ChartDataPoint(this.label, this.dioValue, this.rustValue);
}