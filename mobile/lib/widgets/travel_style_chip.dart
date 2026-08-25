import 'package:flutter/material.dart';

import '../domain/travel_style_presets.dart';
import '../domain/trip_profile.dart';
import '../l10n/app_localizations.dart';

/// AppBar chip that shows the current travel-style preset (or "Custom")
/// and opens a lightweight bottom sheet to switch presets for this
/// trip only, without touching the saved profile.
///
/// Kept minimal (no vehicle/meal editing) so it's a 1-second gesture —
/// the full ProfileScreen is still the place for anything else.
class TravelStyleChip extends StatelessWidget {
  const TravelStyleChip({
    super.key,
    required this.activeProfile,
    required this.savedProfile,
    required this.isOverride,
    required this.onPresetPicked,
    required this.onClearOverride,
  });

  /// The profile being used for the next plan (override if any, else saved).
  final TripProfile activeProfile;
  final TripProfile? savedProfile;
  final bool isOverride;

  /// Called with a preset picked from the sheet. The caller decides
  /// whether to store it as `_overrideProfile` or in the global profile.
  final ValueChanged<TravelStylePreset> onPresetPicked;

  /// Called when the user picks "Use my saved profile" from the sheet.
  final VoidCallback onClearOverride;

  String _label(BuildContext c) {
    final l = AppLocalizations.of(c);
    final preset = TravelStylePreset.matching(activeProfile);
    if (preset == null) {
      return l.planStyleChipCustom(activeProfile.dailyDrivingCapHours);
    }
    final name = switch (preset) {
      TravelStylePreset.direct => l.stylePresetDirect,
      TravelStylePreset.balanced => l.stylePresetBalanced,
      TravelStylePreset.slow => l.stylePresetSlow,
    };
    return l.planStyleChip(name, activeProfile.dailyDrivingCapHours);
  }

  IconData _icon() =>
      TravelStylePreset.matching(activeProfile)?.icon ?? Icons.tune;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        avatar: Icon(_icon(), size: 16),
        label: Text(_label(context)),
        backgroundColor: isOverride
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHigh,
        side: BorderSide(color: scheme.outlineVariant),
        onPressed: () => _openSheet(context),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final active = TravelStylePreset.matching(activeProfile);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.planStyleOverrideTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  l.planStyleOverrideSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (final preset in TravelStylePreset.values)
                  _PresetTile(
                    preset: preset,
                    selected: preset == active,
                    onTap: () {
                      Navigator.of(context).pop();
                      onPresetPicked(preset);
                    },
                  ),
                if (isOverride && savedProfile != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore),
                    title: Text(l.planStyleUseSavedProfile),
                    onTap: () {
                      Navigator.of(context).pop();
                      onClearOverride();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final TravelStylePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = switch (preset) {
      TravelStylePreset.direct => l.stylePresetDirect,
      TravelStylePreset.balanced => l.stylePresetBalanced,
      TravelStylePreset.slow => l.stylePresetSlow,
    };
    final hint = switch (preset) {
      TravelStylePreset.direct => l.stylePresetDirectHint,
      TravelStylePreset.balanced => l.stylePresetBalancedHint,
      TravelStylePreset.slow => l.stylePresetSlowHint,
    };
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: selected ? scheme.primary : scheme.surfaceContainerHigh,
        child: Icon(
          preset.icon,
          color: selected ? scheme.onPrimary : scheme.onSurface,
        ),
      ),
      title: Row(
        children: [
          Text(name),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check, size: 16, color: scheme.primary),
          ],
        ],
      ),
      subtitle: Text(hint),
      onTap: onTap,
    );
  }
}
