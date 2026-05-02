import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final WaveMedAppState appState = ref.watch(appStateProvider);
    final AsyncValue<ChildSessionState>? session = ref.watch(
      activeChildSessionProvider,
    );

    final AlertEvent? activeEmergency = session?.valueOrNull?.activeEmergency(
      locallyAcknowledgedAlerts: appState.locallyAcknowledgedAlertIds,
    );
    final ChildSessionState? state = session?.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.danger,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: state == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white12,
                      ),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      tr(language, 'Emergency mode', 'وضع الطوارئ'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        language,
                        '${state.child.name} needs immediate review',
                        'يحتاج ${state.child.name} إلى مراجعة فورية',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(
                        language,
                        'Backend-confirmed wheeze with SpO2 ${state.frame.vitals.spo2}%. Keep the child upright, continue observation, and contact emergency services if symptoms escalate.',
                        'تم تأكيد الأزيز من الخادم مع أكسجين ${state.frame.vitals.spo2}٪. أبقِ الطفل بوضع مستقيم، واستمر بالملاحظة، واتصل بخدمات الطوارئ إذا تصاعدت الأعراض.',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _EmergencyAction(
                      icon: Icons.call,
                      label: tr(
                        language,
                        'Call emergency services',
                        'اتصل بخدمات الطوارئ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _EmergencyAction(
                      icon: Icons.local_hospital,
                      label: tr(
                        language,
                        'Open nearest hospital map',
                        'افتح أقرب مستشفى',
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: activeEmergency == null
                          ? null
                          : () {
                              ref
                                  .read(appStateProvider)
                                  .acknowledgeEmergency(activeEmergency.id);
                              context.pop();
                            },
                      borderRadius: BorderRadius.circular(24),
                      child: _EmergencyAction(
                        icon: Icons.check_circle_outline,
                        label: activeEmergency == null
                            ? tr(
                                language,
                                'Monitoring only',
                                'مراقبة فقط',
                              )
                            : tr(
                                language,
                                'Acknowledge and keep monitoring',
                                'تم الاستلام مع الاستمرار بالمراقبة',
                              ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmergencyAction extends StatelessWidget {
  const _EmergencyAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
