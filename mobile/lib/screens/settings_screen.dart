import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart' show rootNavigatorKey;
import '../config/beta_access.dart';
import '../design/tokens.dart';
import '../domain/units.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ai_learning_bar.dart';
import '../widgets/feedback_sheet.dart';
import '../providers.dart';
import '../services/app_tutorial.dart';
import '../services/biometric_auth.dart';
import '../services/currency_service.dart';
import '../storage/app_prefs.dart';
import '../theme.dart';
import 'attributions_screen.dart';
import 'inspire_history_screen.dart';
import 'emergency_contacts_screen.dart';
import 'garage_screen.dart';
import 'my_places_screen.dart';
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
      appBar: AppBar(
        title: Text(l.settingsTitle),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A1628).withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: Tokens.space8, bottom: Tokens.space32,
        ),
        children: [
          // ── Tier de acceso (dev / closed beta) ───────────────
          // Closed beta only: lets a tester pick the tier. A production
          // build (BETA_ACCESS=false) must not offer a free upgrade.
          if (kBetaAccess) const _PremiumTierToggle(),
          // ── AI learning bar ──────────────────────────────────
          const AiLearningBar(),
          // ── Vehículo y ruta ──────────────────────────────────
          _CollapsibleSection(
            title: l.settingsSectionVehicle,
            icon: Icons.directions_car_outlined,
            tiles: [
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
              // Multi-vehicle "garage". Shows a live count from the
              // provider so the row hints how many cars the user has
              // saved and, when there's at least one, the first
              // vehicle's friendly name as a preview.
              Consumer(
                builder: (context, ref, _) {
                  final garage = ref.watch(garageProvider);
                  final subtitle = garage.isEmpty
                      ? l.garageEmpty
                      : garage
                          .take(2)
                          .map((v) => v.name)
                          .join(' · ');
                  return ListTile(
                    leading: const Icon(Icons.garage_outlined),
                    title: Text(l.garageSettingsRow(garage.length)),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GarageScreen(),
                      ),
                    ),
                  );
                },
              ),
              // Saved stops: places worth pulling over for, offered when a
              // route passes near them.
              Consumer(
                builder: (context, ref, _) {
                  final places = ref.watch(myPlacesProvider);
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(l.myPlacesSettingsRow(places.length)),
                    subtitle: Text(
                      l.myPlacesSettingsSub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyPlacesScreen(),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(Tokens.space16),
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
                  onSelectionChanged: (s) {
                    ref.read(unitSystemProvider.notifier).set(s.first);
                    ref.read(tripProfileProvider.notifier).pushSettingsChange();
                  },
                ),
              ),
              Consumer(builder: (context, ref, _) {
                final currency = ref.watch(currencyCodeProvider);
                return ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: Text(l.settingsCurrency),
                  subtitle: Text(currencyLabel(currency)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _pickCurrency(context, ref, current: currency),
                );
              }),
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
                    SnackBar(
                        content: Text(l.settingsReplayTutorialToast)),
                  );
                },
              ),
            ],
          ),
          // ── Apariencia ───────────────────────────────────────
          _CollapsibleSection(
            title: l.settingsSectionAppearance,
            icon: Icons.palette_outlined,
            tiles: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l.settingsLanguage),
                subtitle: Text(_localeLabel(l, localeOverride)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _pickLocale(context, ref, current: localeOverride),
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
            ],
          ),
          // ── Personalización IA ───────────────────────────────
          _CollapsibleSection(
            title: l.settingsSectionAI,
            icon: Icons.psychology_outlined,
            tiles: const [_AiPersonalisationSection()],
            initiallyExpanded: false,
          ),
          // ── Contactos y seguridad ────────────────────────────
          _CollapsibleSection(
            title: l.settingsSectionSafety,
            icon: Icons.shield_outlined,
            tiles: [
              // Hall of Fame — nick + country flag for the ranking.
              const _HallOfFameSection(),
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
              Consumer(
                builder: (context, ref, _) => SwitchListTile.adaptive(
                  secondary: const Icon(Icons.speed),
                  title: Text(l.settingsRadarAlerts),
                  subtitle: Text(l.settingsRadarAlertsSubtitle),
                  value: ref.watch(radarAlertsEnabledProvider),
                  onChanged: (v) =>
                      ref.read(radarAlertsEnabledProvider.notifier).state =
                          v,
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final sound = ref.watch(notifSoundProvider);
                  final label = switch (sound) {
                    'silent' => l.notifSoundSilent,
                    _ => l.notifSoundDefault,
                  };
                  return ListTile(
                    leading: Icon(sound == 'silent'
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined),
                    title: Text(l.notifSoundTitle),
                    subtitle: Text(label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickNotifSound(context, ref, current: sound),
                  );
                },
              ),
            ],
            initiallyExpanded: false,
          ),
          // ── Cuenta ───────────────────────────────────────────
          // Data controls — GDPR-required entry points to
          // "download my data" + "delete my account". Both hit
          // the profile endpoints on the backend and, for delete,
          // sign the user out locally regardless of network
          // outcome so the local state matches user intent.
          _CollapsibleSection(
            title: l.settingsSectionAccount,
            icon: Icons.manage_accounts_outlined,
            tiles: [
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
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(l.settingsSendFeedback),
                subtitle: Text(l.settingsSendFeedbackSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showFeedbackSheet(context),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l.settingsVersion),
                subtitle: const Text(
                  // Injected at build time via --dart-define=APP_VERSION=…
                  // Falls back to the pubspec version baked in at compile
                  // time.
                  String.fromEnvironment(
                      'APP_VERSION', defaultValue: '0.2.48'),
                ),
              ),
              // Privacy Policy + Terms + Support links. Play Store
              // review requires all three reachable from within the app.
              // Hosted on Cloudflare Pages at mytravelpal.io.
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
            initiallyExpanded: false,
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
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.settingsDeleteAccountConfirmTitle),
        content: Text(l.settingsDeleteAccountConfirmBody),
        actions: [
          TextButton(
            // Use the DIALOG's context here — the outer `context` is
            // SettingsScreen's, so Navigator.of(context).pop() would
            // pop Settings off the tab navigator instead of closing
            // the dialog (which lives on the root nav). Result: dialog
            // stays visible, Settings goes away, user sees main tabs.
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.settingsDeleteAccountCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.settingsDeleteAccountConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final api = ref.read(apiClientWithPremiumProvider);
    final tripStorage = ref.read(tripStorageProvider);
    final prefs = ref.read(appPrefsProvider);
    final rootNav = rootNavigatorKey.currentState;
    if (rootNav == null) return;

    // Live status so the user sees which step is running. If the
    // dialog "stays forever", the caption pinpoints the culprit.
    final status = ValueNotifier<String>('1/4 · Contactando servidor…');
    unawaited(rootNav.push<void>(
      DialogRoute<void>(
        context: rootNav.context,
        barrierDismissible: false,
        builder: (_) => _DeletingAccountDialog(status: status),
      ),
    ));

    bool ok = false;
    try {
      ok = await api.deleteAccount();
    } catch (_) {
      ok = false;
    }
    status.value = '2/4 · Borrando datos locales…';
    try { await tripStorage.clear(); } catch (_) {}
    try { await prefs.clearUserScoped(); } catch (_) {}
    status.value = l.settingsLogoutStep3;
    try { await ref.read(authProvider.notifier).signOut(); } catch (_) {}
    status.value = l.settingsLogoutStep4;

    if (rootNav.canPop()) rootNav.pop();
    await rootNav.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _pickNotifSound(
    BuildContext context,
    WidgetRef ref, {
    required String current,
  }) async {
    final l = AppLocalizations.of(context);
    const options = ['default', 'silent'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              ListTile(
                leading: Icon(
                  opt == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(opt == 'silent'
                    ? l.notifSoundSilent
                    : l.notifSoundDefault),
                subtitle: Text(opt == 'silent'
                    ? l.notifSoundSilentSub
                    : l.notifSoundDefaultSub),
                onTap: () => Navigator.of(context).pop(opt),
              ),
          ],
        ),
      ),
    );
    if (selected != null && selected != current) {
      await ref.read(notifSoundProvider.notifier).set(selected);
    }
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
      ref.read(tripProfileProvider.notifier).pushSettingsChange();
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
      ref.read(tripProfileProvider.notifier).pushSettingsChange();
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
      ref.read(tripProfileProvider.notifier).pushSettingsChange();
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
            onSelectionChanged: (s) {
              ref.read(uiDensityProvider.notifier).set(s.first);
              ref.read(tripProfileProvider.notifier).pushSettingsChange();
            },
          ),
        ],
      ),
    );
  }
}

