import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/benchmark_provider.dart';
import '../models/benchmark_models.dart';
import '../widgets/live_metrics_card.dart';
import '../widgets/realtime_chart.dart';
import '../widgets/performance_summary.dart';
import '../widgets/benchmark_history.dart';
import '../config/app_theme.dart';

class RustRustTab extends StatefulWidget {
      @override
      _RustRustTabState createState() => _RustRustTabState();
}

class _RustRustTabState extends State<RustRustTab>
    with AutomaticKeepAliveClientMixin {
      @override
      bool get wantKeepAlive => true;

      @override
      Widget build(BuildContext context) {
            super.build(context);

            return Consumer<BenchmarkProvider>(
                  builder: (context, provider, child) {
                        final liveData = provider.liveData[HttpClientType.rustParsedRust];
                        final completedBenchmarks = provider.completedBenchmarks[HttpClientType.rustParsedRust] ?? [];
                        final isActive = provider.activeClient == HttpClientType.rustParsedRust;

                        return CustomScrollView(
                              slivers: [
                                    // Header Section
                                    SliverToBoxAdapter(
                                          child: Container(
                                                margin: EdgeInsets.all(16),
                                                padding: EdgeInsets.all(20),
                                                decoration: AppTheme.cardDecoration(
                                                      borderColor: HttpClientType.rustParsedRust.color,
                                                ),
                                                child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                            Row(
                                                                  children: [
                                                                        Container(
                                                                              padding: EdgeInsets.all(12),
                                                                              decoration: BoxDecoration(
                                                                                    color: HttpClientType.rustParsedRust.color.withOpacity(0.2),
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                              ),
                                                                              child: Icon(
                                                                                    HttpClientType.rustParsedRust.icon,
                                                                                    color: HttpClientType.rustParsedRust.color,
                                                                                    size: 24,
                                                                              ),
                                                                        ),
                                                                        SizedBox(width: 16),
                                                                        Expanded(
                                                                              child: Column(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: [
                                                                                          Text(
                                                                                                'Rust→Rust HTTP Client',
                                                                                                style: TextStyle(
                                                                                                      fontSize: 20,
                                                                                                      fontWeight: FontWeight.bold,
                                                                                                      color: Colors.white,
                                                                                                ),
                                                                                          ),
                                                                                          Text(
                                                                                                'Pure Rust implementation with Rust-side JSON parsing',
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
                                                      ],
                                                ),
                                          ),
                                    ),

                                    // Live Metrics
                                    if (liveData != null && (liveData.isRunning || liveData.progress > 0))
                                          SliverToBoxAdapter(
                                                child: LiveMetricsCard(
                                                      clientType: HttpClientType.rustParsedRust,
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
                                                                        title: 'Latency Trend',
                                                                        data: liveData.realtimeLatencies,
                                                                        color: HttpClientType.rustParsedRust.color,
                                                                        unit: 'ms',
                                                                        icon: Icons.timer,
                                                                  ),
                                                                  SizedBox(height: 16),
                                                                  RealtimeChart(
                                                                        title: 'Throughput',
                                                                        data: liveData.realtimeThroughput,
                                                                        color: Colors.blue,
                                                                        unit: 'RPS',
                                                                        icon: Icons.speed,
                                                                  ),
                                                            ],
                                                      ),
                                                ),
                                          ),

                                    // Performance Summary
                                    if (completedBenchmarks.isNotEmpty)
                                          SliverToBoxAdapter(
                                                child: PerformanceSummary(
                                                      clientType: HttpClientType.rustParsedRust,
                                                      benchmarks: completedBenchmarks,
                                                ),
                                          ),

                                    // Benchmark History
                                    if (completedBenchmarks.isNotEmpty)
                                          SliverToBoxAdapter(
                                                child: BenchmarkHistory(
                                                      clientType: HttpClientType.rustParsedRust,
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
                  'Zero-copy data transfers',
                  'Native Rust JSON parsing',
                  'Minimal memory allocations',
                  'Maximum performance optimization',
                  'Native async/await support',
            ];

            return Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              Row(
                                    children: [
                                          Icon(Icons.star, color: Colors.green, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                                'Key Features',
                                                style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.green,
                                                ),
                                          ),
                                    ],
                              ),
                              SizedBox(height: 12),
                              ...features.map((feature) => Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                          children: [
                                                Icon(Icons.check_circle, color: Colors.green, size: 16),
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
                                                color: HttpClientType.rustParsedRust.color.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                                HttpClientType.rustParsedRust.icon,
                                                size: 48,
                                                color: HttpClientType.rustParsedRust.color,
                                          ),
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                          'Ready for Rust→Rust Benchmark',
                                          style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                          'Start a benchmark to see live performance metrics',
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
                                                borderColor: HttpClientType.rustParsedRust.color,
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
                                                                  _buildExpectedMetric('Latency', '2-10ms', Icons.timer),
                                                                  _buildExpectedMetric('Success', '99.5%', Icons.check_circle),
                                                                  _buildExpectedMetric('CPU', '10-25%', Icons.memory),
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
                        Icon(icon, color: HttpClientType.rustParsedRust.color, size: 24),
                        SizedBox(height: 4),
                        Text(
                              value,
                              style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: HttpClientType.rustParsedRust.color,
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