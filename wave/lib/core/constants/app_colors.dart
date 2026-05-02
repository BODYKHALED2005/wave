import 'package:flutter/material.dart';

class AppColors {
  static const Color bg = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F4F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color primary = Color(0xFF1D6FA4);
  static const Color primaryDark = Color(0xFF155E8A);
  static const Color primarySoft = Color(0xFFEBF5FB);
  static const Color text = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF475569);
  static const Color textSoft = Color(0xFF94A3B8);
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);

  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
