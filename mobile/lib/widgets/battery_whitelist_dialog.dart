import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// One-time nag that tells the user to whitelist MyTravelPal in the
/// system battery optimisation settings, and offers a direct link
/// there.
///
/// **Why this exists**: even with our Android foreground service,
/// aggressive vendor ROMs (MIUI, One UI, ColorOS, Realme) still
/// throttle background CPU / GPS after a few minutes of screen off
/// unless the app is explicitly on the "no restrictions" list.
/// Google's `POWER_USAGE_SUMMARY` intent takes the user to the
/// battery panel; on most ROMs there they see a "restricted / smart
/// / no restrictions" toggle for our app.
///
/// **When it fires**: once per install, at the moment the driver
/// taps "Iniciar viaje". A checkbox lets them dismiss forever.
class BatteryWhitelistDialog extends StatefulWidget {
  const BatteryWhitelistDialog({super.key});

  static const _kBatteryDialogSeen = 'batteryWhitelistDialog.seen.v1';

  /// Show the dialog only when the user hasn't opted out. Returns
  /// once dismissed. Safe to await inline.
  static Future<void> maybeShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kBatteryDialogSeen) ?? false) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BatteryWhitelistDialog(),
    );
  }

  @override
  State<BatteryWhitelistDialog> createState() =>
      _BatteryWhitelistDialogState();
}

class _BatteryWhitelistDialogState extends State<BatteryWhitelistDialog> {
  bool _dontShowAgain = true;

  Future<void> _openBatterySettings() async {
    // On Android there's no clean cross-vendor URL that lands the
    // user directly on our app's battery-optimisation toggle —
    // each ROM (MIUI, One UI, ColorOS) buries it in a different
    // menu tree. Best we can do without adding a native intent
    // dependency is open Google's "Save battery" help page in the
    // browser — it lists the vendor-specific paths and is the
    // canonical reference maintained by Google itself. The dialog
    // text already spells out the shortest generic path.
    try {
      await launchUrl(
        Uri.parse('https://support.google.com/android/answer/9079646'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Ignore — user has the on-screen instructions to follow
      // manually.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l.batteryWhitelistTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.batteryWhitelistBody, style: t.bodyMedium),
            const SizedBox(height: Tokens.space12),
            Container(
              padding: const EdgeInsets.all(Tokens.space12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
              child: Text(
                l.batteryWhitelistSteps,
                style: t.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: Tokens.space8),
            CheckboxListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.batteryWhitelistDontShowAgain,
                  style: t.bodySmall),
              value: _dontShowAgain,
              onChanged: (v) =>
                  setState(() => _dontShowAgain = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (_dontShowAgain) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(
                BatteryWhitelistDialog._kBatteryDialogSeen, true,
              );
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(l.batteryWhitelistLater),
        ),
        FilledButton.icon(
          onPressed: () async {
            // Capture navigator FIRST — analyzer flags any post-await
            // BuildContext use even when a `mounted` check is present.
            final nav = Navigator.of(context);
            if (_dontShowAgain) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(
                BatteryWhitelistDialog._kBatteryDialogSeen, true,
              );
            }
            await _openBatterySettings();
            nav.pop();
          },
          icon: const Icon(Icons.settings),
          label: Text(l.batteryWhitelistOpen),
        ),
      ],
    );
  }
}

