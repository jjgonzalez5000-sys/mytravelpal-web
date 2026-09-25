import 'package:flutter/material.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../l10n/app_localizations.dart';
import 'hotel_preferences.dart';
import 'restaurant_preferences.dart';

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
    required this.saveToProfile,
  });

  final TimeOfDay breakfastAt;
  final TimeOfDay lunchAt;
  final TimeOfDay dinnerAt;

  /// How far around the target meal time the Companion may slide a
  /// stop. Currently unused inside this widget but part of the public
  /// contract — reserved for a future "meal window" control.
  final Duration mealTolerance;

  /// Shared cap for both hotel and restaurant detours, kept simple so
  /// the driver has a single knob at wheel-side.
  final int maxDetourMinutes;

  final Set<PriceBand> mealPriceBands;
  final Set<PriceBand> hotelPriceBands;

  /// When true, the caller should also write these tweaks back to the
  /// user profile so they become the new default for future trips.
  final bool saveToProfile;
}

/// Show the Companion pre-flight sheet.
///
/// Returns the driver's overrides on confirm, or `null` when the sheet
/// is dismissed (swipe down, back button, tap outside).
Future<CompanionOverrides?> showCompanionPreflightSheet(
  BuildContext context, {
  required HotelPreferences initialHotel,
  required RestaurantPreferences initialRestaurant,
  required TripProfile? initialProfile,
}) {
  return showModalBottomSheet<CompanionOverrides>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _CompanionPreflightSheet(
      initialHotel: initialHotel,
      initialRestaurant: initialRestaurant,
      initialProfile: initialProfile,
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
  });

  final HotelPreferences initialHotel;
  final RestaurantPreferences initialRestaurant;
  final TripProfile? initialProfile;

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

  void _onConfirm() {
    Navigator.of(context).pop(
      CompanionOverrides(
        breakfastAt: _breakfast,
        lunchAt: _lunch,
        dinnerAt: _dinner,
        // No dedicated slider yet — fall back to the profile's typical
        // stop duration so downstream code has a sensible non-zero
        // value. The public contract keeps the field for when we surface
        // a tolerance control.
        mealTolerance: Duration(
          minutes:
              widget.initialProfile?.meals.typicalStopMinutes ?? 45,
        ),
        maxDetourMinutes: _maxDetourMinutes,
        mealPriceBands: _mealBands,
        hotelPriceBands: _hotelBands,
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

                      // 2. Meal times.
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

