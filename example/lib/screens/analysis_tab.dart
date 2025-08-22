import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../providers/benchmark_provider.dart';
import '../models/benchmark_models.dart';
import '../config/app_theme.dart';
import '../config/benchmark_scenarios.dart';

class AnalysisTab extends StatefulWidget {
  final TabController? tabController;  // Add this

  const AnalysisTab({super.key, this.tabController});  // Add this

  @override
  _AnalysisTabState createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late AnimationController _chartAnimationController;
  late Animation<double> _chartAnimation;
  Map<String, dynamic> _analysisData = {};
  List<Map<String, dynamic>> _historicalData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chartAnimationController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _chartAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _chartAnimationController, curve: Curves.easeOutCubic),
    );
    _loadAndAnalyzeData();
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadAndAnalyzeData() async {
    setState(() => _isLoading = true);

    try {
      // Load historical data
      final prefs = await SharedPreferences.getInstance();
      final resultsJson = prefs.getString('benchmark_results') ?? '[]';
      final storedResults = json.decode(resultsJson) as List;
      _historicalData = storedResults.cast<Map<String, dynamic>>();

      // Get current data from provider
      final provider = Provider.of<BenchmarkProvider>(context, listen: false);
      final currentResults = provider.getAllResults();

      // Combine current and historical data for comprehensive analysis
      if (currentResults.isNotEmpty || _historicalData.isNotEmpty) {
        _analysisData = _generateComprehensiveAnalysis(currentResults, _historicalData);
        _chartAnimationController.forward();
      }
    } catch (e) {
      print('Error loading analysis data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _generateComprehensiveAnalysis(
      Map<String, Map<String, dynamic>> currentResults,
      List<Map<String, dynamic>> historicalData,
      ) {
    final analysis = <String, dynamic>{};

    // If no current data, use the most recent historical data
    Map<String, Map<String, dynamic>> dataToAnalyze = currentResults;
    if (dataToAnalyze.isEmpty && historicalData.isNotEmpty) {
      dataToAnalyze = Map<String, Map<String, dynamic>>.from(
          historicalData.last['results'] ?? {}
      );
    }

    if (dataToAnalyze.isEmpty) return {};

    // Extract metrics for each client type
    final clientMetrics = <String, Map<String, dynamic>>{};
    final scenarioComparisons = <String, Map<String, dynamic>>{};

    dataToAnalyze.forEach((clientType, scenarios) {
      final allMetrics = <Map<String, dynamic>>[];
      scenarios.forEach((scenarioName, data) {
        if (data is Map && data.containsKey('results')) {
          allMetrics.add(Map<String, dynamic>.from(data['results']));

          // Store individual scenario data
          if (!scenarioComparisons.containsKey(scenarioName)) {
            scenarioComparisons[scenarioName] = <String, dynamic>{};
          }
          scenarioComparisons[scenarioName]![clientType] = data['results'];
        }
      });

      if (allMetrics.isNotEmpty) {
        clientMetrics[clientType] = _calculateAverageMetrics(allMetrics);
      }
    });

    // Comprehensive analysis
    analysis['clientMetrics'] = clientMetrics;
    analysis['scenarioComparisons'] = scenarioComparisons;
    analysis['winner'] = _findOverallWinner(clientMetrics);
    analysis['performanceGains'] = _calculatePerformanceGains(clientMetrics);
    analysis['resourceEfficiency'] = _analyzeResourceEfficiency(clientMetrics);
    analysis['scalabilityAnalysis'] = _analyzeScalability(clientMetrics, scenarioComparisons);
    analysis['gameChangerInsights'] = _generateGameChangerInsights(clientMetrics, scenarioComparisons);
    analysis['recommendations'] = _generateDetailedRecommendations(clientMetrics, scenarioComparisons);
    analysis['trends'] = _analyzeTrends(historicalData);
    analysis['costBenefit'] = _analyzeCostBenefit(clientMetrics);

    return analysis;
  }

  Map<String, dynamic> _calculateAverageMetrics(List<Map<String, dynamic>> metrics) {
    if (metrics.isEmpty) return {};

    final result = <String, dynamic>{
      'averageLatency': 0.0,
      'p95Latency': 0.0,
      'p99Latency': 0.0,
      'throughput': 0.0,
      'successRate': 0.0,
      'cpuUsage': 0.0,
      'memoryUsageMB': 0.0,
      'totalRequests': 0,
      'successfulRequests': 0,
      'failedRequests': 0,
    };

    for (final metric in metrics) {
      result['averageLatency'] += (metric['averageLatency'] ?? 0.0);
      result['p95Latency'] += (metric['p95Latency'] ?? 0.0);
      result['p99Latency'] += (metric['p99Latency'] ?? 0.0);
      result['throughput'] += (metric['throughput'] ?? 0.0);
      result['successRate'] += (metric['successRate'] ?? 0.0);
      result['cpuUsage'] += (metric['cpuUsage'] ?? 0.0);
      result['memoryUsageMB'] += (metric['memoryUsageMB'] ?? 0.0);
      result['totalRequests'] += (metric['totalRequests'] ?? 0);
      result['successfulRequests'] += (metric['successfulRequests'] ?? 0);
      result['failedRequests'] += (metric['failedRequests'] ?? 0);
    }

    final count = metrics.length.toDouble();
    result['averageLatency'] /= count;
    result['p95Latency'] /= count;
    result['p99Latency'] /= count;
    result['throughput'] /= count;
    result['successRate'] /= count;
    result['cpuUsage'] /= count;
    result['memoryUsageMB'] /= count;

    return result;
  }

  String _findOverallWinner(Map<String, Map<String, dynamic>> clientMetrics) {
    if (clientMetrics.isEmpty) return '';

    String winner = '';
    double bestScore = 0;

    clientMetrics.forEach((client, metrics) {
      final latency = metrics['averageLatency'] ?? 1000.0;
      final throughput = metrics['throughput'] ?? 0.0;
      final successRate = metrics['successRate'] ?? 0.0;
      final cpuUsage = metrics['cpuUsage'] ?? 100.0;
      final memoryUsage = metrics['memoryUsageMB'] ?? 100.0;

      // Comprehensive scoring algorithm
      final score = (successRate * 0.25) +                    // 25% success rate
          ((1000 / (latency + 1)) * 0.25) +         // 25% latency (inverted)
          ((throughput / 100) * 0.2) +              // 20% throughput
          (((100 - cpuUsage) / 100) * 0.15) +       // 15% CPU efficiency
          (((100 - memoryUsage) / 100) * 0.15);     // 15% memory efficiency

      if (score > bestScore) {
        bestScore = score;
        winner = client;
      }
    });

    return winner;
  }

  Map<String, dynamic> _calculatePerformanceGains(Map<String, Map<String, dynamic>> clientMetrics) {
    final gains = <String, dynamic>{};

    if (clientMetrics.length < 2) return gains;

    final clients = clientMetrics.keys.toList();
    final baseline = clientMetrics[clients.first];

    clientMetrics.forEach((client, metrics) {
      if (client == clients.first) return;

      final latencyGain = ((baseline!['averageLatency'] - metrics['averageLatency']) / baseline['averageLatency']) * 100;
      final throughputGain = ((metrics['throughput'] - baseline['throughput']) / baseline['throughput']) * 100;
      final cpuEfficiency = ((baseline['cpuUsage'] - metrics['cpuUsage']) / baseline['cpuUsage']) * 100;
      final memoryEfficiency = ((baseline['memoryUsageMB'] - metrics['memoryUsageMB']) / baseline['memoryUsageMB']) * 100;

      gains[client] = {
        'latencyImprovement': latencyGain,
        'throughputGain': throughputGain,
        'cpuEfficiency': cpuEfficiency,
        'memoryEfficiency': memoryEfficiency,
        'overallGain': (latencyGain + throughputGain + cpuEfficiency + memoryEfficiency) / 4,
      };
    });

    return gains;
  }

  Map<String, dynamic> _analyzeResourceEfficiency(Map<String, Map<String, dynamic>> clientMetrics) {
    final efficiency = <String, dynamic>{};

    clientMetrics.forEach((client, metrics) {
      final throughputPerCpu = metrics['throughput'] / (metrics['cpuUsage'] + 1);
      final throughputPerMb = metrics['throughput'] / (metrics['memoryUsageMB'] + 1);
      final requestsPerResource = metrics['totalRequests'] /
          ((metrics['cpuUsage'] + metrics['memoryUsageMB']) + 1);

      efficiency[client] = {
        'throughputPerCpu': throughputPerCpu,
        'throughputPerMb': throughputPerMb,
        'requestsPerResource': requestsPerResource,
        'efficiencyScore': (throughputPerCpu + throughputPerMb + requestsPerResource) / 3,
      };
    });

    return efficiency;
  }

  Map<String, dynamic> _analyzeScalability(
      Map<String, Map<String, dynamic>> clientMetrics,
      Map<String, Map<String, dynamic>> scenarioComparisons,
      ) {
    final scalability = <String, dynamic>{};

    // Analyze how each client performs under different loads
    clientMetrics.forEach((client, metrics) {
      final scenarios = <String, dynamic>{};

      scenarioComparisons.forEach((scenario, clients) {
        if (clients.containsKey(client)) {
          final scenarioMetric = clients[client];
          scenarios[scenario] = {
            'latency': scenarioMetric['averageLatency'],
            'throughput': scenarioMetric['throughput'],
            'degradation': _calculateDegradation(scenarioMetric, metrics),
          };
        }
      });

      scalability[client] = {
        'scenarios': scenarios,
        'scalabilityScore': _calculateScalabilityScore(scenarios),
      };
    });

    return scalability;
  }

  double _calculateDegradation(Map<String, dynamic> scenario, Map<String, dynamic> average) {
    final latencyDeg = (scenario['averageLatency'] - average['averageLatency']) / average['averageLatency'];
    final throughputDeg = (average['throughput'] - scenario['throughput']) / average['throughput'];
    return (latencyDeg + throughputDeg) / 2 * 100;
  }

  double _calculateScalabilityScore(Map<String, dynamic> scenarios) {
    if (scenarios.isEmpty) return 0;

    final degradations = scenarios.values.map((s) => s['degradation'] as double).toList();
    final avgDegradation = degradations.reduce((a, b) => a + b) / degradations.length;
    return max(0, 100 - avgDegradation.abs());
  }

  List<Map<String, dynamic>> _generateGameChangerInsights(
      Map<String, Map<String, dynamic>> clientMetrics,
      Map<String, Map<String, dynamic>> scenarioComparisons,
      ) {
    final insights = <Map<String, dynamic>>[];

    // Find the biggest performance improvements
    final winner = _findOverallWinner(clientMetrics);
    if (winner.isNotEmpty && clientMetrics.containsKey(winner)) {
      final winnerMetrics = clientMetrics[winner]!;

      // Calculate impact metrics
      final otherClients = clientMetrics.keys.where((k) => k != winner).toList();
      if (otherClients.isNotEmpty) {
        final avgOtherLatency = otherClients
            .map((c) => clientMetrics[c]!['averageLatency'] as double)
            .reduce((a, b) => a + b) / otherClients.length;

        final avgOtherThroughput = otherClients
            .map((c) => clientMetrics[c]!['throughput'] as double)
            .reduce((a, b) => a + b) / otherClients.length;

        final latencyImprovement = ((avgOtherLatency - winnerMetrics['averageLatency']) / avgOtherLatency * 100);
        final throughputImprovement = ((winnerMetrics['throughput'] - avgOtherThroughput) / avgOtherThroughput * 100);

        if (latencyImprovement > 20) {
          insights.add({
            'type': 'performance',
            'title': 'Latency Performance',
            'description': '$winner delivers ${latencyImprovement.toStringAsFixed(1)}% faster response times, enabling real-time applications that weren\'t possible before.',
            'impact': 'High',
            'icon': Icons.flash_on,
            'color': Colors.amber,
          });
        }

        if (throughputImprovement > 30) {
          insights.add({
            'type': 'scalability',
            'title': 'Throughput Scaling',
            'description': '$winner handles ${throughputImprovement.toStringAsFixed(1)}% more requests, dramatically reducing infrastructure costs.',
            'impact': 'Very High',
            'icon': Icons.trending_up,
            'color': Colors.green,
          });
        }

        // Resource efficiency insights
        final cpuEfficiency = winnerMetrics['cpuUsage'] as double;
        if (cpuEfficiency < 30) {
          insights.add({
            'type': 'efficiency',
            'title': 'Resource Usage',
            'description': '$winner uses only ${cpuEfficiency.toStringAsFixed(1)}% CPU, enabling massive consolidation and cost savings.',
            'impact': 'High',
            'icon': Icons.eco,
            'color': Colors.teal,
          });
        }

        // Calculate potential cost savings
        final costSavings = _calculateCostSavings(winnerMetrics, avgOtherLatency, avgOtherThroughput);
        if (costSavings > 25) {
          insights.add({
            'type': 'cost',
            'title': 'Mobile Resource',
            'description': 'Up to ${costSavings.toStringAsFixed(0)}% reduction in server costs through superior efficiency.',
            'impact': 'Very High',
            'icon': Icons.savings,
            'color': Colors.purple,
          });
        }
      }
    }

    return insights;
  }

  double _calculateCostSavings(Map<String, dynamic> winnerMetrics, double avgLatency, double avgThroughput) {
    final winnerThroughput = winnerMetrics['throughput'] as double;
    final winnerCpu = winnerMetrics['cpuUsage'] as double;

    // Simplified cost model: fewer servers needed for same workload
    final serversNeeded = (avgThroughput / winnerThroughput) * (winnerCpu / 50); // Normalized
    return max(0, (1 - serversNeeded) * 100);
  }

  List<Map<String, dynamic>> _generateDetailedRecommendations(
      Map<String, Map<String, dynamic>> clientMetrics,
      Map<String, Map<String, dynamic>> scenarioComparisons,
      ) {
    final recommendations = <Map<String, dynamic>>[];

    final winner = _findOverallWinner(clientMetrics);

    recommendations.addAll([
      {
        'category': 'Production Deployment',
        'title': 'High-Traffic Applications',
        'recommendation': 'Use $winner for applications handling >10K requests/minute. The superior throughput and low latency make it ideal for API gateways and microservices.',
        'priority': 'High',
        'icon': Icons.rocket_launch,
        'color': Colors.red,
      },
      {
        'category': 'Development Strategy',
        'title': 'Migration Planning',
        'recommendation': 'Plan gradual migration to $winner starting with non-critical services. The performance gains justify the integration effort.',
        'priority': 'Medium',
        'icon': Icons.timeline,
        'color': Colors.blue,
      },
      {
        'category': 'Cost Optimization',
        'title': 'Infrastructure Scaling',
        'recommendation': 'Leverage ${winner}\'s efficiency to reduce server count by up to 40% while maintaining performance.',
        'priority': 'High',
        'icon': Icons.savings,
        'color': Colors.green,
      },
      {
        'category': 'Technical Implementation',
        'title': 'Performance Monitoring',
        'recommendation': 'Implement comprehensive monitoring to track the ${clientMetrics[winner]?['averageLatency']?.toStringAsFixed(0)}ms target latency.',
        'priority': 'Medium',
        'icon': Icons.monitor,
        'color': Colors.orange,
      },
    ]);

    return recommendations;
  }

  Map<String, dynamic> _analyzeTrends(List<Map<String, dynamic>> historicalData) {
    if (historicalData.length < 2) return {};

    // Analyze performance trends over time
    final trends = <String, dynamic>{};
    final timeSeriesData = <String, List<double>>{};

    for (final data in historicalData) {
      final results = data['results'] as Map<String, dynamic>?;
      if (results != null) {
        results.forEach((client, scenarios) {
          if (!timeSeriesData.containsKey(client)) {
            timeSeriesData[client] = [];
          }

          // Calculate average latency for this time point
          double totalLatency = 0;
          int count = 0;
          (scenarios as Map<String, dynamic>).values.forEach((scenario) {
            if (scenario is Map && scenario.containsKey('results')) {
              totalLatency += scenario['results']['averageLatency'] ?? 0;
              count++;
            }
          });

          if (count > 0) {
            timeSeriesData[client]!.add(totalLatency / count);
          }
        });
      }
    }

    // Calculate trend direction and improvement rate
    timeSeriesData.forEach((client, latencies) {
      if (latencies.length >= 2) {
        final improvement = (latencies.first - latencies.last) / latencies.first * 100;
        trends[client] = {
          'improvement': improvement,
          'trend': improvement > 5 ? 'improving' : improvement < -5 ? 'degrading' : 'stable',
          'dataPoints': latencies.length,
        };
      }
    });

    return trends;
  }

  Map<String, dynamic> _analyzeCostBenefit(Map<String, Map<String, dynamic>> clientMetrics) {
    final analysis = <String, dynamic>{};

    clientMetrics.forEach((client, metrics) {
      final throughput = metrics['throughput'] as double;
      final cpuUsage = metrics['cpuUsage'] as double;
      final memoryUsage = metrics['memoryUsageMB'] as double;

      // Simplified cost model (in arbitrary units)
      final developmentCost = _getDevelopmentCost(client);
      final operationalCost = (cpuUsage + memoryUsage) / 100 * 1000; // Monthly cost
      final revenueCapacity = throughput * 24 * 30; // Monthly request capacity

      final roi = (revenueCapacity * 0.001 - operationalCost) / developmentCost * 100; // 6-month ROI

      analysis[client] = {
        'developmentCost': developmentCost,
        'operationalCost': operationalCost,
        'revenueCapacity': revenueCapacity,
        'roi': roi,
        'paybackMonths': developmentCost / max(1, (revenueCapacity * 0.001 - operationalCost)),
      };
    });

    return analysis;
  }

  double _getDevelopmentCost(String client) {
    // Estimated development costs in arbitrary units
    switch (client.toLowerCase()) {
      case 'rustparsedrust':
        return 5000; // Higher initial cost
      case 'dartparsedrust':
        return 3000; // Medium cost
      case 'rustdartinterop':
        return 4000; // Medium-high cost
      case 'diohttp2':
        return 1000; // Lower cost
      default:
        return 2000;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<BenchmarkProvider>(
      builder: (context, provider, child) {
        if (_isLoading) {
          return _buildLoadingState();
        }

        if (_analysisData.isEmpty) {
          return _buildEmptyState();
        }

        return CustomScrollView(
          slivers: [
            _buildHeader(),
            _buildExecutiveSummary(),
            _buildPerformanceChampion(),
            _buildPerformanceGains(),
            _buildGameChangerInsights(),
            _buildResourceEfficiency(),
            _buildScalabilityAnalysis(),
            _buildDetailedRecommendations(),
            _buildTrendAnalysis(),
            _buildExportOptions(),
            SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(borderColor: Colors.amber),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.analytics, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprehensive Performance Analysis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Data-driven insights and recommendations',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loadAndAnalyzeData,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveSummary() {
    final clientMetrics = _analysisData['clientMetrics'] as Map<String, Map<String, dynamic>>? ?? {};
    final winner = _analysisData['winner'] as String? ?? '';

    if (clientMetrics.isEmpty) return SliverToBoxAdapter(child: SizedBox());

    final winnerMetrics = clientMetrics[winner] ?? {};
    final totalClients = clientMetrics.length;
    final avgLatency = winnerMetrics['averageLatency'] ?? 0.0;
    final avgThroughput = winnerMetrics['throughput'] ?? 0.0;

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: Colors.blue),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.withOpacity(0.1), Colors.purple.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize, color: Colors.blue, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Executive Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Performance Leader',
                      winner,
                      Icons.emoji_events,
                      Colors.amber,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Best Latency',
                      '${avgLatency.toStringAsFixed(0)}ms',
                      Icons.speed,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Peak Throughput',
                      '${avgThroughput.toStringAsFixed(1)} RPS',
                      Icons.trending_up,
                      Colors.orange,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Clients Tested',
                      '$totalClients',
                      Icons.compare,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChampion() {
    final winner = _analysisData['winner'] as String? ?? '';
    final clientMetrics = _analysisData['clientMetrics'] as Map<String, Map<String, dynamic>>? ?? {};

    if (winner.isEmpty || clientMetrics.isEmpty) return SliverToBoxAdapter(child: SizedBox());

    final winnerMetrics = clientMetrics[winner]!;
    final winnerType = HttpClientType.values.firstWhere(
          (type) => type.name.toLowerCase() == winner.toLowerCase(),
      orElse: () => HttpClientType.rustParsedRust,
    );

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: winnerType.color),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                winnerType.color.withOpacity(0.2),
                winnerType.color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🏆 Performance Champion',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: winnerType.color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(winnerType.icon, color: winnerType.color, size: 20),
                            ),
                            SizedBox(width: 12),
                            Text(
                              winnerType.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          winnerType.description,
                          style: TextStyle(color: Colors.grey[300], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Avg Latency',
                      '${winnerMetrics['averageLatency'].toStringAsFixed(1)}ms',
                      Icons.speed,
                      Colors.green,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Throughput',
                      '${winnerMetrics['throughput'].toStringAsFixed(1)} RPS',
                      Icons.trending_up,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Success Rate',
                      '${winnerMetrics['successRate'].toStringAsFixed(1)}%',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceGains() {
    final gains = _analysisData['performanceGains'] as Map<String, dynamic>? ?? {};

    if (gains.isEmpty) return SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: Colors.green),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.green, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Performance Gains Analysis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...gains.entries.map((entry) {
                final client = entry.key;
                final clientGains = entry.value as Map<String, dynamic>;
                final clientType = HttpClientType.values.firstWhere(
                      (type) => type.name.toLowerCase() == client.toLowerCase(),
                  orElse: () => HttpClientType.rustParsedRust,
                );

                return Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: clientType.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: clientType.color.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: clientType.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(clientType.icon, color: clientType.color, size: 20),
                          ),
                          SizedBox(width: 12),
                          Text(
                            client,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: clientType.color,
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getGainColor(clientGains['overallGain']).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${clientGains['overallGain'].toStringAsFixed(1)}% Overall',
                              style: TextStyle(
                                color: _getGainColor(clientGains['overallGain']),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGainMetric(
                              'Latency',
                              clientGains['latencyImprovement'],
                              '%',
                              Icons.speed,
                            ),
                          ),
                          Expanded(
                            child: _buildGainMetric(
                              'Throughput',
                              clientGains['throughputGain'],
                              '%',
                              Icons.trending_up,
                            ),
                          ),
                          Expanded(
                            child: _buildGainMetric(
                              'CPU Eff.',
                              clientGains['cpuEfficiency'],
                              '%',
                              Icons.memory,
                            ),
                          ),
                          Expanded(
                            child: _buildGainMetric(
                              'Memory Eff.',
                              clientGains['memoryEfficiency'],
                              '%',
                              Icons.storage,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGainMetric(String title, double value, String unit, IconData icon) {
    final color = _getGainColor(value);
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(height: 4),
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}$unit',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Color _getGainColor(double value) {
    if (value > 10) return Colors.green;
    if (value > 0) return Colors.lightGreen;
    if (value > -10) return Colors.orange;
    return Colors.red;
  }

  Widget _buildGameChangerInsights() {
    final insights = _analysisData['gameChangerInsights'] as List<Map<String, dynamic>>? ?? [];

    if (insights.isEmpty) return SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: Colors.purple),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.purple, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Game-Changing Insights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...insights.map((insight) {
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: insight['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: insight['color'].withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: insight['color'].withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(insight['icon'], color: insight['color'], size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  insight['title'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: insight['color'],
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: insight['color'].withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    insight['impact'],
                                    style: TextStyle(
                                      color: insight['color'],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              insight['description'],
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceEfficiency() {
    final efficiency = _analysisData['resourceEfficiency'] as Map<String, dynamic>? ?? {};

    if (efficiency.isEmpty) return SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: Colors.teal),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.eco, color: Colors.teal, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Resource Efficiency Analysis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                height: 200,
                child: AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: EfficiencyChartPainter(
                        data: efficiency,
                        animationProgress: _chartAnimation.value,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScalabilityAnalysis() {
    final scalability = _analysisData['scalabilityAnalysis'] as Map<String, dynamic>? ?? {};

    if (scalability.isEmpty) return SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: Colors.indigo),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.scale, color: Colors.indigo, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Scalability Analysis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...scalability.entries.map((entry) {
                final client = entry.key;
                final data = entry.value as Map<String, dynamic>;
                final scalabilityScore = data['scalabilityScore'] as double;
                final clientType = HttpClientType.values.firstWhere(
                      (type) => type.name.toLowerCase() == client.toLowerCase(),
                  orElse: () => HttpClientType.rustParsedRust,
                );

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: clientType.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: clientType.color.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: clientType.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(clientType.icon, color: clientType.color, size: 20),
                          ),
                          SizedBox(width: 12),
                          Text(
                            client,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: clientType.color,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'Score: ${scalabilityScore.toStringAsFixed(1)}/100',
                            style: TextStyle(
                              color: _getScoreColor(scalabilityScore),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: scalabilityScore / 100,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation(_getScoreColor(scalabilityScore)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDetailedRecommendations() {
    final recommendations = _analysisData['recommendations'] as List<Map<String, dynamic>>? ?? [];

    if (recommendations.isEmpty) return SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: Colors.blue),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.blue, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Strategic Recommendations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...recommendations.map((rec) {
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: rec['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: rec['color'].withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: rec['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(rec['icon'], color: rec['color'], size: 20),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      rec['category'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Spacer(),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: rec['color'].withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        rec['priority'],
                                        style: TextStyle(
                                          color: rec['color'],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  rec['title'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: rec['color'],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        rec['recommendation'],
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendAnalysis() {
    final trends = _analysisData['trends'] as Map<String, dynamic>? ?? {};

    if (trends.isEmpty) return SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: Colors.cyan),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.cyan, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Performance Trends',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...trends.entries.map((entry) {
                final client = entry.key;
                final trendData = entry.value as Map<String, dynamic>;
                final improvement = trendData['improvement'] as double;
                final trend = trendData['trend'] as String;
                final dataPoints = trendData['dataPoints'] as int;

                final clientType = HttpClientType.values.firstWhere(
                      (type) => type.name.toLowerCase() == client.toLowerCase(),
                  orElse: () => HttpClientType.rustParsedRust,
                );

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: clientType.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: clientType.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: clientType.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(clientType.icon, color: clientType.color, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              client,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: clientType.color,
                              ),
                            ),
                            Text(
                              '${improvement >= 0 ? '+' : ''}${improvement.toStringAsFixed(1)}% improvement over $dataPoints runs',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getTrendColor(trend).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTrendIcon(trend),
                              color: _getTrendColor(trend),
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              trend.toUpperCase(),
                              style: TextStyle(
                                color: _getTrendColor(trend),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'improving':
        return Colors.green;
      case 'stable':
        return Colors.blue;
      case 'degrading':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case 'improving':
        return Icons.trending_up;
      case 'stable':
        return Icons.trending_flat;
      case 'degrading':
        return Icons.trending_down;
      default:
        return Icons.remove;
    }
  }

  Widget _buildExportOptions() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppTheme.cardDecoration(borderColor: Colors.orange),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.download, color: Colors.orange, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Export & Share',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildExportButton(
                      'Export Report',
                      'PDF Analysis',
                      Icons.picture_as_pdf,
                      Colors.red,
                          () => _showExportDialog('PDF'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildExportButton(
                      'Share Results',
                      'Social/Email',
                      Icons.share,
                      Colors.blue,
                          () => _showExportDialog('Share'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildExportButton(
                      'Clear Data',
                      'Reset All',
                      Icons.clear_all,
                      Colors.red,
                          () => _showClearDialog(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildExportButton(
                      'History',
                      'View Past',
                      Icons.history,
                      Colors.purple,
                          () => _showHistoryDialog(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.amber),
          ),
          SizedBox(height: 24),
          Text(
            'Analyzing Performance Data...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Generating comprehensive insights',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics,
              size: 64,
              color: Colors.amber,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Data to Analyze',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Run benchmarks to see comprehensive\nperformance analysis and insights',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to first tab to run benchmarks
              widget.tabController?.animateTo(0);
            },
            icon: Icon(Icons.rocket_launch),
            label: Text('Start Benchmarking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Export $type',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '$type export functionality would be implemented here with full analysis data.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Clear All Data?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete all benchmark results and analysis data. This action cannot be undone.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<BenchmarkProvider>(context, listen: false);
              await provider.clearStoredResults();
              Navigator.of(context).pop();
              setState(() {
                _analysisData.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All benchmark data cleared'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardColor,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: Colors.purple, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Benchmark History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.grey[400]),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: _historicalData.isEmpty
                    ? Center(
                  child: Text(
                    'No historical data available',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                )
                    : ListView.builder(
                  itemCount: _historicalData.length,
                  itemBuilder: (context, index) {
                    final data = _historicalData[index];
                    final timestamp = DateTime.parse(data['timestamp']);
                    final results = data['results'] as Map<String, dynamic>?;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800]?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.grey[400], size: 16),
                              SizedBox(width: 8),
                              Text(
                                '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                ),
                              ),
                              Spacer(),
                              Text(
                                '${results?.length ?? 0} clients tested',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (results != null && results.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: results.keys.map((client) {
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[700],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    client,
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EfficiencyChartPainter extends CustomPainter {
  final Map<String, dynamic> data;
  final double animationProgress;

  EfficiencyChartPainter({
    required this.data,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final clients = data.keys.toList();
    final barWidth = (size.width - 100) / clients.length;

    // Find max efficiency score for scaling
    final maxScore = data.values
        .map((d) => d['efficiencyScore'] as double)
        .reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < clients.length; i++) {
      final client = clients[i];
      final clientData = data[client] as Map<String, dynamic>;
      final score = clientData['efficiencyScore'] as double;

      final clientType = HttpClientType.values.firstWhere(
            (type) => type.name.toLowerCase() == client.toLowerCase(),
        orElse: () => HttpClientType.rustParsedRust,
      );

      final barHeight = (score / maxScore) * (size.height * 0.8) * animationProgress;

      final rect = Rect.fromLTWH(
        50 + i * barWidth + barWidth * 0.2,
        size.height - barHeight - 20,
        barWidth * 0.6,
        barHeight,
      );

      paint.color = clientType.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(8)),
        paint,
      );

      // Draw efficiency score
      textPainter.text = TextSpan(
        text: score.toStringAsFixed(1),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          rect.center.dx - textPainter.width / 2,
          rect.top - 20,
        ),
      );

      // Draw client name
      textPainter.text = TextSpan(
        text: client,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          rect.center.dx - textPainter.width / 2,
          size.height - 15,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(EfficiencyChartPainter oldDelegate) {
    return data != oldDelegate.data || animationProgress != oldDelegate.animationProgress;
  }
}