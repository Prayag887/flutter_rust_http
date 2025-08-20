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

  late Dio dio;
  late FlutterRustHttp rustClient;
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _pulseController.dispose();
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

    totalIterations = scenarios.fold(0, (sum, s) => sum + s.iterations * 2);
    int currentOperation = 0;

    for (final scenario in scenarios) {
      setState(() {
        currentTest = scenario.name;
      });

      for (int i = 0; i < scenario.iterations; i++) {
        setState(() {
          currentClient = 'Dio';
          currentIteration = i + 1;
        });

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
          progress = currentOperation / totalIterations;
        });

        await Future.delayed(Duration(milliseconds: 50)); // Small delay for UI updates

        setState(() {
          currentClient = 'Rust';
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
          progress = currentOperation / totalIterations;
        });

        await Future.delayed(Duration(milliseconds: 50)); // Small delay for UI updates
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
    totalIterations = scenarios.fold(0, (sum, s) => sum + s.iterations * 2);
    int currentOperation = 0;

    for (final scenario in scenarios) {
      setState(() {
        currentTest = scenario.name;
      });

      final dioTimes = <int>[];
      final rustTimes = <int>[];
      int dioErrors = 0;
      int rustErrors = 0;

      for (int i = 0; i < scenario.iterations; i++) {
        setState(() {
          currentClient = 'Dio';
          currentIteration = i + 1;
        });

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
          progress = currentOperation / totalIterations;
        });

        await Future.delayed(Duration(milliseconds: 50));

        setState(() {
          currentClient = 'Rust';
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
          progress = currentOperation / totalIterations;
        });

        await Future.delayed(Duration(milliseconds: 50));
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

  double _calculateVariance(List<int> values) {
    if (values.length < 2) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSquaredDiffs = values
        .map((value) => pow(value - mean, 2))
        .reduce((a, b) => a + b);

    return sumSquaredDiffs / values.length;
  }

  void runQuickBenchmarks() async {
    setState(() {
      isRunning = true;
      progress = 0.0;
      currentTest = 'Initializing...';
      currentClient = '';
      currentIteration = 0;
    });

    _pulseController.repeat(reverse: true);

    try {
      final result = await runQuickBenchmark();
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

  void runComprehensiveBenchmarks() async {
    setState(() {
      isRunning = true;
      progress = 0.0;
      currentTest = 'Initializing comprehensive test...';
      currentClient = '';
      currentIteration = 0;
    });

    _pulseController.repeat(reverse: true);

    try {
      final result = await runComprehensiveBenchmark();
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

  // Analysis methods
  AnalysisData _generateQuickAnalysis() {
    if (results.isEmpty) {
      return AnalysisData(
        winner: 'No data',
        performanceGain: 0,
        reliabilityDio: 0,
        reliabilityRust: 0,
        bestScenario: 'No data',
        worstScenario: 'No data',
        scenarioPerformance: {},
        recommendations: ['Run benchmarks to see analysis'],
        statistics: {},
      );
    }

    final latestResult = results.last;
    final dioFaster = latestResult.dioAverage < latestResult.rustAverage;
    final winner = dioFaster ? 'Dio' : 'Rust';

    final performanceGain = ((latestResult.dioAverage - latestResult.rustAverage).abs() /
        (dioFaster ? latestResult.rustAverage : latestResult.dioAverage) * 100);

    final reliabilityDio = latestResult.dioTimes.isNotEmpty
        ? (latestResult.dioTimes.length / (latestResult.dioTimes.length + latestResult.dioErrors)) * 100
        : 0.0;

    final reliabilityRust = latestResult.rustTimes.isNotEmpty
        ? (latestResult.rustTimes.length / (latestResult.rustTimes.length + latestResult.rustErrors)) * 100
        : 0.0;

    // Calculate variance/consistency
    final dioVariance = _calculateVariance(latestResult.dioTimes);
    final rustVariance = _calculateVariance(latestResult.rustTimes);
    final moreConsistent = dioVariance < rustVariance ? 'Dio' : 'Rust';

    // Generate dynamic recommendations
    final recommendations = <String>[];

    if (performanceGain > 50) {
      recommendations.add('${winner} shows significant ${performanceGain.toStringAsFixed(1)}% performance advantage - consider switching for performance-critical apps');
    } else if (performanceGain > 20) {
      recommendations.add('${winner} has moderate ${performanceGain.toStringAsFixed(1)}% advantage - evaluate based on your specific use case');
    } else {
      recommendations.add('Performance difference is minimal (${performanceGain.toStringAsFixed(1)}%) - choose based on development preferences');
    }

    if ((reliabilityDio - reliabilityRust).abs() > 10) {
      final moreReliable = reliabilityDio > reliabilityRust ? 'Dio' : 'Rust';
      recommendations.add('${moreReliable} shows better reliability (${reliabilityDio > reliabilityRust ? reliabilityDio.toStringAsFixed(1) : reliabilityRust.toStringAsFixed(1)}% success rate)');
    }

    if (dioVariance < rustVariance * 0.5 || rustVariance < dioVariance * 0.5) {
      recommendations.add('${moreConsistent} provides more consistent performance (lower latency variance)');
    }

    // Latency-based recommendations
    final avgLatency = dioFaster ? latestResult.dioAverage : latestResult.rustAverage;
    if (avgLatency > 2000000) { // > 2 seconds
      recommendations.add('High latency detected - consider implementing request caching and offline-first architecture');
    } else if (avgLatency > 500000) { // > 500ms
      recommendations.add('Moderate latency - implement loading states and consider request batching');
    }

    return AnalysisData(
      winner: winner,
      performanceGain: performanceGain,
      reliabilityDio: reliabilityDio,
      reliabilityRust: reliabilityRust,
      bestScenario: 'Quick test',
      worstScenario: 'Quick test',
      scenarioPerformance: {
        'Dio Average': latestResult.dioAverage / 1000,
        'Rust Average': latestResult.rustAverage / 1000,
      },
      recommendations: recommendations,
      statistics: {
        'Total Requests': latestResult.dioTimes.length + latestResult.rustTimes.length,
        'Dio Variance': dioVariance,
        'Rust Variance': rustVariance,
        'Performance Ratio': dioFaster
            ? latestResult.rustAverage / latestResult.dioAverage
            : latestResult.dioAverage / latestResult.rustAverage,
      },
    );
  }

  AnalysisData _generateDetailedAnalysis() {
    if (detailedResults.isEmpty) {
      return AnalysisData(
        winner: 'No data',
        performanceGain: 0,
        reliabilityDio: 0,
        reliabilityRust: 0,
        bestScenario: 'No data',
        worstScenario: 'No data',
        scenarioPerformance: {},
        recommendations: ['Run comprehensive benchmarks for detailed analysis'],
        statistics: {},
      );
    }

    final latestDetailed = detailedResults.last;
    final scenarioResults = latestDetailed.scenarioResults;

    // Analyze each scenario
    final scenarioPerformance = <String, double>{};
    final scenarioWinners = <String, String>{};
    double totalDioTime = 0;
    double totalRustTime = 0;
    int totalDioErrors = 0;
    int totalRustErrors = 0;
    int totalDioRequests = 0;
    int totalRustRequests = 0;

    String bestScenarioForDio = '';
    String bestScenarioForRust = '';
    double bestDioAdvantage = 0;
    double bestRustAdvantage = 0;

    for (final sr in scenarioResults) {
      final dioAvg = sr.dioTimes.isEmpty ? double.infinity : sr.dioTimes.reduce((a, b) => a + b) / sr.dioTimes.length;
      final rustAvg = sr.rustTimes.isEmpty ? double.infinity : sr.rustTimes.reduce((a, b) => a + b) / sr.rustTimes.length;

      scenarioPerformance['${sr.scenario.name} (Dio)'] = dioAvg / 1000;
      scenarioPerformance['${sr.scenario.name} (Rust)'] = rustAvg / 1000;

      totalDioTime += dioAvg * sr.dioTimes.length;
      totalRustTime += rustAvg * sr.rustTimes.length;
      totalDioErrors += sr.dioErrors;
      totalRustErrors += sr.rustErrors;
      totalDioRequests += sr.dioTimes.length;
      totalRustRequests += sr.rustTimes.length;

      // Track best scenarios for each client
      if (dioAvg < rustAvg) {
        scenarioWinners[sr.scenario.name] = 'Dio';
        final advantage = ((rustAvg - dioAvg) / rustAvg) * 100;
        if (advantage > bestDioAdvantage) {
          bestDioAdvantage = advantage;
          bestScenarioForDio = sr.scenario.name;
        }
      } else {
        scenarioWinners[sr.scenario.name] = 'Rust';
        final advantage = ((dioAvg - rustAvg) / dioAvg) * 100;
        if (advantage > bestRustAdvantage) {
          bestRustAdvantage = advantage;
          bestScenarioForRust = sr.scenario.name;
        }
      }
    }

    final overallDioAvg = totalDioRequests > 0 ? totalDioTime / totalDioRequests : 0;
    final overallRustAvg = totalRustRequests > 0 ? totalRustTime / totalRustRequests : 0;
    final overallWinner = overallDioAvg < overallRustAvg ? 'Dio' : 'Rust';
    final overallGain = overallDioAvg < overallRustAvg
        ? ((overallRustAvg - overallDioAvg) / overallRustAvg) * 100
        : ((overallDioAvg - overallRustAvg) / overallDioAvg) * 100;

    final reliabilityDio = totalDioRequests > 0
        ? (totalDioRequests / (totalDioRequests + totalDioErrors)) * 100
        : 0.0;
    final reliabilityRust = totalRustRequests > 0
        ? (totalRustRequests / (totalRustRequests + totalRustErrors)) * 100
        : 0.0;

    // Generate scenario-specific recommendations
    final recommendations = <String>[];

    recommendations.add('Overall: ${overallWinner} performs ${overallGain.toStringAsFixed(1)}% better across all scenarios');

    if (bestScenarioForDio.isNotEmpty) {
      recommendations.add('Dio excels at ${bestScenarioForDio} (${bestDioAdvantage.toStringAsFixed(1)}% advantage)');
    }

    if (bestScenarioForRust.isNotEmpty) {
      recommendations.add('Rust excels at ${bestScenarioForRust} (${bestRustAdvantage.toStringAsFixed(1)}% advantage)');
    }

    // Analyze by request type
    final getScenarios = scenarioResults.where((sr) => sr.scenario.method == 'GET').toList();
    final postScenarios = scenarioResults.where((sr) => sr.scenario.method == 'POST').toList();

    if (getScenarios.isNotEmpty && postScenarios.isNotEmpty) {
      final getWinner = _getMethodWinner(getScenarios);
      final postWinner = _getMethodWinner(postScenarios);

      if (getWinner.isNotEmpty) recommendations.add('For GET requests: ${getWinner} performs better');
      if (postWinner.isNotEmpty) recommendations.add('For POST requests: ${postWinner} performs better');
    }

    // Error analysis
    if (totalDioErrors > totalRustErrors * 2) {
      recommendations.add('Rust shows significantly better error handling (${totalRustErrors} vs ${totalDioErrors} errors)');
    } else if (totalRustErrors > totalDioErrors * 2) {
      recommendations.add('Dio shows significantly better error handling (${totalDioErrors} vs ${totalRustErrors} errors)');
    }

    // Payload size analysis
    final imageScenarios = scenarioResults.where((sr) => sr.scenario.name.toLowerCase().contains('image')).toList();
    final jsonScenarios = scenarioResults.where((sr) => sr.scenario.name.toLowerCase().contains('json')).toList();

    if (imageScenarios.isNotEmpty && jsonScenarios.isNotEmpty) {
      final imageWinner = _getMethodWinner(imageScenarios);
      final jsonWinner = _getMethodWinner(jsonScenarios);

      if (imageWinner.isNotEmpty) recommendations.add('For large payloads (images): ${imageWinner} is more efficient');
      if (jsonWinner.isNotEmpty) recommendations.add('For JSON data: ${jsonWinner} handles better');
    }

    return AnalysisData(
      winner: overallWinner,
      performanceGain: overallGain,
      reliabilityDio: reliabilityDio,
      reliabilityRust: reliabilityRust,
      bestScenario: overallWinner == 'Dio' ? bestScenarioForDio : bestScenarioForRust,
      worstScenario: overallWinner == 'Dio' ? bestScenarioForRust : bestScenarioForDio,
      scenarioPerformance: scenarioPerformance,
      recommendations: recommendations,
      statistics: {
        'Total Scenarios': scenarioResults.length,
        'Dio Wins': scenarioWinners.values.where((w) => w == 'Dio').length,
        'Rust Wins': scenarioWinners.values.where((w) => w == 'Rust').length,
        'Total Requests': totalDioRequests + totalRustRequests,
        'Overall Dio Avg (ms)': overallDioAvg / 1000,
        'Overall Rust Avg (ms)': overallRustAvg / 1000,
      },
    );
  }

  String _getMethodWinner(List<DetailedScenarioResult> scenarios) {
    double totalDioTime = 0;
    double totalRustTime = 0;
    int dioCount = 0;
    int rustCount = 0;

    for (final sr in scenarios) {
      if (sr.dioTimes.isNotEmpty) {
        totalDioTime += sr.dioTimes.reduce((a, b) => a + b);
        dioCount += sr.dioTimes.length;
      }
      if (sr.rustTimes.isNotEmpty) {
        totalRustTime += sr.rustTimes.reduce((a, b) => a + b);
        rustCount += sr.rustTimes.length;
      }
    }

    if (dioCount == 0 && rustCount == 0) return '';
    if (dioCount == 0) return 'Rust';
    if (rustCount == 0) return 'Dio';

    final dioAvg = totalDioTime / dioCount;
    final rustAvg = totalRustTime / rustCount;

    return dioAvg < rustAvg ? 'Dio' : 'Rust';
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
                SizedBox(height: 20),
                _buildLoadingIndicator(),
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
          _buildRecommendationCard(),
          SizedBox(height: 16),
          if (results.isNotEmpty) _buildQuickAnalysis(),
          SizedBox(height: 16),
          if (detailedResults.isNotEmpty) _buildDetailedAnalysis(),
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
                  'Iteration $currentIteration / ${totalIterations ~/ 2}',
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
    final winner = dioAvg < rustAvg ? 'Dio' : 'Rust';
    final advantage = dioAvg < rustAvg
        ? ((rustAvg - dioAvg) / rustAvg * 100)
        : ((dioAvg - rustAvg) / dioAvg * 100);

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
              Text(sr.scenario.name, style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
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

  Widget _buildRecommendationCard() {
    final analysis = results.isNotEmpty ? _generateQuickAnalysis() : null;
    final detailedAnalysis = detailedResults.isNotEmpty ? _generateDetailedAnalysis() : null;

    // Use the most comprehensive analysis available
    final currentAnalysis = detailedAnalysis ?? analysis;

    if (currentAnalysis == null || currentAnalysis.recommendations.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Recommendations', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              SizedBox(height: 12),
              Text('Run benchmarks to get personalized recommendations based on your performance data.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 8),
                Text('Recommendations', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentAnalysis.winner == 'Rust' ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentAnalysis.winner == 'Rust' ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: currentAnalysis.winner == 'Rust' ? Colors.orange : Colors.blue,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${currentAnalysis.winner} wins with ${currentAnalysis.performanceGain.toStringAsFixed(1)}% better performance',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            ...currentAnalysis.recommendations.map((rec) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_right, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text(rec)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAnalysis() {
    if (results.isEmpty) return SizedBox.shrink();

    final analysis = _generateQuickAnalysis();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Analysis Results', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),

            // Performance summary
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
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
                          color: analysis.winner == 'Rust' ? Colors.orange : Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${analysis.winner} (+${analysis.performanceGain.toStringAsFixed(1)}%)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reliability:'),
                      Text('Dio: ${analysis.reliabilityDio.toStringAsFixed(1)}% | Rust: ${analysis.reliabilityRust.toStringAsFixed(1)}%'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Performance Ratio:'),
                      Text('${analysis.statistics['Performance Ratio']?.toStringAsFixed(2)}x'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Requests:'),
                      Text('${analysis.statistics['Total Requests']}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedAnalysis() {
    if (detailedResults.isEmpty) return SizedBox.shrink();

    final analysis = _generateDetailedAnalysis();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comprehensive Analysis Results', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),

            // Scenario breakdown
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Scenario Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: analysis.winner == 'Rust' ? Colors.orange : Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Overall Winner: ${analysis.winner}',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Dio Wins: ${analysis.statistics['Dio Wins']}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Rust Wins: ${analysis.statistics['Rust Wins']}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (analysis.bestScenario.isNotEmpty)
                    Text('Best for ${analysis.winner}: ${analysis.bestScenario}'),
                  if (analysis.worstScenario.isNotEmpty)
                    Text('Challenging: ${analysis.worstScenario}'),
                  SizedBox(height: 4),
                  Text('Total Requests Tested: ${analysis.statistics['Total Requests']}'),
                ],
              ),
            ),

            SizedBox(height: 12),

            // Performance metrics
            if (analysis.scenarioPerformance.isNotEmpty) ...[
              Text('Average Response Times by Scenario:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: analysis.scenarioPerformance.entries.map((entry) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: entry.key.contains('Dio') ? Colors.blue.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${entry.value.toStringAsFixed(1)} ms',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
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

class AnalysisData {
  final String winner;
  final double performanceGain;
  final double reliabilityDio;
  final double reliabilityRust;
  final String bestScenario;
  final String worstScenario;
  final Map<String, double> scenarioPerformance;
  final List<String> recommendations;
  final Map<String, dynamic> statistics;

  AnalysisData({
    required this.winner,
    required this.performanceGain,
    required this.reliabilityDio,
    required this.reliabilityRust,
    required this.bestScenario,
    required this.worstScenario,
    required this.scenarioPerformance,
    required this.recommendations,
    required this.statistics,
  });
}