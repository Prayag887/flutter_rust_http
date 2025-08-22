import 'package:flutter/material.dart';
import 'dart:math';
import '../config/app_theme.dart';

class RealtimeChart extends StatefulWidget {
  final String title;
  final List<double> data;
  final Color color;
  final String unit;
  final IconData icon;

  const RealtimeChart({
    Key? key,
    required this.title,
    required this.data,
    required this.color,
    required this.unit,
    required this.icon,
  }) : super(key: key);

  @override
  _RealtimeChartState createState() => _RealtimeChartState();
}

class _RealtimeChartState extends State<RealtimeChart>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(RealtimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.length != oldWidget.data.length) {
      _animationController.forward(from: 0.8);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(
        borderColor: widget.color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Real-time ${widget.unit}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.data.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.data.last.toStringAsFixed(1)} ${widget.unit}',
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20),

          // Chart Area
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                height: 120,
                width: double.infinity,
                child: widget.data.isEmpty
                    ? _buildEmptyChart()
                    : CustomPaint(
                  size: Size.infinite,
                  painter: RealtimeChartPainter(
                    data: widget.data,
                    color: widget.color,
                    animationProgress: _animation.value,
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 16),

          // Statistics Row
          if (widget.data.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatistic(
                  'Current',
                  '${widget.data.last.toStringAsFixed(1)}',
                  widget.color,
                ),
                _buildStatistic(
                  'Average',
                  '${_calculateAverage().toStringAsFixed(1)}',
                  Colors.blue,
                ),
                _buildStatistic(
                  'Peak',
                  '${_calculateMax().toStringAsFixed(1)}',
                  Colors.green,
                ),
                _buildStatistic(
                  'Samples',
                  '${widget.data.length}',
                  Colors.grey,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            color: Colors.grey[600],
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            'Waiting for data...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistic(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
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

  double _calculateAverage() {
    if (widget.data.isEmpty) return 0.0;
    return widget.data.reduce((a, b) => a + b) / widget.data.length;
  }

  double _calculateMax() {
    if (widget.data.isEmpty) return 0.0;
    return widget.data.reduce(max);
  }
}

class RealtimeChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double animationProgress;

  RealtimeChartPainter({
    required this.data,
    required this.color,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

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

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;

    // Draw grid lines
    _drawGrid(canvas, size, gridPaint);

    // Calculate data bounds
    final maxValue = data.reduce(max);
    final minValue = data.reduce(min);
    final range = maxValue - minValue;
    final padding = range * 0.1;

    // Draw data
    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    final stepX = size.width / (data.length - 1).clamp(1, data.length);
    final animatedLength = (data.length * animationProgress).round();

    for (int i = 0; i < animatedLength; i++) {
      final x = i * stepX;
      final normalizedY = range > 0
          ? (data[i] - minValue + padding) / (range + 2 * padding)
          : 0.5;
      final y = size.height - (normalizedY * size.height);

      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
    }

    // Draw fill area
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final outerPointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      if (i == points.length - 1) {
        // Highlight current point
        canvas.drawCircle(points[i], 4, outerPointPaint);
        canvas.drawCircle(points[i], 2, pointPaint);
      } else if (i % 5 == 0) {
        // Draw every 5th point
        canvas.drawCircle(points[i], 2, pointPaint);
      }
    }

    // Draw current value indicator
    if (points.isNotEmpty) {
      _drawCurrentValueIndicator(canvas, size, points.last, data.last);
    }
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical grid lines
    for (int i = 0; i <= 8; i++) {
      final x = (size.width / 8) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawCurrentValueIndicator(
      Canvas canvas, Size size, Offset point, double value) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: value.toStringAsFixed(1),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          point.dx.clamp(textPainter.width / 2, size.width - textPainter.width / 2),
          point.dy - 30,
        ),
        width: textPainter.width + 16,
        height: textPainter.height + 8,
      ),
      Radius.circular(8),
    );

    final labelPaint = Paint()
      ..color = color.withOpacity(0.9);

    canvas.drawRRect(labelRect, labelPaint);

    textPainter.paint(
      canvas,
      Offset(
        labelRect.center.dx - textPainter.width / 2,
        labelRect.center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(RealtimeChartPainter oldDelegate) {
    return data != oldDelegate.data ||
        color != oldDelegate.color ||
        animationProgress != oldDelegate.animationProgress;
  }
}