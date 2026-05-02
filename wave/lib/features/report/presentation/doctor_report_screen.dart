import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_card.dart';
import '../../../core/widgets/w_summary_bullet.dart';
import '../../app_state/app_state.dart';
import '../../monitor/presentation/widgets/alert_row.dart';

class DoctorReportScreen extends ConsumerWidget {
  const DoctorReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final child = ref.watch(activeChildProvider);
    final metrics = ref.watch(secondaryMetricsProvider);
    final alerts = ref.watch(activeChildSessionProvider)?.valueOrNull?.alerts ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(language, 'Doctor report', 'تقرير الطبيب')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr(
                    language,
                    'Clinical snapshot for ${child?.name ?? 'child'}',
                    'الملخص السريري لـ ${child?.name ?? 'الطفل'}',
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr(
                    language,
                    'PDF export and sharing remain placeholders until backend-generated report payloads are available.',
                    'يبقى تصدير PDF والمشاركة في وضع مؤقت حتى تتوفر بيانات التقرير الصادرة من الخادم.',
                  ),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                SummaryBullet(
                  text: tr(
                    language,
                    'Weekly entries currently use local snapshot data.',
                    'تستخدم الإدخالات الأسبوعية حالياً بيانات لقطات محلية.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr(language, 'Weekly entries', 'إدخالات الأسبوع'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final metric in metrics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            tr(language, metric.labelEn, metric.labelAr),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          tr(
                            language,
                            '${metric.wheezeCount} events',
                            '${metric.wheezeCount} نوبات',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${metric.spo2.toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr(language, 'Latest alert references', 'أحدث التنبيهات المرجعية'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final alert in alerts.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AlertRow(language: language, alert: alert),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
