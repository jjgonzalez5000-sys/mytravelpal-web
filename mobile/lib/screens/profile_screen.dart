import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components.dart';
import '../design/tokens.dart';
import '../domain/travel_style_presets.dart';
import '../domain/trip_profile.dart';
import '../domain/vehicle_labels.dart';
import '../domain/vehicle_model.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'vehicle_picker_screen.dart';

/// Single-form profile editor. Users set this once; the plan screen
/// then shows a compact chip and applies the profile silently to every
/// plan request. Structured as clearly-titled sections so it doesn't
/// look overwhelming — travellers first (least intimidating), vehicle,
/// then meal times last (most granular).
///
/// Two modes:
/// - **persist** (default): "Save" writes to global prefs and pops.
/// - **override**: "Use for this trip" pops returning the edited profile
///   via `Navigator.pop(profile)` without touching prefs. Used by the
///   plan screen's per-trip override sheet.
enum ProfileScreenMode { persist, override_ }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.mode = ProfileScreenMode.persist,
    this.initial,
  });

  final ProfileScreenMode mode;
  final TripProfile? initial;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TripProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.initial
        ?? ref.read(tripProfileProvider)
        ?? const TripProfile();
  }

  /// Called on every edit. In `persist` mode we quietly write to the
  /// global prefs so the user doesn't need to tap "Save" before backing
  /// out — behaviour they asked for on 2026-08-24. In `override_` mode
  /// we only mutate local state; `Use for this trip` remains the
  /// commit point since that flow returns the profile to the caller.
  void _update(TripProfile p) {
    // Enforce the per-vehicle traveller cap. If the user switches
    // from car (7 max) to motorbike (3 max) while their profile
    // says 5 travellers, silently trim to the new cap so the
    // request payload stays consistent. Trimming here (single
    // funnel) beats sprinkling clamps at each call site.
    final cap = _maxTravellersFor(p.vehicle.type);
    if (p.travellers > cap) {
      p = p.copyWith(travellers: cap);
    }
    setState(() {
      _profile = p;
    });
    if (widget.mode == ProfileScreenMode.persist) {
      // fire-and-forget; SharedPreferences writes are fast and any
      // in-flight write is superseded by the next call.
      unawaited(ref.read(tripProfileProvider.notifier).set(p));
    }
  }

  /// Traveller cap by vehicle type:
  /// - `motorbike` → 3  (rider + kid seat / sidecar / trailer)
  /// - `car`       → 7  (SUV / 7-seater sedan)
  /// - `van` / `camper` → 9 (extended family / crew)
  static int _maxTravellersFor(VehicleType t) => switch (t) {
        VehicleType.motorbike => 3,
        VehicleType.car => 7,
        VehicleType.van => 9,
        VehicleType.camper => 9,
      };

  Future<void> _useForTrip() async {
    Navigator.of(context).pop(_profile);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = _profile.vehicle;
    final isEv = v.fuelType == FuelType.electric;
    final l = AppLocalizations.of(context);

    final overrideMode = widget.mode == ProfileScreenMode.override_;
    return PopScope(
      // Intercept the back gesture so we can guarantee the final
      // profile state is flushed to SharedPreferences BEFORE the
      // route pops. Fire-and-forget `_update` writes lose races
      // with fast back-taps otherwise, and users legitimately
      // reported edits vanishing after backing out.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Capture Navigator BEFORE the await so we don't hold a
        // BuildContext across the async gap (analyzer flags it).
        final nav = Navigator.of(context);
        if (widget.mode == ProfileScreenMode.persist) {
          await ref.read(tripProfileProvider.notifier).set(_profile);
        }
        if (!mounted) return;
        nav.pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(overrideMode ? l.profileOverrideTitle : l.profileTitle),
        actions: [
          // Only override mode keeps the explicit commit button — persist
          // mode saves on every change and pops normally.
          if (overrideMode)
            TextButton(
              onPressed: _useForTrip,
              child: Text(l.profileUse),
            ),
          const SizedBox(width: Tokens.space8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space20),
        children: [
          Text(
            overrideMode ? l.profileOverrideHeroDesc : l.profileGlobalHeroDesc,
            style: t.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.space24),

          SectionHeader(
            title: l.styleSectionTitle,
            eyebrow: l.styleSectionEyebrow,
          ),
          _TravelStyleCard(
            profile: _profile,
            onChanged: _update,
          ),
          const SizedBox(height: Tokens.space24),

          SectionHeader(
            title: l.profileWhoTravelling,
            eyebrow: l.profileWhoEyebrow,
          ),
          SoftCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space16, vertical: Tokens.space4,
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.profileTravellers),
                  trailing: _Stepper(
                    value: _profile.travellers,
                    // Cap driven by vehicle type: bikes seat at
                    // most 2-3 (rider + kid seat + trailer), cars
                    // rarely exceed 7 (SUV / 7-seater). Vans /
                    // campers still get the previous 9-max since
                    // "we're going with the extended family" is
                    // exactly what those exist for.
                    min: 1,
                    max: _maxTravellersFor(_profile.vehicle.type),
                    onChanged: (n) => _update(_profile.copyWith(travellers: n)),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.profileHasKids),
                  subtitle: Text(l.profileKidsSubtitle),
                  value: _profile.hasKids,
                  onChanged: (v) => _update(_profile.copyWith(hasKids: v)),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.profileHasPets),
                  subtitle: Text(l.profilePetsSubtitle),
                  value: _profile.hasPets,
                  onChanged: (v) => _update(_profile.copyWith(hasPets: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space24),

          SectionHeader(
            title: l.profileVehicle,
            eyebrow: l.profileVehicleEyebrow,
          ),
          SoftCard(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledChoice<VehicleType>(
                  label: l.profileVehicleType,
                  value: v.type,
                  options: VehicleType.values,
                  optionLabel: (t) => vehicleTypeLabel(context, t),
                  optionIcon: (t) => t.icon,
                  onChanged: (t) => _update(_profile.copyWith(
                      vehicle: v.copyWith(type: t)),
                  ),
                ),
                const SizedBox(height: Tokens.space16),
                _LabeledChoice<FuelType>(
                  label: l.profileFuelType,
                  value: v.fuelType,
                  options: FuelType.values,
                  optionLabel: (f) => fuelTypeLabel(context, f),
                  onChanged: (f) => _update(_profile.copyWith(
                      vehicle: v.copyWith(fuelType: f)),
                  ),
                ),
                const SizedBox(height: Tokens.space16),
                if (isEv) ...[
                  _LabeledSlider(
                    label: l.profileConsumption,
                    suffix: 'kWh / 100 km',
                    value: v.consumptionKwhPer100km,
                    min: 8, max: 40, divisions: 32,
                    onChanged: (x) => _update(_profile.copyWith(
                        vehicle: v.copyWith(consumptionKwhPer100km: x)),
                    ),
                  ),
                  const SizedBox(height: Tokens.space16),
                  _LabeledSlider(
                    label: l.profileEvRange,
                    suffix: 'km',
                    value: v.evRangeKm,
                    min: 100, max: 800, divisions: 70,
                    onChanged: (x) => _update(_profile.copyWith(
                        vehicle: v.copyWith(evRangeKm: x)),
                    ),
                  ),
                ] else ...[
                  _LabeledSlider(
                    label: l.profileConsumption,
                    suffix: 'L / 100 km',
                    value: v.consumptionLPer100km,
                    min: 2, max: 20, divisions: 36,
                    onChanged: (x) => _update(_profile.copyWith(
                        vehicle: v.copyWith(consumptionLPer100km: x)),
                    ),
                  ),
                  const SizedBox(height: Tokens.space16),
                  _VehicleModelRow(
                    currentId: _profile.vehicleModelId,
                    onPicked: (model) {
                      // Overwrite the manual fuel type / tank / consumption
                      // fields with the picked model's data so the profile
                      // stays consistent (the fields shown above this row
                      // are the same ones that get sent to the backend
                      // when no vehicle_model_id fallback is in play).
                      _update(
                        _profile.copyWith(
                          vehicleModelId: model.id,
                          vehicle: _profile.vehicle.copyWith(
                            fuelType: model.fuelType,
                            fuelTankL: model.tankLiters > 0
                                ? model.tankLiters
                                : _profile.vehicle.fuelTankL,
                            consumptionLPer100km: model.consumptionL100km > 0
                                ? model.consumptionL100km
                                : _profile.vehicle.consumptionLPer100km,
                          ),
                        ),
                      );
                    },
                    onClear: () {
                      _update(_profile.copyWith(
                        vehicleModelId: null,
                        currentTankLevelPercent: null,
                      ));
                    },
                  ),
                  if (_profile.vehicleModelId != null) ...[
                    const SizedBox(height: Tokens.space16),
                    _TankLevelPicker(
                      current: _profile.currentTankLevelPercent,
                      onChanged: (pct) => _update(
                        _profile.copyWith(currentTankLevelPercent: pct),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: Tokens.space24),

          SectionHeader(
            title: l.profileMealTimes,
            eyebrow: l.profileMealsEyebrow,
          ),
          SoftCard(
            padding: const EdgeInsets.all(Tokens.space16),
            child: Column(
              children: [
                _MealTimeTile(
                  label: l.profileBreakfast,
                  hour: _profile.meals.breakfastHour,
                  minute: _profile.meals.breakfastMinute,
                  minHour: 4, maxHour: 12,
                  onChanged: (h, m) => _update(_profile.copyWith(
                      meals: _profile.meals.copyWith(
                        breakfastHour: h, breakfastMinute: m,
                      )),
                  ),
                ),
                const Divider(height: 1),
                _MealTimeTile(
                  label: l.profileLunch,
                  hour: _profile.meals.lunchHour,
                  minute: _profile.meals.lunchMinute,
                  minHour: 11, maxHour: 16,
                  onChanged: (h, m) => _update(_profile.copyWith(
                      meals: _profile.meals.copyWith(
                        lunchHour: h, lunchMinute: m,
                      )),
                  ),
                ),
                const Divider(height: 1),
                _MealTimeTile(
                  label: l.profileDinner,
                  hour: _profile.meals.dinnerHour,
                  minute: _profile.meals.dinnerMinute,
                  minHour: 17, maxHour: 23,
                  onChanged: (h, m) => _update(_profile.copyWith(
                      meals: _profile.meals.copyWith(
                        dinnerHour: h, dinnerMinute: m,
                      )),
                  ),
                ),
              ],
            ),
          ),
          if (!overrideMode) ...[
            const SizedBox(height: Tokens.space24),
            SectionHeader(
              title: l.profileReminders,
              eyebrow: l.profileRemindersEyebrow,
            ),
            SoftCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space16, vertical: Tokens.space4,
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.profileNotifyBefore),
                subtitle: Text(
                  _profile.meals.reminderMinutesBefore == 0
                      ? l.profileNotifyOff
                      : l.profileNotifyMinutesBefore(
                          _profile.meals.reminderMinutesBefore),
                ),
                trailing: _Stepper(
                  value: _profile.meals.reminderMinutesBefore,
                  min: 0, max: 120,
                  onChanged: (v) => _update(_profile.copyWith(
                      meals: _profile.meals.copyWith(
                        reminderMinutesBefore: v,
                      )),
                  ),
                ),
              ),
            ),
          ],
          if (!overrideMode) ...[
            // Simulate-Premium toggle removed for the beta — Premium
            // is ON by default until real receipt validation lands
            // (Play Billing / StoreKit). Re-add the section here when
            // the paywall is wired.
            const SizedBox(height: Tokens.space24),
            if (ref.watch(tripProfileProvider) != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(l.profileClearProfile),
                onPressed: () async {
                  await ref.read(tripProfileProvider.notifier).clear();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
          ],
        ],
      ),
      ),  // PopScope child close
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  int get step => 1;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed:
              value > min ? () => onChanged((value - step).clamp(min, max)) : null,
        ),
        SizedBox(
          width: 36,
          child: Text('$value', textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed:
              value < max ? () => onChanged((value + step).clamp(min, max)) : null,
        ),
      ],
    );
  }
}

