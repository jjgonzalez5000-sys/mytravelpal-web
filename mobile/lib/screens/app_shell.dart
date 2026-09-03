import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'companion_screen.dart';
import 'history_screen.dart';
import 'plan_screen.dart';

/// Root shell with a bottom navigation bar. Three tabs:
///
/// 1. **Plan** — the original trip-planning form + results.
/// 2. **Companion** — configure + launch the driving assistant.
/// 3. **My trips** — saved history + stats.
///
/// Each tab keeps its own Navigator so pushing a result screen
/// inside Plan doesn't wipe the Companion or History state. The
/// `WillPopScope` guard lets Android back-button pop within the
/// active tab before exiting the app.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  // Per-tab navigator keys so back-button pops within the tab.
  final _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navState = _navigatorKeys[_tab].currentState;
        if (navState != null && navState.canPop()) {
          navState.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        }
        // If already on tab 0 and can't pop, do nothing — system
        // handles the app-level back (minimize).
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            _TabNavigator(
              navigatorKey: _navigatorKeys[0],
              child: const PlanScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[1],
              child: const CompanionScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[2],
              child: HistoryScreen(
                onSwitchToPlan: () => setState(() => _tab = 0),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              label: l.tabPlan,
            ),
            NavigationDestination(
              icon: Consumer(
                builder: (context, ref, _) {
                  final active = ref.watch(companionActiveProvider);
                  return Badge(
                    isLabelVisible: active,
                    smallSize: 8,
                    child: const Icon(Icons.explore_outlined),
                  );
                },
              ),
              selectedIcon: Consumer(
                builder: (context, ref, _) {
                  final active = ref.watch(companionActiveProvider);
                  return Badge(
                    isLabelVisible: active,
                    smallSize: 8,
                    child: const Icon(Icons.explore),
                  );
                },
              ),
              label: l.tabCompanion,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bookmark_outline),
              selectedIcon: const Icon(Icons.bookmark),
              label: l.tabMyTrips,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => child,
      ),
    );
  }
}
