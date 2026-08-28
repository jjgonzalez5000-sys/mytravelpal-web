import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api/api_client.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/biometric_auth.dart';
import 'plan_screen.dart';

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
        MaterialPageRoute<void>(builder: (_) => const PlanScreen()),
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

  Future<void> _signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null) {
        setState(() => _error = 'Apple returned no identity token');
        return;
      }
      // Apple only returns the name on the FIRST sign-in and as
      // separate fields (not inside the id_token). Forward it via the
      // demo_name channel so the backend picks it up.
      final firstLoginName = [
        credential.givenName ?? '',
        credential.familyName ?? '',
      ].where((s) => s.isNotEmpty).join(' ').trim();
      await _finish(
        'apple', token,
        demoName: firstLoginName.isEmpty ? null : firstLoginName,
      );
    } catch (e) {
      setState(() => _error =
          'Apple sign-in unavailable (needs iOS platform + APPLE_APP_ID): $e');
    }
  }

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

  Future<void> _signInDemo() async {
    final result = await showDialog<_DemoInput>(
      context: context,
      builder: (context) => const _DemoLoginDialog(),
    );
    if (result == null) return;
    await _finish(
      'demo',
      'demo-token',
      demoEmail: result.email,
      demoName: result.name,
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
              Text(l.appName, style: t.displayMedium)
                  .animate()
                  .fadeIn(duration: Tokens.motionBase)
                  .moveY(begin: 8, end: 0, curve: Tokens.curveOut),
              const SizedBox(height: Tokens.space8),
              Text(
                '${l.appTagline}.',
                style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              _OAuthButton(
                icon: Icons.apple,
                label: l.loginContinueApple,
                onPressed: _busy ? null : _signInWithApple,
              ),
              const SizedBox(height: Tokens.space12),
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
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Tokens.space12,
                    ),
                    child: Text(l.loginDivider, style: t.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: Tokens.space16),
              PrimaryCta(
                label: _busy ? l.loginBusy : l.loginContinueDemo,
                icon: _busy ? null : Icons.person_outline,
                loading: _busy,
                onPressed: _signInDemo,
              ),
              const SizedBox(height: Tokens.space16),
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

class _DemoInput {
  const _DemoInput(this.name, this.email);
  final String name;
  final String email;
}

class _DemoLoginDialog extends StatefulWidget {
  const _DemoLoginDialog();

  @override
  State<_DemoLoginDialog> createState() => _DemoLoginDialogState();
}

class _DemoLoginDialogState extends State<_DemoLoginDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Continue as demo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name (optional)'),
          ),
          const SizedBox(height: Tokens.space8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _DemoInput(_name.text.trim(), _email.text.trim()),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
