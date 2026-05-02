import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../features/app_state/app_state.dart';

class StatusRing extends StatelessWidget {
  const StatusRing({
    super.key,
    required this.status,
    required this.value,
    this.compact = false,
  });

  final AlertSeverity status;
  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 72 : 110;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: StatusRingPainter(
          color: severityColor(status),
          progress: value.clamp(0.0, 1.0),
        ),
        child: Center(
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: compact ? AppColors.text : Colors.white,
              fontSize: compact ? 16 : 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class StatusRingPainter extends CustomPainter {
  StatusRingPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Colors.white24;
    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10
      ..color = color;

    canvas.drawArc(rect.deflate(8), -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(
      rect.deflate(8),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant StatusRingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
