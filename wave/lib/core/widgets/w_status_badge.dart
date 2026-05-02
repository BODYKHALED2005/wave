import 'package:flutter/material.dart';

import '../../features/app_state/app_state.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.language,
    required this.severity,
  });

  final AppLanguage language;
  final AlertSeverity severity;

  @override
  Widget build(BuildContext context) {
    final Color color = severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        severityLabel(language, severity),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
