import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/w_card.dart';
import '../../../core/widgets/w_summary_bullet.dart';
import '../../app_state/app_state.dart';

class SmartHomeScreen extends ConsumerWidget {
  const SmartHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = ref.watch(
      appStateProvider.select((WaveMedAppState state) => state.language),
    );
    final devices = ref.watch(smartDevicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr(language, 'Smart home', 'المنزل الذكي'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr(language, 'Connected devices', 'الأجهزة المتصلة'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                for (int index = 0; index < devices.length; index++) ...<Widget>[
                  _SmartDeviceTile(language: language, device: devices[index]),
                  if (index != devices.length - 1) const Divider(height: 24),
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
                  tr(language, 'Automation rules', 'قواعد التشغيل'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SummaryBullet(
                  text: tr(
                    language,
                    'MQTT-based smart home control is intentionally left as a placeholder in this milestone.',
                    'تم ترك التحكم المنزلي عبر MQTT كعنصر مؤقت في هذه المرحلة.',
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

class _SmartDeviceTile extends StatelessWidget {
  const _SmartDeviceTile({required this.language, required this.device});

  final AppLanguage language;
  final SmartDevice device;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            IconData(device.iconCodePoint, fontFamily: 'MaterialIcons'),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tr(language, device.nameEn, device.nameAr),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                tr(language, device.reasonEn, device.reasonAr),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: device.isOn, onChanged: null),
      ],
    );
  }
}
