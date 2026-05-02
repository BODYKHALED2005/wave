import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../app_state/app_state.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.air, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 18),
            const Text(
              'WaveMed',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                language,
                'Preparing monitoring workspace...',
                'جارٍ تجهيز مساحة المراقبة...',
              ),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