class _LabeledChoice<T> extends StatelessWidget {
  const _LabeledChoice({
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.optionIcon,
  });
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) optionLabel;
  final IconData Function(T)? optionIcon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelMedium),
        const SizedBox(height: Tokens.space8),
        Wrap(
          spacing: Tokens.space8,
          runSpacing: Tokens.space8,
          children: [
            for (final o in options)
              ChoiceChip(
                selected: o == value,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (optionIcon != null) ...[
                      Icon(optionIcon!(o), size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(optionLabel(o)),
                  ],
                ),
                onSelected: (s) {
                  if (s) onChanged(o);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final String suffix;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.labelMedium)),
            Text('${value.toStringAsFixed(1)} $suffix',
                style: t.labelMedium),
          ],
        ),
        Slider(
          value: value,
          min: min, max: max, divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: _Stepper(
        value: value, min: min, max: max, onChanged: onChanged,
      ),
    );
  }
}

/// Travel-style section: preset chips + collapsible Advanced.
///
/// The 3 presets rewrite the 4 style axes; anything else the user has
/// tweaked (bedtime, wake, meals, vehicle) is preserved by
/// [TravelStylePreset.apply].
class _TravelStyleCard extends StatefulWidget {
  const _TravelStyleCard({required this.profile, required this.onChanged});
  final TripProfile profile;
  final ValueChanged<TripProfile> onChanged;

