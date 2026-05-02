import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_card.dart';
import '../../../core/widgets/w_status_badge.dart';
import '../../../core/widgets/w_summary_bullet.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';

class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final String? childId = ref.watch(activeChildIdProvider);
    if (childId == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final AsyncValue<AlertEvent> alert = ref.watch(
      alertDetailProvider(AlertLookup(childId: childId, alertId: alertId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(language, 'Alert detail', 'تفاصيل التنبيه')),
      ),
      body: alert.when(
        data: (AlertEvent data) => ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            StatusBadge(language: language, severity: data.severity),
            const SizedBox(height: 16),
            Text(
              tr(language, data.titleEn, data.titleAr),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              tr(language, data.bodyEn, data.bodyAr),
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr(
                language,
                data.frameTimeLabelEn,
                data.frameTimeLabelAr,
              ),
              style: const TextStyle(color: AppColors.textSoft),
            ),
            const SizedBox(height: 22),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr(language, 'Prediction comparison', 'مقارنة التنبؤات'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SummaryBullet(
                    text: tr(
                      language,
                      'Backend: ${data.comparison.backend.label.name} ${(data.comparison.backend.confidence * 100).round()}%',
                      'الخادم: ${data.comparison.backend.label == PredictionLabel.wheeze ? 'أزيز' : 'طبيعي'} ${(data.comparison.backend.confidence * 100).round()}٪',
                    ),
                  ),
                  SummaryBullet(
                    text: data.comparison.device == null
                        ? tr(
                            language,
                            'Device model was not available for this event.',
                            'لم يتوفر نموذج الجهاز لهذا الحدث.',
                          )
                        : tr(
                            language,
                            'Device: ${data.comparison.device!.label.name} ${(data.comparison.device!.confidence * 100).round()}%',
                            'الجهاز: ${data.comparison.device!.label == PredictionLabel.wheeze ? 'أزيز' : 'طبيعي'} ${(data.comparison.device!.confidence * 100).round()}٪',
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
                    tr(language, 'Vitals at event time', 'العلامات وقت الحدث'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SummaryBullet(text: 'SpO2: ${data.vitals.spo2}%'),
                  SummaryBullet(text: 'BPM: ${data.vitals.bpm}'),
                  SummaryBullet(
                    text:
                        '${tr(language, 'Temperature', 'الحرارة')}: ${data.vitals.temperatureC.toStringAsFixed(1)}°C',
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
                    tr(language, 'Acknowledgement', 'التأكيد'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SummaryBullet(
                    text: data.requiresAck
                        ? tr(
                            language,
                            data.acknowledged
                                ? 'This event has already been acknowledged by a parent.'
                                : 'This event still requires acknowledgement.',
                            data.acknowledged
                                ? 'تم تأكيد هذا الحدث من قبل ولي الأمر بالفعل.'
                                : 'هذا الحدث ما زال يحتاج إلى تأكيد.',
                          )
                        : tr(
                            language,
                            'This event did not require parent acknowledgement.',
                            'هذا الحدث لا يحتاج إلى تأكيد من ولي الأمر.',
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
              'Unable to load alert detail.',
              'تعذر تحميل تفاصيل التنبيه.',
            ),
          ),
        ),
      ),
    );
  }
}

extension on AlertEvent {
  String get frameTimeLabelEn {
    final int minutesAgo = DateTime.now().difference(occurredAt).inMinutes;
    return '$minutesAgo minutes ago';
  }

  String get frameTimeLabelAr {
    final int minutesAgo = DateTime.now().difference(occurredAt).inMinutes;
    return 'منذ $minutesAgo دقيقة';
  }
}
