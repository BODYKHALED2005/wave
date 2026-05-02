import 'dart:math' as math;

import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  WaveformPainter({required this.color, required this.samples});

  final Color color;
  final List<double> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    final List<double> values = samples.isEmpty
        ? List<double>.generate(80, (int index) {
            final double normalized = index / 80;
            return math.sin(normalized * math.pi * 8) * 0.6 +
                math.sin(normalized * math.pi * 22) * 0.2;
          })
        : samples;
    for (int index = 0; index < values.length; index++) {
      final double normalized = values.length == 1 ? 0 : index / (values.length - 1);
      final double x = normalized * size.width;
      final double y = size.height * 0.5 - (values[index] * size.height * 0.34);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint glow = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.samples != samples;
  }
}