  @override
  State<_TravelStyleCard> createState() => _TravelStyleCardState();
}

class _TravelStyleCardState extends State<_TravelStyleCard> {
  bool _expanded = false;

  String _presetLabel(BuildContext c, TravelStylePreset p) {
    final l = AppLocalizations.of(c);
    return switch (p) {
      TravelStylePreset.direct => l.stylePresetDirect,
      TravelStylePreset.balanced => l.stylePresetBalanced,
      TravelStylePreset.slow => l.stylePresetSlow,
    };
  }

  String _presetHint(BuildContext c, TravelStylePreset p) {
    final l = AppLocalizations.of(c);
    return switch (p) {
      TravelStylePreset.direct => l.stylePresetDirectHint,
      TravelStylePreset.balanced => l.stylePresetBalancedHint,
      TravelStylePreset.slow => l.stylePresetSlowHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final active = TravelStylePreset.matching(widget.profile);

    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Tokens.space8,
            runSpacing: Tokens.space8,
            children: [
              for (final preset in TravelStylePreset.values)
                ChoiceChip(
                  selected: preset == active,
                  avatar: Icon(preset.icon, size: 16),
                  label: Text(_presetLabel(context, preset)),
                  onSelected: (v) {
                    if (!v) return;
                    widget.onChanged(preset.apply(widget.profile));
                  },
                ),
              if (active == null)
                Chip(
                  avatar: const Icon(Icons.tune, size: 16),
                  label: Text(l.styleCustom),
                  backgroundColor: scheme.tertiaryContainer,
                ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            active == null ? l.styleCustom : _presetHint(context, active),
            style: t.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space8),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(l.styleAdvanced),
          ),
          if (_expanded) _AdvancedStyleControls(
            profile: widget.profile,
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

class _AdvancedStyleControls extends StatelessWidget {
  const _AdvancedStyleControls({
    required this.profile, required this.onChanged,
  });
  final TripProfile profile;
  final ValueChanged<TripProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Tokens.space12),
        _LabelText(l.stylePaceLabel),
        SegmentedButton<TravelPace>(
          segments: [
            ButtonSegment(
              value: TravelPace.push, label: Text(l.stylePacePush),
            ),
            ButtonSegment(
              value: TravelPace.steady, label: Text(l.stylePaceSteady),
            ),
            ButtonSegment(
              value: TravelPace.savour, label: Text(l.stylePaceSavour),
            ),
          ],
          selected: {profile.travelPace},
          onSelectionChanged: (s) =>
              onChanged(profile.copyWith(travelPace: s.first)),
        ),
        const SizedBox(height: Tokens.space16),
        _LabelText(l.styleOvernightLabel),
        SegmentedButton<OvernightPolicy>(
          segments: [
            ButtonSegment(
              value: OvernightPolicy.never,
              label: Text(l.styleOvernightNever),
            ),
            ButtonSegment(
              value: OvernightPolicy.ifNeeded,
              label: Text(l.styleOvernightIfNeeded),
            ),
            ButtonSegment(
              value: OvernightPolicy.alwaysIfLong,
              label: Text(l.styleOvernightAlwaysIfLong),
            ),
          ],
          selected: {profile.overnightPolicy},
          onSelectionChanged: (s) =>
              onChanged(profile.copyWith(overnightPolicy: s.first)),
        ),
        const SizedBox(height: Tokens.space16),
        Builder(builder: (_) {
          // Daily-driving cap: always 4-14 h, no hard limit by pace.
          // Pace only drives a "recommended" hint — the user has the
          // final say. Previously we hard-clamped steady to 6 h and
          // silently corrected higher values; users pushed back
          // because 6 h wasn't a suggestion, it was a wall.
          const capMin = 4;
          const capMax = 14;
          final recommended = switch (profile.travelPace) {
            TravelPace.push => null,        // no advice — the user picked "push".
            TravelPace.steady => 6,
            TravelPace.savour => 8,
          };
          final value = profile.dailyDrivingCapHours;
          final showHint =
              recommended != null && value > recommended;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(
                    '${l.styleDailyCapLabel}: $value h',
                  )),
                  _Stepper(
                    value: value,
                    min: capMin, max: capMax,
                    onChanged: (v) => onChanged(
                      profile.copyWith(dailyDrivingCapHours: v),
                    ),
                  ),
                ],
              ),
              if (showHint) ...[
                const SizedBox(height: 4),
                Text(
                  l.styleDailyCapRecommendedHint(recommended),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          );
        }),
        const SizedBox(height: Tokens.space8),
        _HourPicker(
          label: l.styleBedtimeLabel,
          value: profile.bedtimeHour,
          min: 18, max: 23,
          onChanged: (h) => onChanged(profile.copyWith(bedtimeHour: h)),
        ),
        _HourPicker(
          label: l.styleWakeLabel,
          value: profile.wakeHour,
          min: 5, max: 11,
          onChanged: (h) => onChanged(profile.copyWith(wakeHour: h)),
        ),
        // Preferred driving start hour — independent of wake_hour so
        // a driver who prefers "wake at 07:00, drive at 07:30" gets
        // that instead of being forced to eat breakfast first.
        _HourPicker(
          label: l.styleDrivingStartLabel,
          value: profile.preferredDrivingStartHour ?? profile.wakeHour,
          min: 4, max: 14,
          onChanged: (h) => onChanged(
            profile.copyWith(preferredDrivingStartHour: h),
          ),
        ),
        // Break-style picker removed (2026-08-25). Users pointed out
        // that scenic / foodie / minimal was redundant with the
        // pace choice + the ability to add restaurants manually
        // from the results screen. The enum stays in the domain
        // model for backend compat — we always send whatever's
        // stored (default `scenic`) but the UI no longer surfaces
        // the choice.
      ],
    );
  }
}

