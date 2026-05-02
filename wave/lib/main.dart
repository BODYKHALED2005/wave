import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/app_state/app_state.dart';
import 'services/firebase_service.dart';
import 'services/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final LocalStorage localStorage = await LocalStorage.init();
  await FirebaseService.initialize();

  runApp(
    ProviderScope(
      overrides: <Override>[
        localStorageProvider.overrideWithValue(localStorage),
      ],
      child: const WaveMedApp(),
    ),
  );
}
