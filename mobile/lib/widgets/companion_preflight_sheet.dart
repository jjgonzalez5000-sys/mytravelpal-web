import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../l10n/app_localizations.dart';
import 'hotel_preferences.dart';
import 'restaurant_preferences.dart';

const _kSkipCarConfirmKey = 'companion_skip_car_confirm';

/// Snapshot of the driver's ad-hoc Companion tweaks for this trip.
///
/// This is the return payload from [showCompanionPreflightSheet]. The
/// caller (usually `ResultScreen` on its way into `CompanionDriveScreen`)
/// decides how to apply the values: they can be forwarded to the drive
/// session as-is and, when [saveToProfile] is true, also persisted back
/// to the user's stored [HotelPreferences] / [RestaurantPreferences] /
/// [TripProfile].
///
/// Kept as a plain immutable value object — no JSON, no controller. The
/// sheet builds one on confirm and pops it; there is no partial state to
/// reconcile if the driver dismisses without confirming (we return null).
@immutable
class CompanionOverrides {
  const CompanionOverrides({
    required this.breakfastAt,
    required this.lunchAt,
    required this.dinnerAt,
    required this.mealTolerance,
    required this.maxDetourMinutes,
    required this.mealPriceBands,
    required this.hotelPriceBands,
    required this.tankLevelPct,
    required this.saveToProfile,
  });

  final TimeOfDay breakfastAt;
  final TimeOfDay lunchAt;
  final TimeOfDay dinnerAt;

  /// How far around the target meal time the Companion may slide a stop.
  final Duration mealTolerance;

  /// Shared cap for both hotel and restaurant detours.
  final int maxDetourMinutes;

  final Set<PriceBand> mealPriceBands;
  final Set<PriceBand> hotelPriceBands;

  /// Current fuel tank level 0–100 %. Used to filter reachable
  /// stations and compute accurate fuel-spend estimates.
  final int tankLevelPct;

  /// When true, the caller should also write these tweaks back to the
  /// user profile so they become the new default for future trips.
  final bool saveToProfile;
}

/// Show the Companion pre-flight sheet.
///
/// [vehicleLabel] is the human-readable "Make Model" string for the
/// vehicle in the profile. Pass null when the profile has no model set.
///
/// Returns the driver's overrides on confirm, or `null` when dismissed.
Future<CompanionOverrides?> showCompanionPreflightSheet(
  BuildContext context, {
  required HotelPreferences initialHotel,
  required RestaurantPreferences initialRestaurant,
  required TripProfile? initialProfile,
  String? vehicleLabel,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final skipCarConfirm = prefs.getBool(_kSkipCarConfirmKey) ?? false;
  if (!context.mounted) return null;
  return showModalBottomSheet<CompanionOverrides>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _CompanionPreflightSheet(
      initialHotel: initialHotel,
      initialRestaurant: initialRestaurant,
      initialProfile: initialProfile,
      vehicleLabel: skipCarConfirm ? null : vehicleLabel,
    ),
  );
}

/// Modal body. Stateful so meal-time pickers and chip selections stay
/// local until the driver taps "Start" — dismissing the sheet discards
/// everything.
class _CompanionPreflightSheet extends StatefulWidget {
  const _CompanionPreflightSheet({
    required this.initialHotel,
    required this.initialRestaurant,
    required this.initialProfile,
    this.vehicleLabel,
  });

  final HotelPreferences initialHotel;
  final RestaurantPreferences initialRestaurant;
  final TripProfile? initialProfile;
  /// Non-null only when we should show the car-confirmation row
  /// (i.e. skip-flag is NOT set). Null means either no model in
  /// profile or the user already confirmed "don't ask again".
  final String? vehicleLabel;

  @override
  State<_CompanionPreflightSheet> createState() =>
      _CompanionPreflightSheetState();
}

class _CompanionPreflightSheetState extends State<_CompanionPreflightSheet> {
  late TimeOfDay _breakfast;
  late TimeOfDay _lunch;
  late TimeOfDay _dinner;
  late int _maxDetourMinutes;
  late Set<PriceBand> _mealBands;
  late Set<PriceBand> _hotelBands;
  int _tankPct = 75;
  bool _carConfirmed = true;   // "yes, I'm driving this car"
  bool _skipCarConfirmNext = false;
  bool _saveToProfile = false;

