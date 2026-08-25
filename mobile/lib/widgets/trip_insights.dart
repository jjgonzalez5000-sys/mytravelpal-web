import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Amber-tinted advisory shown above the fuel section when the backend
/// found a materially cheaper country to refuel in before crossing.
/// Explicit numeric savings so the user knows why it's worth acting.
class FuelArbitrageBanner extends StatelessWidget {
  const FuelArbitrageBanner({super.key, required this.hint});
  final FuelArbitrage hint;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_gas_station, color: scheme.tertiary, size: 22),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.fuelArbitrageTitle,
                  style: t.titleSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.fuelArbitrageBody(
                    hint.cheaperCountry.displayName,
                    hint.cheaperMedianEurPerL.toStringAsFixed(2),
                    hint.pricierCountry.displayName,
                    hint.pricierMedianEurPerL.toStringAsFixed(2),
                    hint.estimatedTankSavingEur.toStringAsFixed(0),
                  ),
                  style: t.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the per-day breakdown for multi-day trips. One card per
/// day showing distance range, meal stops on that day, and the
/// overnight-sleep marker at the end (all days except the last).
class DayPlanSection extends StatelessWidget {
  const DayPlanSection({
    super.key,
    required this.days,
    required this.timeFormat,
    this.hotels = const [],
  });
  final List<DayPlan> days;
  final DateFormat timeFormat;

  /// Full hotels list from the response. We rank the closest ones to
  /// each day's `sleepCoord` and render up to `_maxSleepHotels` under
  /// the overnight marker.
  final List<Hotel> hotels;

  static const int _maxSleepHotels = 3;

  List<Hotel> _hotelsNear(LatLon coord) {
    final scored = hotels.map((h) {
      final dLat = h.coordinate.lat - coord.lat;
      final dLon = h.coordinate.lon - coord.lon;
      // L2 in degrees is fine for ranking; distance is only used to
      // sort, not to display.
      return (h, dLat * dLat + dLon * dLon);
    }).toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return scored.take(_maxSleepHotels).map((e) => e.$1).toList();
  }

  String _slotLabel(AppLocalizations l, String slot) => switch (slot) {
        'breakfast' => l.profileBreakfast,
        'lunch' => l.profileLunch,
        'dinner' => l.profileDinner,
        _ => slot,
      };

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in days) ...[
          Container(
            padding: const EdgeInsets.all(Tokens.space16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dayHeaderRange(
                    d.dayIndex,
                    d.fromKm.toStringAsFixed(0),
                    d.toKm.toStringAsFixed(0),
                  ),
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (d.mealStops.isNotEmpty) ...[
                  const SizedBox(height: Tokens.space8),
                  for (final m in d.mealStops)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.restaurant, size: 14,
                              color: scheme.tertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_slotLabel(l, m.slot)}  ·  '
                              '${timeFormat.format(m.at.toLocal())}'
                              '${m.restaurantName != null ? "  ·  ${m.restaurantName}" : ""}',
                              style: t.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (d.sleepAt != null) ...[
                  const SizedBox(height: Tokens.space8),
                  Row(
                    children: [
                      Icon(Icons.bedtime, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        l.daySleepMarker(
                          timeFormat.format(d.sleepAt!.toLocal()),
                        ),
                        style: t.labelMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (d.sleepCoord != null) ...[
                    const SizedBox(height: Tokens.space8),
                    _SleepHotelsBlock(
                      hotels: hotels.isEmpty
                          ? const []
                          : _hotelsNear(d.sleepCoord!),
                      hotelsPresent: hotels.isNotEmpty,
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: Tokens.space12),
        ],
      ],
    );
  }
}

class _SleepHotelsBlock extends StatelessWidget {
  const _SleepHotelsBlock({
    required this.hotels,
    required this.hotelsPresent,
  });
  final List<Hotel> hotels;
  final bool hotelsPresent;  // whether the plan itself has any hotels

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    if (!hotelsPresent) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          l.daySleepHotelsEmpty,
          style: t.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    if (hotels.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.daySleepHotelsLabel.toUpperCase(),
          style: t.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
        for (final h in hotels)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hotel_outlined, size: 14,
                    color: scheme.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${h.name}  ·  '
                    '${h.priceEurPerNight.toStringAsFixed(0)} €/night  ·  '
                    '${h.distanceFromRouteKm.toStringAsFixed(1)} km off route',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Sticky-ish hero above the sections: "Próxima parada sugerida:
/// comida en Zaragoza a las 13:20". Only rendered when the trip has
/// at least one upcoming meal stop.
class NextStopHero extends StatelessWidget {
  const NextStopHero({
    super.key,
    required this.mealStop,
    required this.timeFormat,
    this.onTap,
  });
  final MealStopOpt mealStop;
  final DateFormat timeFormat;
  final VoidCallback? onTap;

  String _slotLabel(AppLocalizations l) {
    // Backend enum values map to plain strings ("breakfast" / "lunch"
    // / "dinner"). Localise each; unknown → raw string as safe
    // degradation.
    switch (mealStop.slot) {
      case 'breakfast':
        return l.profileBreakfast;
      case 'lunch':
        return l.profileLunch;
      case 'dinner':
        return l.profileDinner;
      default:
        return mealStop.slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final name = mealStop.restaurantName ?? '—';
    // Only tappable when the meal stop has a coordinate to plot — a
    // stop with no restaurant chosen (rare, when the corridor has no
    // restaurants at the meal hour) opens an empty sheet, so we hide
    // the affordance.
    final canOpen = onTap != null && mealStop.restaurantCoordinate != null;
    final content = Padding(
      padding: const EdgeInsets.all(Tokens.space16),
      child: Row(
        children: [
          Icon(Icons.restaurant_menu, color: scheme.primary, size: 22),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.nextStopHeroLabel.toUpperCase(),
                  style: t.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.nextStopHeroBody(
                    _slotLabel(l),
                    name,
                    timeFormat.format(mealStop.at.toLocal()),
                  ),
                  style: t.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canOpen)
            Icon(
              Icons.map_outlined,
              color: scheme.onPrimaryContainer, size: 18,
            ),
        ],
      ),
    );
    final decoration = BoxDecoration(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
    );
    if (!canOpen) {
      return Container(decoration: decoration, child: content);
    }
    // Wrapped in Material + InkWell so the ripple respects the
    // rounded corners of the hero.
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: decoration,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
