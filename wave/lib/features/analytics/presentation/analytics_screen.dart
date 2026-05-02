import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/w_card.dart';
import '../../../core/widgets/w_stat_card.dart';
import '../../../core/widgets/w_summary_bullet.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';
import 'widgets/trend_line_painter.dart';
import 'widgets/wheeze_bar_chart_painter.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final ChildSummary? child = ref.watch(activeChildProvider);
    final List<WeeklyMetric> metrics = ref.watch(secondaryMetricsProvider);
    final int totalWheeze = metrics.fold<int>(0, (
      int sum,
      WeeklyMetric item,
    ) {
      return sum + item.wheezeCount;
    });

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          Text(
            tr(language, 'Weekly analytics', 'تحليلات أسبوعية'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F2F7),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              tr(
                language,
                'Analytics remains a secondary snapshot screen in this milestone. Core live monitoring is implemented first.',
                'ما زالت شاشة التحليلات شاشة ثانوية لعرض اللقطات في هذه المرحلة. تم تنفيذ المراقبة المباشرة الأساسية أولاً.',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: StatCard(
                  title: tr(language, 'Wheeze events', 'نوبات الأزيز'),
                  value: '$totalWheeze',
                  caption: tr(language, 'Snapshot', 'لقطة'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: tr(language, 'Average SpO2', 'متوسط الأكسجين'),
                  value:
                      '${(metrics.map((WeeklyMetric e) => e.spo2).reduce((double a, double b) => a + b) / metrics.length).toStringAsFixed(1)}%',
                  caption: child?.name ?? '--',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr(language, 'Daily wheeze pattern', 'نمط الأزيز اليومي'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: WheezeBarChartPainter(
                      metrics: metrics,
                      language: language,
                    ),
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
                  tr(language, 'SpO2 trend', 'اتجاه الأكسجين'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 170,
                  child: CustomPaint(
                    painter: TrendLinePainter(metrics: metrics),
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
                  tr(language, 'Clinical summary', 'الملخص السريري'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SummaryBullet(
                  text: tr(
                    language,
                    'Historical charts will be switched to backend-fed series in a later milestone.',
                    'سيتم تحويل الرسوم التاريخية إلى بيانات حقيقية من الخادم في مرحلة لاحقة.',
                  ),
                ),
                SummaryBullet(
                  text: tr(
                    language,
                    'Doctor report export remains available as a placeholder route.',
                    'يبقى تصدير تقرير الطبيب متاحاً كمسار مؤقت.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/report'),
                  child: Text(
                    tr(language, 'Open doctor report', 'افتح تقرير الطبيب'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