class _LabelText extends StatelessWidget {
  const _LabelText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      );
}

/// Row that shows `Breakfast   08:30 ›` and opens a two-column
/// Cupertino-style wheel picker (hour + minute at 5-min steps).
///
/// Rationale: hardcore users (siesta lovers, night-owls, athletes)
/// asked for minute-level control. A stepper for hours + a second
/// stepper for minutes would work but feel clunky; a spinning wheel is
/// what most consumer apps use for time and fits Android's Material 3
/// theme when embedded in a modal bottom sheet.
class _MealTimeTile extends StatelessWidget {
  const _MealTimeTile({
    required this.label,
    required this.hour,
    required this.minute,
    required this.minHour,
    required this.maxHour,
    required this.onChanged,
  });

  final String label;
  final int hour;
  final int minute;
  final int minHour;
  final int maxHour;
  final void Function(int hour, int minute) onChanged;

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _open(BuildContext context) async {
    // Snap current value into an allowed step. Minutes advance by 5;
    // hours are clamped to the slot's window.
    int selHour = hour.clamp(minHour, maxHour);
    int selMinute = ((minute ~/ 5) * 5).clamp(0, 55);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space16, vertical: Tokens.space8,
                ),
                child: Text(
                  label,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36,
                        scrollController: FixedExtentScrollController(
                          initialItem: selHour - minHour,
                        ),
                        onSelectedItemChanged: (i) =>
                            selHour = minHour + i,
                        children: [
                          for (int h = minHour; h <= maxHour; h++)
                            Center(
                              child: Text(
                                h.toString().padLeft(2, '0'),
                                style: Theme.of(ctx).textTheme.headlineSmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(':',
                        style: Theme.of(ctx).textTheme.headlineSmall),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36,
                        scrollController: FixedExtentScrollController(
                          initialItem: selMinute ~/ 5,
                        ),
                        onSelectedItemChanged: (i) => selMinute = i * 5,
                        children: [
                          for (int m = 0; m < 60; m += 5)
                            Center(
                              child: Text(
                                m.toString().padLeft(2, '0'),
                                style: Theme.of(ctx).textTheme.headlineSmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Tokens.space8),
            ],
          ),
        );
      },
    );
    onChanged(selHour, selMinute);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fmt(hour, minute),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () => _open(context),
    );
  }
}

