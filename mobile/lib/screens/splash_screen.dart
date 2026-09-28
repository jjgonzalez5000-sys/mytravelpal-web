import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/app_tutorial.dart';
import '../services/biometric_auth.dart';
import '../services/trip_session_persistence.dart';
import '../storage/saved_trip.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'app_shell.dart';
import 'result_screen.dart';

/// Compile-time flag: `--dart-define=AUTO_DEMO=1` skips the login +
/// profile-config screens on first launch of a dev build. Wired into
/// `make mobile-local` for fast dogfood cycles; `make mobile-local-clean`
/// omits the flag so the login flow can still be smoke-tested. Empty on
/// production builds → no code path in this file fires.
const String _kAutoDemoFlag = String.fromEnvironment('AUTO_DEMO');
bool get _autoDemoEnabled => _kAutoDemoFlag == '1';

/// Splash — animated brand mark, then routes to onboarding (first launch)
/// or straight to the planner.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_route());
  }

  Future<void> _route() async {
    // Enough time to see the mark animate in, not enough to feel padding.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    // Grab the localised biometric prompt copy BEFORE any async
    // gap so the system dialog matches the app locale even if the
    // widget rebuilds mid-flight.
    final l = AppLocalizations.of(context);
    final prefs = ref.read(appPrefsProvider);
    final auth = ref.read(authProvider);
    // AUTO_DEMO shortcut: dev builds only. Fires when a compile-time
    // `--dart-define=AUTO_DEMO=1` is set AND we don't already have a
    // stored auth session. The gate on `auth.token == null` means real
    // users on production builds are never touched (no compile-time
    // flag → early return) and testers who log in normally on a
    // clean install aren't re-hijacked on the next launch.
    if (_autoDemoEnabled && auth.token == null) {
      final ok = await _runAutoDemo();
      if (!mounted) return;
      if (ok) {
        await Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => const AppShell(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: Tokens.motionBase,
          ),
        );
        if (!mounted) return;
        await _maybeOfferResume();
        return;
      }
      // Auto-demo failed (backend down, network glitch) — fall
      // through to the normal login flow so the tester isn't
      // stranded on the splash screen.
    }
    final Widget next;
    if (!prefs.onboardingShown) {
      next = const OnboardingScreen();
    } else if (!auth.isAuthenticated) {
      next = const LoginScreen();
    } else {
      // Biometric gate: if enabled, require fingerprint/face before
      // showing the main screen. Fail → fall back to login.
      final bio = BiometricService.instance;
      if (await bio.isEnabled) {
        final ok = await bio.authenticate(
          reason: l.biometricPromptReason,
        );
        if (!ok) {
          next = const LoginScreen();
        } else {
          next = const AppShell();
        }
      } else {
        next = const AppShell();
      }
      // Auth already valid from a previous session — the login
      // screen never runs on this launch, so we must wire the
      // api client into TripStorage + TripProfileNotifier here
      // too. Without this hook every locally-saved trip stayed
      // local (never pushed to Postgres), so `borrar datos +
      // re-login` wiped everything even though the user
      // expected the cloud copy to survive.
      final api = ref.read(apiClientWithPremiumProvider);
      final profileNotifier = ref.read(tripProfileProvider.notifier);
      profileNotifier.api = api;
      final storage = ref.read(tripStorageProvider);
      storage.api = api;
      // Fire the sync so any trips / profile changes the user
      // made on another device (or before the last install)
      // land locally. Fire-and-forget: navigation to Plan runs
      // in parallel so the user doesn't wait for the network.
      unawaited(profileNotifier.syncFromServer());
      unawaited(storage.syncFromServer());
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: Tokens.motionBase,
      ),
    );
    // After the initial route lands, check for a persisted trip
    // session and offer to resume. Doing this AFTER the transition
    // so the user always sees Plan first (their mental home) — the
    // resume dialog then floats on top instead of hijacking startup.
    if (!mounted) return;
    await _maybeOfferResume();
  }

  /// Headless equivalent of `LoginScreen._signInDemo` + the profile
  /// setup a tester would otherwise walk through. Only invoked when
  /// `--dart-define=AUTO_DEMO=1` is compiled in AND no auth session
  /// is stored. Returns true on success so the caller can route to
  /// `AppShell`; false on error so it can fall back to `LoginScreen`.
  Future<bool> _runAutoDemo() async {
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final session = await api.createSession(
        provider: 'demo',
        idToken: 'demo-id-token',
        demoEmail: 'demo@mytravelpal.local',
        demoName: 'Demo user',
      );
      await ref
          .read(authProvider.notifier)
          .set(session.user, session.token);
      // Rewire the api client so profile + storage pushes carry the
      // new JWT. Mirrors the wiring done at the end of `_route` for
      // returning users.
      final authedApi = ref.read(apiClientWithPremiumProvider);
      final profileNotifier = ref.read(tripProfileProvider.notifier);
      profileNotifier.api = authedApi;
      final storage = ref.read(tripStorageProvider);
      storage.api = authedApi;
      // Hardcoded dogfood profile: family-of-3 with kids, mid-morning
      // start, 6h daily cap. Everything else stays at the sensible
      // defaults from `const TripProfile()` (car / petrol / steady
      // pace / if-needed overnight / scenic breaks).
      const demoProfile = TripProfile(
        travellers: 3,
        hasKids: true,
        dailyDrivingCapHours: 6,
        preferredDrivingStartHour: 10,
      );
      // `set` persists to AppPrefs AND fires _pushToServer (fire-and-
      // forget) so the backend sees the profile too.
      await profileNotifier.set(demoProfile);
      // Skip the intro/onboarding wizard on auto-demo — the tester
      // just wants to land in the planner. Persisted so subsequent
      // launches also skip it.
      final prefs = ref.read(appPrefsProvider);
      await prefs.markOnboardingShown();
      // Also silence the plan + result coach-mark tutorials so a
      // fresh install doesn't stop the dogfood flow at the first
      // "welcome to the planner" overlay.
      await markTutorialsSeen();
      // Pre-seed a Yaris 4 Hybrid at 25% tank in the garage so the
      // dogfood profile has a realistic car to plan against without
      // the tester having to fill the garage form on every fresh
      // install. Silently swallow failures — garage endpoint being
      // down shouldn't block the demo path.
      try {
        await authedApi.addGarageVehicle(
          name: 'Yaris',
          modelId: 'toyota_yaris_4_hev',
          defaultTankPercent: 25,
        );
      } catch (e) {
        debugPrint('AUTO_DEMO garage pre-seed failed: $e');
      }
      // Pre-seed a Toledo → Paris trip in the local saved-trips
      // storage so the "Recent trips" dropdown on the PlanScreen
      // has something to demo the picker with. Uses the same
      // helper the manual "Save this plan" button uses.
      try {
        final now = DateTime.now();
        final toledo = GeocodeResult(
          displayName: 'Toledo, España',
          coordinate: const LatLon(lat: 39.8628, lon: -4.0273),
          country: Country.es,
        );
        final paris = GeocodeResult(
          displayName: 'Paris, France',
          coordinate: const LatLon(lat: 48.8566, lon: 2.3522),
          country: Country.fr,
        );
        final departure =
            DateTime(now.year, now.month, now.day + 1, 10);
        await storage.save(SavedTrip(
          id: 'demo:toledo-paris',
          origin: toledo,
          destination: paris,
          desiredDepartureAt: departure,
          savedAt: now,
          distanceKm: 1450,
          recommendedDepartureAt: departure,
          recommendedMinutes: 900,
          countriesCrossed: const [Country.es, Country.fr],
        ));
      } catch (e) {
        debugPrint('AUTO_DEMO saved-trip pre-seed failed: $e');
      }
      return true;
    } catch (e, stack) {
      debugPrint('AUTO_DEMO auto-login failed: $e\n$stack');
      return false;
    }
  }

  Future<void> _maybeOfferResume() async {
    final session = await TripSessionPersistence.instance.read();
    if (session == null || !mounted) return;
    final l = AppLocalizations.of(context);
    final resume = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.resumeTripTitle),
        content: Text(
          l.resumeTripBody(
            session.origin.displayName.split(',').first,
            session.destination.displayName.split(',').first,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.resumeTripDismiss),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.resumeTripResume),
          ),
        ],
      ),
    );
    if (resume != true) {
      // "No" → discard the snapshot so we don't nag again on the
      // next launch.
      await TripSessionPersistence.instance.clear();
      return;
    }
    if (!mounted) return;
    // Push the ResultScreen with the restored request/response, then
    // let the driver tap "Iniciar viaje" again to reopen the
    // dashboard — the FAB there will re-persist a fresh session.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          request: session.request,
          origin: session.origin,
          destination: session.destination,
          response: session.response,
          desiredDepartureAt: session.desiredDepartureAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(color: scheme.primary)
                .animate()
                .fadeIn(duration: Tokens.motionBase)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: Tokens.space20),
            Text('MyTravelPal', style: t.headlineMedium)
                .animate()
                .fadeIn(delay: 200.ms, duration: Tokens.motionBase)
                .moveY(begin: 8, end: 0, curve: Tokens.curveOut),
            const SizedBox(height: Tokens.space4),
            Text(
              'Plan the drive, not just the destination',
              style: t.bodySmall,
            )
                .animate()
                .fadeIn(delay: 320.ms, duration: Tokens.motionBase),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: CustomPaint(painter: _BrandPainter(color)),
    );
  }
}

class _BrandPainter extends CustomPainter {
  _BrandPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.78)
      ..cubicTo(
        size.width * 0.32, size.height * 0.32,
        size.width * 0.68, size.height * 0.90,
        size.width * 0.86, size.height * 0.32,
      );
    canvas.drawPath(path, stroke);

    final dot = Paint()..color = color;
    canvas.drawCircle(Offset(size.width * 0.14, size.height * 0.78), 5, dot);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.32), 5, dot);
  }

  @override
  bool shouldRepaint(covariant _BrandPainter oldDelegate) =>
      oldDelegate.color != color;
}
