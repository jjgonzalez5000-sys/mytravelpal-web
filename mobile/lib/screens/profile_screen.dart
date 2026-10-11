import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components.dart';
import '../design/tokens.dart';
// travel_style_presets import removed — presets replaced by direct parameters
import '../domain/trip_profile.dart';
import '../domain/vehicle_labels.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/garage_profile.dart';
import '../widgets/hour_wheel_picker.dart';
import 'garage_screen.dart';

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
    final cap = _maxTravellersFor(
      effectiveTripProfile(ref, override: p)?.vehicle.type ?? p.vehicle.type,
    );
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
          _GarageVehicleCard(
            profile: _profile,
            onTankLevel: (pct) => _update(
              _profile.copyWith(currentTankLevelPercent: pct),
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
    this.step = 1,
  });
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final int step;

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
  @override
  Widget build(BuildContext context) {
    // Presets removed — all parameters always visible.
    // The user configures their actual values directly; a label
    // like "Directo" adds abstraction without clarity.
    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space16),
      child: _AdvancedStyleControls(
        profile: widget.profile,
        onChanged: widget.onChanged,
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
          const capMin = 2;
          const capMax = 14;
          final recommended = switch (profile.travelPace) {
            TravelPace.push => null,
            TravelPace.steady => 6,
            TravelPace.savour => 4,
          };
          final value = profile.dailyDrivingCapHours;
          final showHint =
              recommended != null && value > recommended;
          final kmCap = profile.dailyKmCap;
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
              const SizedBox(height: Tokens.space12),
              // km cap — optional daily distance limit.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      kmCap == null
                          ? l.styleKmCapNone
                          : l.styleKmCapValue(kmCap),
                    ),
                  ),
                  if (kmCap != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: l.styleKmCapRemove,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onChanged(
                        profile.copyWith(dailyKmCap: null),
                      ),
                    ),
                  _Stepper(
                    value: kmCap ?? 0,
                    min: 0, max: 800, step: 50,
                    onChanged: (v) => onChanged(
                      profile.copyWith(dailyKmCap: v == 0 ? null : v),
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
        const SizedBox(height: Tokens.space16),
        HourWheelPicker(
          label: l.styleBedtimeLabel,
          value: profile.bedtimeHour,
          min: 18, max: 23,
          onChanged: (h) => onChanged(profile.copyWith(bedtimeHour: h)),
        ),
        const SizedBox(height: Tokens.space12),
        HourWheelPicker(
          label: l.styleWakeLabel,
          value: profile.wakeHour,
          min: 5, max: 11,
          onChanged: (h) => onChanged(profile.copyWith(wakeHour: h)),
        ),
        const SizedBox(height: Tokens.space12),
        // Preferred driving start hour — independent of wake_hour so
        // a driver who prefers "wake at 07:00, drive at 07:30" gets
        // that instead of being forced to eat breakfast first.
        HourWheelPicker(
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


/// The vehicle a trip is planned with always comes from the garage, so the
/// profile only shows it (type, fuel, consumption) and links to the garage
/// to change it, instead of offering a second, separate set of controls.
class _GarageVehicleCard extends ConsumerWidget {
  const _GarageVehicleCard({required this.profile, required this.onTankLevel});

  final TripProfile profile;
  final ValueChanged<int?> onTankLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    ref.watch(garageProvider);
    ref.watch(selectedGarageVehicleIdProvider);
    ref.watch(vehicleCatalogueProvider);
    final garageVehicle = activeGarageVehicle(ref);
    final effective = effectiveTripProfile(ref, override: profile);

    Future<void> openGarage() => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const GarageScreen()),
        );

    if (garageVehicle == null || effective == null) {
      return SoftCard(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.profileVehicleGarageEmpty, style: t.bodyMedium),
            const SizedBox(height: Tokens.space12),
            FilledButton.tonalIcon(
              onPressed: openGarage,
              icon: const Icon(Icons.add),
              label: Text(l.garageAdd),
            ),
          ],
        ),
      );
    }

    final v = effective.vehicle;
    final isEv = v.fuelType == FuelType.electric;
    final consumption = isEv
        ? '${v.consumptionKwhPer100km.toStringAsFixed(1)} kWh / 100 km'
        : '${v.consumptionLPer100km.toStringAsFixed(1)} L / 100 km';
    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(v.type.icon, color: scheme.primary),
              const SizedBox(width: Tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(garageVehicle.name.isEmpty
                            ? l.garageDefaultName
                            : garageVehicle.name,
                        style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${vehicleTypeLabel(context, v.type)} · '
                      '${fuelTypeLabel(context, v.fuelType)} · $consumption',
                      style: t.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            l.profileVehicleFromGarage,
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space8),
          TextButton.icon(
            onPressed: openGarage,
            icon: const Icon(Icons.garage_outlined),
            label: Text(l.profileVehicleGarageManage),
          ),
          const SizedBox(height: Tokens.space8),
          _TankLevelPicker(
            current: profile.currentTankLevelPercent,
            onChanged: onTankLevel,
          ),
        ],
      ),
    );
  }
}
