import 'package:flutter/material.dart';

import '../../features/app_state/app_state.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.language,
    required this.onChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppLanguage>(
      showSelectedIcon: false,
      segments: const <ButtonSegment<AppLanguage>>[
        ButtonSegment<AppLanguage>(value: AppLanguage.en, label: Text('EN')),
        ButtonSegment<AppLanguage>(value: AppLanguage.ar, label: Text('AR')),
      ],
      selected: <AppLanguage>{language},
      onSelectionChanged: (Set<AppLanguage> value) => onChanged(value.first),
    );
  }
}
