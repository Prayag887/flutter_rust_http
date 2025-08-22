import 'package:flutter/material.dart';
import 'dart:math';
import '../models/benchmark_models.dart';
import '../config/app_theme.dart';

class PerformanceSummary extends StatelessWidget {
  final HttpClientType clientType;
  final List<BenchmarkMetrics> benchmarks;

  const PerformanceSummary({
    Key? key,
    required this.clientType,
    required this.benchmarks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (benchmarks.isEmpty) return SizedBox.shrink();

    final avgMetrics = _calculateAverageMetrics();
    final bestResult = _getBestResult();
    final worstResult = _getWorstResult();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.cardDecoration(
        borderColor: clientType.color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  clientType.color.withOpacity(0.2),
                  clientType.color.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: clientType.color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: clientType.color,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performance Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${benchmarks.length} benchmark${benchmarks.length > 1 ? 's' : ''} completed',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: avgMetrics.gradeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: avgMetrics.gradeColor.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    '${avgMetrics.grade} Grade',
                    style: TextStyle(
                      color: avgMetrics.gradeColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metrics Grid
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Average Performance Row
                _buildSectionHeader('Average Performance', Icons.trending_up),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Latency',
                        '${avgMetrics.averageLatency.toStringAsFixed(1)}ms',
                        Icons.timer,
                        Colors.orange,
                        subtitle: 'P95: ${avgMetrics.p95Latency.toStringAsFixed(1)}ms',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Throughput',
                        '${avgMetrics.throughput.toStringAsFixed(1)}',
                        Icons.speed,
                        Colors.blue,
                        subtitle: 'requests/sec',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Success Rate',
                        '${avgMetrics.successRate.toStringAsFixed(1)}%',
                        Icons.check_circle,
                        Colors.green,
                        subtitle: '${avgMetrics.totalRequests} total',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Resources',
                        '${avgMetrics.cpuUsage.toStringAsFixed(1)}%',
                        Icons.memory,
                        Colors.purple,
                        subtitle: '${avgMetrics.memoryUsageMB.toStringAsFixed(1)}MB RAM',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Best vs Worst Comparison
                _buildSectionHeader('Performance Range', Icons.compare),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildComparisonCard(
                        'Best Result',
                        bestResult,
                        Colors.green,
                        Icons.emoji_events,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildComparisonCard(
                        'Worst Result',
                        worstResult,
                        Colors.red,
                        Icons.warning,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Performance Trends
                _buildSectionHeader('Performance Trends', Icons.show_chart),
                SizedBox(height: 12),
                _buildTrendsChart(),

                SizedBox(height: 24),

                // Insights
                _buildInsights(avgMetrics),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: clientType.color, size: 20),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title,
      String value,
      IconData icon,
      Color color, {
        String? subtitle,
      }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
      String title,
      BenchmarkMetrics metrics,
      Color color,
      IconData icon,
      ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildComparisonRow('Latency', '${metrics.averageLatency.toStringAsFixed(1)}ms'),
          _buildComparisonRow('TP', '${metrics.throughput.toStringAsFixed(1)} RPS'),
          _buildComparisonRow('Success', '${metrics.successRate.toStringAsFixed(1)}%'),
          _buildComparisonRow('Grade', metrics.grade),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsChart() {
    return Container(
      height: 120,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: clientType.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: clientType.color.withOpacity(0.3)),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: TrendChartPainter(
          benchmarks: benchmarks,
          color: clientType.color,
        ),
      ),
    );
  }

  Widget _buildInsights(BenchmarkMetrics avgMetrics) {
    final insights = _generateInsights(avgMetrics);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.withOpacity(0.2),
            Colors.purple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Performance Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...insights.map((insight) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  insight['icon'],
                  color: insight['color'],
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight['text'],
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

  BenchmarkMetrics _calculateAverageMetrics() {
    if (benchmarks.isEmpty) {
      return BenchmarkMetrics(
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        averageLatency: 0,
        p95Latency: 0,
        p99Latency: 0,
        throughput: 0,
        cpuUsage: 0,
        memoryUsageMB: 0,
        latencyHistory: [],
        startTime: DateTime.now(),
      );
    }

    final totalRequests = benchmarks.fold(0, (sum, b) => sum + b.totalRequests);
    final successfulRequests = benchmarks.fold(0, (sum, b) => sum + b.successfulRequests);
    final failedRequests = benchmarks.fold(0, (sum, b) => sum + b.failedRequests);
    final avgLatency = benchmarks.fold(0.0, (sum, b) => sum + b.averageLatency) / benchmarks.length;
    final avgP95Latency = benchmarks.fold(0.0, (sum, b) => sum + b.p95Latency) / benchmarks.length;
    final avgP99Latency = benchmarks.fold(0.0, (sum, b) => sum + b.p99Latency) / benchmarks.length;
    final avgThroughput = benchmarks.fold(0.0, (sum, b) => sum + b.throughput) / benchmarks.length;
    final avgCpuUsage = benchmarks.fold(0.0, (sum, b) => sum + b.cpuUsage) / benchmarks.length;
    final avgMemoryUsage = benchmarks.fold(0.0, (sum, b) => sum + b.memoryUsageMB) / benchmarks.length;

    return BenchmarkMetrics(
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      averageLatency: avgLatency,
      p95Latency: avgP95Latency,
      p99Latency: avgP99Latency,
      throughput: avgThroughput,
      cpuUsage: avgCpuUsage,
      memoryUsageMB: avgMemoryUsage,
      latencyHistory: [],
      startTime: benchmarks.first.startTime,
      endTime: benchmarks.last.endTime,
    );
  }

  BenchmarkMetrics _getBestResult() {
    return benchmarks.reduce((a, b) {
      final scoreA = (a.successRate * 0.4) + ((1000 / (a.averageLatency + 1)) * 0.4) + (a.throughput * 0.2);
      final scoreB = (b.successRate * 0.4) + ((1000 / (b.averageLatency + 1)) * 0.4) + (b.throughput * 0.2);
      return scoreA > scoreB ? a : b;
    });
  }

  BenchmarkMetrics _getWorstResult() {
    return benchmarks.reduce((a, b) {
      final scoreA = (a.successRate * 0.4) + ((1000 / (a.averageLatency + 1)) * 0.4) + (a.throughput * 0.2);
      final scoreB = (b.successRate * 0.4) + ((1000 / (b.averageLatency + 1)) * 0.4) + (b.throughput * 0.2);
      return scoreA < scoreB ? a : b;
    });
  }

  List<Map<String, dynamic>> _generateInsights(BenchmarkMetrics avgMetrics) {
    final insights = <Map<String, dynamic>>[];

    // Latency insights
    if (avgMetrics.averageLatency < 10) {
      insights.add({
        'icon': Icons.flash_on,
        'color': Colors.green,
        'text': 'Excellent latency performance - suitable for real-time applications',
      });
    } else if (avgMetrics.averageLatency < 50) {
      insights.add({
        'icon': Icons.thumb_up,
        'color': Colors.orange,
        'text': 'Good latency performance - acceptable for most use cases',
      });
    } else {
      insights.add({
        'icon': Icons.warning,
        'color': Colors.red,
        'text': 'High latency detected - consider optimization strategies',
      });
    }

    // Success rate insights
    if (avgMetrics.successRate >= 99) {
      insights.add({
        'icon': Icons.check_circle,
        'color': Colors.green,
        'text': 'Excellent reliability with ${avgMetrics.successRate.toStringAsFixed(1)}% success rate',
      });
    } else if (avgMetrics.successRate >= 95) {
      insights.add({
        'icon': Icons.info,
        'color': Colors.orange,
        'text': 'Good reliability but monitor error patterns',
      });
    } else {
      insights.add({
        'icon': Icons.error,
        'color': Colors.red,
        'text': 'Low success rate - investigate error causes',
      });
    }

    // Throughput insights
    if (avgMetrics.throughput > 100) {
      insights.add({
        'icon': Icons.speed,
        'color': Colors.green,
        'text': 'High throughput - excellent for heavy traffic applications',
      });
    } else if (avgMetrics.throughput > 50) {
      insights.add({
        'icon': Icons.trending_up,
        'color': Colors.blue,
        'text': 'Moderate throughput - suitable for standard applications',
      });
    } else {
      insights.add({
        'icon': Icons.trending_down,
        'color': Colors.orange,
        'text': 'Lower throughput - consider performance optimizations',
      });
    }

    // Resource usage insights
    if (avgMetrics.cpuUsage < 30) {
      insights.add({
        'icon': Icons.eco,
        'color': Colors.green,
        'text': 'Efficient resource usage - low CPU overhead',
      });
    } else if (avgMetrics.cpuUsage > 60) {
      insights.add({
        'icon': Icons.warning,
        'color': Colors.red,
        'text': 'High CPU usage - may impact device performance',
      });
    }

    return insights;
  }
}

class TrendChartPainter extends CustomPainter {
  final List<BenchmarkMetrics> benchmarks;
  final Color color;

  TrendChartPainter({
    required this.benchmarks,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (benchmarks.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Calculate bounds
    final latencies = benchmarks.map((b) => b.averageLatency).toList();
    final maxLatency = latencies.reduce(max);
    final minLatency = latencies.reduce(min);
    final range = maxLatency - minLatency;

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (benchmarks.length - 1);

    for (int i = 0; i < benchmarks.length; i++) {
      final x = i * stepX;
      final normalizedY = range > 0
          ? (benchmarks[i].averageLatency - minLatency) / range
          : 0.5;
      final y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw data points
    for (int i = 0; i < benchmarks.length; i++) {
      final x = i * stepX;
      final normalizedY = range > 0
          ? (benchmarks[i].averageLatency - minLatency) / range
          : 0.5;
      final y = size.height - (normalizedY * size.height);

      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(TrendChartPainter oldDelegate) {
    return benchmarks != oldDelegate.benchmarks || color != oldDelegate.color;
  }
}