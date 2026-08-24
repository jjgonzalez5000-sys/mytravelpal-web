import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Compact popup menu that cycles through System / Light / Dark. Uses the
/// active mode's icon so users see at a glance which mode is on.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  IconData _iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  String _labelFor(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme: ${_labelFor(mode)}',
      icon: Icon(_iconFor(mode)),
      position: PopupMenuPosition.under,
      onSelected: (m) => ref.read(themeModeProvider.notifier).set(m),
      itemBuilder: (context) => [
        for (final m in ThemeMode.values)
          PopupMenuItem<ThemeMode>(
            value: m,
            child: Row(
              children: [
                Icon(_iconFor(m), size: 18),
                const SizedBox(width: 12),
                Text(_labelFor(m)),
                if (m == mode) ...[
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