/// A tappable row showing the currently-picked vehicle model (short
/// label) or a "pick model" hint. Opens the [VehiclePickerScreen] and
/// forwards the selection back up to the parent form.
class _VehicleModelRow extends ConsumerWidget {
  const _VehicleModelRow({
    required this.currentId,
    required this.onPicked,
    required this.onClear,
  });

  final String? currentId;
  // Callback receives the resolved [VehicleModel] (not just its id)
  // so the caller can also overwrite the profile's `Vehicle` fields
  // (fuelType / tankLiters / consumption) — otherwise the "manual"
  // spec fields shown below stay stale and disagree with the model.
  final ValueChanged<VehicleModel> onPicked;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    // Resolve id -> VehicleModel using the cached catalogue. If the
    // catalogue is still loading (cold start) we render the raw id so
    // the row is never empty for the user.
    final async = ref.watch(vehicleCatalogueProvider);
    VehicleModel? picked;
    if (currentId != null && async.hasValue) {
      picked = async.value!.firstWhere(
        (m) => m.id == currentId,
        orElse: () => VehicleModel(
          id: currentId!,
          make: '',
          model: currentId!,
          yearFrom: 0,
          yearTo: null,
          fuelType: FuelType.petrol,
          tankLiters: 0,
          consumptionL100km: 0,
        ),
      );
    }
    final labelText = picked == null
        ? l.profileVehicleModelHint
        : '${picked.make} ${picked.model}';
    final subLabel = picked == null || picked.tankLiters <= 0
        ? null
        : picked.shortLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final id = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => VehiclePickerScreen(currentId: currentId),
          ),
        );
        if (id == null || id.isEmpty) return;
        // Resolve to a full VehicleModel via the cached catalogue so
        // the caller can apply fuel type + tank + consumption to the
        // profile's Vehicle. Fall back to a stub with just the id if
        // the catalogue isn't loaded yet (extremely rare — the
        // picker itself needs the catalogue to render).
        final list = async.hasValue ? async.value! : const <VehicleModel>[];
        final resolved = list.firstWhere(
          (m) => m.id == id,
          orElse: () => VehicleModel(
            id: id, make: '', model: id, yearFrom: 0, yearTo: null,
            fuelType: FuelType.petrol, tankLiters: 0, consumptionL100km: 0,
          ),
        );
        onPicked(resolved);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
        child: Row(
          children: [
            Icon(Icons.directions_car_filled, color: scheme.primary),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.profileVehicleModel,
                    style: t.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(labelText, style: t.titleMedium),
                  if (subLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subLabel,
                      style: t.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (currentId != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l.profileVehicleModelClear,
                onPressed: onClear,
              ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// 4-notch chip picker (25 / 50 / 75 / 100 %) for the current fuel
/// level. Only surfaced when a `vehicleModelId` is set — without it
/// the backend has no tank size to project against.
class _TankLevelPicker extends StatelessWidget {
  const _TankLevelPicker({required this.current, required this.onChanged});

  final int? current;
  final ValueChanged<int?> onChanged;

  static const _notches = <int>[25, 50, 75, 100];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.profileTankLevel,
          style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Tokens.space8),
        Wrap(
          spacing: Tokens.space8,
          children: [
            for (final n in _notches)
              ChoiceChip(
                label: Text('$n %'),
                selected: current == n,
                onSelected: (yes) => onChanged(yes ? n : null),
              ),
          ],
        ),
      ],
    );
  }
}
