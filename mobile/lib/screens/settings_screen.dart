import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../domain/units.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/app_tutorial.dart';
import '../services/biometric_auth.dart';
import '../services/currency_service.dart';
import '../storage/app_prefs.dart';
import '../theme.dart';
import 'attributions_screen.dart';
import 'inspire_history_screen.dart';
import 'emergency_contacts_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Single home for all persistent user preferences.
///
/// Two things live here today: **language** (moved from an AppBar
/// popup) and **unit system** (metric / imperial). Sections for
/// notifications, connected accounts, and data controls slot in as
/// separate `_SettingsSection`s without touching this shell.
///
/// Also hosts the two GDPR-required user actions:
/// - "Descargar mis datos" (portability): fetches the server-side
///   JSON dump and hands it to the platform share sheet.
/// - "Borrar mi cuenta" (right-to-erasure): DELETE /v1/profile
///   which cascades to saved_trips, then signs the user out.
/// Play Store requires both to be reachable from within the app
/// since 2024, and GDPR requires both regardless of platform.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final localeOverride = ref.watch(localeOverrideProvider);
    final unitSystem = ref.watch(unitSystemProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space16),
        children: [
          _Section(title: l.settingsSectionAppearance),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.settingsLanguage),
            subtitle: Text(_localeLabel(l, localeOverride)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLocale(context, ref, current: localeOverride),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l.settingsTheme),
            subtitle: Text(_themeLabel(l, mode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, ref, current: mode),
          ),
          // Colour preset picker — three swatch chips. Ignored
          // when Material You (below) is on AND the device is
          // Android 12+, but the chips stay tappable so the user
          // knows what will apply if they disable dynamic colour.
          const _ColorPresetPicker(),
          Consumer(builder: (context, ref, _) {
            final enabled = ref.watch(themeDynamicProvider);
            return SwitchListTile.adaptive(
              secondary: const Icon(Icons.palette_outlined),
              title: Text(l.settingsDynamicColor),
              subtitle: Text(l.settingsDynamicColorSub),
              value: enabled,
              onChanged: (v) =>
                  ref.read(themeDynamicProvider.notifier).set(v),
            );
          }),
          Consumer(builder: (context, ref, _) {
            final enabled = ref.watch(themeOledProvider);
            return SwitchListTile.adaptive(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: Text(l.settingsOled),
              subtitle: Text(l.settingsOledSub),
              value: enabled,
              onChanged: (v) =>
                  ref.read(themeOledProvider.notifier).set(v),
            );
          }),
          const _DensityPicker(),
          const Divider(height: Tokens.space32),
          _Section(title: l.settingsSectionUnits),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: Tokens.space16),
            child: SegmentedButton<UnitSystem>(
              segments: [
                ButtonSegment(
                  value: UnitSystem.metric,
                  label: Text(l.settingsUnitsMetric),
                  icon: const Text('km · L'),
                ),
                ButtonSegment(
                  value: UnitSystem.imperial,
                  label: Text(l.settingsUnitsImperial),
                  icon: const Text('mi · gal'),
                ),
              ],
              selected: {unitSystem},
              onSelectionChanged: (s) =>
                  ref.read(unitSystemProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: Tokens.space16),
          Consumer(builder: (context, ref, _) {
            final currency = ref.watch(currencyCodeProvider);
            return ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: Text(l.settingsCurrency),
              subtitle: Text(currencyLabel(currency)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickCurrency(context, ref, current: currency),
            );
          }),
          const Divider(height: Tokens.space32),
          _Section(title: l.settingsSectionTrip),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l.profileTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.contact_emergency_outlined),
            title: Text(l.emergencyContactsTitle),
            subtitle: Text(l.emergencyContactsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyContactsScreen(),
              ),
            ),
          ),
          const _BiometricTile(),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: Text(l.settingsMyAiPlans),
            subtitle: Text(l.settingsMyAiPlansSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const InspireHistoryScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(l.settingsReplayTutorial),
            subtitle: Text(l.settingsReplayTutorialSub),
            trailing: const Icon(Icons.replay),
            onTap: () async {
              await resetTutorials();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.settingsReplayTutorialToast)),
              );
            },
          ),
          const Divider(height: Tokens.space32),
          // Data controls — GDPR-required entry points to
          // "download my data" + "delete my account". Both hit
          // the profile endpoints on the backend and, for delete,
          // sign the user out locally regardless of network
          // outcome so the local state matches user intent.
          _Section(title: l.settingsSectionData),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l.settingsExportData),
            subtitle: Text(l.settingsExportDataSub),
            onTap: () => _exportData(context, ref),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l.settingsDeleteAccount,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            subtitle: Text(l.settingsDeleteAccountSub),
            onTap: () => _deleteAccount(context, ref),
          ),
          const Divider(height: Tokens.space32),
          _Section(title: l.settingsSectionAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.settingsVersion),
            subtitle: const Text('0.1.0 · MVP'),
          ),
          // Privacy Policy + Terms + Support links. Play Store
          // review requires all three to be reachable from within
          // the app. Hosted on Cloudflare Pages at mytravelpal.io.
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.settingsPrivacyPolicy),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('https://mytravelpal.io/privacy.html'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l.settingsTerms),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('https://mytravelpal.io/terms.html'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l.settingsSupport),
            subtitle: const Text('support@mytravelpal.io'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('https://mytravelpal.io/support.html'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.balance),
            title: Text(l.settingsLicensesAndData),
            subtitle: Text(l.settingsLicensesAndDataSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AttributionsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _localeLabel(AppLocalizations l, Locale? locale) {
    if (locale == null) return l.localeSystem;
    return switch (locale.languageCode) {
      'en' => 'English',
      'es' => 'Español',
      'fr' => 'Français',
      'it' => 'Italiano',
      'de' => 'Deutsch',
      'pt' => 'Português',
      'ca' => 'Català',
      _ => locale.languageCode.toUpperCase(),
    };
  }

  String _themeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
        ThemeMode.system => l.localeSystem,
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(apiClientWithPremiumProvider);
    final data = await api.exportProfile();
    if (data == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.settingsExportError)),
      );
      return;
    }
    // Pretty-print so a human opening the shared JSON in Notes /
    // email / drive can read it. Even at ~50 trips this stays
    // well under 100 KB — small enough for the platform share
    // sheet without a temp file.
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    await Share.share(pretty, subject: 'MyTravelPal — my data');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    // Two-step confirmation for a destructive action — losing
    // saved trips to a fat-finger is a bad first impression.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.settingsDeleteAccountConfirmTitle),
        content: Text(l.settingsDeleteAccountConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.settingsDeleteAccountCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.settingsDeleteAccountConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(apiClientWithPremiumProvider);
    final tripStorage = ref.read(tripStorageProvider);
    final prefs = ref.read(appPrefsProvider);

    // Non-modal progress dialog — the delete round-trip is a
    // single ~500 ms request but on a bad network it can take
    // a couple of seconds and the user shouldn't be able to
    // re-tap the row in the meantime.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeletingAccountDialog(),
    );

    // Fire the server delete BEFORE the local sign-out so we
    // still have the JWT to authenticate the request. Sign out
    // + wipe local state afterwards regardless of the server
    // outcome — the user's intent was to erase, so at minimum
    // local state should reflect that.
    final ok = await api.deleteAccount();
    // Wipe user-scoped local data (auth, trip profile, saved
    // trips, favourites, recents, emergency contacts). Locale,
    // theme, unit system, currency and density are preserved
    // so a fresh account on the same device doesn't have to
    // re-pick them.
    await tripStorage.clear();
    await prefs.clearUserScoped();
    await ref.read(authProvider.notifier).signOut();

    if (!context.mounted) return;
    // Dismiss the progress dialog before navigating.
    Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l.settingsDeleteAccountDone
              : l.settingsDeleteAccountPartial,
        ),
      ),
    );
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref, {
    required String current,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final code in supportedCurrencyCodes)
              ListTile(
                leading: Icon(
                  code == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(currencyLabel(code)),
                onTap: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(currencyCodeProvider.notifier).set(selected);
    }
  }

  Future<void> _pickLocale(
    BuildContext context,
    WidgetRef ref, {
    required Locale? current,
  }) async {
    final l = AppLocalizations.of(context);
    const options = <Locale?>[
      null,
      Locale('en'), Locale('es'), Locale('fr'),
      Locale('it'), Locale('de'),
      // Added 2026-08-30. Portuguese: full mainland Portugal +
      // Brazil-adjacent. Catalan: Catalunya, Balears, Valencia,
      // Andorra. Both start with the essential ~60 strings
      // translated; the rest fall back to English gracefully.
      Locale('pt'), Locale('ca'),
    ];
    final selected = await showModalBottomSheet<Locale?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              ListTile(
                leading: Icon(
                  (opt?.languageCode ?? '_system') ==
                          (current?.languageCode ?? '_system')
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(_localeLabel(l, opt)),
                onTap: () => Navigator.of(context).pop(opt),
              ),
          ],
        ),
      ),
    );
    if (selected != null || current != null) {
      await ref.read(localeOverrideProvider.notifier).set(selected);
    }
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref, {
    required ThemeMode current,
  }) async {
    final l = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in ThemeMode.values)
              ListTile(
                leading: Icon(
                  m == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(_themeLabel(l, m)),
                onTap: () => Navigator.of(context).pop(m),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(themeModeProvider.notifier).set(selected);
    }
  }
}

