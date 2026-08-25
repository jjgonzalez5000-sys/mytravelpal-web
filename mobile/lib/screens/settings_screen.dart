import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../domain/units.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'attributions_screen.dart';
import 'profile_screen.dart';

/// Single home for all persistent user preferences.
///
/// Two things live here today: **language** (moved from an AppBar
/// popup) and **unit system** (metric / imperial). Sections for
/// notifications, connected accounts, and data controls slot in as
/// separate `_SettingsSection`s without touching this shell.
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
          const Divider(height: Tokens.space32),
          _Section(title: l.settingsSectionAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.settingsVersion),
            subtitle: const Text('0.1.0 · MVP'),
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
      _ => locale.languageCode.toUpperCase(),
    };
  }

  String _themeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
        ThemeMode.system => l.localeSystem,
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  Future<void> _pickLocale(
    BuildContext context,
    WidgetRef ref, {
    required Locale? current,
  }) async {
    final l = AppLocalizations.of(context);
    const options = <Locale?>[
      null, Locale('en'), Locale('es'), Locale('fr'),
      Locale('it'), Locale('de'),
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
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}
