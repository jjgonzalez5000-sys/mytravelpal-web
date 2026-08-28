import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/biometric_auth.dart';
import '../services/trip_session_persistence.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'plan_screen.dart';
import 'result_screen.dart';

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
    final prefs = ref.read(appPrefsProvider);
    final auth = ref.read(authProvider);
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
          reason: 'Verify your identity to access MyTravelPal',
        );
        if (!ok) {
          next = const LoginScreen();
        } else {
          next = const PlanScreen();
        }
      } else {
        next = const PlanScreen();
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