  static const _detourMin = 5;
  static const _detourMax = 90;
  static const _detourDivisions = 17; // 5-min steps.

  @override
  void initState() {
    super.initState();
    final meals = widget.initialProfile?.meals;
    _breakfast = meals != null
        ? TimeOfDay(hour: meals.breakfastHour, minute: meals.breakfastMinute)
        : const TimeOfDay(hour: 8, minute: 30);
    _lunch = meals != null
        ? TimeOfDay(hour: meals.lunchHour, minute: meals.lunchMinute)
        : const TimeOfDay(hour: 13, minute: 30);
    _dinner = meals != null
        ? TimeOfDay(hour: meals.dinnerHour, minute: meals.dinnerMinute)
        : const TimeOfDay(hour: 20, minute: 30);
    // Shared detour slider: seed from the hotel value, which the
    // restaurant pref usually mirrors anyway.
    _maxDetourMinutes = widget.initialHotel.maxDetourMinutes
        .clamp(_detourMin, _detourMax);
    _mealBands = {...widget.initialRestaurant.priceBands};
    _hotelBands = {...widget.initialHotel.priceBands};
    // Seed tank level from profile if available, else default 75 %.
    final savedTank =
        widget.initialProfile?.currentTankLevelPercent;
    if (savedTank != null) _tankPct = savedTank.clamp(0, 100);
  }

