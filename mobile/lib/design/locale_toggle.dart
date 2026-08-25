import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';

/// Compact popup that switches between the supported UI locales.
/// `null` = follow the device's system locale.
class LocaleToggleButton extends ConsumerWidget {
  const LocaleToggleButton({super.key});

  /// Locales we ship translations for — must stay in sync with
  /// `AppLocalizations.supportedLocales`.
  static const _locales = <Locale?>[
    null,             // system
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('de'),
  ];

  String _labelFor(Locale? locale, AppLocalizations l) {
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

  String _flagFor(Locale? locale) => switch (locale?.languageCode) {
        null => '🌐',
        'en' => '🇬🇧',
        'es' => '🇪🇸',
        'fr' => '🇫🇷',
        'it' => '🇮🇹',
        'de' => '🇩🇪',
        _ => '🌐',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(localeOverrideProvider);
    return PopupMenuButton<Locale?>(
      tooltip: l.localeMenuTooltip,
      icon: const Icon(Icons.language),
      position: PopupMenuPosition.under,
      onSelected: (v) => ref.read(localeOverrideProvider.notifier).set(v),
      itemBuilder: (context) => [
        for (final locale in _locales)
          PopupMenuItem<Locale?>(
            value: locale,
            child: Row(
              children: [
                Text(_flagFor(locale), style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 12),
                Text(_labelFor(locale, l)),
                if ((locale?.languageCode ?? '_none') ==
                    (current?.languageCode ?? '_none')) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 16,
                      color: Theme.of(context).colorScheme.primary),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