/// Groups a list of tiles into a single rounded card with subtle separators.
/// In dark mode the border is a barely-visible white shimmer; in light mode
/// it follows the scheme's outlineVariant.
class _TileCard extends StatelessWidget {
  const _TileCard({required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final children = <Widget>[];
    for (int i = 0; i < tiles.length; i++) {
      children.add(tiles[i]);
      if (i < tiles.length - 1) {
        children.add(Divider(
          height: 1,
          thickness: 0.5,
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          indent: Tokens.space16,
          endIndent: Tokens.space16,
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16,
        vertical: Tokens.space4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFFFFFFF).withValues(alpha: 0.05)
                  : scheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Combines a section header with a collapsible tile-card body.
/// Tapping the header row toggles the card. All sections start
/// expanded so the settings look familiar on first open; the
/// collapsed state is ephemeral (not persisted).
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.tiles,
    this.initiallyExpanded = true,
  });

  final String title;
  final IconData icon;
  final List<Widget> tiles;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.initiallyExpanded ? 1.0 : 0.0,
    );
    _rotation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space16, Tokens.space20, Tokens.space16, Tokens.space8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 16, color: scheme.tertiary),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.tertiary,
                    ),
                  ),
                ),
                RotationTransition(
                  turns: _rotation,
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: scheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            child: _TileCard(tiles: widget.tiles),
          ),
      ],
    );
  }
}

