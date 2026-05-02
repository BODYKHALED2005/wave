import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseService {
  FirebaseService._();

  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    } catch (error, stackTrace) {
      debugPrint('Firebase initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
