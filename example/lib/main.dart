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
  String currentClient = '';
  int currentIteration = 0;
  int totalIterations = 0;
  String lastResponseData = '';
  Map<String, dynamic> responseStats = {};

  late Dio dio;
  late FlutterRustHttp rustClient;
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeClients();
  }

  void _initializeClients() {
    // Configure Dio with realistic settings
    dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
      sendTimeout: Duration(seconds: 30),
      // Disable caching to ensure fair comparison
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    ));

    // Disable logging for accurate benchmarks
    dio.interceptors.clear();

    rustClient = FlutterRustHttp();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    dio.close();
    super.dispose();
  }

  Future<BenchmarkResult> runRealisticBenchmark() async {
    // Use real APIs with different characteristics
    final scenarios = [
      BenchmarkScenario(
          'GitHub API - Small JSON',
          'https://api.github.com/users/flutter',
          10,
          'Small structured API response (~2KB)'
      ),
      BenchmarkScenario(
          'JSONPlaceholder - Posts',
          'https://jsonplaceholder.typicode.com/posts',
          10,
          'Medium JSON array (~15KB)'
      ),
      BenchmarkScenario(
          'REST Countries - All',
          'https://restcountries.com/v3.1/all',
          8,
          'Large JSON dataset (~500KB)'
      ),
      BenchmarkScenario(
          'httpbin - JSON Response',
          'https://httpbin.org/json',
          15,
          'Simple JSON response with random data'
      ),
      BenchmarkScenario(
          'Random User API',
          'https://randomuser.me/api/?results=10',
          12,
          'Dynamic user data API'
      ),
    ];

    final results = <String, List<RequestResult>>{};
    results['dio'] = [];
    results['rust'] = [];

    totalIterations = scenarios.fold(0, (sum, s) => sum + s.iterations * 2);
    int currentOperation = 0;

    // Randomize scenario order to prevent bias
    scenarios.shuffle();

    for (final scenario in scenarios) {
      setState(() {
        currentTest = scenario.name;
      });

      // Alternate between clients for each request to minimize network bias
      for (int i = 0; i < scenario.iterations; i++) {
        final shouldStartWithDio = Random().nextBool();

        final clients = shouldStartWithDio ? ['dio', 'rust'] : ['rust', 'dio'];

        for (final clientName in clients) {
          setState(() {
            currentClient = clientName == 'dio' ? 'Dio' : 'Rust';
            currentIteration = i + 1;
          });

          final stopwatch = Stopwatch()..start();
          RequestResult result;

          try {
            dynamic response;
            if (clientName == 'dio') {
              final dioResponse = await dio.get(scenario.url);
              response = dioResponse.data;
            } else {
              response = await rustClient.get(scenario.url);
              // Parse JSON if it's a string
              if (response is String) {
                response = json.decode(response);
              }
            }

            stopwatch.stop();

            // Validate response to ensure both clients got valid data
            final responseSize = _calculateResponseSize(response);

            result = RequestResult(
              latency: stopwatch.elapsedMicroseconds,
              success: true,
              responseSize: responseSize,
              scenario: scenario.name,
              error: null,
            );

            // Store sample response for display
            if (results[clientName]!.isEmpty && response != null) {
              setState(() {
                lastResponseData = _formatResponseForDisplay(response);
                responseStats = {
                  'size': responseSize,
                  'type': response.runtimeType.toString(),
                  'client': clientName,
                  'scenario': scenario.name,
                };
              });
            }

          } catch (e) {
            stopwatch.stop();
            result = RequestResult(
              latency: stopwatch.elapsedMicroseconds,
              success: false,
              responseSize: 0,
              scenario: scenario.name,
              error: e.toString(),
            );
          }

          results[clientName]!.add(result);

          currentOperation++;
          setState(() {
            progress = currentOperation / totalIterations;
          });

          // Small delay to prevent overwhelming the APIs
          await Future.delayed(Duration(milliseconds: 100));
        }

        // Longer delay between iterations to prevent rate limiting
        await Future.delayed(Duration(milliseconds: 200));
      }
    }

    return BenchmarkResult.fromRequestResults(results['dio']!, results['rust']!);
  }

  int _calculateResponseSize(dynamic response) {
    try {
      if (response == null) return 0;

      String jsonString;
      if (response is String) {
        jsonString = response;
      } else {
        jsonString = json.encode(response);
      }

      return jsonString.length;
    } catch (e) {
      return 0;
    }
  }

  String _formatResponseForDisplay(dynamic response) {
    try {
      if (response == null) return 'null';

      Map<String, dynamic> formatted;
      if (response is String) {
        formatted = json.decode(response);
      } else if (response is Map<String, dynamic>) {
        formatted = response;
      } else if (response is List) {
        formatted = {'array_length': response.length, 'first_item': response.isNotEmpty ? response[0] : null};
      } else {
        formatted = {'data': response.toString()};
      }

      // Limit display size
      final encoder = JsonEncoder.withIndent('  ');
      String result = encoder.convert(formatted);

      if (result.length > 1000) {
        result = result.substring(0, 1000) + '\n... (truncated)';
      }

      return result;
    } catch (e) {
      return 'Error formatting response: $e';
    }
  }

  Future<DetailedBenchmarkResult> runStressTest() async {
    final scenarios = [
      DetailedScenario(
          'Sequential Requests',
          'https://httpbin.org/uuid',
          'GET',
          null,
          20,
          'Multiple sequential requests to test consistency'
      ),
      DetailedScenario(
          'POST with Data',
          'https://httpbin.org/post',
          'POST',
          {'test': 'data', 'timestamp': DateTime.now().millisecondsSinceEpoch},
          10,
          'POST requests with JSON payload'
      ),
      DetailedScenario(
          'Large Response',
          'https://httpbin.org/drip?duration=1&numbytes=50000',
          'GET',
          null,
          5,
          'Large response with controlled delay'
      ),
      DetailedScenario(
          'Headers Test',
          'https://httpbin.org/headers',
          'GET',
          null,
          15,
          'Request reflection to test header handling'
      ),
      DetailedScenario(
          'Status Code Test',
          'https://httpbin.org/status/200',
          'GET',
          null,
          10,
          'Basic status code validation'
      ),
    ];

    final scenarioResults = <DetailedScenarioResult>[];
    totalIterations = scenarios.fold(0, (sum, s) => sum + s.iterations * 2);
    int currentOperation = 0;

    for (final scenario in scenarios) {
      setState(() {
        currentTest = scenario.name;
      });

      final dioResults = <RequestResult>[];
      final rustResults = <RequestResult>[];

      for (int i = 0; i < scenario.iterations; i++) {
        // Randomize client order for each iteration
        final clients = Random().nextBool() ? ['dio', 'rust'] : ['rust', 'dio'];

        for (final clientName in clients) {
          setState(() {
            currentClient = clientName == 'dio' ? 'Dio' : 'Rust';
            currentIteration = i + 1;
          });

          final stopwatch = Stopwatch()..start();
          RequestResult result;

          try {
            dynamic response;
            if (clientName == 'dio') {
              if (scenario.method == 'GET') {
                final dioResponse = await dio.get(scenario.url);
                response = dioResponse.data;
              } else if (scenario.method == 'POST') {
                final dioResponse = await dio.post(scenario.url, data: scenario.body);
                response = dioResponse.data;
              }
            } else {
              if (scenario.method == 'GET') {
                response = await rustClient.get(scenario.url);
              } else if (scenario.method == 'POST') {
                response = await rustClient.post(scenario.url, body: scenario.body);
              }

              if (response is String) {
                try {
                  response = json.decode(response);
                } catch (e) {
                  // Keep as string if not valid JSON
                }
              }
            }

            stopwatch.stop();

            result = RequestResult(
              latency: stopwatch.elapsedMicroseconds,
              success: true,
              responseSize: _calculateResponseSize(response),
              scenario: scenario.name,
              error: null,
            );

          } catch (e) {
            stopwatch.stop();
            result = RequestResult(
              latency: stopwatch.elapsedMicroseconds,
              success: false,
              responseSize: 0,
              scenario: scenario.name,
              error: e.toString(),
            );
          }

          if (clientName == 'dio') {
            dioResults.add(result);
          } else {
            rustResults.add(result);
          }

          currentOperation++;
          setState(() {
            progress = currentOperation / totalIterations;
          });

          await Future.delayed(Duration(milliseconds: 150));
        }
      }

      scenarioResults.add(DetailedScenarioResult(
        scenario: scenario,
        dioResults: dioResults,
        rustResults: rustResults,
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

  double _calculateStandardDeviation(List<int> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSquaredDiffs = values.map((value) => pow(value - mean, 2)).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiffs / values.length);
  }

  void runRealisticBenchmarks() async {
    setState(() {
      isRunning = true;
      progress = 0.0;
      currentTest = 'Initializing realistic benchmark...';
      currentClient = '';
      currentIteration = 0;
      lastResponseData = '';
      responseStats = {};
    });

    _pulseController.repeat(reverse: true);

    try {
      final result = await runRealisticBenchmark();
      setState(() {
        results.add(result);
        isRunning = false;
        progress = 0.0;
        currentTest = '';
        currentClient = '';
        currentIteration = 0;
      });
      _pulseController.stop();
    } catch (e) {
      setState(() {
        isRunning = false;
        progress = 0.0;
        currentTest = 'Error: $e';
        currentClient = '';
        currentIteration = 0;
      });
      _pulseController.stop();
    }
  }

  void runStressBenchmarks() async {
    setState(() {
      isRunning = true;
      progress = 0.0;
      currentTest = 'Initializing stress test...';
      currentClient = '';
      currentIteration = 0;
    });

    _pulseController.repeat(reverse: true);

    try {
      final result = await runStressTest();
      setState(() {
        detailedResults.add(result);
        isRunning = false;
        progress = 0.0;
        currentTest = '';
        currentClient = '';
        currentIteration = 0;
      });
      _pulseController.stop();
    } catch (e) {
      setState(() {
        isRunning = false;
        progress = 0.0;
        currentTest = 'Error: $e';
        currentClient = '';
        currentIteration = 0;
      });
      _pulseController.stop();
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
            Tab(text: 'Realistic Test'),
            Tab(text: 'Stress Test'),
            Tab(text: 'Analysis'),
            Tab(text: 'Response Data'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRealisticTestTab(),
          _buildStressTestTab(),
          _buildAnalysisTab(),
          _buildResponseDataTab(),
        ],
      ),
    );
  }

  Widget _buildRealisticTestTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: isRunning ? null : runRealisticBenchmarks,
                icon: Icon(Icons.speed),
                label: Text('Run Realistic Benchmark'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tests real-world APIs with various response sizes and characteristics',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (isRunning) ...[
                SizedBox(height: 20),
                _buildLoadingIndicator(),
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
                      _buildResultSummary(result),
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

  Widget _buildStressTestTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: isRunning ? null : runStressBenchmarks,
                icon: Icon(Icons.analytics),
                label: Text('Run Stress Test'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Intensive testing with various scenarios and edge cases',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (isRunning) ...[
                SizedBox(height: 20),
                _buildLoadingIndicator(),
              ],
            ],
          ),
        ),
        Expanded(
          child: detailedResults.isEmpty
              ? Center(child: Text('No stress test results yet'))
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
                      Text('Stress Test ${detailedResults.length - index}',
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
          Text('Performance Analysis',
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          if (results.isNotEmpty) _buildRealisticAnalysis(),
          SizedBox(height: 16),
          if (detailedResults.isNotEmpty) _buildStressAnalysis(),
        ],
      ),
    );
  }

  Widget _buildResponseDataTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Latest Response Data',
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          if (responseStats.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Response Statistics', style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 8),
                    Text('Client: ${responseStats['client']}'),
                    Text('Scenario: ${responseStats['scenario']}'),
                    Text('Response Size: ${responseStats['size']} bytes'),
                    Text('Data Type: ${responseStats['type']}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
          if (lastResponseData.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sample Response', style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          lastResponseData,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Center(
              child: Text('No response data available yet. Run a benchmark to see sample responses.'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: currentClient == 'Dio' ? Colors.blue : Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (currentClient == 'Dio' ? Colors.blue : Colors.orange).withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    currentClient == 'Dio' ? Icons.http : Icons.flash_on,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              currentClient == 'Dio' ? Colors.blue : Colors.orange,
            ),
          ),
          SizedBox(height: 12),
          Text(
            currentTest,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (currentClient.isNotEmpty) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: currentClient == 'Dio' ? Colors.blue : Colors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Testing $currentClient',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Iteration $currentIteration',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
          SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% Complete',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummary(BenchmarkResult result) {
    final dioFaster = result.dioAverage < result.rustAverage;
    final winner = dioFaster ? 'Dio' : 'Rust';
    final performanceRatio = dioFaster
        ? result.rustAverage / result.dioAverage.toDouble()
        : result.dioAverage / result.rustAverage.toDouble();

    return Column(
      children: [
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
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dioFaster ? Colors.blue.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: dioFaster ? Colors.blue.shade200 : Colors.orange.shade200,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Winner:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dioFaster ? Colors.blue : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$winner (${performanceRatio.toStringAsFixed(2)}x faster)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('Dio Success: ${result.dioSuccessCount}/${result.dioTotalCount}',
                        style: TextStyle(color: result.dioSuccessCount == result.dioTotalCount ? Colors.green : Colors.red)),
                  ),
                  Expanded(
                    child: Text('Rust Success: ${result.rustSuccessCount}/${result.rustTotalCount}',
                        style: TextStyle(color: result.rustSuccessCount == result.rustTotalCount ? Colors.green : Colors.red)),
                  ),
                ],
              ),
              if (result.dioStdDev > 0 && result.rustStdDev > 0) ...[
                SizedBox(height: 4),
                Text('Consistency: Dio ±${(result.dioStdDev / 1000).toStringAsFixed(1)}ms, Rust ±${(result.rustStdDev / 1000).toStringAsFixed(1)}ms',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ],
          ),
        ),
      ],
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
    final dioSuccessful = sr.dioResults.where((r) => r.success).toList();
    final rustSuccessful = sr.rustResults.where((r) => r.success).toList();

    final dioAvg = dioSuccessful.isEmpty ? 0 :
    dioSuccessful.map((r) => r.latency).reduce((a, b) => a + b) / dioSuccessful.length;
    final rustAvg = rustSuccessful.isEmpty ? 0 :
    rustSuccessful.map((r) => r.latency).reduce((a, b) => a + b) / rustSuccessful.length;

    final winner = dioAvg < rustAvg ? 'Dio' : 'Rust';
    final advantage = dioAvg < rustAvg && rustAvg > 0
        ? ((rustAvg - dioAvg) / rustAvg * 100)
        : rustAvg < dioAvg && dioAvg > 0
        ? ((dioAvg - rustAvg) / dioAvg * 100)
        : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: winner == 'Dio' ? Colors.blue.shade50 : Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(sr.scenario.name, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (advantage > 0) Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: winner == 'Dio' ? Colors.blue : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$winner +${advantage.toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(sr.scenario.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Dio: ${(dioAvg / 1000).toStringAsFixed(1)} ms (${dioSuccessful.length}/${sr.dioResults.length} success)'),
              ),
              Expanded(
                child: Text('Rust: ${(rustAvg / 1000).toStringAsFixed(1)} ms (${rustSuccessful.length}/${sr.rustResults.length} success)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealisticAnalysis() {
    if (results.isEmpty) return SizedBox.shrink();

    final result = results.last;
    final dioFaster = result.dioAverage < result.rustAverage;
    final performanceRatio = dioFaster
        ? result.rustAverage / result.dioAverage.toDouble()
        : result.dioAverage / result.rustAverage.toDouble();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Realistic Test Analysis', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Performance Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Winner: ${dioFaster ? 'Dio' : 'Rust'} (${performanceRatio.toStringAsFixed(2)}x faster)'),
                  Text('• Dio Average: ${(result.dioAverage / 1000).toStringAsFixed(1)}ms ± ${(result.dioStdDev / 1000).toStringAsFixed(1)}ms'),
                  Text('• Rust Average: ${(result.rustAverage / 1000).toStringAsFixed(1)}ms ± ${(result.rustStdDev / 1000).toStringAsFixed(1)}ms'),
                  Text('• Dio Success Rate: ${((result.dioSuccessCount / result.dioTotalCount) * 100).toStringAsFixed(1)}%'),
                  Text('• Rust Success Rate: ${((result.rustSuccessCount / result.rustTotalCount) * 100).toStringAsFixed(1)}%'),
                  SizedBox(height: 8),
                  Text('Interpretation:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (performanceRatio < 1.5) ...[
                    Text('• Performance difference is minimal - choose based on other factors',
                        style: TextStyle(color: Colors.green.shade700)),
                  ] else if (performanceRatio < 3.0) ...[
                    Text('• Moderate performance difference - consider for performance-critical apps',
                        style: TextStyle(color: Colors.orange.shade700)),
                  ] else ...[
                    Text('• Significant performance difference detected',
                        style: TextStyle(color: Colors.red.shade700)),
                    Text('• This large difference may indicate measurement issues or network conditions',
                        style: TextStyle(color: Colors.red.shade700)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStressAnalysis() {
    if (detailedResults.isEmpty) return SizedBox.shrink();

    final result = detailedResults.last;

    // Calculate overall statistics
    int totalDioRequests = 0;
    int totalRustRequests = 0;
    int successfulDioRequests = 0;
    int successfulRustRequests = 0;
    double totalDioTime = 0;
    double totalRustTime = 0;

    for (final sr in result.scenarioResults) {
      totalDioRequests += sr.dioResults.length;
      totalRustRequests += sr.rustResults.length;

      final dioSuccessful = sr.dioResults.where((r) => r.success).toList();
      final rustSuccessful = sr.rustResults.where((r) => r.success).toList();

      successfulDioRequests += dioSuccessful.length;
      successfulRustRequests += rustSuccessful.length;

      totalDioTime += dioSuccessful.map((r) => r.latency).fold(0, (a, b) => a + b);
      totalRustTime += rustSuccessful.map((r) => r.latency).fold(0, (a, b) => a + b);
    }

    final avgDioTime = successfulDioRequests > 0 ? totalDioTime / successfulDioRequests : 0;
    final avgRustTime = successfulRustRequests > 0 ? totalRustTime / successfulRustRequests : 0;
    final overallWinner = avgDioTime < avgRustTime ? 'Dio' : 'Rust';
    final overallRatio = avgDioTime < avgRustTime && avgRustTime > 0
        ? avgRustTime / avgDioTime
        : avgRustTime < avgDioTime && avgDioTime > 0
        ? avgDioTime / avgRustTime
        : 1.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stress Test Analysis', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Results', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Overall Winner: $overallWinner (${overallRatio.toStringAsFixed(2)}x faster)'),
                  Text('• Total Scenarios Tested: ${result.scenarioResults.length}'),
                  Text('• Total Requests: ${totalDioRequests + totalRustRequests}'),
                  Text('• Dio Success Rate: ${totalDioRequests > 0 ? ((successfulDioRequests / totalDioRequests) * 100).toStringAsFixed(1) : '0'}%'),
                  Text('• Rust Success Rate: ${totalRustRequests > 0 ? ((successfulRustRequests / totalRustRequests) * 100).toStringAsFixed(1) : '0'}%'),
                  Text('• Average Dio Time: ${(avgDioTime / 1000).toStringAsFixed(1)}ms'),
                  Text('• Average Rust Time: ${(avgRustTime / 1000).toStringAsFixed(1)}ms'),
                ],
              ),
            ),
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
      title: ChartTitle(text: 'Performance Comparison'),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Time (ms)'),
      ),
      series: <CartesianSeries<ChartData, String>>[
        ColumnSeries<ChartData, String>(
          name: 'Response Time',
          dataSource: [
            ChartData('Dio Avg', result.dioAverage.toDouble() / 1000),
            ChartData('Rust Avg', result.rustAverage.toDouble() / 1000),
            ChartData('Dio Median', result.dioMedian.toDouble() / 1000),
            ChartData('Rust Median', result.rustMedian.toDouble() / 1000),
          ],
          xValueMapper: (ChartData data, _) => data.label,
          yValueMapper: (ChartData data, _) => data.value,
          dataLabelSettings: DataLabelSettings(isVisible: true),
          pointColorMapper: (ChartData data, _) =>
          data.label.contains('Dio') ? Colors.blue : Colors.orange,
        ),
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }
}

// Data Models
class RequestResult {
  final int latency;
  final bool success;
  final int responseSize;
  final String scenario;
  final String? error;

  RequestResult({
    required this.latency,
    required this.success,
    required this.responseSize,
    required this.scenario,
    this.error,
  });
}

class BenchmarkResult {
  final int dioAverage, rustAverage;
  final int dioMedian, rustMedian;
  final int dioMin, rustMin;
  final int dioMax, rustMax;
  final double dioStdDev, rustStdDev;
  final int dioSuccessCount, rustSuccessCount;
  final int dioTotalCount, rustTotalCount;
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
    required this.dioStdDev,
    required this.rustStdDev,
    required this.dioSuccessCount,
    required this.rustSuccessCount,
    required this.dioTotalCount,
    required this.rustTotalCount,
    required this.dioTimes,
    required this.rustTimes,
  });

  static BenchmarkResult fromRequestResults(List<RequestResult> dioResults, List<RequestResult> rustResults) {
    final dioSuccessful = dioResults.where((r) => r.success).map((r) => r.latency).toList();
    final rustSuccessful = rustResults.where((r) => r.success).map((r) => r.latency).toList();

    return BenchmarkResult(
      dioAverage: dioSuccessful.isEmpty ? 0 : dioSuccessful.reduce((a, b) => a + b) ~/ dioSuccessful.length,
      rustAverage: rustSuccessful.isEmpty ? 0 : rustSuccessful.reduce((a, b) => a + b) ~/ rustSuccessful.length,
      dioMedian: _calculateMedian(dioSuccessful),
      rustMedian: _calculateMedian(rustSuccessful),
      dioMin: dioSuccessful.isEmpty ? 0 : dioSuccessful.reduce(min),
      rustMin: rustSuccessful.isEmpty ? 0 : rustSuccessful.reduce(min),
      dioMax: dioSuccessful.isEmpty ? 0 : dioSuccessful.reduce(max),
      rustMax: rustSuccessful.isEmpty ? 0 : rustSuccessful.reduce(max),
      dioStdDev: _calculateStandardDeviation(dioSuccessful),
      rustStdDev: _calculateStandardDeviation(rustSuccessful),
      dioSuccessCount: dioResults.where((r) => r.success).length,
      rustSuccessCount: rustResults.where((r) => r.success).length,
      dioTotalCount: dioResults.length,
      rustTotalCount: rustResults.length,
      dioTimes: dioSuccessful,
      rustTimes: rustSuccessful,
    );
  }

  static int _calculateMedian(List<int> values) {
    if (values.isEmpty) return 0;
    values.sort();
    int middle = values.length ~/ 2;
    if (values.length % 2 == 1) {
      return values[middle];
    } else {
      return (values[middle - 1] + values[middle]) ~/ 2;
    }
  }

  static double _calculateStandardDeviation(List<int> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSquaredDiffs = values.map((value) => pow(value - mean, 2)).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiffs / values.length);
  }
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
  final List<RequestResult> dioResults;
  final List<RequestResult> rustResults;

  DetailedScenarioResult({
    required this.scenario,
    required this.dioResults,
    required this.rustResults,
  });
}

class BenchmarkScenario {
  final String name;
  final String url;
  final int iterations;
  final String description;

  BenchmarkScenario(this.name, this.url, this.iterations, this.description);
}

class DetailedScenario {
  final String name;
  final String url;
  final String method;
  final dynamic body;
  final int iterations;
  final String description;

  DetailedScenario(this.name, this.url, this.method, this.body, this.iterations, this.description);
}

class ChartData {
  final String label;
  final double value;

  ChartData(this.label, this.value);
}