  Future<void> _pickTime(
    TimeOfDay current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked != null) onPicked(picked);
  }

  void _togglePriceBand(Set<PriceBand> selected, PriceBand band) {
    final next = {...selected};
    if (band == PriceBand.any) {
      next
        ..clear()
        ..add(PriceBand.any);
    } else {
      next.remove(PriceBand.any);
      if (next.contains(band)) {
        next.remove(band);
      } else {
        next.add(band);
      }
      if (next.isEmpty) next.add(PriceBand.any);
    }
    if (identical(selected, _mealBands)) {
      setState(() => _mealBands = next);
    } else {
      setState(() => _hotelBands = next);
    }
  }

  Future<void> _onConfirm() async {
    if (_skipCarConfirmNext) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSkipCarConfirmKey, true);
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      CompanionOverrides(
        breakfastAt: _breakfast,
        lunchAt: _lunch,
        dinnerAt: _dinner,
        mealTolerance: Duration(
          minutes:
              widget.initialProfile?.meals.typicalStopMinutes ?? 45,
        ),
        maxDetourMinutes: _maxDetourMinutes,
        mealPriceBands: _mealBands,
        hotelPriceBands: _hotelBands,
        tankLevelPct: _tankPct,
        saveToProfile: _saveToProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AppLocalizations is imported so future migration to l10n keys
    // (companionPreflightTitle, companionPreflightMealWindows, etc.) is
    // a straight swap without touching imports.
    // ignore: unused_local_variable
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space20,
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: Tokens.space16),
                    children: [
                      // 1. Title.
                      Padding(
                        padding: const EdgeInsets.only(
                          top: Tokens.space8,
                          bottom: Tokens.space16,
                        ),
                        child: Text(
                          l.companionPreflightTitle,
                          style: tt.titleLarge,
                        ),
                      ),

                      // 2a. Car model confirmation (shown only when
                      //     the user hasn't checked "don't ask again").
                      if (widget.vehicleLabel != null) ...[
                        Text(
                          'Coche',
                          style: tt.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: Tokens.space8),
                        Container(
                          padding: const EdgeInsets.all(Tokens.space12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius:
                                BorderRadius.circular(Tokens.radiusMd),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.directions_car_outlined,
                                      size: 18,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: Tokens.space8),
                                  Expanded(
                                    child: Text(
                                      widget.vehicleLabel!,
                                      style: tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  // Toggle: "sí, conduzco este coche"
                                  Switch.adaptive(
                                    value: _carConfirmed,
                                    onChanged: (v) =>
                                        setState(() => _carConfirmed = v),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Tokens.space4),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _skipCarConfirmNext,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (v) => setState(
                                      () => _skipCarConfirmNext = v ?? false,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'No volver a preguntar para este coche',
                                      style: tt.bodySmall?.copyWith(
                                        color: theme.colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Tokens.space20),
                      ],

                      // 2b. Tank level.
                      Text(
                        'Nivel de depósito',
                        style: tt.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Tokens.space4),
                      Row(
                        children: [
                          Icon(
                            _tankPct <= 25
                                ? Icons.local_gas_station_outlined
                                : Icons.local_gas_station,
                            size: 20,
                            color: _tankPct <= 25
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: 100,
                              divisions: 20,
                              value: _tankPct.toDouble(),
                              label: '$_tankPct %',
                              onChanged: (v) =>
                                  setState(() => _tankPct = v.round()),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '$_tankPct %',
                              textAlign: TextAlign.end,
                              style: tt.bodyMedium?.copyWith(
                                color: _tankPct <= 25
                                    ? theme.colorScheme.error
                                    : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Tokens.space20),

                      // 3. Meal times.
                      Text(
                        l.companionPreflightMealWindows,
                        style: tt.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Tokens.space8),
                      _MealTimeTile(
                        label: l.companionPreflightBreakfast,
                        value: _breakfast,
                        onTap: () => _pickTime(
                          _breakfast,
                          (t) => setState(() => _breakfast = t),
                        ),
                      ),
                      _MealTimeTile(
                        label: l.companionPreflightLunch,
                        value: _lunch,
                        onTap: () => _pickTime(
                          _lunch,
                          (t) => setState(() => _lunch = t),
                        ),
                      ),
                      _MealTimeTile(
                        label: l.companionPreflightDinner,
                        value: _dinner,
                        onTap: () => _pickTime(
                          _dinner,
                          (t) => setState(() => _dinner = t),
                        ),
                      ),
                      const SizedBox(height: Tokens.space20),

                      // 3. Detour tolerance.
                      Text(
                        l.companionPreflightDetourTolerance,
                        style: tt.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Tokens.space4),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              min: _detourMin.toDouble(),
                              max: _detourMax.toDouble(),
                              divisions: _detourDivisions,
                              value: _maxDetourMinutes.toDouble(),
                              label: '$_maxDetourMinutes min',
                              onChanged: (v) => setState(
                                () => _maxDetourMinutes = v.round(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              '$_maxDetourMinutes min',
                              textAlign: TextAlign.end,
                              style: tt.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Tokens.space16),

                      // 4. Meal budget.
                      Text(
                        l.companionPreflightMealBudget,
                        style: tt.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Tokens.space8),
                      _BandChipRow(
                        selected: _mealBands,
                        onTap: (b) => _togglePriceBand(_mealBands, b),
                      ),
                      const SizedBox(height: Tokens.space16),

                      // 5. Hotel budget.
                      Text(
                        l.companionPreflightHotelBudget,
                        style: tt.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Tokens.space8),
                      _BandChipRow(
                        selected: _hotelBands,
                        onTap: (b) => _togglePriceBand(_hotelBands, b),
                      ),
                      const SizedBox(height: Tokens.space20),

                      // 6. Save to profile.
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l.companionPreflightSaveToProfile,
                        ),
                        value: _saveToProfile,
                        onChanged: (v) =>
                            setState(() => _saveToProfile = v),
                      ),
                    ],
                  ),
                ),

                // 7. Action row.
                Padding(
                  padding: const EdgeInsets.only(
                    top: Tokens.space8,
                    bottom: Tokens.space16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l.companionPreflightStart),
                      onPressed: _onConfirm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One meal-time row.
class _MealTimeTile extends StatelessWidget {
  const _MealTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      trailing: ActionChip(
        avatar: Icon(
          Icons.schedule,
          size: 18,
          color: scheme.onSecondaryContainer,
        ),
        label: Text(value.format(context)),
        onPressed: onTap,
      ),
      onTap: onTap,
    );
  }
}

/// Filter-chip row for the four [PriceBand] values.
class _BandChipRow extends StatelessWidget {
  const _BandChipRow({
    required this.selected,
    required this.onTap,
  });

  final Set<PriceBand> selected;
  final ValueChanged<PriceBand> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Tokens.space8,
      runSpacing: Tokens.space4,
      children: [
        for (final b in PriceBand.values)
          FilterChip(
            label: Text(b.symbol),
            selected: selected.contains(b),
            onSelected: (_) => onTap(b),
          ),
      ],
    );
  }
}

