import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../domain/vehicle_labels.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'companion_drive_screen.dart';
import 'passenger_companion_screen.dart';
import 'profile_screen.dart';

/// Companion tab: configure driving conditions → start tracking.
///
/// Phase A (MVP): rule-based engine. The config screen collects the
/// parameters the engine uses to trigger recommendations:
/// - Break interval (how often to suggest stops).
/// - Meal timing (from profile, but overridable here).
/// - Budget bias (economy / comfort / speed).
/// - Alerts on/off for each category.
///
/// Tapping "Start" enters CompanionDriveScreen (TODO) which runs
/// the foreground GPS service and renders recommendation cards.
class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> {
  // Break suggestions are OFF by default — the timer heuristic is
  // noisy and long-time drivers dismissed it in most sessions.
  // When the driver opts in, the slider + sub-options appear.
  bool _suggestBreak = false;
  bool _fatigueStopSuggestion = false;
  double _breakIntervalHours = 2.0;
  bool _alertCriticalAdverse = true;
  bool _alertWeather = true;
  bool _alertFuel = true;
  bool _alertBorder = true;
  bool _alertToll = true;
  bool _alertHotel = true;

  // Passenger join code input.
  final _joinCodeController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _joinAsPassenger() {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).companionJoinCodeInvalid)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PassengerCompanionScreen(joinCode: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(tripProfileProvider) ?? const TripProfile();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabCompanion),
        // Profile access moved from an AppBar icon to a tap on
        // the vehicle-summary card below (more discoverable in
        // context — the driver sees "Coche · Petrol · 2 pax"
        // and taps to change it).
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space20),
        children: [
          // Hero
          Icon(Icons.explore, size: 56, color: scheme.primary),
          const SizedBox(height: Tokens.space16),
          Text(
            l.companionHeroTitle,
            style: t.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            l.companionHeroBody,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: Tokens.space24),

          // Passenger join card
          SoftCard(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.group_add_outlined,
                        color: scheme.secondary, size: 22),
                    const SizedBox(width: Tokens.space8),
                    Text(l.companionJoinTitle, style: t.titleSmall),
                  ],
                ),
                const SizedBox(height: Tokens.space12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _joinCodeController,
                        decoration: InputDecoration(
                          hintText: l.companionJoinHint,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        onSubmitted: (_) => _joinAsPassenger(),
                      ),
                    ),
                    const SizedBox(width: Tokens.space8),
                    FilledButton.tonal(
                      onPressed: _joinAsPassenger,
                      child: Text(l.companionJoinButton),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: Tokens.space24),

          // Profile summary chip — tap opens the profile editor.
          SoftCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileScreen(),
              ),
            ),
            padding: const EdgeInsets.all(Tokens.space16),
            child: Row(
              children: [
                Icon(profile.vehicle.type.icon,
                    color: scheme.primary, size: 28),
                const SizedBox(width: Tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vehicleTypeLabel(context, profile.vehicle.type)} · '
                        '${fuelTypeLabel(context, profile.vehicle.fuelType)}',
                        style: t.titleSmall,
                      ),
                      Text(
                        '${profile.travellers} ${l.profileTravellers.toLowerCase()}'
                        '${profile.hasKids ? " · ${l.profileHasKids}" : ""}'
                        '${profile.hasPets ? " · ${l.profileHasPets}" : ""}',
                        style: t.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),

          const SizedBox(height: Tokens.space24),

          // Rest suggestions — off by default; slider + fatigue
          // sub-option only render when the parent toggle is on.
          SectionHeader(
            title: l.companionBreakInterval,
            eyebrow: l.companionConfigSection,
          ),
          _AlertToggle(
            icon: Icons.coffee_outlined,
            label: l.companionSuggestBreak,
            value: _suggestBreak,
            onChanged: (v) => setState(() {
              _suggestBreak = v;
              if (!v) _fatigueStopSuggestion = false;
            }),
          ),
          if (_suggestBreak) ...[
            Padding(
              padding: const EdgeInsets.only(left: Tokens.space40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Slider(
                    value: _breakIntervalHours,
                    min: 1.0,
                    max: 4.0,
                    divisions: 6,
                    label: '${_breakIntervalHours.toStringAsFixed(1)} h',
                    onChanged: (v) =>
                        setState(() => _breakIntervalHours = v),
                  ),
                  Text(
                    l.companionBreakHint(
                        _breakIntervalHours.toStringAsFixed(1)),
                    style: t.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Tokens.space8),
                  _AlertToggle(
                    icon: Icons.science_outlined,
                    label: l.companionFatigueStopExperimental,
                    subtitle: l.companionFatigueStopHint,
                    value: _fatigueStopSuggestion,
                    onChanged: (v) =>
                        setState(() => _fatigueStopSuggestion = v),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: Tokens.space24),

          // Alert toggles
          SectionHeader(
            title: l.companionAlerts,
            eyebrow: l.companionConfigSection,
          ),
          _AlertToggle(
            icon: Icons.warning_amber_outlined,
            label: l.companionAlertCriticalAdverse,
            subtitle: l.companionAlertCriticalAdverseHint,
            value: _alertCriticalAdverse,
            onChanged: (v) => setState(() => _alertCriticalAdverse = v),
          ),
          _AlertToggle(
            icon: Icons.cloud,
            label: l.companionAlertWeather,
            value: _alertWeather,
            onChanged: (v) => setState(() => _alertWeather = v),
          ),
          _AlertToggle(
            icon: Icons.local_gas_station,
            label: l.companionAlertFuel,
            value: _alertFuel,
            onChanged: (v) => setState(() => _alertFuel = v),
          ),
          _AlertToggle(
            icon: Icons.flag,
            label: l.companionAlertBorder,
            value: _alertBorder,
            onChanged: (v) => setState(() => _alertBorder = v),
          ),
          _AlertToggle(
            icon: Icons.toll,
            label: l.companionAlertToll,
            value: _alertToll,
            onChanged: (v) => setState(() => _alertToll = v),
          ),
          _AlertToggle(
            icon: Icons.hotel,
            label: l.companionAlertHotel,
            value: _alertHotel,
            onChanged: (v) => setState(() => _alertHotel = v),
          ),

          const SizedBox(height: Tokens.space32),

          // Start button
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CompanionDriveScreen(
                    breakIntervalHours: _breakIntervalHours,
                    suggestBreak: _suggestBreak,
                    fatigueStopSuggestion: _fatigueStopSuggestion,
                    alertCriticalAdverse: _alertCriticalAdverse,
                    alertWeather: _alertWeather,
                    alertFuel: _alertFuel,
                    alertBorder: _alertBorder,
                    alertToll: _alertToll,
                    alertHotel: _alertHotel,
                    hasKids: profile.hasKids,
                    hasPets: profile.hasPets,
                    bedtimeHour: profile.bedtimeHour,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(l.companionStart),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: t.titleMedium,
            ),
          ),
          const SizedBox(height: Tokens.space16),
        ],
      ),
    );
  }
}

class _AlertToggle extends StatelessWidget {
  const _AlertToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, size: 22),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
