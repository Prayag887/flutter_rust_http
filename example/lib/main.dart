import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_rust_http/flutter_rust_http.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:collection/collection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterRustHttp.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live HTTP Benchmark',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LiveBenchmarkPage(),
    );
  }
}

class LiveBenchmarkPage extends StatefulWidget {
  const LiveBenchmarkPage({super.key});

  @override
  State<LiveBenchmarkPage> createState() => _LiveBenchmarkPageState();
}

class _LiveBenchmarkPageState extends State<LiveBenchmarkPage> {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Flutter-Live-Benchmark/1.0',
      'Accept': 'application/json',
      'Connection': 'keep-alive',
    },
    persistentConnection: true,
  ));

  final FlutterRustHttp _rustClient = FlutterRustHttp.instance;

  // State variables
  bool _isRunning = false;
  String _currentStatus = 'Ready to start';
  String _currentTest = '';
  int _currentIteration = 0;
  int _totalIterations = 0;
  double _progress = 0;

  // Live data for real-time visualization
  final List<LiveDataPoint> _liveRustData = [];
  final List<LiveDataPoint> _liveDioData = [];
  final List<ComparisonPoint> _comparisonData = [];
  final List<ThroughputPoint> _throughputData = [];

  // Current test metrics (updates in real-time)
  double _currentRustAvg = 0;
  double _currentDioAvg = 0;
  double _rustSuccessRate = 0;
  double _dioSuccessRate = 0;
  int _rustRequests = 0;
  int _dioRequests = 0;

  // Test scenarios
  final List<BenchmarkScenario> _scenarios = [
    BenchmarkScenario('Small JSON', 'https://httpbin.org/json', 15, 'json'),
    BenchmarkScenario('User Data', 'https://jsonplaceholder.typicode.com/users/1', 15, 'user'),
    BenchmarkScenario('Posts List', 'https://jsonplaceholder.typicode.com/posts', 12, 'posts'),
    BenchmarkScenario('POST Request', 'https://httpbin.org/post', 10, 'post'),
  ];

  Future<void> runLiveBenchmark() async {
    setState(() {
      _isRunning = true;
      _clearAllData();
      _progress = 0;
      _currentStatus = 'Starting live benchmark...';
    });

    try {
      // Calculate total iterations for progress tracking
      _totalIterations = _scenarios.fold(0, (sum, scenario) => sum + (scenario.iterations * 2)); // *2 for both clients
      int completedIterations = 0;

      for (int scenarioIndex = 0; scenarioIndex < _scenarios.length; scenarioIndex++) {
        final scenario = _scenarios[scenarioIndex];

        setState(() {
          _currentTest = scenario.name;
          _currentStatus = 'Warming up ${scenario.name}...';
        });

        // Warmup phase
        await _performWarmup(scenario);
        await Future.delayed(const Duration(milliseconds: 500));

        // Test Rust with live updates
        setState(() {
          _currentStatus = 'Testing Rust - ${scenario.name}';
        });

        for (int i = 0; i < scenario.iterations; i++) {
          setState(() {
            _currentIteration = i + 1;
            _progress = completedIterations / _totalIterations;
          });

          await _performLiveRustTest(scenario, scenarioIndex);
          completedIterations++;

          // Small delay for UI updates
          await Future.delayed(const Duration(milliseconds: 150));
        }

        // Brief pause between clients
        await Future.delayed(const Duration(milliseconds: 500));

        // Test Dio with live updates
        setState(() {
          _currentStatus = 'Testing Dio - ${scenario.name}';
        });

        for (int i = 0; i < scenario.iterations; i++) {
          setState(() {
            _currentIteration = i + 1;
            _progress = completedIterations / _totalIterations;
          });

          await _performLiveDioTest(scenario, scenarioIndex);
          completedIterations++;

          // Small delay for UI updates
          await Future.delayed(const Duration(milliseconds: 150));
        }

        // Update comparison data after each scenario
        _updateComparisonData();

        // Longer pause between scenarios
        if (scenarioIndex < _scenarios.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      setState(() {
        _currentStatus = 'Live benchmark complete! 🎉';
        _progress = 1.0;
      });

    } catch (e) {
      setState(() {
        _currentStatus = 'Error: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _clearAllData() {
    _liveRustData.clear();
    _liveDioData.clear();
    _comparisonData.clear();
    _throughputData.clear();
    _currentRustAvg = 0;
    _currentDioAvg = 0;
    _rustSuccessRate = 0;
    _dioSuccessRate = 0;
    _rustRequests = 0;
    _dioRequests = 0;
  }

  Future<void> _performWarmup(BenchmarkScenario scenario) async {
    for (int i = 0; i < 2; i++) {
      try {
        await _rustClient.request(_createRustRequest(scenario));
        await _dio.get(scenario.url);
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (_) {}
    }
  }

  Future<void> _performLiveRustTest(BenchmarkScenario scenario, int scenarioIndex) async {
    final stopwatch = Stopwatch()..start();

    try {
      dynamic result;

      if (scenario.type == 'post') {
        result = await _performRustPost(scenario);
      } else {
        result = await _rustClient.request(_createRustRequest(scenario));
      }

      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMicroseconds / 1000.0;

      // Process response and calculate throughput
      final processedData = _processResponse(result);
      final dataSize = _calculateDataSize(processedData);
      final throughput = dataSize / (latencyMs / 1000.0); // bytes/sec

      // Update live data
      setState(() {
        final now = DateTime.now();
        _liveRustData.add(LiveDataPoint(
          timestamp: now,
          latency: latencyMs,
          scenario: scenario.name,
          scenarioIndex: scenarioIndex,
          success: true,
        ));

        _throughputData.add(ThroughputPoint(
          timestamp: now,
          rustThroughput: throughput / 1024, // KB/s
          dioThroughput: 0, // Will be updated when Dio runs
          scenario: scenario.name,
        ));

        _rustRequests++;
        _updateRustMetrics();
      });

    } catch (e) {
      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMicroseconds / 1000.0;

      setState(() {
        _liveRustData.add(LiveDataPoint(
          timestamp: DateTime.now(),
          latency: latencyMs,
          scenario: scenario.name,
          scenarioIndex: scenarioIndex,
          success: false,
        ));
        _rustRequests++;
        _updateRustMetrics();
      });

      debugPrint('Rust error in ${scenario.name}: $e');
    }
  }

  Future<void> _performLiveDioTest(BenchmarkScenario scenario, int scenarioIndex) async {
    final stopwatch = Stopwatch()..start();

    try {
      dynamic result;

      if (scenario.type == 'post') {
        final response = await _dio.post(
          scenario.url,
          data: {
            'title': 'Live Test Post',
            'body': 'Testing Dio performance live',
            'userId': 1,
          },
        );
        result = response.data;
      } else {
        final response = await _dio.get(scenario.url);
        result = response.data;
      }

      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMicroseconds / 1000.0;

      // Process response and calculate throughput
      final processedData = _processResponse(result);
      final dataSize = _calculateDataSize(processedData);
      final throughput = dataSize / (latencyMs / 1000.0); // bytes/sec

      // Update live data
      setState(() {
        final now = DateTime.now();
        _liveDioData.add(LiveDataPoint(
          timestamp: now,
          latency: latencyMs,
          scenario: scenario.name,
          scenarioIndex: scenarioIndex,
          success: true,
        ));

        // Update throughput data (find matching timestamp or create new)
        final matchingThroughput = _throughputData.lastWhereOrNull(
              (point) => point.scenario == scenario.name && point.dioThroughput == 0,
        );
        if (matchingThroughput != null) {
          matchingThroughput.dioThroughput = throughput / 1024; // KB/s
        } else {
          _throughputData.add(ThroughputPoint(
            timestamp: now,
            rustThroughput: 0,
            dioThroughput: throughput / 1024,
            scenario: scenario.name,
          ));
        }

        _dioRequests++;
        _updateDioMetrics();
      });

    } catch (e) {
      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMicroseconds / 1000.0;

      setState(() {
        _liveDioData.add(LiveDataPoint(
          timestamp: DateTime.now(),
          latency: latencyMs,
          scenario: scenario.name,
          scenarioIndex: scenarioIndex,
          success: false,
        ));
        _dioRequests++;
        _updateDioMetrics();
      });

      debugPrint('Dio error in ${scenario.name}: $e');
    }
  }

  Map<String, dynamic> _createRustRequest(BenchmarkScenario scenario) {
    return {
      'url': scenario.url,
      'method': 'GET',
      'headers': {
        'User-Agent': 'Flutter-Live-Benchmark/1.0',
        'Accept': 'application/json',
      },
      'body': null,
      'query_params': {},
    };
  }

  Future<dynamic> _performRustPost(BenchmarkScenario scenario) async {
    final request = {
      'url': scenario.url,
      'method': 'POST',
      'headers': {
        'User-Agent': 'Flutter-Live-Benchmark/1.0',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      'body': jsonEncode({
        'title': 'Live Test Post',
        'body': 'Testing Rust performance live',
        'userId': 1,
      }),
      'query_params': {},
    };

    return await _rustClient.request(request);
  }

  dynamic _processResponse(dynamic response) {
    if (response is List) {
      return response.take(5).map((item) => _normalizeData(item)).toList();
    }
    return _normalizeData(response);
  }

  Map<String, dynamic> _normalizeData(dynamic data) {
    if (data is! Map<String, dynamic>) return {'raw': data};

    return {
      'id': data['id'],
      'title': data['title'] ?? data['name'] ?? 'N/A',
      'content': data['body'] ?? data['email'] ?? 'N/A',
      'processedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  int _calculateDataSize(dynamic data) {
    try {
      return utf8.encode(jsonEncode(data)).length;
    } catch (e) {
      return 0;
    }
  }

  void _updateRustMetrics() {
    final successfulRequests = _liveRustData.where((point) => point.success).toList();
    if (successfulRequests.isNotEmpty) {
      _currentRustAvg = successfulRequests.map((point) => point.latency).average;
      _rustSuccessRate = successfulRequests.length / _liveRustData.length;
    }
  }

  void _updateDioMetrics() {
    final successfulRequests = _liveDioData.where((point) => point.success).toList();
    if (successfulRequests.isNotEmpty) {
      _currentDioAvg = successfulRequests.map((point) => point.latency).average;
      _dioSuccessRate = successfulRequests.length / _liveDioData.length;
    }
  }

  void _updateComparisonData() {
    // Group data by scenario and calculate averages
    final rustByScenario = _liveRustData.where((point) => point.success).groupListsBy((point) => point.scenario);
    final dioByScenario = _liveDioData.where((point) => point.success).groupListsBy((point) => point.scenario);

    for (final scenarioName in rustByScenario.keys) {
      final rustLatencies = rustByScenario[scenarioName]?.map((point) => point.latency).toList() ?? [];
      final dioLatencies = dioByScenario[scenarioName]?.map((point) => point.latency).toList() ?? [];

      if (rustLatencies.isNotEmpty && dioLatencies.isNotEmpty) {
        // Remove existing data for this scenario and add updated
        _comparisonData.removeWhere((point) => point.scenario == scenarioName);
        _comparisonData.add(ComparisonPoint(
          scenario: scenarioName,
          rustAvg: rustLatencies.average,
          dioAvg: dioLatencies.average,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live HTTP Benchmark'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          if (_isRunning)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white24,
                strokeWidth: 3,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildLiveControlPanel(),
          if (_isRunning) _buildLiveStatusBar(),
          Expanded(child: _buildLiveGraphs()),
        ],
      ),
    );
  }

  Widget _buildLiveControlPanel() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Performance Monitor',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Real-time HTTP performance visualization',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLiveMetric('Rust Avg', '${_currentRustAvg.toStringAsFixed(1)}ms', Colors.orange),
                _buildLiveMetric('Dio Avg', '${_currentDioAvg.toStringAsFixed(1)}ms', Colors.blue),
                _buildLiveMetric('Requests', '${_rustRequests + _dioRequests}', Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isRunning ? null : runLiveBenchmark,
              icon: _isRunning ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ) : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running...' : 'Start Live Benchmark'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildLiveStatusBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentStatus,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
          if (_currentTest.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$_currentTest - Iteration $_currentIteration',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveGraphs() {
    if (_liveRustData.isEmpty && _liveDioData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'Ready for Live Monitoring',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Start the benchmark to see real-time performance graphs\n'
                  'Watch as each request is processed live!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLiveLatencyChart(),
        const SizedBox(height: 16),
        _buildLiveThroughputChart(),
        const SizedBox(height: 16),
        if (_comparisonData.isNotEmpty) _buildLiveComparisonChart(),
        const SizedBox(height: 16),
        _buildLiveStatistics(),
      ],
    );
  }

  Widget _buildLiveLatencyChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Live Latency (ms)', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    const Text('Rust'),
                    const SizedBox(width: 12),
                    Container(
                      width: 12,
                      height: 12,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    const Text('Dio'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(
                  intervalType: DateTimeIntervalType.seconds,
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Latency (ms)'),
                  majorGridLines: const MajorGridLines(width: 0.5),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: [
                  ScatterSeries<LiveDataPoint, DateTime>(
                    name: 'Rust',
                    dataSource: _liveRustData.where((point) => point.success).toList(),
                    xValueMapper: (point, _) => point.timestamp,
                    yValueMapper: (point, _) => point.latency,
                    color: Colors.orange,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      width: 6,
                      height: 6,
                    ),
                  ),
                  ScatterSeries<LiveDataPoint, DateTime>(
                    name: 'Dio',
                    dataSource: _liveDioData.where((point) => point.success).toList(),
                    xValueMapper: (point, _) => point.timestamp,
                    yValueMapper: (point, _) => point.latency,
                    color: Colors.blue,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      width: 6,
                      height: 6,
                    ),
                  ),
                  // Show failures as red X marks
                  ScatterSeries<LiveDataPoint, DateTime>(
                    name: 'Failures',
                    dataSource: [..._liveRustData, ..._liveDioData].where((point) => !point.success).toList(),
                    xValueMapper: (point, _) => point.timestamp,
                    yValueMapper: (point, _) => point.latency,
                    color: Colors.red,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      width: 8,
                      height: 8,
                      shape: DataMarkerType.triangle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveThroughputChart() {
    if (_throughputData.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Live Throughput (KB/s)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(
                  intervalType: DateTimeIntervalType.seconds,
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Throughput (KB/s)'),
                ),
                series: [
                  LineSeries<ThroughputPoint, DateTime>(
                    name: 'Rust',
                    dataSource: _throughputData.where((point) => point.rustThroughput > 0).toList(),
                    xValueMapper: (point, _) => point.timestamp,
                    yValueMapper: (point, _) => point.rustThroughput,
                    color: Colors.orange,
                    width: 2,
                  ),
                  LineSeries<ThroughputPoint, DateTime>(
                    name: 'Dio',
                    dataSource: _throughputData.where((point) => point.dioThroughput > 0).toList(),
                    xValueMapper: (point, _) => point.timestamp,
                    yValueMapper: (point, _) => point.dioThroughput,
                    color: Colors.blue,
                    width: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveComparisonChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Average Latency by Scenario', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(title: AxisTitle(text: 'Average Latency (ms)')),
                series: [
                  ColumnSeries<ComparisonPoint, String>(
                    name: 'Rust',
                    dataSource: _comparisonData,
                    xValueMapper: (point, _) => point.scenario,
                    yValueMapper: (point, _) => point.rustAvg,
                    color: Colors.orange,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  ColumnSeries<ComparisonPoint, String>(
                    name: 'Dio',
                    dataSource: _comparisonData,
                    xValueMapper: (point, _) => point.scenario,
                    yValueMapper: (point, _) => point.dioAvg,
                    color: Colors.blue,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatistics() {
    final rustSuccessful = _liveRustData.where((point) => point.success).length;
    final dioSuccessful = _liveDioData.where((point) => point.success).length;
    final totalRequests = _liveRustData.length + _liveDioData.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Live Statistics', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn('Total Requests', totalRequests.toString(), Colors.green),
                _buildStatColumn('Rust Success', '$rustSuccessful/${_liveRustData.length}', Colors.orange),
                _buildStatColumn('Dio Success', '$dioSuccessful/${_liveDioData.length}', Colors.blue),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn('Rust Success Rate', '${(_rustSuccessRate * 100).toStringAsFixed(1)}%', Colors.orange),
                _buildStatColumn('Dio Success Rate', '${(_dioSuccessRate * 100).toStringAsFixed(1)}%', Colors.blue),
                _buildStatColumn('Overall Winner',
                    _currentRustAvg > 0 && _currentDioAvg > 0
                        ? (_currentRustAvg < _currentDioAvg ? 'Rust' : 'Dio')
                        : 'TBD',
                    _currentRustAvg > 0 && _currentDioAvg > 0
                        ? (_currentRustAvg < _currentDioAvg ? Colors.orange : Colors.blue)
                        : Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Data Models
class BenchmarkScenario {
  final String name;
  final String url;
  final int iterations;
  final String type;

  BenchmarkScenario(this.name, this.url, this.iterations, this.type);
}

class LiveDataPoint {
  final DateTime timestamp;
  final double latency;
  final String scenario;
  final int scenarioIndex;
  final bool success;

  LiveDataPoint({
    required this.timestamp,
    required this.latency,
    required this.scenario,
    required this.scenarioIndex,
    required this.success,
  });
}

class ThroughputPoint {
  final DateTime timestamp;
  double rustThroughput;
  double dioThroughput;
  final String scenario;

  ThroughputPoint({
    required this.timestamp,
    required this.rustThroughput,
    required this.dioThroughput,
    required this.scenario,
  });
}

class ComparisonPoint {
  final String scenario;
  final double rustAvg;
  final double dioAvg;

  ComparisonPoint({
    required this.scenario,
    required this.rustAvg,
    required this.dioAvg,
  });
}