/// Biometric unlock toggle — async because both the "supported"
/// probe and the "currently enabled" flag come from the plugin /
/// SharedPreferences. Renders a disabled tile with an explanatory
/// subtitle when the device lacks the hardware or the user
/// removed all enrolled biometrics.
class _BiometricTile extends StatefulWidget {
  const _BiometricTile();

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  bool? _available;
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final bio = BiometricService.instance;
    final available = await bio.isAvailable;
    final enabled = available ? await bio.isEnabled : false;
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
    });
  }

  Future<void> _toggle(bool value) async {
    final bio = BiometricService.instance;
    if (value) {
      final l = AppLocalizations.of(context);
      final ok = await bio.authenticate(reason: l.biometricPromptSettings);
      if (!ok) return;
    }
    await bio.setEnabled(value);
    if (!mounted) return;
    setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final available = _available;
    final enabled = _enabled ?? false;
    if (available == null) {
      return ListTile(
        leading: const Icon(Icons.fingerprint),
        title: Text(l.settingsBiometric),
        trailing: const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (!available) {
      return ListTile(
        leading: const Icon(Icons.fingerprint),
        title: Text(l.settingsBiometric),
        subtitle: Text(l.settingsBiometricUnavailable),
        enabled: false,
      );
    }
    return SwitchListTile.adaptive(
      secondary: const Icon(Icons.fingerprint),
      title: Text(l.settingsBiometric),
      subtitle: Text(l.settingsBiometricSub),
      value: enabled,
      onChanged: _toggle,
    );
  }
}

/// Three swatch chips (Forest / Sunset / Ocean). Tapping a chip
/// updates [themePresetProvider] which the app rebuilds against
/// via `AppTheme.buildLight/buildDark`.
class _ColorPresetPicker extends ConsumerWidget {
  const _ColorPresetPicker();

  String _labelFor(AppLocalizations l, ThemePreset p) => switch (p) {
        ThemePreset.forest => l.settingsPresetForest,
        ThemePreset.sunset => l.settingsPresetSunset,
        ThemePreset.ocean => l.settingsPresetOcean,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(themePresetProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16, vertical: Tokens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            child: Row(
              children: [
                Icon(Icons.color_lens_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: Tokens.space12),
                Text(
                  l.settingsColorPreset,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in ThemePreset.values)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: p.seed, radius: 10),
                  label: Text(_labelFor(l, p)),
                  selected: current == p,
                  onSelected: (v) {
                    if (v) ref.read(themePresetProvider.notifier).set(p);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two-segment picker for global UI density. Wired to
/// [uiDensityProvider] — flips `visualDensity`, card margins,
/// chip padding, and body-text scale across the whole app.
class _DensityPicker extends ConsumerWidget {
  const _DensityPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(uiDensityProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16, vertical: Tokens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            child: Row(
              children: [
                Icon(Icons.density_medium,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: Tokens.space12),
                Text(
                  l.settingsDensityLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          SegmentedButton<UiDensity>(
            segments: [
              ButtonSegment(
                value: UiDensity.comfortable,
                label: Text(l.settingsDensityComfortable),
                icon: const Icon(Icons.density_large),
              ),
              ButtonSegment(
                value: UiDensity.compact,
                label: Text(l.settingsDensityCompact),
                icon: const Icon(Icons.density_small),
              ),
            ],
            selected: {current},
            onSelectionChanged: (s) =>
                ref.read(uiDensityProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space16, Tokens.space16, Tokens.space16, Tokens.space4,
        ),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

/// Non-dismissible progress dialog shown while the delete-account
/// request is in flight. Uses [PopScope] to also swallow the
/// system back gesture — cancelling mid-delete would leave state
/// half-wiped and confuse the user.
class _DeletingAccountDialog extends StatelessWidget {
  const _DeletingAccountDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: Tokens.space16),
            Expanded(
              child: Text(l.settingsDeleteAccountInProgress),
            ),
          ],
        ),
      ),
    );
  }
}
