import 'package:flutter/material.dart';
import '../models/benchmark_models.dart';
import '../config/app_theme.dart';

class LiveMetricsCard extends StatefulWidget {
  final HttpClientType clientType;
  final LiveBenchmarkData liveData;

  const LiveMetricsCard({
    Key? key,
    required this.clientType,
    required this.liveData,
  }) : super(key: key);

  @override
  _LiveMetricsCardState createState() => _LiveMetricsCardState();
}

class _LiveMetricsCardState extends State<LiveMetricsCard>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.liveData.isRunning) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiveMetricsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.liveData.progress != oldWidget.liveData.progress) {
      _progressController.animateTo(widget.liveData.progress);
    }

    if (widget.liveData.isRunning && !oldWidget.liveData.isRunning) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.liveData.isRunning && oldWidget.liveData.isRunning) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.cardDecoration(
        borderColor: widget.clientType.color,
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
                  widget.clientType.color.withOpacity(0.2),
                  widget.clientType.color.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: widget.liveData.isRunning ? _pulseAnimation.value : 1.0,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.clientType.color.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.liveData.isRunning ? Icons.play_arrow : Icons.check_circle,
                              color: widget.clientType.color,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.liveData.scenario.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.liveData.currentStatus ?? 'Ready',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.liveData.currentMetrics.gradeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.liveData.currentMetrics.gradeColor.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        widget.liveData.currentMetrics.grade,
                        style: TextStyle(
                          color: widget.liveData.currentMetrics.gradeColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${(widget.liveData.progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: widget.clientType.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _progressAnimation.value * widget.liveData.progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    widget.clientType.color,
                                    widget.clientType.color.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.clientType.color.withOpacity(0.5),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Metrics Grid
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Primary Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Requests',
                        '${widget.liveData.currentMetrics.totalRequests}',
                        Icons.send,
                        Colors.blue,
                        subtitle: '${widget.liveData.currentMetrics.successfulRequests} success',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Latency',
                        '${widget.liveData.currentMetrics.averageLatency.toStringAsFixed(0)}ms',
                        Icons.timer,
                        Colors.orange,
                        subtitle: 'P95: ${widget.liveData.currentMetrics.p95Latency.toStringAsFixed(0)}ms',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Secondary Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Throughput',
                        '${widget.liveData.currentMetrics.throughput.toStringAsFixed(1)}',
                        Icons.speed,
                        Colors.purple,
                        subtitle: 'requests/sec',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Success Rate',
                        '${widget.liveData.currentMetrics.successRate.toStringAsFixed(1)}%',
                        Icons.check_circle,
                        Colors.green,
                        subtitle: '${widget.liveData.currentMetrics.failedRequests} failed',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Resource Usage Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'CPU Usage',
                        '${widget.liveData.currentMetrics.cpuUsage.toStringAsFixed(1)}%',
                        Icons.memory,
                        Colors.red,
                        subtitle: 'current load',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Memory',
                        '${widget.liveData.currentMetrics.memoryUsageMB.toStringAsFixed(1)}MB',
                        Icons.storage,
                        Colors.cyan,
                        subtitle: 'current usage',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
}