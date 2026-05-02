import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/presentation/ai_chat_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/app_state/app_state.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/children/presentation/child_profile_screen.dart';
import '../../features/emergency/presentation/emergency_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/monitor/presentation/alert_detail_screen.dart';
import '../../features/monitor/presentation/history_screen.dart';
import '../../features/monitor/presentation/live_monitor_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/report/presentation/doctor_report_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/setup/presentation/device_setup_screen.dart';
import '../../features/smart_home/presentation/smart_home_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/workspace/presentation/workspace_screen.dart';
import '../widgets/app_shell_scaffold.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final WaveMedAppState appState = ref.watch(appStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: appState,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      final bool isPublicRoute =
          location == '/splash' ||
          location == '/onboarding' ||
          location == '/login';

      if (!appState.completedOnboarding && location != '/onboarding') {
        return '/onboarding';
      }

      if (appState.completedOnboarding &&
          !appState.authenticated &&
          location != '/login') {
        return '/login';
      }

      if (appState.authenticated && isPublicRoute) {
        return '/home';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (BuildContext context, GoRouterState state) =>
            SplashScreen(language: appState.language),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            OnboardingScreen(
              language: appState.language,
              onLanguageChanged: appState.setLanguage,
              onCompleted: appState.completeOnboarding,
            ),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const AuthScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (BuildContext context, GoRouterState state) =>
            const DeviceSetupScreen(),
      ),
      GoRoute(
        path: '/children',
        builder: (BuildContext context, GoRouterState state) =>
            const ChildProfileScreen(),
      ),
      GoRoute(
        path: '/smart-home',
        builder: (BuildContext context, GoRouterState state) =>
            const SmartHomeScreen(),
      ),
      GoRoute(
        path: '/report',
        builder: (BuildContext context, GoRouterState state) =>
            const DoctorReportScreen(),
      ),
      GoRoute(
        path: '/emergency',
        builder: (BuildContext context, GoRouterState state) =>
            const EmergencyScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: '/monitor/history',
        builder: (BuildContext context, GoRouterState state) =>
            const HistoryScreen(),
      ),
      GoRoute(
        path: '/monitor/alert/:alertId',
        builder: (BuildContext context, GoRouterState state) =>
            AlertDetailScreen(
              alertId: state.pathParameters['alertId'] ?? '',
            ),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return AppShellScaffold(
            language: appState.language,
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeScreen(),
          ),
          GoRoute(
            path: '/monitor',
            builder: (BuildContext context, GoRouterState state) =>
                const MonitorScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (BuildContext context, GoRouterState state) =>
                const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/ai-chat',
            builder: (BuildContext context, GoRouterState state) =>
                const AssistantScreen(),
          ),
          GoRoute(
            path: '/workspace',
            builder: (BuildContext context, GoRouterState state) =>
                const MoreScreen(),
          ),
        ],
      ),
    ],
  );
});
