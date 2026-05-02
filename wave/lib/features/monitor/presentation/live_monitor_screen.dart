import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_card.dart';
import '../../../core/widgets/w_status_badge.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';
import 'widgets/alert_row.dart';
import 'widgets/waveform_painter.dart';

class MonitorScreen extends ConsumerWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final AsyncValue<ChildSessionState>? session = ref.watch(
      activeChildSessionProvider,
    );

    return SafeArea(
      child: session == null
          ? const SizedBox.shrink()
          : session.when(
              data: (ChildSessionState data) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: <Widget>[
                  Text(
                    tr(language, 'Live monitor', 'المراقبة المباشرة'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      language,
                      'Waveform, countdown, and event timeline.',
                      'الموجة، العد التنازلي، وسجل الأحداث.',
                    ),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  if (data.connection != ConnectionHealth.connected) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tr(
                          language,
                          'The live stream is reconnecting. The latest stable scan remains visible.',
                          'يتم الآن إعادة الاتصال بالبث المباشر. آخر فحص مستقر ما زال معروضاً.',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            StatusBadge(
                              language: language,
                              severity: data.frame.status,
                            ),
                            const Spacer(),
                            Text(
                              tr(
                                language,
                                'Next scan in ${data.frame.nextScanSeconds}s',
                                'المسح التالي خلال ${data.frame.nextScanSeconds}ث',
                              ),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 150,
                          child: CustomPaint(
                            painter: WaveformPainter(
                              color: severityColor(data.frame.status),
                              samples: data.frame.waveformPreview,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value:
                                (30 - data.frame.nextScanSeconds.clamp(0, 30)) /
                                30,
                            backgroundColor: AppColors.primarySoft,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SectionCard(
                          child: _SignalMetric(
                            title: tr(
                              language,
                              'Backend model',
                              'نموذج الخادم',
                            ),
                            value:
                                '${(data.frame.comparison.backend.confidence * 100).round()}%',
                            subtitle: severityLabel(
                              language,
                              data.frame.status,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SectionCard(
                          child: _SignalMetric(
                            title: tr(language, 'Device model', 'نموذج الجهاز'),
                            value: data.frame.comparison.device == null
                                ? '--'
                                : '${(data.frame.comparison.device!.confidence * 100).round()}%',
                            subtitle: data.frame.comparison.device == null
                                ? tr(language, 'Unavailable', 'غير متاح')
                                : severityLabel(
                                    language,
                                    data.frame.comparison.device!.label ==
                                            PredictionLabel.wheeze
                                        ? AlertSeverity.wheeze
                                        : AlertSeverity.normal,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              tr(language, 'Alert history', 'سجل التنبيهات'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.push('/emergency'),
                              child: Text(
                                tr(language, 'Emergency view', 'عرض الطوارئ'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final AlertEvent alert in data.alerts.take(4))
                          InkWell(
                            onTap: () =>
                                context.push('/monitor/alert/${alert.id}'),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: AlertRow(language: language, alert: alert),
                            ),
                          ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () => context.push('/monitor/history'),
                            child: Text(tr(language, 'Full history', 'كامل السجل')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Text(
                  tr(
                    language,
                    'Unable to start live monitoring.',
                    'تعذر بدء المراقبة المباشرة.',
                  ),
                ),
              ),
            ),
    );
  }
}

class _SignalMetric extends StatelessWidget {
  const _SignalMetric({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: AppColors.textSoft)),
      ],
    );
  }
}
