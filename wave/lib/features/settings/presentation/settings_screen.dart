import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/w_card.dart';
import '../../../core/widgets/w_lang_toggle.dart';
import '../../app_state/app_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WaveMedAppState appState = ref.watch(appStateProvider);
    final AppLanguage language = appState.language;

    return Scaffold(
      appBar: AppBar(title: Text(tr(language, 'Settings', 'الإعدادات'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tr(language, 'Language', 'اللغة'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                LanguageToggle(
                  language: language,
                  onChanged: appState.setLanguage,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tr(language, 'Push notifications', 'الإشعارات الفورية'),
                  ),
                  subtitle: Text(
                    tr(
                      language,
                      'Critical, warning, and normal alerts.',
                      'تنبيهات حرجة وتحذيرية وعادية.',
                    ),
                  ),
                  value: appState.notificationsEnabled,
                  onChanged: appState.setNotificationsEnabled,
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tr(language, 'Offline AI inference', 'التحليل الذكي بدون نت'),
                  ),
                  subtitle: Text(
                    tr(
                      language,
                      'Fallback to on-device model when offline.',
                      'استخدم النموذج المحلي عند انقطاع الإنترنت.',
                    ),
                  ),
                  value: appState.offlineInferenceEnabled,
                  onChanged: appState.setOfflineInferenceEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => appState.signOut(),
            child: Text(tr(language, 'Sign out', 'تسجيل الخروج')),
          ),
        ],
      ),
    );
  }
}
