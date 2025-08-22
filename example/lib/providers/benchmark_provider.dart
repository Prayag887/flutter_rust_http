import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/benchmark_models.dart';
import '../services/http_clients.dart';
import '../config/benchmark_scenarios.dart';

class BenchmarkProvider extends ChangeNotifier {
  final Map<HttpClientType, LiveBenchmarkData> _liveData = {};
  final Map<HttpClientType, List<BenchmarkMetrics>> _completedBenchmarks = {};
  final Map<HttpClientType, HttpClientInterface> _clients = {};

  // New properties for running all scenarios
  final Map<String, Map<String, dynamic>> _allScenarioResults = {};
  bool _runningAllScenarios = false;
  int _currentScenarioIndex = 0;
  String? _currentScenarioName;
  HttpClientType? _currentClientForAllScenarios;

  BenchmarkAnalysis? _analysis;
  bool _isRunning = false;
  HttpClientType? _activeClient;
  Timer? _realtimeTimer;

  // Getters
  Map<HttpClientType, LiveBenchmarkData> get liveData => Map.unmodifiable(_liveData);
  Map<HttpClientType, List<BenchmarkMetrics>> get completedBenchmarks => Map.unmodifiable(_completedBenchmarks);
  Map<String, Map<String, dynamic>> get allScenarioResults => Map.unmodifiable(_allScenarioResults);
  BenchmarkAnalysis? get analysis => _analysis;
  bool get isRunning => _isRunning;
  bool get runningAllScenarios => _runningAllScenarios;
  int get currentScenarioIndex => _currentScenarioIndex;
  String? get currentScenarioName => _currentScenarioName;
  HttpClientType? get activeClient => _activeClient;

  BenchmarkProvider() {
    _initializeClients();
    _initializeLiveData();
    _loadStoredResults();
  }

  Future<void> _initializeClients() async {
    for (final clientType in HttpClientType.values) {
      _clients[clientType] = await HttpClientFactory.createClient(clientType);
      _completedBenchmarks[clientType] = [];
    }
  }

  void _initializeLiveData() {
    for (final clientType in HttpClientType.values) {
      _liveData[clientType] = LiveBenchmarkData(
        clientType: clientType,
        scenario: BenchmarkScenarios.scenarios.first,
        currentMetrics: _createEmptyMetrics(),
        progress: 0.0,
        isRunning: false,
      );
    }
  }

  Future<void> _loadStoredResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resultsJson = prefs.getString('benchmark_results') ?? '[]';
      final storedResults = json.decode(resultsJson) as List;

