import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_state/app_state.dart';
import '../../features/live_data/live_models.dart';

class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({
    super.key,
    required this.language,
    required this.location,
    required this.child,
  });

  final AppLanguage language;
  final String location;
  final Widget child;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<ChildSessionState>?>(activeChildSessionProvider, (
      AsyncValue<ChildSessionState>? previous,
      AsyncValue<ChildSessionState>? next,
    ) {
      final ChildSessionState? state = next?.valueOrNull;
      if (state == null) {
        return;
      }
      final WaveMedAppState appState = ref.read(appStateProvider);
      final bool hasEmergency =
          state.activeEmergency(
            locallyAcknowledgedAlerts: appState.locallyAcknowledgedAlertIds,
          ) !=
          null;
      if (hasEmergency && GoRouterState.of(context).matchedLocation != '/emergency') {
        context.push('/emergency');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          context.go(_routeForIndex(index));
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: tr(widget.language, 'Home', 'الرئيسية'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.monitor_heart_outlined),
            selectedIcon: const Icon(Icons.monitor_heart),
            label: tr(widget.language, 'Monitor', 'المراقبة'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: tr(widget.language, 'Analytics', 'التحليلات'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: tr(widget.language, 'AI', 'الذكاء'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard_customize_outlined),
            selectedIcon: const Icon(Icons.dashboard_customize),
            label: tr(widget.language, 'More', 'المزيد'),
          ),
        ],
      ),
    );
  }

  int get _selectedIndex {
    if (widget.location.startsWith('/monitor')) {
      return 1;
    }
    if (widget.location.startsWith('/analytics')) {
      return 2;
    }
    if (widget.location.startsWith('/ai-chat')) {
      return 3;
    }
    if (widget.location.startsWith('/workspace')) {
      return 4;
    }
    return 0;
  }

  String _routeForIndex(int index) {
    return switch (index) {
      0 => '/home',
      1 => '/monitor',
      2 => '/analytics',
      3 => '/ai-chat',
      _ => '/workspace',
    };
  }
}
