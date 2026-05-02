import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wavemed/app.dart';
import 'package:wavemed/features/app_state/app_state.dart';
import 'package:wavemed/services/auth_session_service.dart';
import 'package:wavemed/services/local_storage.dart';

void main() {
  testWidgets('WaveMed opens onboarding flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStorageProvider.overrideWithValue(LocalStorage.memory()),
          authSessionServiceProvider.overrideWithValue(AuthSessionService.memory()),
        ],
        child: const WaveMedApp(),
      ),
    );

    expect(find.text('WaveMed'), findsOneWidget);
    expect(find.text('Smart Wheeze Monitor'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
