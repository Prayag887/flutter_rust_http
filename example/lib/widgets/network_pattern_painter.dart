import 'package:flutter/material.dart';
import 'dart:math';

class NetworkPatternPainter extends CustomPainter {
  final double animationValue;

  NetworkPatternPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final connectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Create animated network pattern
    final nodes = <Offset>[];

    // Generate node positions
    for (int i = 0; i < 15; i++) {
      for (int j = 0; j < 8; j++) {
        final x = (size.width / 14) * i;
        final baseY = (size.height / 7) * j;
        final animatedY = baseY + sin((i * 0.3) + (j * 0.2) + (animationValue * 2 * pi)) * 15;
        nodes.add(Offset(x, animatedY));
      }
    }

    // Draw connections between nearby nodes
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final distance = (nodes[i] - nodes[j]).distance;
        if (distance < 80) {
          final opacity = (80 - distance) / 80;
          connectionPaint.color = Colors.cyan.withOpacity(opacity * 0.3);
          canvas.drawLine(nodes[i], nodes[j], connectionPaint);
        }
      }
    }

    // Draw animated nodes
    for (int i = 0; i < nodes.length; i++) {
      final pulseSize = 2 + sin(animationValue * 2 * pi + i * 0.1) * 1.5;

      // Draw outer glow
      canvas.drawCircle(
        nodes[i],
        pulseSize + 2,
        Paint()..color = Colors.cyan.withOpacity(0.2),
      );

      // Draw main node
      canvas.drawCircle(nodes[i], pulseSize, nodePaint);

      // Draw inner highlight
      canvas.drawCircle(
        nodes[i],
        pulseSize * 0.6,
        Paint()..color = Colors.white.withOpacity(0.8),
      );
    }

    // Draw data flow lines
    _drawDataFlowLines(canvas, size, animationValue);
  }

  void _drawDataFlowLines(Canvas canvas, Size size, double progress) {
    final flowPaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Create multiple flowing lines
    for (int i = 0; i < 5; i++) {
      final path = Path();
      final startX = size.width * 0.1;
      final endX = size.width * 0.9;
      final y = size.height * (0.2 + i * 0.15);

      // Create wavy path
      path.moveTo(startX, y);

      for (double x = startX; x <= endX; x += 10) {
        final waveY = y + sin((x * 0.02) + (progress * 4 * pi)) * 8;
        path.lineTo(x, waveY);
      }

      // Animate flow effect
      final flowProgress = (progress + i * 0.2) % 1.0;
      final gradientStart = flowProgress - 0.3;
      final gradientEnd = flowProgress;

      if (gradientStart >= 0) {
        final gradient = LinearGradient(
          begin: Alignment(gradientStart * 2 - 1, 0),
          end: Alignment(gradientEnd * 2 - 1, 0),
          colors: [
            Colors.transparent,
            Colors.cyan.withOpacity(0.8),
            Colors.white,
            Colors.cyan.withOpacity(0.8),
            Colors.transparent,
          ],
          stops: [0.0, 0.3, 0.5, 0.7, 1.0],
        );

        flowPaint.shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      } else {
        flowPaint.shader = null;
        flowPaint.color = Colors.cyan.withOpacity(0.3);
      }

      canvas.drawPath(path, flowPaint);
    }
  }

  @override
  bool shouldRepaint(NetworkPatternPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}