      // Load the most recent results if available
      if (storedResults.isNotEmpty) {
        final latestResults = storedResults.last['results'] as Map<String, dynamic>?;
        if (latestResults != null) {
          _allScenarioResults.clear();
          _allScenarioResults.addAll(latestResults.cast<String, Map<String, dynamic>>());
        }
      }
    } catch (e) {
      print('Error loading stored results: $e');
    }
  }

  BenchmarkMetrics _createEmptyMetrics() {
    return BenchmarkMetrics(
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      averageLatency: 0.0,
      p95Latency: 0.0,
      p99Latency: 0.0,
      throughput: 0.0,
      cpuUsage: 0.0,
      memoryUsageMB: 0.0,
      latencyHistory: [],
      startTime: DateTime.now(),
    );
  }

  /// Run all benchmark scenarios sequentially for a given client type
  Future<void> runAllScenarios(HttpClientType clientType) async {
    if (_isRunning || _runningAllScenarios) return;

    _runningAllScenarios = true;
    _isRunning = true;
    _currentClientForAllScenarios = clientType;
    _currentScenarioIndex = 0;
    _activeClient = clientType;

    // Clear previous results for this client
    if (!_allScenarioResults.containsKey(clientType.name)) {
      _allScenarioResults[clientType.name] = {};
    }
    _allScenarioResults[clientType.name]!.clear();
    _completedBenchmarks[clientType]!.clear();

    notifyListeners();

    try {
      for (int i = 0; i < BenchmarkScenarios.scenarios.length; i++) {
        if (!_runningAllScenarios || !_isRunning) break; // Stop if cancelled

        _currentScenarioIndex = i;
        final scenario = BenchmarkScenarios.scenarios[i];
        _currentScenarioName = scenario.name;

        // Update status
        _liveData[clientType] = _liveData[clientType]!.copyWith(
          scenario: scenario,
          currentStatus: 'Running scenario ${i + 1}/${BenchmarkScenarios.scenarios.length}: ${scenario.name}',
          progress: 0.0,
          isRunning: true,
        );

        notifyListeners();

        // Add a small delay between scenarios for UI updates
        await Future.delayed(Duration(milliseconds: 500));

        // Run the benchmark for this scenario
        final result = await _runBenchmark(clientType, scenario);

        // Store the results
        _allScenarioResults[clientType.name]![scenario.name] = {
          'scenario': _scenarioToJson(scenario),
          'results': _metricsToJson(result),
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Also store in completed benchmarks for analysis
        _completedBenchmarks[clientType]!.add(result);

        // Update progress
        final overallProgress = (i + 1) / BenchmarkScenarios.scenarios.length;
        _liveData[clientType] = _liveData[clientType]!.copyWith(
          currentMetrics: result,
          progress: overallProgress,
          currentStatus: 'Completed scenario: ${scenario.name}',
        );

        notifyListeners();

        // Small delay before next scenario
        if (i < BenchmarkScenarios.scenarios.length - 1) {
          await Future.delayed(Duration(milliseconds: 1000));
        }
      }

      // Final update
      _liveData[clientType] = _liveData[clientType]!.copyWith(
        currentStatus: 'All scenarios completed successfully!',
        isRunning: false,
        progress: 1.0,
      );

      // Save results to persistent storage
      await _saveAllResultsToStorage();

    } catch (e) {
      _liveData[clientType] = _liveData[clientType]!.copyWith(
        isRunning: false,
        currentStatus: 'Error running scenarios: ${e.toString()}',
      );
      print('Error running all scenarios: $e');
    } finally {
      _runningAllScenarios = false;
      _isRunning = false;
      _currentScenarioName = null;
      _currentClientForAllScenarios = null;
      _activeClient = null;
      _stopRealtimeUpdates();
      notifyListeners();
    }
  }

  /// Save all results to persistent storage
  Future<void> _saveAllResultsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();

      // Get existing results
      final existingResultsJson = prefs.getString('benchmark_results') ?? '[]';
      final existingResults = json.decode(existingResultsJson) as List;

      // Add new results with timestamp
      existingResults.add({
        'id': _generateResultId(),
        'timestamp': timestamp,
        'results': _allScenarioResults,
        'version': '1.0',
      });

      // Keep only last 50 benchmark runs to prevent excessive storage
      if (existingResults.length > 50) {
        existingResults.removeRange(0, existingResults.length - 50);
      }

      // Save back to preferences
      await prefs.setString('benchmark_results', json.encode(existingResults));

      print('Benchmark results saved successfully!');
    } catch (e) {
      print('Error saving results to storage: $e');
    }
  }

  String _generateResultId() {
    return 'bench_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  Map<String, dynamic> _scenarioToJson(BenchmarkScenario scenario) {
    return {
      'name': scenario.name,
      'description': scenario.description,
      'concurrentRequests': scenario.concurrentRequests,
      'totalRequests': scenario.totalRequests,
      'endpoint': scenario.endpoint,
      'method': scenario.method,
      'enableCacheBusting': scenario.enableCacheBusting,
      'enableComplexParsing': scenario.enableComplexParsing,
    };
  }

  Map<String, dynamic> _metricsToJson(BenchmarkMetrics metrics) {
    return {
      'totalRequests': metrics.totalRequests,
      'successfulRequests': metrics.successfulRequests,
      'failedRequests': metrics.failedRequests,
      'averageLatency': metrics.averageLatency,
      'p95Latency': metrics.p95Latency,
      'p99Latency': metrics.p99Latency,
      'throughput': metrics.throughput,
      'cpuUsage': metrics.cpuUsage,
      'memoryUsageMB': metrics.memoryUsageMB,
      'successRate': metrics.successRate,
      'startTime': metrics.startTime?.toIso8601String(),
      'endTime': metrics.endTime?.toIso8601String(),
      'additionalMetrics': metrics.additionalMetrics,
    };
  }

  /// Get all stored results for external access
  Map<String, Map<String, dynamic>> getAllResults() {
    return Map.from(_allScenarioResults);
  }

  /// Load historical results from storage
  Future<List<Map<String, dynamic>>> getHistoricalResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resultsJson = prefs.getString('benchmark_results') ?? '[]';
      final results = json.decode(resultsJson) as List;
      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading historical results: $e');
      return [];
    }
  }

  /// Clear all stored results
  Future<void> clearStoredResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('benchmark_results');
      _allScenarioResults.clear();
      notifyListeners();
    } catch (e) {
      print('Error clearing stored results: $e');
    }
  }

  // Start benchmark for specific client (original single scenario method)
  Future<void> startBenchmark(HttpClientType clientType, BenchmarkScenario scenario) async {
    if (_isRunning) return;

    _isRunning = true;
    _activeClient = clientType;

    // Reset live data for this client
    _liveData[clientType] = LiveBenchmarkData(
      clientType: clientType,
      scenario: scenario,
      currentMetrics: _createEmptyMetrics(),
      progress: 0.0,
      isRunning: true,
      currentStatus: 'Initializing benchmark...',
      realtimeLatencies: [],
      realtimeThroughput: [],
    );

    notifyListeners();

    try {
      final result = await _runBenchmark(clientType, scenario);

      // Store completed benchmark
      _completedBenchmarks[clientType]!.add(result);

      // Update live data with final results
      _liveData[clientType] = _liveData[clientType]!.copyWith(
        currentMetrics: result,
        progress: 1.0,
        isRunning: false,
        currentStatus: 'Benchmark completed successfully!',
      );

    } catch (e) {
      _liveData[clientType] = _liveData[clientType]!.copyWith(
        isRunning: false,
        currentStatus: 'Benchmark failed: ${e.toString()}',
      );
    } finally {
      _isRunning = false;
      _activeClient = null;
      _stopRealtimeUpdates();
      notifyListeners();
    }
  }

  Future<BenchmarkMetrics> _runBenchmark(HttpClientType clientType, BenchmarkScenario scenario) async {
    final client = _clients[clientType]!;
    final startTime = DateTime.now();
    final latencies = <double>[];
    final realtimeLatencies = <double>[];
    final realtimeThroughput = <double>[];

    int totalRequests = 0;
    int successfulRequests = 0;
    int failedRequests = 0;
    double currentThroughput = 0.0;

    // Start realtime updates
    _startRealtimeUpdates(clientType, realtimeLatencies, realtimeThroughput);

    // Calculate batch size for concurrent execution
    final batchSize = scenario.totalRequests ~/ scenario.concurrentRequests;
    final batches = <Future<List<RequestResult>>>[];

    // Create concurrent batches
    for (int i = 0; i < scenario.concurrentRequests; i++) {
      batches.add(_executeBatch(client, scenario, batchSize, i));
    }

    int completedBatches = 0;

    // Execute batches and collect results
    await for (final batchResults in Stream.fromFutures(batches)) {
      if (!_isRunning && !_runningAllScenarios) break; // Stop if cancelled

      completedBatches++;

      for (final result in batchResults) {
        totalRequests++;
        latencies.add(result.latency);
        realtimeLatencies.add(result.latency);

        if (result.success) {
          successfulRequests++;
        } else {
          failedRequests++;
        }

        // Update progress and metrics
        final progress = totalRequests / scenario.totalRequests;
        final elapsed = DateTime.now().difference(startTime);
        currentThroughput = totalRequests / (elapsed.inMilliseconds / 1000.0);

        if (realtimeThroughput.length < 100) {
          realtimeThroughput.add(currentThroughput);
        } else {
          realtimeThroughput.removeAt(0);
          realtimeThroughput.add(currentThroughput);
        }

        // Update live data periodically
        if (totalRequests % 10 == 0) {
          await _updateLiveMetrics(clientType, totalRequests, successfulRequests,
              failedRequests, latencies, progress, currentThroughput, startTime);
        }
      }
    }

    final endTime = DateTime.now();

    // Calculate final metrics
    latencies.sort();
    final avgLatency = latencies.isNotEmpty ? latencies.reduce((a, b) => a + b) / latencies.length : 0.0;
    final p95Index = (latencies.length * 0.95).floor();
    final p99Index = (latencies.length * 0.99).floor();
    final p95Latency = latencies.isNotEmpty ? latencies[min(p95Index, latencies.length - 1)] : 0.0;
    final p99Latency = latencies.isNotEmpty ? latencies[min(p99Index, latencies.length - 1)] : 0.0;
    final finalThroughput = totalRequests / (endTime.difference(startTime).inMilliseconds / 1000.0);

    return BenchmarkMetrics(
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      averageLatency: avgLatency,
      p95Latency: p95Latency,
      p99Latency: p99Latency,
      throughput: finalThroughput,
      cpuUsage: _simulateCpuUsage(clientType),
      memoryUsageMB: _simulateMemoryUsage(),
      latencyHistory: List.from(latencies),
      startTime: startTime,
      endTime: endTime,
      additionalMetrics: {
        'concurrent_requests': scenario.concurrentRequests,
        'scenario_name': scenario.name,
        'cache_busting': scenario.enableCacheBusting,
        'complex_parsing': scenario.enableComplexParsing,
      },
    );
  }

  Future<List<RequestResult>> _executeBatch(
      HttpClientInterface client,
      BenchmarkScenario scenario,
      int batchSize,
      int batchIndex) async {
    final results = <RequestResult>[];

    print('Starting batch $batchIndex with $batchSize requests');
    print('Endpoint: ${scenario.endpoint}');
    print('Method: ${scenario.method}');

    for (int i = 0; i < batchSize; i++) {
      if (!_isRunning && !_runningAllScenarios) break;

      final requestStart = DateTime.now();

      try {
        final url = _prepareBenchmarkUrl(scenario.endpoint, scenario.enableCacheBusting);
        final payload = _prepareBenchmarkPayload(scenario.payload);

        print('Making request ${i + 1}/$batchSize to: $url');
        print('Payload: $payload');
        print('Headers: ${scenario.headers}');

        final response = await client.makeRequest(
          method: scenario.method,
          url: url,
          payload: payload,
          headers: scenario.headers,
          timeout: scenario.timeout ?? Duration(seconds: 30),
        );

        final latency = DateTime.now().difference(requestStart).inMicroseconds / 1000.0;

        print('Response: Status=${response.statusCode}, Success=${response.isSuccess}, Body length=${response.body.length}');

        results.add(RequestResult(
          success: response.isSuccess,
          latency: latency,
          statusCode: response.statusCode,
          responseSize: response.body.length,
        ));

        if (i < batchSize - 1) {
          await Future.delayed(Duration(milliseconds: Random().nextInt(10) + 1));
        }

      } catch (e, stackTrace) {
        final latency = DateTime.now().difference(requestStart).inMicroseconds / 1000.0;

        print('Request failed with error: $e');
        print('Stack trace: $stackTrace');

        results.add(RequestResult(
          success: false,
          latency: latency,
          statusCode: 500,
          responseSize: 0,
        ));
      }
    }

    print('Batch $batchIndex completed. Success rate: ${results.where((r) => r.success).length}/${results.length}');
    return results;
  }

  String _prepareBenchmarkUrl(String baseUrl, bool enableCacheBusting) {
    if (!enableCacheBusting) return baseUrl;

    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['_cb'] = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}';

    return uri.replace(queryParameters: params).toString();
  }

  Map<String, dynamic>? _prepareBenchmarkPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;

    final prepared = Map<String, dynamic>.from(payload);

    // Replace template variables
    prepared.forEach((key, value) {
      if (value is String) {
        if (value.contains('{{timestamp}}')) {
          prepared[key] = value.replaceAll('{{timestamp}}', DateTime.now().millisecondsSinceEpoch.toString());
        }
        if (value.contains('{{user_id}}')) {
          prepared[key] = value.replaceAll('{{user_id}}', Random().nextInt(10000).toString());
        }
        if (value.contains('{{large_payload}}')) {
          prepared[key] = value.replaceAll('{{large_payload}}', 'x' * 1024); // 1KB payload
        }
      }
    });

    return prepared;
  }

  void _startRealtimeUpdates(HttpClientType clientType, List<double> latencies, List<double> throughput) {
    _realtimeTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_liveData[clientType] != null && (_isRunning || _runningAllScenarios)) {
        _liveData[clientType] = _liveData[clientType]!.copyWith(
          realtimeLatencies: List.from(latencies.length > 50 ? latencies.sublist(latencies.length - 50) : latencies),
          realtimeThroughput: List.from(throughput.length > 50 ? throughput.sublist(throughput.length - 50) : throughput),
        );
        notifyListeners();
      }
    });
  }

  void _stopRealtimeUpdates() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
  }

  Future<void> _updateLiveMetrics(
      HttpClientType clientType,
      int totalRequests,
      int successfulRequests,
      int failedRequests,
      List<double> latencies,
      double progress,
      double throughput,
      DateTime startTime) async {

    final sortedLatencies = List<double>.from(latencies)..sort();
    final avgLatency = sortedLatencies.isNotEmpty
        ? sortedLatencies.reduce((a, b) => a + b) / sortedLatencies.length
        : 0.0;

    final currentMetrics = BenchmarkMetrics(
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      averageLatency: avgLatency,
      p95Latency: sortedLatencies.isNotEmpty
          ? sortedLatencies[min((sortedLatencies.length * 0.95).floor(), sortedLatencies.length - 1)]
          : 0.0,
      p99Latency: sortedLatencies.isNotEmpty
          ? sortedLatencies[min((sortedLatencies.length * 0.99).floor(), sortedLatencies.length - 1)]
          : 0.0,
      throughput: throughput,
      cpuUsage: _simulateCpuUsage(clientType),
      memoryUsageMB: _simulateMemoryUsage(),
      latencyHistory: List.from(sortedLatencies),
      startTime: startTime,
    );

    String status = 'Processing... ${(progress * 100).toStringAsFixed(1)}% complete';
    if (_runningAllScenarios && _currentScenarioName != null) {
      status = 'Scenario ${_currentScenarioIndex + 1}/${BenchmarkScenarios.scenarios.length}: $_currentScenarioName - ${(progress * 100).toStringAsFixed(1)}%';
    }

    _liveData[clientType] = _liveData[clientType]!.copyWith(
      currentMetrics: currentMetrics,
      progress: progress,
      currentStatus: status,
    );

    notifyListeners();
  }

  double _simulateCpuUsage(HttpClientType clientType) {
    final random = Random();
    switch (clientType) {
      case HttpClientType.rustParsedRust:
        return random.nextDouble() * 15 + 10;
      case HttpClientType.dartParsedRust:
        return random.nextDouble() * 20 + 15;
      case HttpClientType.rustDartInterop:
        return random.nextDouble() * 25 + 20;
      case HttpClientType.dioHttp2:
        return random.nextDouble() * 30 + 25;
    }
  }

  double _simulateMemoryUsage() {
    return Random().nextDouble() * 50 + 20; // 20-70 MB
  }

  // Generate comprehensive analysis
  void generateAnalysis() {
    if (_completedBenchmarks.values.any((list) => list.isEmpty)) {
      _analysis = null;
      notifyListeners();
      return;
    }

    final allResults = <BenchmarkMetrics>[];
    for (final results in _completedBenchmarks.values) {
      allResults.addAll(results);
    }

    // Calculate averages per client
    final clientAverages = <HttpClientType, BenchmarkMetrics>{};
    for (final clientType in HttpClientType.values) {
      final results = _completedBenchmarks[clientType]!;
      if (results.isNotEmpty) {
        clientAverages[clientType] = _calculateAverageMetrics(results);
      }
    }

    // Find winner
    final winner = _findWinner(clientAverages);

    // Generate comparisons
    final comparisons = _generateComparisons(clientAverages, winner);

    // Generate rankings
    final rankings = _generateRankings(clientAverages);

    // Generate recommendation
    final recommendation = _generateRecommendation(winner, clientAverages);

    // Build performance matrix
    final performanceMatrix = _buildPerformanceMatrix(clientAverages);

    _analysis = BenchmarkAnalysis(
      allResults: allResults,
      winner: winner,
      comparisons: comparisons,
      rankings: rankings,
      recommendation: recommendation,
      performanceMatrix: performanceMatrix,
    );

    notifyListeners();
  }

  BenchmarkMetrics _calculateAverageMetrics(List<BenchmarkMetrics> results) {
    if (results.isEmpty) return _createEmptyMetrics();

    final avgLatency = results.map((r) => r.averageLatency).reduce((a, b) => a + b) / results.length;
    final avgThroughput = results.map((r) => r.throughput).reduce((a, b) => a + b) / results.length;
    final avgCpu = results.map((r) => r.cpuUsage).reduce((a, b) => a + b) / results.length;
    final avgMemory = results.map((r) => r.memoryUsageMB).reduce((a, b) => a + b) / results.length;
    final totalRequests = results.map((r) => r.totalRequests).reduce((a, b) => a + b);
    final totalSuccess = results.map((r) => r.successfulRequests).reduce((a, b) => a + b);
    final totalFailed = results.map((r) => r.failedRequests).reduce((a, b) => a + b);

    return BenchmarkMetrics(
      totalRequests: totalRequests,
      successfulRequests: totalSuccess,
      failedRequests: totalFailed,
      averageLatency: avgLatency,
      p95Latency: results.map((r) => r.p95Latency).reduce((a, b) => a + b) / results.length,
      p99Latency: results.map((r) => r.p99Latency).reduce((a, b) => a + b) / results.length,
      throughput: avgThroughput,
      cpuUsage: avgCpu,
      memoryUsageMB: avgMemory,
      latencyHistory: [],
      startTime: results.first.startTime,
      endTime: results.last.endTime,
    );
  }

  HttpClientType _findWinner(Map<HttpClientType, BenchmarkMetrics> averages) {
    HttpClientType? winner;
    double bestScore = 0;

    averages.forEach((clientType, metrics) {
      final score = (metrics.successRate * 0.3) +
          ((1000 / (metrics.averageLatency + 1)) * 0.3) +
          (metrics.throughput / 100 * 0.2) +
          ((100 - metrics.cpuUsage) * 0.1) +
          ((100 - metrics.memoryUsageMB) * 0.1);

      if (score > bestScore) {
        bestScore = score;
        winner = clientType;
      }
    });

    return winner ?? HttpClientType.rustParsedRust;
  }

  Map<String, String> _generateComparisons(Map<HttpClientType, BenchmarkMetrics> averages, HttpClientType winner) {
    final comparisons = <String, String>{};
    final winnerMetrics = averages[winner]!;

    averages.forEach((clientType, metrics) {
      if (clientType == winner) return;

      final latencyRatio = metrics.averageLatency / winnerMetrics.averageLatency;
      final throughputRatio = winnerMetrics.throughput / metrics.throughput;

      String comparison;
      if (latencyRatio > 2) {
        comparison = '${latencyRatio.toStringAsFixed(1)}x slower response time';
      } else if (throughputRatio > 2) {
        comparison = '${throughputRatio.toStringAsFixed(1)}x lower throughput';
      } else {
        comparison = 'Similar performance with slight differences';
      }

      comparisons[clientType.name] = comparison;
    });

    return comparisons;
  }

  Map<String, double> _generateRankings(Map<HttpClientType, BenchmarkMetrics> averages) {
    final rankings = <String, double>{};

    averages.forEach((clientType, metrics) {
      final score = (metrics.successRate * 0.3) +
          ((1000 / (metrics.averageLatency + 1)) * 0.3) +
          (metrics.throughput / 100 * 0.2) +
          ((100 - metrics.cpuUsage) * 0.1) +
          ((100 - metrics.memoryUsageMB) * 0.1);

      rankings[clientType.name] = score;
    });

    return rankings;
  }

  String _generateRecommendation(HttpClientType winner, Map<HttpClientType, BenchmarkMetrics> averages) {
    final winnerMetrics = averages[winner]!;

    switch (winner) {
      case HttpClientType.rustParsedRust:
        return 'Rust→Rust offers the best overall performance with ${winnerMetrics.averageLatency.toStringAsFixed(0)}ms average latency and ${winnerMetrics.throughput.toStringAsFixed(1)} RPS. Recommended for high-performance applications requiring maximum throughput.';
      case HttpClientType.dartParsedRust:
        return 'Rust→Dart provides excellent performance while maintaining Dart-side parsing flexibility. Good balance of speed and development convenience.';
      case HttpClientType.dioHttp2:
        return 'Dio HTTP/2 offers solid performance for pure Dart applications. Best choice when Rust integration is not feasible.';
      case HttpClientType.rustDartInterop:
        return 'Rust-Dart Interop provides optimized performance with good integration. Suitable for applications needing hybrid approaches.';
    }
  }

  Map<String, List<double>> _buildPerformanceMatrix(Map<HttpClientType, BenchmarkMetrics> averages) {
    final matrix = <String, List<double>>{};

    averages.forEach((clientType, metrics) {
      matrix[clientType.name] = [
        metrics.averageLatency,
        metrics.throughput,
        metrics.successRate,
        metrics.cpuUsage,
        metrics.memoryUsageMB,
      ];
    });

    return matrix;
  }

  // Stop all running benchmarks
  void stopAllBenchmarks() {
    _isRunning = false;
    _runningAllScenarios = false;
    _activeClient = null;
    _currentScenarioName = null;
    _currentClientForAllScenarios = null;
    _stopRealtimeUpdates();

    for (final clientType in HttpClientType.values) {
      if (_liveData[clientType]?.isRunning == true) {
        _liveData[clientType] = _liveData[clientType]!.copyWith(
          isRunning: false,
          currentStatus: 'Benchmark stopped by user',
        );
      }
    }

    notifyListeners();
  }

  // Clear all results
  void clearAllResults() {
    for (final clientType in HttpClientType.values) {
      _completedBenchmarks[clientType]!.clear();
    }
    _allScenarioResults.clear();
    _analysis = null;
    _initializeLiveData();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopRealtimeUpdates();
    _clients.values.forEach((client) => client.dispose());
    super.dispose();
  }
}

class RequestResult {
  final bool success;
  final double latency;
  final int statusCode;
  final int responseSize;

  RequestResult({
    required this.success,
    required this.latency,
    required this.statusCode,
    required this.responseSize,
  });
}