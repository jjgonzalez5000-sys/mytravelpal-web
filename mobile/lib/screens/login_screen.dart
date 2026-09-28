import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Apple sign-in removed 2026-08-29 — Android-only build, no iOS
// target. Re-add when we ship an iOS build (Apple then requires
// this button per App Store Review Guidelines §4.8 for any app
// offering 3rd-party sign-in).

import '../api/api_client.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/biometric_auth.dart';
import 'app_shell.dart';

/// Sign-in screen. In production this offers Google + Facebook + Apple;
/// in dev/demo builds a **Continue as demo** button lets you skip
/// through without any OAuth configuration.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _finish(String provider, String idToken,
      {String? demoEmail, String? demoName}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final session = await api.createSession(
        provider: provider,
        idToken: idToken,
        demoEmail: demoEmail,
        demoName: demoName,
      );
      await ref
          .read(authProvider.notifier)
          .set(session.user, session.token);
      // Sync profile from server after login — if the user has
      // a saved profile from a previous device/install, it
      // overrides the local defaults.
      final profileNotifier = ref.read(tripProfileProvider.notifier);
      profileNotifier.api = api;
      await profileNotifier.syncFromServer();
      // Same wiring for saved trips — merges server trips into
      // local storage AND arms the storage so future save/delete
      // pushes to the server too. Without this the user only
      // sees their local device's trips.
      final storage = ref.read(tripStorageProvider);
      storage.api = api;
      await storage.syncFromServer();
      if (!mounted) return;
      // Offer biometric setup on first real login (not demo)
      final bio = BiometricService.instance;
      if (provider != 'demo' &&
          await bio.isAvailable && !(await bio.isEnabled)) {
        if (mounted) {
          final loc = AppLocalizations.of(context);
          final enable = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(loc.biometricSetupTitle),
              content: Text(loc.biometricSetupBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(loc.biometricSetupSkip),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(loc.biometricSetupEnable),
                ),
              ],
            ),
          );
          if (enable == true) await bio.setEnabled(true);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AppShell()),
      );
    } on ApiException catch (e) {
      setState(() => _error = 'Auth failed (${e.statusCode})');
    } catch (e) {
      setState(() => _error = 'Auth failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _googleWebClientId =
      '885268678623-t4vdjvdf7n7i5v8s6bs6jqcbn4327a4d.apps.googleusercontent.com';

  Future<void> _signInWithGoogle() async {
    try {
      final account = await GoogleSignIn(
        serverClientId: _googleWebClientId,
      ).signIn();
      if (account == null) return; // user cancelled
      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null) {
        setState(() => _error = 'Google returned no id token');
        return;
      }
      await _finish('google', token);
    } catch (e, stack) {
      debugPrint('Google sign-in error: $e\n$stack');
      setState(
        () => _error = 'Google sign-in error: $e',
      );
    }
  }

  // _signInWithApple removed — Apple sign-in comes back when we
  // ship iOS (Apple App Store rule §4.8 requires it for any app
  // that offers a 3rd-party login option).

  Future<void> _signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success ||
          result.accessToken == null) {
        setState(() => _error = 'Facebook login cancelled or failed');
        return;
      }
      await _finish('facebook', result.accessToken!.tokenString);
    } catch (e) {
      setState(
        () => _error =
            'Facebook sign-in unavailable (needs app configuration): $e',
      );
    }
  }

  /// Restored 2026-09-27: a lightweight "Continuar como demo" path
  /// so testers + the beta funnel can bypass Google/Facebook when
  /// evaluating features. Backend still accepts provider="demo" +
  /// demo_email / demo_name (see backend/app/api/v1/auth.py:14 —
  /// never removed). No dialog, no persistence — the account is
  /// ephemeral and lives inside this install only.
  Future<void> _signInDemo() async {
    await _finish(
      'demo',
      // Backend demo provider ignores the id_token entirely — send
      // a stable dummy string so the wire contract is satisfied.
      'demo-id-token',
      demoEmail: 'demo@mytravelpal.local',
      demoName: 'Demo user',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space24, vertical: Tokens.space20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // FittedBox scales the app name down on narrow phones
              // instead of overflowing (tester report 2026-09-28: a
              // 6px overflow on the "MyTravelPal" displayMedium on
              // an sdk gphone screen). Alignment left keeps the
              // rest of the stretch column feeling natural.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(l.appName, style: t.displayMedium)
                    .animate()
                    .fadeIn(duration: Tokens.motionBase)
                    .moveY(begin: 8, end: 0, curve: Tokens.curveOut),
              ),
              const SizedBox(height: Tokens.space8),
              Text(
                '${l.appTagline}.',
                style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              _OAuthButton(
                icon: Icons.g_mobiledata,
                label: l.loginContinueGoogle,
                onPressed: _busy ? null : _signInWithGoogle,
              ),
              const SizedBox(height: Tokens.space12),
              _OAuthButton(
                icon: Icons.facebook,
                label: l.loginContinueFacebook,
                onPressed: _busy ? null : _signInWithFacebook,
              ),
              const SizedBox(height: Tokens.space16),
              // Demo login RESTORED 2026-09-27 for tester funnel —
              // ephemeral, install-scoped, no OAuth roundtrip.
              // Backend endpoint still supported it the whole time
              // (see backend/app/api/v1/auth.py:14).
              TextButton(
                onPressed: _busy ? null : _signInDemo,
                child: Text(l.loginContinueDemo),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: t.bodySmall?.copyWith(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              const Spacer(),
              Text(
                l.loginTerms,
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space20, vertical: Tokens.space16,
          ),
        ),
      ),
    );
  }
}

// _DemoInput + _DemoLoginDialog removed 2026-08-30 with the
// demo login path. See comment near the removed button above.
