import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'poi_detail_sheet.dart';

const double _earthRadiusKm = 6371.0088;

double _haversineKm(LatLon a, LatLon b) {
  final lat1 = a.lat * math.pi / 180.0;
  final lat2 = b.lat * math.pi / 180.0;
  final dLat = (b.lat - a.lat) * math.pi / 180.0;
  final dLon = (b.lon - a.lon) * math.pi / 180.0;
  final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return _earthRadiusKm *
      2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
}

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
    this.destination,
    this.origin,
    this.routeGeometry = const [],
    this.selectedNightHotels = const {},
    this.onToggleNightHotel,
    this.showHotelSections = true,
  });
  final List<DayPlan> days;
  final DateFormat timeFormat;

  /// Full hotels list from the response.
  final List<Hotel> hotels;

  /// When false, no hotel-related content renders in any day
  /// (no "HOTELES CERCA DE PERNOCTA", no "cerca del destino"
  /// block, no empty-state). The user explicitly opted OUT of
  /// hotel search on the plan form so a hotel section — even
  /// an empty one — reads as noise.
  final bool showHotelSections;

  /// Trip endpoints + geometry for POI detail sheet.
  final LatLon? destination;
  final LatLon? origin;
  final List<LatLon> routeGeometry;

  /// Which hotel the user has picked for each night, keyed by
  /// day index (1-based). Empty when nothing picked. The child
  /// `_SleepHotelsBlock` renders the picked one with a filled
  /// check icon and the others with an "add" icon.
  final Map<int, Hotel> selectedNightHotels;

  /// Fired when the user taps the add/remove hotel button on a
  /// row. Parent screen stores the pick and re-computes the
  /// total trip cost.
  final void Function(int dayIndex, Hotel hotel)? onToggleNightHotel;

  static const int _maxSleepHotels = 5;

  /// Rank hotels by real great-circle distance to `coord` and drop
  /// anything past `_maxHotelKmFromSleep`. Testers reported day-1
  /// showing Bucarest hotels (destination) for a Zurich→Bucarest
  /// sleep stop near Munich — the old L2-in-degrees ranking was
  /// fine, but with a corridor-wide hotel pool skewed to big
  /// cities the top-3 could still be 1000 km away. Cap + haversine
  /// makes "cerca del punto de pernocta" mean what it says.
  ///
  /// Returned pairs carry the km distance so the UI can render it
  /// next to each row.
  List<(Hotel, double)> _hotelsNear(LatLon coord) {
    final scored = <(Hotel, double)>[];
    for (final h in hotels) {
      final km = _haversineKm(coord, h.coordinate);
      if (km > _maxHotelKmFromSleep) continue;
      scored.add((h, km));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return scored.take(_maxSleepHotels).toList();
  }

  static const double _maxHotelKmFromSleep = 60.0;

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
                              // Km from origin gives the user a
                              // spatial sense of where the meal
                              // lands along the route — testers
                              // asked for it after seeing the hero
                              // hide it.
                              '${_slotLabel(l, m.slot)}  ·  '
                              '${timeFormat.format(m.at.toLocal())}  ·  '
                              'km ${m.distanceFromOriginKm.toStringAsFixed(0)}'
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
                  if (d.sleepCoord != null && showHotelSections) ...[
                    const SizedBox(height: Tokens.space8),
                    _SleepHotelsBlock(
                      entries: hotels.isEmpty
                          ? const []
                          : _hotelsNear(d.sleepCoord!),
                      hotelsPresent: hotels.isNotEmpty,
                      isDestination: false,
                      origin: origin,
                      destination: destination,
                      routeGeometry: routeGeometry,
                      dayIndex: d.dayIndex,
                      selectedHotel: selectedNightHotels[d.dayIndex],
                      onToggleHotel: onToggleNightHotel,
                    ),
                  ],
                ],
                // Last day (no sleepAt): show hotels near destination
                if (d.sleepAt == null &&
                    d.dayIndex == days.length &&
                    destination != null &&
                    hotels.isNotEmpty &&
                    showHotelSections) ...[
                  const SizedBox(height: Tokens.space8),
                  _SleepHotelsBlock(
                    entries: _hotelsNear(destination!),
                    hotelsPresent: true,
                    isDestination: true,
                    origin: origin,
                    destination: destination,
                    routeGeometry: routeGeometry,
                    dayIndex: d.dayIndex,
                    selectedHotel: selectedNightHotels[d.dayIndex],
                    onToggleHotel: onToggleNightHotel,
                  ),
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
    required this.entries,
    required this.hotelsPresent,
    this.isDestination = false,
    this.origin,
    this.destination,
    this.routeGeometry = const [],
    this.dayIndex,
    this.selectedHotel,
    this.onToggleHotel,
  });
  final List<(Hotel, double)> entries;
  final bool hotelsPresent;
  final bool isDestination;
  final LatLon? origin;
  final LatLon? destination;
  final List<LatLon> routeGeometry;

  /// 1-based day index this block belongs to (for the parent's
  /// per-day picked-hotel map).
  final int? dayIndex;

  /// The hotel the user picked for this night, if any. Rendered
  /// with a filled check + primary color so the pick stands out.
  final Hotel? selectedHotel;

  /// Callback that flips a hotel between picked / unpicked.
  final void Function(int dayIndex, Hotel hotel)? onToggleHotel;

  bool _isPicked(Hotel h) {
    final s = selectedHotel;
    if (s == null) return false;
    return s.name == h.name &&
        s.coordinate.lat == h.coordinate.lat &&
        s.coordinate.lon == h.coordinate.lon;
  }

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
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final label = isDestination
        ? l.daySleepHotelsLabelDestination
        : l.daySleepHotelsLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: t.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
        for (final (h, km) in entries)
          Builder(builder: (context) {
            final picked = _isPicked(h);
            final canPick = dayIndex != null && onToggleHotel != null;
            return InkWell(
              onTap: () => showPoiDetailSheet(
                context,
                kind: PoiKind.hotel,
                name: h.name,
                subtitle:
                    '${h.priceEurPerNight.toStringAsFixed(0)} €/night · '
                    '${km.toStringAsFixed(1)} km',
                poi: h.coordinate,
                origin: origin ?? h.coordinate,
                destination: destination ?? h.coordinate,
                routeGeometry: routeGeometry,
                attributes: h.attributes,
                icon: Icons.hotel_outlined,
                accent: scheme.tertiary,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.hotel_outlined, size: 14,
                        color: picked ? scheme.primary : scheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${h.name}  ·  '
                        '${h.priceEurPerNight.toStringAsFixed(0)} €/night  ·  '
                        '${isDestination ? l.hotelDistFromDestination(km.toStringAsFixed(1)) : l.hotelDistFromStop(km.toStringAsFixed(1))}',
                        style: t.bodySmall?.copyWith(
                          fontWeight:
                              picked ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    // "Add / picked" toggle: filled check when this
                    // hotel is the night's pick, outline plus when
                    // available to add. Tapping FIRES the parent's
                    // toggle so the cost card updates the same tick.
                    if (canPick) ...[
                      const SizedBox(width: 4),
                      InkResponse(
                        onTap: () => onToggleHotel!(dayIndex!, h),
                        radius: 18,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            picked
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                            size: 20,
                            color: picked
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ] else
                      Icon(Icons.chevron_right, size: 16,
                          color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            );
          }),
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
