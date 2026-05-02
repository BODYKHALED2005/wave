import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_status_badge.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';

class ChildProfileScreen extends ConsumerWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final String? activeChildId = ref.watch(activeChildIdProvider);
    final AsyncValue<List<ChildSummary>> children = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr(language, 'Children', 'الأطفال'))),
      body: children.when(
        data: (List<ChildSummary> data) => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: data.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final ChildSummary child = data[index];
            final bool isSelected = child.id == activeChildId;
            return InkWell(
              onTap: () {
                ref.read(appStateProvider).selectChild(child.id);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.child_care,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            child.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(
                              language,
                              'Age ${child.ageLabel}  •  Device ${child.deviceId}',
                              'العمر ${child.ageLabel}  •  الجهاز ${child.deviceId}',
                            ),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 10),
                          StatusBadge(
                            language: language,
                            severity: child.hasAssignedDevice
                                ? AlertSeverity.normal
                                : AlertSeverity.wheeze,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: AppColors.primary),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Text(
            tr(
              language,
              'Unable to load child profiles.',
              'تعذر تحميل ملفات الأطفال.',
            ),
          ),
        ),
      ),
    );
  }
}
