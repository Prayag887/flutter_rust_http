import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/benchmark_provider.dart';
import '../models/benchmark_models.dart';
import '../widgets/live_metrics_card.dart';
import '../widgets/realtime_chart.dart';
import '../widgets/performance_summary.dart';
import '../widgets/benchmark_history.dart';
import '../config/app_theme.dart';

class RustDartTab extends StatefulWidget {
  @override
  _RustDartTabState createState() => _RustDartTabState();
}

class _RustDartTabState extends State<RustDartTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<BenchmarkProvider>(
      builder: (context, provider, child) {
        final liveData = provider.liveData[HttpClientType.dartParsedRust];
        final completedBenchmarks = provider.completedBenchmarks[HttpClientType.dartParsedRust] ?? [];
        final isActive = provider.activeClient == HttpClientType.dartParsedRust;

        return CustomScrollView(
          slivers: [
            // Header Section
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(
                  borderColor: HttpClientType.dartParsedRust.color,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: HttpClientType.dartParsedRust.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            HttpClientType.dartParsedRust.icon,
                            color: HttpClientType.dartParsedRust.color,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rust→Dart HTTP Client',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Rust HTTP with Dart-side JSON parsing and processing',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildFeaturesList(),
                    SizedBox(height: 16),
                    _buildArchitectureComparison(),
                  ],
                ),
              ),
            ),

            // Live Metrics
            if (liveData != null && (liveData.isRunning || liveData.progress > 0))
              SliverToBoxAdapter(
                child: LiveMetricsCard(
                  clientType: HttpClientType.dartParsedRust,
                  liveData: liveData,
                ),
              ),

            // Real-time Charts
            if (liveData != null && liveData.isRunning)
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      RealtimeChart(
                        title: 'Latency Distribution',
                        data: liveData.realtimeLatencies,
                        color: HttpClientType.dartParsedRust.color,
                        unit: 'ms',
                        icon: Icons.timer,
                      ),
                      SizedBox(height: 16),
                      RealtimeChart(
                        title: 'Request Rate',
                        data: liveData.realtimeThroughput,
                        color: Colors.orange,
                        unit: 'RPS',
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ),
              ),

            // Performance Summary
            if (completedBenchmarks.isNotEmpty)
              SliverToBoxAdapter(
                child: PerformanceSummary(
                  clientType: HttpClientType.dartParsedRust,
                  benchmarks: completedBenchmarks,
                ),
              ),

            // Benchmark History
            if (completedBenchmarks.isNotEmpty)
              SliverToBoxAdapter(
                child: BenchmarkHistory(
                  clientType: HttpClientType.dartParsedRust,
                  benchmarks: completedBenchmarks,
                ),
              ),

            // Empty State
            if (completedBenchmarks.isEmpty && !isActive)
              SliverFillRemaining(
                child: _buildEmptyState(),
              ),

            // Bottom spacing
            SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      'Fast Rust HTTP networking',
      'Flexible Dart JSON processing',
      'Easy integration with Flutter widgets',
      'Balanced performance and convenience',
      'Dart isolate support for heavy parsing',
    ];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: Colors.lightGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Hybrid Architecture Benefits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightGreen,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...features.map((feature) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.lightGreen, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildArchitectureComparison() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Architecture Flow',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildArchitectureStep(
                  'HTTP Request',
                  'Rust',
                  Icons.rocket_launch,
                  Colors.orange,
                  'Fast network I/O',
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400]),
              Expanded(
                child: _buildArchitectureStep(
                  'JSON Parsing',
                  'Dart',
                  Icons.code,
                  Colors.blue,
                  'Flexible processing',
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400]),
              Expanded(
                child: _buildArchitectureStep(
                  'UI Update',
                  'Flutter',
                  Icons.widgets,
                  Colors.purple,
                  'Smooth integration',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureStep(
      String title,
      String tech,
      IconData icon,
      Color color,
      String description,
      ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        Text(
          tech,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          description,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HttpClientType.dartParsedRust.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                HttpClientType.dartParsedRust.icon,
                size: 48,
                color: HttpClientType.dartParsedRust.color,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Ready for Rust→Dart Benchmark',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Hybrid architecture balancing speed and flexibility',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(
                borderColor: HttpClientType.dartParsedRust.color,
              ),
              child: Column(
                children: [
                  Text(
                    'Expected Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildExpectedMetric('Latency', '3-13ms', Icons.timer),
                      _buildExpectedMetric('Success', '99%', Icons.check_circle),
                      _buildExpectedMetric('CPU', '15-35%', Icons.memory),
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

  Widget _buildExpectedMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: HttpClientType.dartParsedRust.color, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: HttpClientType.dartParsedRust.color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}