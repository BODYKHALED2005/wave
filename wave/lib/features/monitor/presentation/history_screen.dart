import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';
import 'widgets/alert_row.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final AsyncValue<ChildSessionState>? session = ref.watch(
      activeChildSessionProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr(language, 'Alert history', 'سجل التنبيهات'))),
      body: session == null
          ? const SizedBox.shrink()
          : session.when(
              data: (ChildSessionState data) => ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: data.alerts.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final AlertEvent alert = data.alerts[index];
                  return InkWell(
                    onTap: () => context.push('/monitor/alert/${alert.id}'),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: AlertRow(language: language, alert: alert),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Text(
                  tr(
                    language,
                    'Unable to load alert history.',
                    'تعذر تحميل سجل التنبيهات.',
                  ),
                ),
              ),
            ),
    );
  }
}
