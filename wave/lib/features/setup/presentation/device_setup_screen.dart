import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_card.dart';
import '../../app_state/app_state.dart';
import '../../live_data/live_models.dart';

class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen> {
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _networkNameController = TextEditingController();
  final TextEditingController _networkPasswordController =
      TextEditingController();
  bool _submitting = false;
  String? _message;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _networkNameController.dispose();
    _networkPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final AsyncValue<ChildSessionState>? session = ref.watch(
      activeChildSessionProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr(language, 'Device setup', 'إعداد الجهاز'))),
      body: session == null
          ? const SizedBox.shrink()
          : session.when(
              data: (ChildSessionState data) {
                if (_deviceIdController.text.isEmpty) {
                  _deviceIdController.text = data.child.deviceId;
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tr(
                              language,
                              'Setup flow for ${data.child.name}',
                              'خطوات الإعداد لـ ${data.child.name}',
                            ),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (int i = 0; i < data.setupStatus.steps.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == data.setupStatus.steps.length - 1
                                    ? 0
                                    : 12,
                              ),
                              child: _SetupRow(
                                language: language,
                                step: data.setupStatus.steps[i],
                                index: i + 1,
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
                            tr(
                              language,
                              'Backend device assignment',
                              'ربط الجهاز على الخادم',
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _deviceIdController,
                            decoration: InputDecoration(
                              labelText: tr(
                                language,
                                'Device ID',
                                'معرف الجهاز',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _networkNameController,
                            decoration: InputDecoration(
                              labelText: tr(
                                language,
                                'Wi-Fi network name',
                                'اسم شبكة Wi-Fi',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _networkPasswordController,
                            decoration: InputDecoration(
                              labelText: tr(
                                language,
                                'Wi-Fi password',
                                'كلمة مرور Wi-Fi',
                              ),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _submitting
                                ? null
                                : () => _submit(data.child.id),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              backgroundColor: AppColors.primary,
                            ),
                            child: Text(
                              _submitting
                                  ? tr(language, 'Saving...', 'جارٍ الحفظ...')
                                  : tr(
                                      language,
                                      'Assign device',
                                      'ربط الجهاز',
                                    ),
                            ),
                          ),
                          if (_message != null) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              _message!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tr(language, 'Provisioning status', 'حالة التهيئة'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr(
                              language,
                              'BLE and Wi-Fi provisioning are intentionally disabled in this version until the firmware GATT contract is provided.',
                              'تم تعطيل تهيئة BLE و Wi-Fi عمداً في هذه النسخة حتى يتم توفير عقد GATT الخاص بالبرنامج الثابت.',
                            ),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Text(
                  tr(
                    language,
                    'Unable to load device setup state.',
                    'تعذر تحميل حالة إعداد الجهاز.',
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _submit(String childId) async {
    final AppLanguage language = ref.read(appStateProvider).language;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await ref.read(deviceApiServiceProvider).assignDevice(
        DeviceAssignment(
          childId: childId,
          deviceId: _deviceIdController.text.trim(),
          networkName: _networkNameController.text.trim(),
          networkPassword: _networkPasswordController.text,
        ),
      );
      ref.invalidate(childrenProvider);
      ref.invalidate(childSessionProvider(childId));
      setState(() {
        _message = tr(
          language,
          'Device assignment saved. Live data will refresh on the next scan.',
          'تم حفظ ربط الجهاز. سيتم تحديث البيانات المباشرة مع الفحص التالي.',
        );
      });
    } catch (error) {
      setState(() {
        _message = tr(
          language,
          'Unable to save the device assignment right now.',
          'تعذر حفظ ربط الجهاز حالياً.',
        );
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.language,
    required this.step,
    required this.index,
  });

  final AppLanguage language;
  final SetupStepStatus step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (step.state) {
      SetupStepState.completed => AppColors.primary,
      SetupStepState.blocked => AppColors.warning,
      SetupStepState.pending => AppColors.surfaceAlt,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: step.state == SetupStepState.completed
              ? const Icon(Icons.check, color: Colors.white)
              : step.state == SetupStepState.blocked
              ? const Icon(Icons.pause_rounded, color: Colors.white)
              : Text(
                  '$index',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tr(language, step.titleEn, step.titleAr),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                tr(language, step.descriptionEn, step.descriptionAr),
                style: const TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
