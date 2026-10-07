// Full-auto Play Store screenshot capture. Boots the app with
// AUTO_DEMO=1 so demo login + Toledo → Paris trip + Yaris in the
// garage are pre-seeded, then navigates through the key screens
// snapping a PNG at each.
//
// Runs against the REAL Fly backend by default (AUTO_DEMO builds
// the same as `flutter run --dart-define=AUTO_DEMO=1` and uses
// whatever API_BASE_URL you pass on the command line).
//
// Invocation (from `mobile/`):
//   flutter drive \
//     --driver=test_driver/screenshots_test.dart \
//     --target=integration_test/screenshots_test.dart \
//     --dart-define=AUTO_DEMO=1 \
//     --dart-define=API_BASE_URL=https://mytravelpal-api.fly.dev \
//     --dart-define=API_KEY=<the release key>
//
// Or via `make screenshots-auto LOCALE=es`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mytravelpal/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Play Store screenshots', (tester) async {
    // Boot the app + wait for the splash → PlanScreen routing to
    // finish. AUTO_DEMO fires demo login + profile push + garage +
    // trip pre-seed, then AppShell mounts — comfortably under 25 s.
    await app.main();
    // pumpAndSettle spins the frame clock until no timers are
    // pending; capped so an infinite spinner (e.g. Lottie loop)
    // can't hang the test forever.
    try {
      await tester.pumpAndSettle(
        const Duration(seconds: 20),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
    } catch (_) {
      // Long-running animations block pumpAndSettle — fall through
      // and start polling for the CTA anyway.
    }
    // Poll for the PlanScreen CTA up to 30 s more; the demo login
    // itself is a ~2 s network round-trip but a cold Fly wake-up
    // can push that to 15-25 s.
    final ctaReady = await _waitForAnyText(
      tester,
      const ['Planificar viaje', 'Plan trip', 'Plan trip'],
      timeout: const Duration(seconds: 30),
    );
    // Scroll to reveal the CTA if it's below the fold on small
    // screens — the form's own scrollable contains it.
    if (!ctaReady) {
      await _scrollDown(tester, pixels: 400);
      await tester.pump(const Duration(seconds: 1));
    }

    // 1) Plan screen — form pre-filled by AUTO_DEMO bootstrap.
    await _snap(binding, tester, '01-plan');

    // 2) Trigger the plan.
    final planCta = _findByAnyText(
      tester,
      const ['Planificar viaje', 'Plan trip'],
    );
    if (planCta.evaluate().isEmpty) {
      // ignore: avoid_print
      print('WARN: plan CTA not found — bailing out with what we have');
      return;
    }
    await tester.tap(planCta.first);

    // Wait for the loading dialog + backend response. `pumpAndSettle`
    // won't work because the loading spinner animates forever; wait
    // for ResultScreen to appear by polling for a known text.
    final resultReady = await _waitForAnyText(
      tester,
      const ['km', 'Coste total', 'Total cost'],
      timeout: const Duration(seconds: 90),
    );
    if (!resultReady) {
      // ignore: avoid_print
      print('WARN: result screen never surfaced — snapping current state');
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 3) Result hero — top of the screen.
    await _snap(binding, tester, '02-result-hero');

    // 4) Scroll down to reveal the day plan / fuel section.
    await _scrollDown(tester, pixels: 900);
    await _snap(binding, tester, '03-result-days');

    // 5) Scroll further for fuel + weather + adverse.
    await _scrollDown(tester, pixels: 900);
    await _snap(binding, tester, '04-result-fuel');

    // 6) Companion tab (bottom nav — icon = assistant_navigation).
    //    NavigationBar destinations are indexed; the Companion tab
    //    is index 2 in AppShell.
    final companionTab = _findByAnyText(
      tester, const ['Companion', 'Copiloto'],
    );
    if (companionTab.evaluate().isNotEmpty) {
      await tester.tap(companionTab.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await _snap(binding, tester, '05-companion');
    }

    // 7) History tab.
    final historyTab = _findByAnyText(
      tester, const ['Viajes', 'History', 'Trips'],
    );
    if (historyTab.evaluate().isNotEmpty) {
      await tester.tap(historyTab.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await _snap(binding, tester, '06-history');
    }

    // 8) Profile / settings tab.
    final profileTab = _findByAnyText(
      tester, const ['Perfil', 'Profile', 'Yo'],
    );
    if (profileTab.evaluate().isNotEmpty) {
      await tester.tap(profileTab.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await _snap(binding, tester, '07-profile');
    }
  });
}

// ---- helpers ---------------------------------------------------------

Future<void> _snap(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  // Android needs the Flutter surface converted to an image before
  // takeScreenshot works — no-op on iOS / macOS.
  await binding.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  await binding.takeScreenshot(name);
}

/// Case-insensitive text finder that accepts any of the provided
/// labels — makes the driver survive locale switches.
Finder _findByAnyText(WidgetTester tester, List<String> labels) {
  return find.byWidgetPredicate((w) {
    if (w is Text) {
      final data = (w.data ?? '').toLowerCase();
      return labels.any((l) => data.contains(l.toLowerCase()));
    }
    return false;
  });
}

/// Poll every 500 ms until any of the [labels] appears or [timeout]
/// elapses. Returns true when found, false otherwise.
Future<bool> _waitForAnyText(
  WidgetTester tester,
  List<String> labels, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (_findByAnyText(tester, labels).evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Drag the primary scrollable up by [pixels]. Uses the first
/// scrollable in the tree — fine for single-screen scaffolds.
Future<void> _scrollDown(WidgetTester tester, {double pixels = 600}) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  await tester.drag(scrollables.first, Offset(0, -pixels));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}
