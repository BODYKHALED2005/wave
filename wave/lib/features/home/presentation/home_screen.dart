import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_card.dart';
import '../../../core/widgets/w_lang_toggle.dart';
import '../../../core/widgets/w_status_ring.dart';
import '../../../core/widgets/w_vital_tile.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';
import '../../monitor/presentation/widgets/alert_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final WaveMedAppState appState = ref.watch(appStateProvider);
    final AsyncValue<ChildSessionState>? session = ref.watch(
      activeChildSessionProvider,
    );

    return SafeArea(
      child: session == null
          ? _EmptyState(language: language)
          : session.when(
              data: (ChildSessionState data) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              tr(language, 'Good evening', 'مساء الخير'),
                              style: const TextStyle(
                                color: AppColors.textSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr(
                                language,
                                'Monitoring ${data.child.name}',
                                'متابعة ${data.child.name}',
                              ),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LanguageToggle(
                        language: language,
                        onChanged: appState.setLanguage,
                      ),
                    ],
                  ),
                  if (data.connection != ConnectionHealth.connected) ...<Widget>[
                    const SizedBox(height: 14),
                    _ConnectionBanner(language: language),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          const Color(0xFF08314D),
                          severityColor(data.frame.status),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    tr(
                                      language,
                                      'Authoritative live status',
                                      'الحالة المباشرة المعتمدة',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    severityLabel(language, data.frame.status),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    tr(
                                      language,
                                      'Backend ${(data.frame.comparison.backend.confidence * 100).round()}%  •  ${data.frame.lastSyncLabel(language)}',
                                      'الخادم ${(data.frame.comparison.backend.confidence * 100).round()}٪  •  ${data.frame.lastSyncLabel(language)}',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusRing(
                              status: data.frame.status,
                              value: data.frame.comparison.backend.confidence,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton(
                                onPressed: () => context.push('/emergency'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.text,
                                ),
                                child: Text(
                                  tr(language, 'Emergency plan', 'خطة الطوارئ'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context.push('/setup'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                ),
                                child: Text(
                                  tr(language, 'Device setup', 'إعداد الجهاز'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (data.frame.status != AlertSeverity.normal) ...<Widget>[
                    const SizedBox(height: 14),
                    _RiskBanner(language: language, frame: data.frame),
                  ],
                  const SizedBox(height: 18),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              data.child.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.push('/children'),
                              child: Text(
                                tr(language, 'Switch child', 'تبديل الطفل'),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          tr(
                            language,
                            'Age ${data.child.ageLabel}  •  Device ${data.child.deviceId}',
                            'العمر ${data.child.ageLabel}  •  الجهاز ${data.child.deviceId}',
                          ),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: VitalTile(
                          label: 'SpO2',
                          value: data.frame.vitals.spo2 != null
                              ? '${data.frame.vitals.spo2}%'
                              : tr(language, '--', '--'),
                          icon: Icons.bubble_chart,
                          tone: data.frame.vitals.spo2 != null &&
                                  data.frame.vitals.spo2! >= 96
                              ? AppColors.success
                              : data.frame.vitals.spo2 != null
                                  ? AppColors.warning
                                  : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VitalTile(
                          label: 'BPM',
                          value: data.frame.vitals.bpm != null
                              ? '${data.frame.vitals.bpm}'
                              : tr(language, '--', '--'),
                          icon: Icons.favorite_border,
                          tone: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VitalTile(
                          label: tr(language, 'Temp', 'الحرارة'),
                          value:
                              '${data.frame.vitals.temperatureC.toStringAsFixed(1)}°',
                          icon: Icons.thermostat,
                          tone: AppColors.warning,
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
                              tr(
                                language,
                                'Prediction comparison',
                                'مقارنة التنبؤات',
                              ),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (data.frame.comparison.isMismatch)
                              _MismatchBadge(language: language),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _PredictionCard(
                                language: language,
                                result: data.frame.comparison.backend,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PredictionCard(
                                language: language,
                                result: data.frame.comparison.device,
                                emptyLabel: tr(
                                  language,
                                  'Device prediction unavailable',
                                  'لا يوجد تنبؤ من الجهاز',
                                ),
                              ),
                            ),
                          ],
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
                          tr(language, 'Environment and device', 'البيئة والجهاز'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _MetricPill(
                                label: tr(language, 'Battery', 'البطارية'),
                                value: '${data.frame.vitals.battery}%',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricPill(
                                label: tr(language, 'Humidity', 'الرطوبة'),
                                value: '${data.frame.vitals.humidity}%',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetricPill(
                                label: 'AQI',
                                value: '${data.frame.vitals.aqi}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              tr(language, 'Recent alerts', 'أحدث التنبيهات'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.push('/monitor/history'),
                              child: Text(tr(language, 'View all', 'عرض الكل')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final AlertEvent alert in data.alerts.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () =>
                                  context.push('/monitor/alert/${alert.id}'),
                              borderRadius: BorderRadius.circular(18),
                              child: AlertRow(language: language, alert: alert),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr(
                      language,
                      'Unable to load live monitoring right now.',
                      'تعذر تحميل المراقبة المباشرة حالياً.',
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          tr(
            language,
            'No child profile is available yet.',
            'لا يوجد ملف طفل متاح حتى الآن.',
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.wifi_off_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(
                language,
                'Connection degraded. Showing the last good live snapshot while the stream reconnects.',
                'الاتصال غير مستقر. يتم عرض آخر لقطة موثوقة أثناء إعادة الاتصال.',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBanner extends StatelessWidget {
  const _RiskBanner({required this.language, required this.frame});

  final AppLanguage language;
  final LiveMonitorFrame frame;

  @override
  Widget build(BuildContext context) {
    final bool emergency = frame.status == AlertSeverity.emergency;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emergency ? AppColors.dangerSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            emergency ? Icons.warning_amber_rounded : Icons.info_outline,
            color: severityColor(frame.status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              emergency
                  ? tr(
                      language,
                      'Backend confirms wheeze with low oxygen. Emergency mode is available now.',
                      'أكد الخادم وجود أزيز مع انخفاض الأكسجين. وضع الطوارئ متاح الآن.',
                    )
                  : tr(
                      language,
                      'Backend wheeze confidence is elevated. Keep the child upright and continue monitoring.',
                      'ثقة الخادم بوجود الأزيز مرتفعة. أبقِ الطفل بوضع مستقيم واستمر بالمراقبة.',
                    ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.language,
    required this.result,
    this.emptyLabel,
  });

  final AppLanguage language;
  final PredictionResult? result;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          emptyLabel ?? tr(language, 'Unavailable', 'غير متاح'),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final PredictionResult resolved = result!;
    final AlertSeverity severity = resolved.label == PredictionLabel.wheeze
        ? AlertSeverity.wheeze
        : AlertSeverity.normal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            resolved.source == PredictionSource.backend
                ? tr(language, 'Backend model', 'نموذج الخادم')
                : tr(language, 'Device model', 'نموذج الجهاز'),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            severityLabel(language, severity),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: severityColor(severity),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              language,
              'Confidence ${(resolved.confidence * 100).round()}%',
              'الثقة ${(resolved.confidence * 100).round()}٪',
            ),
          ),
        ],
      ),
    );
  }
}

class _MismatchBadge extends StatelessWidget {
  const _MismatchBadge({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.28),
            ),
          ),
          child: Text(
            tr(language, 'Mismatch', 'اختلاف'),
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
