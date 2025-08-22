import 'package:flutter/material.dart';
import '../models/benchmark_models.dart';
import '../config/app_theme.dart';

class BenchmarkHistory extends StatelessWidget {
  final HttpClientType clientType;
  final List<BenchmarkMetrics> benchmarks;

  const BenchmarkHistory({
    Key? key,
    required this.clientType,
    required this.benchmarks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (benchmarks.isEmpty) return SizedBox.shrink();

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
                    Icons.history,
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
                        'Benchmark History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${benchmarks.length} test${benchmarks.length > 1 ? 's' : ''} completed',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showDetailedHistory(context),
                  icon: Icon(
                    Icons.open_in_full,
                    color: clientType.color,
                  ),
                ),
              ],
            ),
          ),

          // History List
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(20),
            itemCount: benchmarks.length > 5 ? 5 : benchmarks.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final benchmark = benchmarks[benchmarks.length - 1 - index]; // Most recent first
              return _buildHistoryItem(benchmark, index == 0);
            },
          ),

          // Show More Button
          if (benchmarks.length > 5)
            Padding(
              padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: TextButton(
                onPressed: () => _showDetailedHistory(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View all ${benchmarks.length} benchmarks',
                      style: TextStyle(color: clientType.color),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: clientType.color,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BenchmarkMetrics benchmark, bool isLatest) {
    final duration = benchmark.endTime?.difference(benchmark.startTime) ?? Duration.zero;
    final scenario = benchmark.additionalMetrics['scenario_name'] ?? 'Unknown';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLatest
            ? clientType.color.withOpacity(0.1)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: isLatest
            ? Border.all(color: clientType.color.withOpacity(0.3))
            : Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              if (isLatest)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: clientType.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'LATEST',
                    style: TextStyle(
                      color: clientType.color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (isLatest) SizedBox(width: 8),
              Expanded(
                child: Text(
                  scenario,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: benchmark.gradeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  benchmark.grade,
                  style: TextStyle(
                    color: benchmark.gradeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricChip(
                  'Latency',
                  '${benchmark.averageLatency.toStringAsFixed(1)}ms',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMetricChip(
                  'Throughput',
                  '${benchmark.throughput.toStringAsFixed(1)}',
                  Icons.speed,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildMetricChip(
                  'Success',
                  '${benchmark.successRate.toStringAsFixed(1)}%',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Details Row
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.grey[400], size: 14),
              SizedBox(width: 4),
              Text(
                _formatDateTime(benchmark.startTime),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 16),
              Icon(Icons.timer, color: Colors.grey[400], size: 14),
              SizedBox(width: 4),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              Spacer(),
              Text(
                '${benchmark.totalRequests} requests',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailedHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: clientType.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          clientType.icon,
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
                              '${clientType.name} History',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Complete benchmark history',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),

                // History List
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: benchmarks.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final benchmark = benchmarks[benchmarks.length - 1 - index];
                      return _buildDetailedHistoryItem(benchmark, index == 0);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailedHistoryItem(BenchmarkMetrics benchmark, bool isLatest) {
    final duration = benchmark.endTime?.difference(benchmark.startTime) ?? Duration.zero;
    final scenario = benchmark.additionalMetrics['scenario_name'] ?? 'Unknown';

    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(
        borderColor: isLatest ? clientType.color : Colors.grey,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              if (isLatest)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: clientType.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LATEST RUN',
                    style: TextStyle(
                      color: clientType.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (isLatest) SizedBox(width: 12),
              Expanded(
                child: Text(
                  scenario,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: benchmark.gradeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${benchmark.grade} Grade',
                  style: TextStyle(
                    color: benchmark.gradeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Detailed Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildDetailedMetric(
                  'Average Latency',
                  '${benchmark.averageLatency.toStringAsFixed(1)}ms',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDetailedMetric(
                  'P95 Latency',
                  '${benchmark.p95Latency.toStringAsFixed(1)}ms',
                  Icons.show_chart,
                  Colors.red,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildDetailedMetric(
                  'Throughput',
                  '${benchmark.throughput.toStringAsFixed(1)} RPS',
                  Icons.speed,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDetailedMetric(
                  'Success Rate',
                  '${benchmark.successRate.toStringAsFixed(1)}%',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildDetailedMetric(
                  'CPU Usage',
                  '${benchmark.cpuUsage.toStringAsFixed(1)}%',
                  Icons.memory,
                  Colors.purple,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDetailedMetric(
                  'Memory',
                  '${benchmark.memoryUsageMB.toStringAsFixed(1)}MB',
                  Icons.storage,
                  Colors.cyan,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Request Statistics
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRequestStat('Total', '${benchmark.totalRequests}'),
                _buildRequestStat('Success', '${benchmark.successfulRequests}'),
                _buildRequestStat('Failed', '${benchmark.failedRequests}'),
                _buildRequestStat('Duration', _formatDuration(duration)),
              ],
            ),
          ),

          SizedBox(height: 12),

          // Timestamp
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.grey[400], size: 16),
              SizedBox(width: 8),
              Text(
                'Started: ${_formatDateTime(benchmark.startTime)}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetric(String label, String value, IconData icon, Color color) {
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
              Icon(icon, color: color, size: 16),
              Spacer(),
            ],
          ),
          SizedBox(height: 8),
          Text(
            label,
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}