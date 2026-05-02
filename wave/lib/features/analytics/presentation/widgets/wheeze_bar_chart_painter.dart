import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../app_state/app_state.dart';

class WheezeBarChartPainter extends CustomPainter {
  WheezeBarChartPainter({required this.metrics, required this.language});

  final List<WeeklyMetric> metrics;
  final AppLanguage language;

  @override
  void paint(Canvas canvas, Size size) {
    final double maxValue = metrics
        .map((WeeklyMetric e) => e.wheezeCount)
        .reduce(math.max)
        .toDouble();
    final double barWidth = size.width / (metrics.length * 1.7);
    final TextPainter painter = TextPainter(
      textDirection: language == AppLanguage.ar
          ? TextDirection.rtl
          : TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < metrics.length; i++) {
      final WeeklyMetric item = metrics[i];
      final double left = i * (barWidth * 1.7);
      final double height = (item.wheezeCount / maxValue) * (size.height - 34);
      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - height - 20, barWidth, height),
        const Radius.circular(18),
      );
      final Paint paint = Paint()
        ..shader = const LinearGradient(
          colors: <Color>[AppColors.primary, Color(0xFF78B8E1)],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      painter.text = TextSpan(
        text: tr(language, item.labelEn, item.labelAr),
        style: const TextStyle(fontSize: 11, color: AppColors.textSoft),
      );
      painter.layout(minWidth: barWidth, maxWidth: barWidth + 8);
      painter.paint(canvas, Offset(left - 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant WheezeBarChartPainter oldDelegate) {
    return oldDelegate.metrics != metrics || oldDelegate.language != language;
  }
}
