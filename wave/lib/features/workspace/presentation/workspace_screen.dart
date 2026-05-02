import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_card.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final List<ChildSummary>? children = ref.watch(childrenProvider).valueOrNull;
    final child = ref.watch(activeChildProvider);
    final devices = ref.watch(smartDevicesProvider);
    final WaveMedAppState appState = ref.watch(appStateProvider);

    final List<_MoreAction> actions = <_MoreAction>[
      _MoreAction(
        icon: Icons.family_restroom,
        title: tr(language, 'Children', 'الأطفال'),
        subtitle: tr(
          language,
          '${children?.length ?? 0} profiles',
          '${children?.length ?? 0} ملفات',
        ),
        onTap: () => context.push('/children'),
      ),
      _MoreAction(
        icon: Icons.bluetooth_searching,
        title: tr(language, 'Device setup', 'إعداد الجهاز'),
        subtitle: tr(language, 'Backend assignment flow', 'مسار ربط الخادم'),
        onTap: () => context.push('/setup'),
      ),
      _MoreAction(
        icon: Icons.home_work_outlined,
        title: tr(language, 'Smart home', 'المنزل الذكي'),
        subtitle: tr(
          language,
          '${devices.where((SmartDevice d) => d.isOn).length} devices shown',
          '${devices.where((SmartDevice d) => d.isOn).length} أجهزة معروضة',
        ),
        onTap: () => context.push('/smart-home'),
      ),
      _MoreAction(
        icon: Icons.picture_as_pdf_outlined,
        title: tr(language, 'Doctor report', 'تقرير الطبيب'),
        subtitle: tr(language, 'Snapshot export route', 'مسار تصدير مؤقت'),
        onTap: () => context.push('/report'),
      ),
      _MoreAction(
        icon: Icons.crisis_alert_outlined,
        title: tr(language, 'Emergency screen', 'شاشة الطوارئ'),
        subtitle: tr(
          language,
          'Full-screen critical mode',
          'وضع كامل للحالات الحرجة',
        ),
        onTap: () => context.push('/emergency'),
      ),
      _MoreAction(
        icon: Icons.settings_outlined,
        title: tr(language, 'Settings', 'الإعدادات'),
        subtitle: tr(
          language,
          'Language, notifications, offline',
          'اللغة والإشعارات والعمل دون نت',
        ),
        onTap: () => context.push('/settings'),
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          Text(
            tr(language, 'Workspace', 'المساحة'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Row(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.child_care, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        child?.name ?? '--',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          language,
                          'Notifications ${appState.notificationsEnabled ? 'on' : 'off'}  •  Offline inference ${appState.offlineInferenceEnabled ? 'ready' : 'disabled'}',
                          'الإشعارات ${appState.notificationsEnabled ? 'مفعلة' : 'متوقفة'}  •  التحليل بدون نت ${appState.offlineInferenceEnabled ? 'جاهز' : 'موقوف'}',
                        ),
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final _MoreAction action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MoreActionCard(action: action),
            ),
        ],
      ),
    );
  }
}

class _MoreAction {
  const _MoreAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _MoreActionCard extends StatelessWidget {
  const _MoreActionCard({required this.action});

  final _MoreAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(action.icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    action.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSoft),
          ],
        ),
      ),
    );
  }
}