// --------------- AI Personalisation section ---------------

/// Renders the AI Personalisation preference block inside Settings.
/// Each change is fire-and-forget PUT to /v1/profile/learning so the
/// companion AI accumulates context about the user's preferences.
class _AiPersonalisationSection extends ConsumerStatefulWidget {
  const _AiPersonalisationSection();

  @override
  ConsumerState<_AiPersonalisationSection> createState() =>
      _AiPersonalisationSectionState();
}

class _AiPersonalisationSectionState
    extends ConsumerState<_AiPersonalisationSection> {
  // Loaded from server on first build; nil until loaded.
  Map<String, dynamic>? _learning;

  static const _dietOptions = [
    'vegetarian',
    'vegan',
    'gluten-free',
    'halal',
  ];
  static const _interestOptions = [
    'culture',
    'nature',
    'gastronomy',
    'shopping',
    'adventure',
  ];

  String _dietLabel(String key, AppLocalizations l) => switch (key) {
        'vegetarian' => l.aiDietVegetarian,
        'vegan'      => l.aiDietVegan,
        'gluten-free'=> l.aiDietGlutenFree,
        'halal'      => l.aiDietHalal,
        _            => key,
      };

  String _interestLabel(String key, AppLocalizations l) => switch (key) {
        'culture'     => l.aiInterestCulture,
        'nature'      => l.aiInterestNature,
        'gastronomy'  => l.aiInterestGastronomy,
        'shopping'    => l.aiInterestShopping,
        'adventure'   => l.aiInterestAdventure,
        _             => key,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientWithPremiumProvider);
    final data = await api.getUserLearning();
    if (mounted) setState(() => _learning = data);
  }

  Future<void> _save(Map<String, dynamic> updated) async {
    setState(() => _learning = updated);
    // Fire-and-forget — UserLearningTracker wraps the PUT.
    final api = ref.read(apiClientWithPremiumProvider);
    unawaited(api.putUserLearning(updated));
  }

  bool _getBool(String key) =>
      (_learning?[key] as bool?) ?? false;

  int _getInt(String key, int fallback) =>
      (_learning?[key] as int?) ?? fallback;

  List<String> _getList(String key) =>
      List<String>.from(_learning?[key] as List? ?? []);

  Map<String, dynamic> _copy() =>
      Map<String, dynamic>.from(_learning ?? {});

  @override
  Widget build(BuildContext context) {
    if (_learning == null) {
      return const Padding(
        padding: EdgeInsets.all(Tokens.space16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final dietary = _getList('dietary_restrictions');
    final interests = _getList('interests');
    final departureHour = _getInt('typical_departure_hour', 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.landscape_outlined),
          title: Text(l.aiPrefScenicRoutes),
          subtitle: Text(l.aiPrefScenicRoutesSub),
          value: _getBool('prefers_scenic_routes'),
          onChanged: (v) {
            final u = _copy();
            u['prefers_scenic_routes'] = v;
            _save(u);
          },
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.eco_outlined),
          title: Text(l.aiPrefEcoConscious),
          subtitle: Text(l.aiPrefEcoConsciousSub),
          value: _getBool('eco_conscious'),
          onChanged: (v) {
            final u = _copy();
            u['eco_conscious'] = v;
            _save(u);
          },
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.restaurant_outlined),
          title: Text(l.aiPrefLocalFood),
          subtitle: Text(l.aiPrefLocalFoodSub),
          value: _getBool('interested_in_local_food'),
          onChanged: (v) {
            final u = _copy();
            u['interested_in_local_food'] = v;
            _save(u);
          },
        ),
        // Typical departure hour
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space16,
            vertical: Tokens.space8,
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 20),
              const SizedBox(width: Tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.aiPrefDepartureHour),
                    Text(
                      '${departureHour.toString().padLeft(2, '0')}:00',
                      style: t.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButton<int>(
                value: departureHour.clamp(6, 12),
                items: [
                  for (int h = 6; h <= 12; h++)
                    DropdownMenuItem(
                      value: h,
                      child: Text(
                          '${h.toString().padLeft(2, '0')}:00'),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  final u = _copy();
                  u['typical_departure_hour'] = v;
                  _save(u);
                },
              ),
            ],
          ),
        ),
        // Dietary restrictions chips
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space16, Tokens.space8, Tokens.space16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.aiPrefDietary,
                style: t.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Tokens.space8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dietOptions.map((opt) {
                  final selected = dietary.contains(opt);
                  return FilterChip(
                    label: Text(_dietLabel(opt, l)),
                    selected: selected,
                    onSelected: (v) {
                      final u = _copy();
                      final list = _getList('dietary_restrictions');
                      if (v) {
                        list.add(opt);
                      } else {
                        list.remove(opt);
                      }
                      u['dietary_restrictions'] = list;
                      _save(u);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space12),
        // Interests chips
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space16, 0, Tokens.space16, Tokens.space8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.aiPrefInterests,
                style: t.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Tokens.space8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interestOptions.map((opt) {
                  final selected = interests.contains(opt);
                  return FilterChip(
                    label: Text(_interestLabel(opt, l)),
                    selected: selected,
                    onSelected: (v) {
                      final u = _copy();
                      final list = _getList('interests');
                      if (v) {
                        list.add(opt);
                      } else {
                        list.remove(opt);
                      }
                      u['interests'] = list;
                      _save(u);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------- End AI Personalisation section ---------------

/// Non-dismissible progress dialog shown while the delete-account
/// request is in flight. Uses [PopScope] to also swallow the
/// system back gesture — cancelling mid-delete would leave state
/// half-wiped and confuse the user.
/// Loading dialog with a live status line so we can see at which
/// step the delete flow hangs (backend call vs local wipe vs
/// navigation) when the user reports "dialog stays forever".
class _DeletingAccountDialog extends StatelessWidget {
  const _DeletingAccountDialog({required this.status});
  final ValueNotifier<String> status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<String>(
          valueListenable: status,
          builder: (_, s, __) => Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: Tokens.space16),
              Expanded(
                child: Text(
                  s.isEmpty ? l.settingsDeleteAccountInProgress : s,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hall of Fame section — nick + country flag for the leaderboard.
// ---------------------------------------------------------------------------

class _HallOfFameSection extends ConsumerStatefulWidget {
  const _HallOfFameSection();

  @override
  ConsumerState<_HallOfFameSection> createState() => _HallOfFameSectionState();
}

class _HallOfFameSectionState extends ConsumerState<_HallOfFameSection> {
  late TextEditingController _nickCtrl;
  bool _saving = false;
  // null = unknown / not checked yet; true = available; false = taken
  bool? _nickAvailable;
  bool _checkingNick = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appPrefsProvider);
    _nickCtrl = TextEditingController(text: prefs.hallNick ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nickCtrl.dispose();
    super.dispose();
  }

  void _onNickChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _nickAvailable = null;
        _checkingNick = false;
      });
      return;
    }
    setState(() {
      _nickAvailable = null;
      _checkingNick = true;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final auth = ref.read(authProvider);
      if (auth.token == null) {
        if (mounted) setState(() => _checkingNick = false);
        return;
      }
      final api = ref.read(apiClientWithPremiumProvider);
      final available = await api.checkNickAvailable(trimmed);
      if (!mounted) return;
      setState(() {
        _nickAvailable = available;
        _checkingNick = false;
      });
    });
  }

  Future<void> _save() async {
    final prefs = ref.read(appPrefsProvider);
    setState(() => _saving = true);
    await prefs.setHallNick(_nickCtrl.text.trim());
    // Sync to backend so the nick survives reinstall + re-login.
    ref.read(tripProfileProvider.notifier).pushSettingsChange();
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nick guardado'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPrefsProvider);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final selectedCountry = prefs.hallCountry;

    // Nick field suffix: spinner / check / error based on availability state
    Widget? nickSuffix;
    String? nickHelperText;
    Color? nickHelperColor;
    if (_checkingNick) {
      nickSuffix = const SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_nickAvailable == true) {
      nickSuffix = Icon(Icons.check_circle_outline,
          color: scheme.primary, size: 20);
      nickHelperText = 'Disponible';
      nickHelperColor = scheme.primary;
    } else if (_nickAvailable == false) {
      nickSuffix = Icon(Icons.cancel_outlined,
          color: scheme.error, size: 20);
      nickHelperText = l.settingsNickTaken;
      nickHelperColor = scheme.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space16, vertical: Tokens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.settingsNickHelper,
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country picker button
              InkWell(
                onTap: () => _pickCountry(context, prefs),
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Center(
                    child: selectedCountry != null
                        ? Text(
                            _countryFlag(selectedCountry),
                            style: const TextStyle(fontSize: 28),
                          )
                        : Icon(Icons.flag_outlined,
                            color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: Tokens.space12),
              // Nick text field with availability indicator
              Expanded(
                child: TextField(
                  controller: _nickCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nick',
                    hintText: 'RoadWarrior42',
                    border: const OutlineInputBorder(),
                    counterText: '',
                    suffixIcon: nickSuffix != null
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: nickSuffix,
                          )
                        : null,
                    helperText: nickHelperText,
                    helperStyle: nickHelperColor != null
                        ? TextStyle(color: nickHelperColor)
                        : null,
                  ),
                  maxLength: 20,
                  textInputAction: TextInputAction.done,
                  onChanged: _onNickChanged,
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: Tokens.space8),
              // Save button — disabled while checking or when nick is taken
              FilledButton(
                onPressed: (_saving || _checkingNick || _nickAvailable == false)
                    ? null
                    : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  padding: EdgeInsets.zero,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
              ),
            ],
          ),
          if (selectedCountry != null || _nickCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Tokens.space8),
              child: Row(
                children: [
                  if (selectedCountry != null)
                    Text(
                      _countryFlag(selectedCountry),
                      style: const TextStyle(fontSize: 16),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _nickCtrl.text.isEmpty
                        ? l.settingsNickEmpty
                        : _nickCtrl.text,
                    style: t.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCountry(BuildContext context, AppPrefs prefs) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (result != null) {
      await prefs.setHallCountry(result);
      // Sync to backend so the country survives reinstall + re-login.
      ref.read(tripProfileProvider.notifier).pushSettingsChange();
      setState(() {});
    }
  }

  // ISO 3166-1 alpha-2 code → flag emoji (regional indicator symbols)
  static String _countryFlag(String code) {
    if (code.length != 2) return '🏳';
    final base = 0x1F1E6 - 0x41;
    return String.fromCharCodes([
      base + code.codeUnitAt(0),
      base + code.codeUnitAt(1),
    ]);
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  static const _eu = <(String, String)>[
    ('ES', 'España'),   ('FR', 'Francia'),   ('DE', 'Alemania'),
    ('IT', 'Italia'),   ('PT', 'Portugal'),  ('BE', 'Bélgica'),
    ('NL', 'Países Bajos'), ('AT', 'Austria'), ('CH', 'Suiza'),
    ('PL', 'Polonia'),  ('CZ', 'Chequia'),   ('SK', 'Eslovaquia'),
    ('HU', 'Hungría'),  ('RO', 'Rumanía'),   ('HR', 'Croacia'),
    ('SI', 'Eslovenia'),('GR', 'Grecia'),    ('SE', 'Suecia'),
    ('NO', 'Noruega'),  ('DK', 'Dinamarca'), ('FI', 'Finlandia'),
    ('GB', 'Reino Unido'), ('IE', 'Irlanda'),
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final filtered = _query.isEmpty
        ? _eu
        : _eu
            .where((e) =>
                e.$2.toLowerCase().contains(_query.toLowerCase()) ||
                e.$1.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Tokens.space12),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.settingsCountrySearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final (code, name) = filtered[i];
                final flag = _HallOfFameSectionState._countryFlag(code);
                return ListTile(
                  leading: Text(flag, style: const TextStyle(fontSize: 24)),
                  title: Text(name, style: t.bodyMedium),
                  onTap: () => Navigator.of(ctx).pop(code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Dev/beta tier selector — lets testers experience each subscription level.
/// Writes to [subscriptionTierProvider] which gates ALL premium features.
/// In production this is replaced by the Play Billing receipt check.
class _PremiumTierToggle extends ConsumerWidget {
  const _PremiumTierToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(subscriptionTierProvider);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    final tiers = [
      ('free', l.settingsTierFreeName, Icons.lock_outline),
      ('essential', 'Essential', Icons.star_half),
      ('premium', 'Premium', Icons.star_rounded),
    ];

    Color tierColor(String t) => switch (t) {
      'premium' => const Color(0xFFF59E0B),
      'essential' => const Color(0xFF60A5FA),
      _ => scheme.onSurfaceVariant,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tierColor(tier).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tierColor(tier).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 14,
                  color: tierColor(tier)),
              const SizedBox(width: 6),
              Text(
                l.settingsBetaAccess,
                style: TextStyle(
                  color: tierColor(tier),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                l.settingsPremiumDevNote,
                style: t.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (value, label, icon) in tiers)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => applySubscriptionTier(ref, value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8),
                        decoration: BoxDecoration(
                          color: tier == value
                              ? tierColor(value).withValues(alpha: 0.2)
                              : scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: tier == value
                                ? tierColor(value).withValues(alpha: 0.7)
                                : scheme.outlineVariant,
                            width: tier == value ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(icon,
                                size: 18,
                                color: tier == value
                                    ? tierColor(value)
                                    : scheme.onSurfaceVariant),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: tier == value
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: tier == value
                                    ? tierColor(value)
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _tierDescription(tier, l),
            style: t.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _tierDescription(String tier, AppLocalizations l) => switch (tier) {
    'premium' => l.settingsTierFeaturesPremium,
    'essential' => l.settingsTierFeaturesEssential,
    _ => l.settingsTierFeaturesFree,
  };
}
