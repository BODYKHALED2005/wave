import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../app_state/app_state.dart';

class TrendLinePainter extends CustomPainter {
  TrendLinePainter({required this.metrics});

  final List<WeeklyMetric> metrics;

  @override
  void paint(Canvas canvas, Size size) {
    final double minValue = metrics
        .map((WeeklyMetric e) => e.spo2)
        .reduce(math.min);
    final double maxValue = metrics
        .map((WeeklyMetric e) => e.spo2)
        .reduce(math.max);
    final double range = (maxValue - minValue).clamp(0.5, double.infinity);

    final Paint grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final double y = (size.height - 20) * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final Path path = Path();
    for (int i = 0; i < metrics.length; i++) {
      final double x = (size.width / (metrics.length - 1)) * i;
      final double normalized = (metrics[i].spo2 - minValue) / range;
      final double y = (size.height - 30) - normalized * (size.height - 50);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint line = Paint()
      ..color = AppColors.success
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter oldDelegate) {
    return oldDelegate.metrics != metrics;
  }
}
