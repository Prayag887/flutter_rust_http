import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/benchmark_provider.dart';
import '../models/benchmark_models.dart';
import '../widgets/live_metrics_card.dart';
import '../widgets/realtime_chart.dart';
import '../widgets/performance_summary.dart';
import '../widgets/benchmark_history.dart';
import '../config/app_theme.dart';

class DioHttp2Tab extends StatefulWidget {
  @override
  _DioHttp2TabState createState() => _DioHttp2TabState();
}

class _DioHttp2TabState extends State<DioHttp2Tab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<BenchmarkProvider>(
      builder: (context, provider, child) {
        final liveData = provider.liveData[HttpClientType.dioHttp2];
        final completedBenchmarks = provider.completedBenchmarks[HttpClientType.dioHttp2] ?? [];
        final isActive = provider.activeClient == HttpClientType.dioHttp2;

        return CustomScrollView(
          slivers: [
            // Header Section
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(
                  borderColor: HttpClientType.dioHttp2.color,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: HttpClientType.dioHttp2.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            HttpClientType.dioHttp2.icon,
                            color: HttpClientType.dioHttp2.color,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dio HTTP/2 Client',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Pure Dart implementation with HTTP/2 multiplexing',
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
                    _buildHttp2Features(),
                  ],
                ),
              ),
            ),

            // Live Metrics
            if (liveData != null && (liveData.isRunning || liveData.progress > 0))
              SliverToBoxAdapter(
                child: LiveMetricsCard(
                  clientType: HttpClientType.dioHttp2,
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
                        title: 'Response Times',
                        data: liveData.realtimeLatencies,
                        color: HttpClientType.dioHttp2.color,
                        unit: 'ms',
                        icon: Icons.access_time,
                      ),
                      SizedBox(height: 16),
                      RealtimeChart(
                        title: 'Connection Multiplexing',
                        data: liveData.realtimeThroughput,
                        color: Colors.teal,
                        unit: 'RPS',
                        icon: Icons.network_check,
                      ),
                    ],
                  ),
                ),
              ),

            // Performance Summary
            if (completedBenchmarks.isNotEmpty)
              SliverToBoxAdapter(
                child: PerformanceSummary(
                  clientType: HttpClientType.dioHttp2,
                  benchmarks: completedBenchmarks,
                ),
              ),

            // Benchmark History
            if (completedBenchmarks.isNotEmpty)
              SliverToBoxAdapter(
                child: BenchmarkHistory(
                  clientType: HttpClientType.dioHttp2,
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
      'HTTP/2 multiplexing support',
      'Connection pooling and reuse',
      'Built-in interceptors and middleware',
      'Comprehensive error handling',
      'Native Dart ecosystem integration',
    ];

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
              Icon(Icons.network_check, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Dio HTTP/2 Advantages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...features.map((feature) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue, size: 16),
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

  Widget _buildHttp2Features() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: Colors.purple, size: 20),
              SizedBox(width: 8),
              Text(
                'HTTP/2 Protocol Benefits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildProtocolFeature(
                  'Multiplexing',
                  'Multiple requests over single connection',
                  Icons.merge_type,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildProtocolFeature(
                  'Header Compression',
                  'HPACK reduces overhead',
                  Icons.compress,
                  Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildProtocolFeature(
                  'Server Push',
                  'Proactive resource delivery',
                  Icons.push_pin,
                  Colors.cyan,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildProtocolFeature(
                  'Stream Priority',
                  'Intelligent request ordering',
                  Icons.sort,
                  Colors.pink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolFeature(
      String title,
      String description,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
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
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HttpClientType.dioHttp2.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              HttpClientType.dioHttp2.icon,
              size: 48,
              color: HttpClientType.dioHttp2.color,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Ready for Dio HTTP/2 Benchmark',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pure Dart solution with modern HTTP/2 features',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(
              borderColor: HttpClientType.dioHttp2.color,
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
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildExpectedMetric('Latency', '8-28ms', Icons.timer),
                    _buildExpectedMetric('Success', '98%', Icons.check_circle),
                    _buildExpectedMetric('CPU', '25-55%', Icons.memory),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Best Dart-native solution for production apps',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildExpectedMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: HttpClientType.dioHttp2.color, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: HttpClientType.dioHttp2.color,
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