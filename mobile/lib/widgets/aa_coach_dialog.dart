import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// One-time coach shown the FIRST time a user taps "Iniciar viaje"
/// on the result screen. Explains where MyTravelPal appears on the
/// Android Auto head unit (POI category, not the main Navigation
/// launcher) — which testers consistently missed on their first
/// drive.
///
/// A checkbox lets them dismiss forever. State persisted in
/// SharedPreferences under [kAaCoachSeen] — matches the naming
/// convention of other prefs written from Dart.
class AaCoachDialog extends StatefulWidget {
  const AaCoachDialog({super.key});

  static const String kAaCoachSeen = 'aaCoach.seen.v1';

  /// Show the coach only when the user hasn't opted out yet. Returns
  /// once the dialog is dismissed. Safe to await inline.
  static Future<void> maybeShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kAaCoachSeen) ?? false) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      // Not barrier-dismissible: the button click IS the "OK" that
      // stamps the seen flag. Barrier dismissal would leave the flag
      // unset and re-show the coach on the next open.
      barrierDismissible: false,
      builder: (_) => const AaCoachDialog(),
    );
  }

  @override
  State<AaCoachDialog> createState() => _AaCoachDialogState();
}

class _AaCoachDialogState extends State<AaCoachDialog> {
  bool _dontShowAgain = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(l.aaCoachTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _step(context, Icons.usb, l.aaCoachStep1),
            const SizedBox(height: Tokens.space12),
            _step(context, Icons.category_outlined, l.aaCoachStep2),
            const SizedBox(height: Tokens.space12),
            _step(context, Icons.play_circle_outline, l.aaCoachStep3),
            const SizedBox(height: Tokens.space16),
            Container(
              padding: const EdgeInsets.all(Tokens.space12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
              child: Text(
                l.aaCoachHint,
                style: t.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: Tokens.space8),
            CheckboxListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.aaCoachDontShowAgain,
                  style: t.bodySmall),
              value: _dontShowAgain,
              onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () async {
            if (_dontShowAgain) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AaCoachDialog.kAaCoachSeen, true);
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(l.aaCoachDone),
        ),
      ],
    );
  }

  Widget _step(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.primary, size: 22),
        const SizedBox(width: Tokens.space12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
