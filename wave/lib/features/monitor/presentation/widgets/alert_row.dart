import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../app_state/app_state.dart';
import '../../../live_data/live_models.dart';

class AlertRow extends StatelessWidget {
  const AlertRow({super.key, required this.language, required this.alert});

  final AppLanguage language;
  final AlertEvent alert;

  @override
  Widget build(BuildContext context) {
    final Color tone = severityColor(alert.severity);
    final int minutesAgo = DateTime.now().difference(alert.occurredAt).inMinutes;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            alert.severity == AlertSeverity.emergency
                ? Icons.warning_amber
                : alert.severity == AlertSeverity.wheeze
                ? Icons.graphic_eq
                : Icons.check_circle_outline,
            color: tone,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tr(language, alert.titleEn, alert.titleAr),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                tr(language, alert.bodyEn, alert.bodyAr),
                style: const TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          tr(language, '$minutesAgo' 'm', '$minutesAgo' 'د'),
          style: const TextStyle(color: AppColors.textSoft),
        ),
      ],
    );
  }
}
