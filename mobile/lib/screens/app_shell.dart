import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// `PopScope` guard lets Android back-button pop within the
/// active tab before exiting the app.
///
/// Tab transitions use an M3 fade-through: outgoing fades out
/// quickly, incoming fades in with a subtle scale-up. All tabs
/// remain mounted (like `IndexedStack`) so form state and
/// navigator route stacks survive tab switches.
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

  void _onDestinationSelected(int i) {
    if (i == _tab) return;
    // Subtle tick on physical devices, no-op on emulators.
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
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
        body: _FadeThroughStack(
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
          onDestinationSelected: _onDestinationSelected,
          // Soft primary-container pill behind the selected icon.
          indicatorColor: scheme.primaryContainer.withValues(alpha: 0.6),
          // Explicit ripple/hover so the tap feels responsive on
          // both light and dark themes.
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return scheme.primary.withValues(alpha: 0.12);
            }
            return null;
          }),
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

/// State-preserving fade-through stack.
///
/// Behaves like `IndexedStack` (all children stay mounted so
/// form state and per-tab Navigator route stacks survive tab
/// switches) but cross-fades the visible child with an M3
/// fade-through curve: outgoing fades out over the first 35% of
/// the animation, incoming fades in over the last 65% with a
/// subtle scale from 0.94 → 1.0.
///
/// The `animations` package isn't in pubspec, so this is a
/// hand-rolled equivalent to `PageTransitionSwitcher` with
/// `FadeThroughTransition`.
class _FadeThroughStack extends StatefulWidget {
  const _FadeThroughStack({
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<_FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<_FadeThroughStack>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 240);

  late int _previous = widget.index;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1, // start settled
  );

  @override
  void didUpdateWidget(covariant _FadeThroughStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _previous = old.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        // Fade-through: outgoing dies in first 35%, incoming
        // grows in last 65%.
        final outOpacity = (1 - (t / 0.35)).clamp(0.0, 1.0);
        final inRaw = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
        // Ease-out on the incoming fade so the settle is soft.
        final inOpacity = Curves.easeOut.transform(inRaw);
        final inScale = 0.94 + 0.06 * inOpacity;

        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (i) {
            final child = widget.children[i];
            if (i == widget.index) {
              // Incoming (or settled) tab.
              return Opacity(
                opacity: inOpacity,
                child: Transform.scale(
                  scale: inScale,
                  child: child,
                ),
              );
            }
            if (i == _previous && _controller.isAnimating && outOpacity > 0) {
              // Outgoing tab — briefly overlaid on top of the
              // stack so the cross-fade reads.
              return IgnorePointer(
                child: Opacity(
                  opacity: outOpacity,
                  child: child,
                ),
              );
            }
            // Inactive tab — kept mounted (state preserved) but
            // hidden and non-interactive. `TickerMode` pauses
            // any implicit animations inside the tab.
            return Offstage(
              offstage: true,
              child: TickerMode(
                enabled: false,
                child: child,
              ),
            );
          }),
        );
      },
    );
  }
}
