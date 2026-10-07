import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart' show appPrefsProvider, currencyCodeProvider;
import '../services/currency_service.dart' show formatMoney;
import 'added_stops_map_sheet.dart';
import 'consistency_banner.dart' show DayConsistencyChip;
import 'hotel_preferences.dart';
import 'poi_detail_sheet.dart';
import 'poi_picker_sheet.dart';
import 'restaurant_preferences.dart';
import 'skeleton.dart';

void _showHotelPrefsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Consumer(
      builder: (ctx, ref, _) {
        final prefs = ref.watch(appPrefsProvider);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: HotelPreferencesSection(
              value: prefs.hotelPrefs,
              onChanged: (v) => prefs.setHotelPrefs(v),
            ),
          ),
        );
      },
    ),
  );
}

void _showRestaurantPrefsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Consumer(
      builder: (ctx, ref, _) {
        final prefs = ref.watch(appPrefsProvider);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: RestaurantPreferencesSection(
              value: prefs.restaurantPrefs,
              onChanged: (v) => prefs.setRestaurantPrefs(v),
            ),
          ),
        );
      },
    ),
  );
}

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

/// Amber-tinted advisory shown INSIDE the day card of every night that
/// lands in the pricier country. Explicit total savings ("shift N nights
/// south → save €Y") so the driver sees the win at a glance.
class HotelArbitrageBanner extends StatelessWidget {
  const HotelArbitrageBanner({
    super.key,
    required this.hint,
    this.onTap,
  });
  final HotelArbitrage hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
      child: Container(
      padding: const EdgeInsets.all(Tokens.space12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hotel, color: scheme.tertiary, size: 20),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.hotelArbitrageTitle,
                  style: t.titleSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.hotelArbitrageBody(
                    hint.cheaperCountry.displayName,
                    hint.cheaperMedianEurPerNight.toStringAsFixed(0),
                    hint.pricierCountry.displayName,
                    hint.pricierMedianEurPerNight.toStringAsFixed(0),
                    hint.deltaPercent.toStringAsFixed(0),
                    hint.affectedDayIndices.length,
                    hint.estimatedTotalSavingEur.toStringAsFixed(0),
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
    ),  // InkWell
    );
  }
}

/// One-line reminder for follow-up nights in the pricier country.
/// Full context lives in the first-night `HotelArbitrageBanner`;
/// this just keeps the framing visible without banner fatigue.
class _HotelArbitrageMiniHint extends StatelessWidget {
  const _HotelArbitrageMiniHint({required this.hint});
  final HotelArbitrage hint;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Icons.hotel_outlined,
            size: 14, color: scheme.tertiary.withValues(alpha: 0.75)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l.hotelArbitrageMiniHint,
            style: t.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

/// Filter buckets for the rest-stops row inside `DayPlanSection`.
/// `all` shows every stop the backend returned; the other three
/// hide stops that don't carry the matching OSM-tag-derived flag.
/// Multi-select (Set) after 2026-09-28 — driver may want e.g. both
/// kid + pet friendly stops surfaced at once. Which chips actually
/// render is gated on the trip profile: only kids-friendly appears
/// if `hasKids`, etc. — no reason to offer a filter the driver
/// wouldn't use anyway.
enum _RestStopFilter { kidFriendly, petFriendly, rvFriendly }

/// Does this stop pass the current filter set? An empty set matches
/// everything (no filter active). Non-empty is an OR — the stop
/// passes if it carries ANY of the requested flags.
bool _restStopMatchesFilter(RestStop r, Set<_RestStopFilter> active) {
  if (active.isEmpty) return true;
  for (final f in active) {
    switch (f) {
      case _RestStopFilter.kidFriendly:
        if (r.kidFriendly) return true;
      case _RestStopFilter.petFriendly:
        if (r.petFriendly) return true;
      case _RestStopFilter.rvFriendly:
        if (r.rvFriendly) return true;
    }
  }
  return false;
}

/// Extra safety net on top of the backend enrichment: drop stops
/// whose stop_type is a poor bet even when they came back named.
///
/// - `unknown` stops slipped through the backend's Overpass filter
///   somehow (usually a cache miss on a coord that used to have a
///   typed match) — the driver can't tell what kind of place it is.
/// - `parking` without any amenity flag is often a random industrial
///   / roadside lay-by; drop unless SOMETHING (kid/pet/rv flag) says
///   it's a real rest facility.
bool _restStopIsReliable(RestStop r) {
  if (r.stopType == RestStopType.unknown) return false;
  if (r.stopType == RestStopType.parking &&
      !r.kidFriendly && !r.petFriendly && !r.rvFriendly) {
    return false;
  }
  return true;
}

/// Dedup rest stops that Overpass returned as separate elements but
/// clearly refer to the same physical facility (same lowercase name
/// AND within ~300 m). Keeps the first occurrence.
List<RestStop> _dedupRestStops(Iterable<RestStop> stops) {
  final out = <RestStop>[];
  for (final s in stops) {
    final key = (s.name ?? '').toLowerCase().trim();
    final duplicate = out.any((existing) {
      if (key.isEmpty) return false;
      if ((existing.name ?? '').toLowerCase().trim() != key) return false;
      final dLat = (existing.coordinate.lat - s.coordinate.lat).abs();
      final dLon = (existing.coordinate.lon - s.coordinate.lon).abs();
      // ~300 m at European latitudes: 0.003° lat ≈ 333 m, and the
      // longitude budget of 0.004° ≈ 300 m at 45° N.
      return dLat < 0.003 && dLon < 0.004;
    });
    if (!duplicate) out.add(s);
  }
  return out;
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
    this.originName,
    this.destinationName,
    this.routeGeometry = const [],
    this.selectedNightHotels = const {},
    this.onToggleNightHotel,
    this.showHotelSections = true,
    this.partialTollSkips = const [],
    this.enabledTollIndices = const {},
    this.onToggleToll,
    this.hourlyTollReport,
    this.tripDepartureAt,
    this.routeFreeFlowMinutes,
    this.routeTotalKm,
    this.addedStops = const [],
    this.weatherSegments = const [],
    this.enrichPending = false,
    this.replanning = false,
    this.hotelsRequested = true,
    this.onEditDay,
    this.onEditDayEndTime,
    this.overriddenDayIndices = const {},
    this.activeReplanDayIndex,
    this.fuelPrices = const [],
    this.addedFuelKeys = const {},
    this.onToggleFuelPick,
    this.addedRestaurantKeys = const {},
    this.onToggleRestaurantPick,
    this.addedRestStopKeys = const {},
    this.onToggleRestStop,
    this.vehicleTankL = 50.0,
    this.vehicleConsumptionL100km = 7.0,
    this.initialTankPct = 100,
    this.restaurants = const [],
    this.profileHasKids = false,
    this.profileHasPets = false,
    this.profileIsCamper = false,
    this.consistencyIssues = const [],
    this.hotelArbitrage,
    this.isEv = false,
  });

  /// Backend consistency issues (meal / sleep sanity failures)
  /// anchored to a day. Rendered inline in the matching day card
  /// via [DayConsistencyChip] so the driver sees the warning next
  /// to the day it applies to. Trip-wide issues (no `dayIndex`)
  /// stay in the global banner above the section.
  final List<ConsistencyIssue> consistencyIssues;

  /// Cross-country hotel-price gap the backend detected. Rendered as a
  /// banner INSIDE each day card whose 1-based `dayIndex` is in
  /// `hotelArbitrage.affectedDayIndices` — the driver sees the hint
  /// exactly on the days that could be moved south to save money.
  final HotelArbitrage? hotelArbitrage;

  /// True when the trip vehicle is electric — swaps the fuel-search
  /// pending copy from "gasolineras" to "electrolineras".
  final bool isEv;

  /// Keys of the meal-row restaurants currently added to the route.
  /// Shared with the standalone restaurants list so a restaurant
  /// added from either surface stays consistent. Key format:
  /// `restaurant:{name}:{lat.4},{lon.4}` — mirrors what
  /// `_restaurantTileFor` computes in result_screen.
  final Set<String> addedRestaurantKeys;

  /// Fires when the driver hits "+" (or "-") on a meal row's POI
  /// sheet. Parent stores the pick + tallies its cost into the trip
  /// cost card (same accounting as the standalone list).
  final void Function(MealStopOpt m)? onToggleRestaurantPick;

  /// Full trip-level restaurant list from the backend response.
  /// Used to populate the "Ver restaurantes cercanos" picker sheet
  /// on each meal-stop row.
  final List<Restaurant> restaurants;

  /// Trip profile flags — gate which amenity filter chips render.
  /// Only chips that match the driver's context show up (no point
  /// offering "kid friendly" filter for a solo driver).
  final bool profileHasKids;
  final bool profileHasPets;
  final bool profileIsCamper;

  /// Fuel stations along the whole route. The day card filters this
  /// list by its own `fromKm..toKm` range and renders up to 2 rows
  /// per day (cheapest by savings-vs-median). Empty = no fuel row
  /// on the day card. Kept plan-wide so the day cards stay in sync
  /// when enrich fires a swap.
  final List<FuelPrice> fuelPrices;

  /// Keys of the fuel picks currently added to the route. The row's
  /// POI sheet uses this to render "+" vs "−" (added state) so the
  /// same tap flow toggles.
  final Set<String> addedFuelKeys;

  /// Fires when the user hits "+" (or "-") on a day-card fuel row's
  /// POI sheet. Parent stores the pick + rolls its €-savings into
  /// the trip cost card.
  final void Function(FuelPrice p)? onToggleFuelPick;
  final Set<String> addedRestStopKeys;
  final void Function(RestStop r)? onToggleRestStop;
  /// Tank capacity in litres — used to estimate fill volume at each stop.
  final double vehicleTankL;
  /// Fuel consumption in L/100 km — used to estimate level depletion.
  final double vehicleConsumptionL100km;
  /// Initial tank level (0-100 %) at departure.
  final int initialTankPct;
  final List<DayPlan> days;
  final DateFormat timeFormat;

  /// Fired when the driver taps the pencil icon on a day header —
  /// parent opens the per-day override sheet + re-plans. `null` hides
  /// the icon entirely.
  final void Function(int dayIndex)? onEditDay;

  /// Fired when the driver taps the end-time label on a day's summary
  /// strip — parent shows a time picker and re-plans with a new cap.
  /// `null` = not tappable.
  final void Function(int dayIndex)? onEditDayEndTime;

  /// 1-based day indices that currently carry an active override.
  /// Used to highlight the pencil icon on those days so the driver
  /// remembers which days they've tweaked.
  final Set<int> overriddenDayIndices;

  /// True while the `/plan/enrich` future is still in flight. When
  /// true, per-day hotel blocks show a "buscando hoteles..." message
  /// instead of the misleading "activa hoteles en las preferencias"
  /// empty state (which is only correct when prefs were disabled).
  final bool enrichPending;

  /// True while a per-day override re-plan (triggered by tapping the
  /// pencil on a day header) is in flight. Same UX role as
  /// [enrichPending] for the child hotel blocks: keep the "searching"
  /// affordance instead of briefly flashing the empty state while the
  /// new plan is en route.
  final bool replanning;

  /// The 1-based day index the user just edited via the pencil sheet.
  /// While [replanning] is true, that specific day card renders a
  /// small "Recalculando..." pill so the affordance is anchored to
  /// the card that changed. Null when no replan is in flight.
  final int? activeReplanDayIndex;

  /// True when the user opted-in to hotel search (hotelMaxDetourMinutes
  /// > 0 on the plan form). Forwarded to `_SleepHotelsBlock` so the
  /// empty state can distinguish "opt-out" vs "searched but nothing
  /// on this route".
  final bool hotelsRequested;

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
  final String? originName;
  final String? destinationName;
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

  /// Full plan-wide list of partial toll skips (booth-level).
  /// The day card filters this list by its own `fromKm..toKm`
  /// range so each day shows just the tolls that fall inside.
  final List<PartialTollSkip> partialTollSkips;
  /// Indices in [partialTollSkips] the driver keeps paying — the
  /// COMPLEMENT of the "will skip" set. Kept as `enabled` (not
  /// `skipped`) to match the existing `_tollSkipEnabled` state
  /// naming in ResultScreen.
  final Set<int> enabledTollIndices;
  /// Called when the driver toggles a booth. `enabled = true`
  /// means "keep paying it"; `false` means "skip it".
  final void Function(int skipIndex, bool enabled)? onToggleToll;

  /// Optional hourly toll verdicts (Premium). When supplied
  /// together with [tripDepartureAt] / [routeFreeFlowMinutes] /
  /// [routeTotalKm], each toll row shows a coloured hint chip
  /// ("Buen momento para saltar" green / "Mala hora" amber)
  /// based on the ETA at that booth's coord.
  final HourlyTollReport? hourlyTollReport;
  final DateTime? tripDepartureAt;
  final double? routeFreeFlowMinutes;
  final double? routeTotalKm;
  final List<AddedStop> addedStops;
  final List<WeatherSegment> weatherSegments;

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
  /// Build a stable string key for a FuelPrice, matching the format used by
  /// _toggleDayFuel in result_screen so the picked-state check is consistent.
  static String _fuelKey(FuelPrice p) {
    if (p.coordinate == null) return 'fuel:${p.stationName}:nocoord';
    return 'fuel:${p.stationName}'
        ':${p.coordinate!.lat.toStringAsFixed(4)},'
        '${p.coordinate!.lon.toStringAsFixed(4)}';
  }

  /// Estimate (litersInTank, volumeToFill, savingsEur) at [station].
  ///
  /// Accounts for fuel consumed from origin and for any stations the
  /// driver has already marked as picked (those are assumed filled to
  /// the tank top at their km position).
  ({double liters, double toFill, double savings}) _fuelStateAt(
    FuelPrice station,
  ) {
    final tankL = vehicleTankL;
    final consL100 = vehicleConsumptionL100km;
    final startL = tankL * initialTankPct / 100.0;

    // Collect picked stations that come BEFORE this one on the route.
    final before = fuelPrices
        .where((p) =>
            addedFuelKeys.contains(_fuelKey(p)) &&
            p.distanceFromOriginKm < station.distanceFromOriginKm)
        .toList()
      ..sort((a, b) => a.distanceFromOriginKm.compareTo(b.distanceFromOriginKm));

    // Simulate tank level from start to each picked station, then to here.
    double liters = startL;
    double prevKm = 0.0;
    for (final s in before) {
      liters -= (s.distanceFromOriginKm - prevKm) * consL100 / 100.0;
      liters = liters.clamp(0, tankL);
      // Refuel to full at picked station.
      liters = tankL;
      prevKm = s.distanceFromOriginKm;
    }
    // Consume from last picked station (or origin) to this station.
    liters -= (station.distanceFromOriginKm - prevKm) * consL100 / 100.0;
    liters = liters.clamp(0, tankL);

    final toFill = (tankL - liters).clamp(0.0, tankL);
    final savL = (station.savingsVsCountryMedianEurPerL ?? 0.0).clamp(0.0, 10.0);
    return (liters: liters, toFill: toFill, savings: toFill * savL);
  }

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

  // Widened 60→90 (2026-08-31), then 90→150 (2026-09-30 Unterägeri→
  // Madrid tester report: day-1 sleep near Nîmes had 0 hotels because
  // nearest Provence hotels were ~100 km away — just past the 90 km
  // cap). Backend pools hotels from a 40 km corridor around the route;
  // for a long diagonal trip like CH→ES, the pool concentrates at
  // endpoints and the mid-corridor sleep stop falls outside 90 km.
  // 150 km keeps "cerca del punto de pernocta" meaningful while
  // catching one-exit-away options on long driving days.
  static const double _maxHotelKmFromSleep = 150.0;

  /// Returns `(fromLabel, toLabel)` for the day-header summary strip.
  /// Falls back through reverse-geocoded city → trip endpoint (day 1 /
  /// last day) → meal-stop city hint → rest-stop city hint → `km NN`
  /// marker, so every day always renders a two-endpoint strip even
  /// before enrich finishes.
  (String, String) _dayEndpointLabels(DayPlan d, int totalDays) {
    final isFirst = d.dayIndex == 1;
    final isLast = d.dayIndex == totalDays;
    final from = _extractCity(d.fromName)
        ?? (isFirst ? _extractCity(originName) : null)
        ?? _cityFromDay(d, useTo: false)
        ?? 'km ${d.fromKm.toStringAsFixed(0)}';
    final to = _extractCity(d.toName)
        ?? (isLast ? _extractCity(destinationName) : null)
        ?? _cityFromDay(d, useTo: true)
        ?? 'km ${d.toKm.toStringAsFixed(0)}';
    return (from, to);
  }

  /// Returns a rough city label for the start or end of a day, derived
  /// from meal-stop city hints when the backend didn't provide named
  /// endpoints. [useTo] = true picks from the last stop.
  String? _cityFromDay(DayPlan d, {required bool useTo}) {
    final mealStop = useTo ? d.mealStops.lastOrNull : d.mealStops.firstOrNull;
    return mealStop?.cityHint;
  }

  /// Extracts a short city/town name from a potentially verbose address
  /// string like "Avenue du Docteur Albert Schweitzer, Mulhouse, France".
  /// Returns null when the input is null or empty.
  String? _extractCity(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final parts = fullName.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts[0];
    // If the first part looks like a street (starts with a digit or contains
    // a common road-type keyword), skip it and use the second part.
    final streetPattern = RegExp(
      r'(^|\s)(rue|avenue|calle|street|road|boulevard|via|stra(ss|ße)e|'
      r'carretera|avenida|plaza|paseo|gasse|all[eé]e|lane|drive|place|'
      r'camino|rambla|corso|viale|straat|weg|laan)\b',
      caseSensitive: false,
    );
    final startsWithDigit = RegExp(r'^\d');
    if (streetPattern.hasMatch(parts[0]) || startsWithDigit.hasMatch(parts[0])) {
      return parts[1];
    }
    return parts[0];
  }

  void _showDayMap(BuildContext context, DayPlan d) {
    final slice = _daySliceGeometry(
      routeGeometry, d.fromKm, d.toKm, days.last.toKm,
    );
    if (slice.isEmpty) return;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    // POIs relevant to this day: hotels near the sleep coord,
    // restaurants + fuel + rest_stops with distance_from_origin_km
    // inside the day's [from_km, to_km] range. Small padding on
    // both ends so a POI right at a boundary still surfaces on the
    // day it belongs to.
    bool inRange(double km) =>
        km >= (d.fromKm - 1) && km <= (d.toKm + 1);
    final dayFuel = fuelPrices
        .where((p) => p.coordinate != null && inRange(p.distanceFromOriginKm))
        .toList(growable: false);
    final dayRests = d.restStops;
    final dayMeals = d.mealStops.where(
      (m) => m.restaurantCoordinate != null,
    ).toList(growable: false);
    // Hotels: show only the one picked for THIS night, plus a small
    // radius fallback if none picked (top 3 by proximity to sleep
    // coord). Keeps the map from becoming a wall of hotel pins.
    final dayHotels = <Hotel>[];
    final pickedH = selectedNightHotels[d.dayIndex];
    if (pickedH != null) {
      dayHotels.add(pickedH);
    } else if (d.sleepCoord != null) {
      final sc = d.sleepCoord!;
      final ranked = hotels
          .map((h) => (
                h,
                (h.coordinate.lat - sc.lat).abs() +
                    (h.coordinate.lon - sc.lon).abs(),
              ))
          .toList()
        ..sort((a, b) => a.$2.compareTo(b.$2));
      dayHotels.addAll(ranked.take(3).map((e) => e.$1));
    }

    // Bounds cover the polyline slice + every POI marker so nothing
    // is clipped off-screen on first paint.
    final boundsPoints = <ll.LatLng>[...slice];
    if (d.sleepCoord != null) {
      boundsPoints.add(ll.LatLng(d.sleepCoord!.lat, d.sleepCoord!.lon));
    }
    for (final p in dayFuel) {
      boundsPoints.add(ll.LatLng(p.coordinate!.lat, p.coordinate!.lon));
    }
    for (final m in dayMeals) {
      boundsPoints.add(ll.LatLng(
          m.restaurantCoordinate!.lat, m.restaurantCoordinate!.lon));
    }
    for (final r in dayRests) {
      boundsPoints.add(ll.LatLng(r.coordinate.lat, r.coordinate.lon));
    }
    for (final h in dayHotels) {
      boundsPoints.add(ll.LatLng(h.coordinate.lat, h.coordinate.lon));
    }

    fmap.Marker markerFor(
      double lat, double lon, IconData icon, Color color, {
      VoidCallback? onTap,
    }) =>
        fmap.Marker(
          point: ll.LatLng(lat, lon),
          width: 32, height: 32,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
          ),
        );

    // Route endpoints for the shared POI sheet — use the DAY's
    // slice endpoints so the mini-map inside the sheet shows the
    // correct segment, not the whole trip's origin/destination.
    final dayOrigin = origin ?? LatLon(
      lat: slice.first.latitude, lon: slice.first.longitude,
    );
    final dayDestination = destination ?? LatLon(
      lat: slice.last.latitude, lon: slice.last.longitude,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SizedBox(
        height: MediaQuery.of(sheetCtx).size.height * 0.6,
        child: fmap.FlutterMap(
          options: fmap.MapOptions(
            initialCameraFit: fmap.CameraFit.bounds(
              bounds: fmap.LatLngBounds.fromPoints(boundsPoints),
              padding: const EdgeInsets.all(40),
            ),
            interactionOptions: const fmap.InteractionOptions(
              flags: fmap.InteractiveFlag.pinchZoom | fmap.InteractiveFlag.drag,
            ),
          ),
          children: [
            fmap.TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mytravelpal.travel',
            ),
            fmap.PolylineLayer(
              polylines: [
                fmap.Polyline(
                  points: slice,
                  color: Colors.blue.shade700,
                  strokeWidth: 4.0,
                ),
                // Alternative toll-skip detour polylines (HERE
                // `avoid=tollRoad`). One dashed orange overlay per
                // skip whose km falls inside this day's range and
                // whose backend responded with a geometry. The
                // driver sees the real secondary road they'd take
                // instead of "+8 min +2.5 km" abstract numbers.
                for (final skip in partialTollSkips)
                  if (skip.detourGeometry.length >= 2 &&
                      inRange(skip.distanceFromOriginKm))
                    fmap.Polyline(
                      points: [
                        for (final c in skip.detourGeometry)
                          ll.LatLng(c.lat, c.lon),
                      ],
                      color: Colors.deepOrange.shade600,
                      strokeWidth: 3.5,
                      pattern: fmap.StrokePattern.dashed(
                        segments: const [10, 6],
                      ),
                    ),
              ],
            ),
            fmap.MarkerLayer(
              markers: [
                // Fuel stations — tap opens shared POI sheet with
                // fuel type + price attributes so the driver reads
                // the same detail card the day-card row surfaces.
                for (final p in dayFuel)
                  markerFor(
                    p.coordinate!.lat, p.coordinate!.lon,
                    p.isChargingStation
                        ? Icons.electric_bolt
                        : Icons.local_gas_station,
                    Colors.deepOrange.shade600,
                    onTap: () => showPoiDetailSheet(
                      sheetCtx,
                      kind: PoiKind.fuel,
                      name: p.stationName,
                      subtitle: '${p.priceEurPerL.toStringAsFixed(3)}'
                          ' ${p.unitLabel}',
                      poi: p.coordinate!,
                      origin: dayOrigin,
                      destination: dayDestination,
                      routeGeometry: routeGeometry,
                      attributes: p.attributes,
                      icon: p.isChargingStation
                          ? Icons.electric_bolt
                          : Icons.local_gas_station_outlined,
                      accent: Colors.deepOrange.shade600,
                    ),
                  ),
                // Rest stops (only named / typed ones — parking-
                // only anchors already dropped upstream via
                // `_restStopIsReliable`).
                for (final r in dayRests)
                  markerFor(
                    r.coordinate.lat, r.coordinate.lon,
                    _iconForRestStopType(r.stopType),
                    Colors.brown.shade400,
                    onTap: r.name == null ? null : () =>
                        _openRestStopSheet(
                          sheetCtx, r,
                          origin ?? r.coordinate,
                          destination ?? r.coordinate,
                          routeGeometry,
                        ),
                  ),
                // Meal restaurants
                for (final m in dayMeals)
                  markerFor(
                    m.restaurantCoordinate!.lat,
                    m.restaurantCoordinate!.lon,
                    Icons.restaurant, Colors.orange.shade700,
                    onTap: () => showPoiDetailSheet(
                      sheetCtx,
                      kind: PoiKind.restaurant,
                      name: m.restaurantName ?? '',
                      subtitle: _mealSubtitle(l, m),
                      poi: m.restaurantCoordinate!,
                      origin: dayOrigin,
                      destination: dayDestination,
                      routeGeometry: routeGeometry,
                      attributes: _mealAttributes(l, m),
                      icon: Icons.restaurant,
                      accent: Colors.orange.shade700,
                    ),
                  ),
                // Hotels (picked + fallback near sleep coord)
                for (final h in dayHotels)
                  markerFor(
                    h.coordinate.lat, h.coordinate.lon,
                    Icons.hotel, scheme.primary,
                    onTap: () => showPoiDetailSheet(
                      sheetCtx,
                      kind: PoiKind.hotel,
                      name: h.name,
                      subtitle:
                          '${h.priceEurPerNight.toStringAsFixed(0)} €'
                          '  ·  +${h.detourMinutes.toStringAsFixed(0)} min',
                      poi: h.coordinate,
                      origin: dayOrigin,
                      destination: dayDestination,
                      routeGeometry: routeGeometry,
                      attributes: h.attributes,
                      icon: Icons.hotel_outlined,
                      accent: scheme.primary,
                      photoUrl: h.photoUrl,
                    ),
                  ),
                // Sleep waypoint marker on top so it's not hidden by
                // the hotel pin for the same night.
                if (d.sleepCoord != null)
                  markerFor(d.sleepCoord!.lat, d.sleepCoord!.lon,
                      Icons.bedtime, scheme.tertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _slotLabel(AppLocalizations l, String slot) => switch (slot) {
        'breakfast' => l.profileBreakfast,
        'lunch' => l.profileLunch,
        'dinner' => l.profileDinner,
        'break' => l.mealSlotBreak,
        _ => slot,
      };

  /// Subtitle for the meal-tap POI sheet: slot · price band · city.
  String _mealSubtitle(AppLocalizations l, MealStopOpt m) {
    final parts = <String>[_slotLabel(l, m.slot)];
    if (m.restaurantPriceEurPerMeal != null) {
      parts.add('${m.restaurantPriceEurPerMeal!.toStringAsFixed(0)} €');
    }
    if (m.cityHint != null) parts.add(m.cityHint!);
    return parts.join(' · ');
  }

  /// Attribute chips for the meal-tap POI sheet. Keeps the format
  /// consistent with rest-stop / hotel sheets that already use a
  /// key→value map for `attributes`.
  Map<String, String> _mealAttributes(AppLocalizations l, MealStopOpt m) {
    final out = <String, String>{};
    out['km'] = m.distanceFromOriginKm.toStringAsFixed(0);
    out['slot'] = _slotLabel(l, m.slot);
    if (m.restaurantPriceEurPerMeal != null) {
      out['price'] = '${m.restaurantPriceEurPerMeal!.toStringAsFixed(0)} €';
    }
    if (m.cityHint != null) out['city'] = m.cityHint!;
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Any rest stop across ANY day carrying at least one amenity
    // flag = the filter chip row is useful. When every rest stop
    // has all three flags off (OSM tags absent for the whole
    // corridor), the row is dead weight and we hide it.
    final anyFlagged = days.any((d) => d.restStops.any(
          (r) => r.kidFriendly || r.petFriendly || r.rvFriendly,
        ));

    // Only offer the amenity filter chips that MATCH the trip
    // profile — no point showing "kid friendly" filter for a solo
    // driver. Empty set → chip row is skipped entirely.
    final available = <_RestStopFilter>{
      if (profileHasKids) _RestStopFilter.kidFriendly,
      if (profileHasPets) _RestStopFilter.petFriendly,
      if (profileIsCamper) _RestStopFilter.rvFriendly,
    };

    // Filters that match the profile default to ON — a family with
    // kids expects "kid friendly" pre-checked on the first render.
    // The static _userTouchedFilter flip lets manual toggles (incl.
    // unchecking a default-ON) win over the auto-init.
    if (!_userTouchedFilter && available.isNotEmpty) {
      _restStopFilter = {...available};
    }

    return StatefulBuilder(
      builder: (context, setState) {
        final Set<_RestStopFilter> filter = _restStopFilter;
        void toggleFilter(_RestStopFilter f) {
          setState(() {
            _userTouchedFilter = true;
            if (_restStopFilter.contains(f)) {
              _restStopFilter = {..._restStopFilter}..remove(f);
            } else {
              _restStopFilter = {..._restStopFilter, f};
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (anyFlagged && available.isNotEmpty) ...[
              _RestStopFilterChips(
                available: available,
                active: filter,
                onToggle: toggleFilter,
              ),
              const SizedBox(height: Tokens.space8),
            ],
            for (final d in days) ..._buildDay(
              context, l, scheme, t, d, filter,
            ),
          ],
        );
      },
    );
  }

  // Filter state persists across rebuilds of DayPlanSection within
  // the same ResultScreen frame. Set-based (multi-select) since
  // 2026-09-28. Empty set = no filter, matches everything.
  //
  // Default init: filters that match the trip profile pre-check
  // themselves on first render (a family with kids sees
  // "kid friendly" already active). Once the user toggles ANY chip
  // (including unchecking a default-ON one), `_userTouchedFilter`
  // flips true and manual state wins — the auto-init doesn't
  // second-guess them on subsequent rebuilds.
  static Set<_RestStopFilter> _restStopFilter = <_RestStopFilter>{};
  static bool _userTouchedFilter = false;

  /// Split day-card composition out of `build` so `StatefulBuilder`
  /// can call it repeatedly on filter change without duplicating
  /// the (large) inline layout code below.
  List<Widget> _buildDay(
    BuildContext context,
    AppLocalizations l,
    ColorScheme scheme,
    TextTheme t,
    DayPlan d,
    Set<_RestStopFilter> filter,
  ) {
    // Original body inlined below unchanged. The `filter` parameter
    // is applied at the rest-stops loop only.
    const dayAccents = [
      Color(0xFFF59E0B), // amber  – day 1
      Color(0xFF10B981), // mint   – day 2
      Color(0xFFA78BFA), // lilac  – day 3
      Color(0xFF38BDF8), // sky    – day 4
    ];
    final dayAccent = dayAccents[(d.dayIndex - 1) % dayAccents.length];
    return [
          Container(
            padding: const EdgeInsets.all(Tokens.space16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
              border: Border(
                left: BorderSide(color: dayAccent, width: 2),
                top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5)),
                right: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5)),
                bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Day pill + date/km subtitle + right-side
                // actions (in-flight pill, pencil edit, map opener).
                // The mini-map thumb previously anchored here was
                // demoted to a Map icon button so the primary summary
                // strip (line 2) can span the full width — driver
                // scans hours + city names first, opens the map on tap.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        d.isDwellDay
                            ? l.dayHeaderDwell(d.dayIndex, d.dwellLabel!)
                            : l.dayTabLabel(d.dayIndex),
                        style: t.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: Tokens.space8),
                    Expanded(
                      child: Text(
                        () {
                          final date = DateFormat('EEE, d MMM',
                                  Localizations.localeOf(context)
                                      .toString())
                              .format(d.startAt.toLocal());
                          if (d.isDwellDay) return date;
                          final km = (d.toKm - d.fromKm).round();
                          return '$date  ·  $km km';
                        }(),
                        style: t.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Anchored "Recalculando..." pill for the day
                    // that carries the in-flight override edit. Sits
                    // next to the pencil so the driver's finger's
                    // origin point tells them the tap was heard while
                    // the global LinearProgressIndicator above the
                    // section reinforces "something is loading".
                    if (!d.isDwellDay &&
                        replanning &&
                        activeReplanDayIndex == d.dayIndex) ...[
                      const SizedBox(width: Tokens.space8),
                      _ReplanningPill(),
                    ],
                    // Pencil icon → per-day edit sheet (start hour +
                    // max driving hours). Only rendered on driving
                    // days (skips dwell) and only when the parent
                    // provided a handler. Highlighted primary color
                    // when the day carries an active override. Also
                    // disabled globally while any replan is in flight
                    // (the parent already passes null in that case,
                    // this is a defensive duplicate for clarity).
                    if (!d.isDwellDay && onEditDay != null) ...[
                      const SizedBox(width: Tokens.space4),
                      IconButton(
                        icon: Icon(
                          Icons.tune,
                          size: 18,
                          color: overriddenDayIndices.contains(d.dayIndex)
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        tooltip: 'Ajustar día',
                        onPressed: replanning
                            ? null
                            : () => onEditDay!(d.dayIndex),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    if (!d.isDwellDay && routeGeometry.isNotEmpty) ...[
                      const SizedBox(width: Tokens.space4),
                      IconButton(
                        icon: Icon(
                          Icons.map_outlined,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        tooltip: 'Ver mapa del día',
                        onPressed: () => _showDayMap(context, d),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                // Backend consistency issues (meal / sleep sanity
                // warnings) anchored to THIS day, inlined below the
                // header row so the driver reads the localized copy
                // next to the day it applies to.
                for (final issue in consistencyIssues
                    .where((i) => i.dayIndex == d.dayIndex))
                  DayConsistencyChip(issue: issue),
                // Line 2: primary summary strip.
                // "07:00  Toledo  →  15:32  Bordeaux" — hh:mm in
                // primary color (labelMedium bold) so the driver
                // scans clock-first, city name secondary (bodyMedium),
                // full-width tap area opens the day map sheet.
                if (!d.isDwellDay) ...[
                  const SizedBox(height: Tokens.space8),
                  Builder(builder: (context) {
                    final endpoints =
                        _dayEndpointLabels(d, days.length);
                    final startHhmm =
                        timeFormat.format(d.startAt.toLocal());
                    final endHhmm = timeFormat.format(
                      (d.sleepAt ?? d.endAt).toLocal(),
                    );
                    final mapTap = routeGeometry.isNotEmpty
                        ? () => _showDayMap(context, d)
                        : null;
                    final endTimeTap = onEditDayEndTime != null &&
                            !replanning
                        ? () => onEditDayEndTime!(d.dayIndex)
                        : null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          // Left half: start time + origin city → arrow
                          Expanded(
                            child: InkWell(
                              onTap: mapTap,
                              borderRadius:
                                  BorderRadius.circular(Tokens.radiusMd),
                              child: Row(
                                children: [
                                  Text(
                                    startHhmm,
                                    style: t.labelMedium?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      endpoints.$1,
                                      style: t.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ),
                          // Right half: end time (tappable to edit) + destination city
                          InkWell(
                            onTap: endTimeTap,
                            borderRadius:
                                BorderRadius.circular(Tokens.radiusMd),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    endHhmm,
                                    style: t.labelMedium?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (endTimeTap != null) ...[
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.expand_circle_down_outlined,
                                      size: 13,
                                      color: scheme.primary
                                          .withValues(alpha: 0.6),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: InkWell(
                              onTap: mapTap,
                              borderRadius:
                                  BorderRadius.circular(Tokens.radiusMd),
                              child: Text(
                                endpoints.$2,
                                style: t.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                // Weather segments overlapping this day's km range.
                Builder(builder: (context) {
                  final dayWeather = weatherSegments.where((w) =>
                    w.fromKm < d.toKm && w.toKm > d.fromKm,
                  ).toList();
                  if (dayWeather.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: Tokens.space8),
                    child: Row(
                      children: [
                        for (final w in dayWeather) ...[
                          if (dayWeather.indexOf(w) > 0)
                            const SizedBox(width: Tokens.space12),
                          Icon(w.iconData, size: 16,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            w.temperatureC != null
                                ? '${w.temperatureC!.round()}°'
                                : w.localizedLabel(l),
                            style: t.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                if (d.waypointAnchors.isNotEmpty) ...[
                  const SizedBox(height: Tokens.space12),
                  _WaypointTimeline(
                    anchors: d.waypointAnchors,
                    dayFromKm: d.fromKm,
                  ),
                ],
                if (d.mealStops.isNotEmpty) ...[
                  const SizedBox(height: Tokens.space8),
                  // Single unified "filtrando restaurantes" line when
                  // ANY meal is still pending, instead of repeating
                  // it below every breakfast/lunch/dinner row
                  // (tester report 2026-09-30: three identical
                  // italic pending lines felt noisy).
                  if (enrichPending &&
                      d.mealStops.any((m) => m.restaurantName == null))
                    const SizedBox.shrink(),
                  for (final m in d.mealStops)
                    Builder(builder: (context) {
                      // Restaurants near this meal-stop coordinate —
                      // used to populate the "Ver restaurantes" picker.
                      // Use restaurantCoordinate first (actual pick),
                      // fall back to generic stop coordinate.
                      final mCoord =
                          m.restaurantCoordinate ?? m.coordinate;
                      final nearbyRestaurants = (mCoord != null &&
                              restaurants.isNotEmpty)
                          ? restaurantsNear(restaurants, mCoord)
                          : <(Restaurant, double)>[];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            // Tapping the meal row opens the shared POI
                            // detail sheet (mini-map + POI marker +
                            // amenity chips) when the meal has an actual
                            // restaurant pick. Pre-enrich rows (name
                            // still null) stay unclickable — there's
                            // nothing to show yet, and the skeleton makes
                            // that visible.
                            onTap: (m.restaurantName != null
                                    && m.restaurantCoordinate != null)
                                ? () {
                                    final coord = m.restaurantCoordinate!;
                                    final key =
                                        'restaurant:${m.restaurantName!}:'
                                        '${coord.lat.toStringAsFixed(4)},'
                                        '${coord.lon.toStringAsFixed(4)}';
                                    final isAdded =
                                        addedRestaurantKeys.contains(key);
                                    showPoiDetailSheet(
                                      context,
                                      kind: PoiKind.restaurant,
                                      name: m.restaurantName!,
                                      subtitle: _mealSubtitle(l, m),
                                      poi: coord,
                                      origin: origin ?? coord,
                                      destination: destination ?? coord,
                                      routeGeometry: routeGeometry,
                                      attributes: _mealAttributes(l, m),
                                      icon: Icons.restaurant,
                                      accent: scheme.tertiary,
                                      isAdded: isAdded,
                                      onAddToRoute:
                                          onToggleRestaurantPick == null
                                          ? null
                                          : () =>
                                              onToggleRestaurantPick!(m),
                                    );
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: (m.restaurantName == null &&
                                                enrichPending
                                            ? scheme.tertiary
                                                .withValues(alpha: 0.4)
                                            : scheme.tertiary)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.restaurant, size: 14,
                                      color: m.restaurantName == null &&
                                              enrichPending
                                          ? scheme.tertiary
                                              .withValues(alpha: 0.4)
                                          : scheme.tertiary),
                                ),
                                const SizedBox(width: 6),
                                if (m.restaurantName == null &&
                                    enrichPending)
                                  // Minimal placeholder: time + slot
                                  // only. The single "filtrando
                                  // restaurantes" spinner sits above
                                  // the meal loop and covers ALL
                                  // pending meals at once.
                                  Expanded(
                                    child: Text(
                                      '${timeFormat.format(m.at.toLocal())}  ·  '
                                      '${_slotLabel(l, m.slot)}',
                                      style: t.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                else Expanded(
                                  child: Text(
                                    () {
                                      final time = timeFormat
                                          .format(m.at.toLocal());
                                      final primaryName =
                                          m.restaurantName ??
                                          _slotLabel(l, m.slot);
                                      final where = m.cityHint != null
                                          ? l.resultCityHint(
                                              m.cityHint!)
                                          : 'km ${m.distanceFromOriginKm.toStringAsFixed(0)}';
                                      final base = l.dayMealStopAt(
                                        time, primaryName,
                                      );
                                      if (m.restaurantName != null) {
                                        return '$base  ·  $where  ·  '
                                            '${_slotLabel(l, m.slot)}';
                                      }
                                      return '$base  ·  $where';
                                    }(),
                                    style: t.bodySmall,
                                  ),
                                ),
                                // Inline add-to-route toggle.
                                if (m.restaurantCoordinate != null &&
                                    onToggleRestaurantPick != null) ...[
                                  const SizedBox(width: 4),
                                  _AddRouteIconButton(
                                    isAdded: addedRestaurantKeys.contains(
                                      'restaurant:${m.restaurantName}:'
                                      '${m.restaurantCoordinate!.lat.toStringAsFixed(4)},'
                                      '${m.restaurantCoordinate!.lon.toStringAsFixed(4)}',
                                    ),
                                    onTap: () => onToggleRestaurantPick!(m),
                                  ),
                                ],
                              ],
                            ),
                            ),
                          ),
                          // "Ver restaurantes cercanos" button — only
                          // shown when enrich has finished and we have
                          // restaurant alternatives near this stop.
                          if (!enrichPending &&
                              nearbyRestaurants.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: TextButton(
                                onPressed: () =>
                                    showRestaurantPickerSheet(
                                  context,
                                  title: l.poiPickerRestaurants,
                                  entries: nearbyRestaurants,
                                  onPicked: (_) {},
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  l.poiPickerRestaurants,
                                  style: t.labelSmall?.copyWith(
                                      color: scheme.primary),
                                ),
                              ),
                            ),
                          // No restaurant found + enrich done + no
                          // alternatives → offer prefs adjustment.
                          if (!enrichPending &&
                              nearbyRestaurants.isEmpty &&
                              m.restaurantName == null)
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: TextButton(
                                onPressed: () =>
                                    _showRestaurantPrefsSheet(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  l.noRestaurantsAdjustPrefs,
                                  style: t.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                ],
                // Rest stops: same clock-first pattern. Rendered when
                // the backend flagged any along this day's km range —
                // usually short coffee / stretch pauses the driver
                // will naturally take. Time is computed from the day
                // start + cumulative driving hours (pause-adjusted).
                // Rest stops passing the current filter. When the
                // driver picks e.g. `Con mascota`, stops without
                // `pet_friendly=true` are hidden — the header
                // filter is applied here, per-day.
                Builder(builder: (context) {
                  // Triple-verification pipeline for the day's rest
                  // stops before they hit the UI:
                  //   1) reliability screen (drops unknown/parking-
                  //      without-amenities);
                  //   2) proximity+name dedup;
                  //   3) profile filter — with a SOFT fallback: if
                  //      the filter empties this day, we show all
                  //      reliable stops instead of a blank card and
                  //      flag it with a hint (better a stop 30 min
                  //      later that lacks the tag than no stop at all).
                  // While enrich is still in flight, hide unnamed
                  // rest stops. Pre-enrich rows fall back to a bare
                  // "km X" label which is worse than showing nothing
                  // for a beat and popping the real place name in
                  // when Overpass answers.
                  final rawStops = enrichPending
                      ? d.restStops.where((r) => r.name != null)
                      : d.restStops;
                  final reliable = _dedupRestStops(
                    rawStops.where(_restStopIsReliable),
                  );
                  final matched = reliable
                      .where((r) => _restStopMatchesFilter(r, filter))
                      .toList();
                  final bool widened = filter.isNotEmpty && matched.isEmpty;
                  final visibleRests = widened ? reliable : matched;
                  if (visibleRests.isEmpty) {
                    if (enrichPending) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Row(children: [
                          SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6, color: scheme.primary)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.enrichPulseRestStops,
                            style: t.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic))),
                        ]),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Tokens.space8),
                      if (widened) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer
                                .withValues(alpha: 0.55),
                            borderRadius:
                                BorderRadius.circular(Tokens.radiusSm),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.zoom_out_map,
                                  size: 14,
                                  color: scheme.onTertiaryContainer),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l.restStopsWidenedHint,
                                  style: t.labelSmall?.copyWith(
                                    color: scheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      for (final r in visibleRests)
                        // Row is wholly tappable → opens the shared
                        // POI detail sheet with the mini-map + POI
                        // marker + amenity chips. The (i) info icon
                        // inside the row keeps its own onTap for the
                        // concise "why this stop" reason sheet, so
                        // the driver can pick between "see on map"
                        // (whole row) and "why" (icon only).
                        InkWell(
                          onTap: () => _openRestStopSheet(
                            context, r, origin, destination,
                            routeGeometry,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: scheme.secondary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconForRestStopType(r.stopType),
                                  size: 16,
                                  color: scheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Primary line: time · name (if
                                    // backend matched one) · duration.
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: [
                                        Text(
                                          () {
                                            final span = d.toKm - d.fromKm;
                                            final frac = span > 0
                                                ? ((r.distanceFromOriginKm -
                                                            d.fromKm) /
                                                        span)
                                                    .clamp(0.0, 1.0)
                                                : 0.0;
                                            final elapsed = d.endAt
                                                .difference(d.startAt);
                                            final at = d.startAt.add(
                                              Duration(
                                                milliseconds: (elapsed
                                                            .inMilliseconds *
                                                        frac)
                                                    .round(),
                                              ),
                                            );
                                            final displayName = r.name ??
                                                'km ${r.distanceFromOriginKm.toStringAsFixed(0)}';
                                            return '${timeFormat.format(at.toLocal())}  ·  $displayName  ·  ${r.recommendedBreakMinutes} min';
                                          }(),
                                          style: t.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        // Amenity icons: when a filter
                                        // is active, only render the
                                        // icons the driver actively
                                        // asked for. A stop that
                                        // happens to be pet-friendly
                                        // AND kid-friendly won't show
                                        // the pet icon to a
                                        // kid-filter user (they don't
                                        // care about pet). Empty
                                        // filter = show every flag
                                        // the stop carries.
                                        if (r.kidFriendly &&
                                            (filter.isEmpty ||
                                                filter.contains(_RestStopFilter
                                                    .kidFriendly)))
                                          Icon(Icons.child_care,
                                              size: 14,
                                              color: scheme.secondary),
                                        if (r.petFriendly &&
                                            (filter.isEmpty ||
                                                filter.contains(_RestStopFilter
                                                    .petFriendly)))
                                          Icon(Icons.pets,
                                              size: 14,
                                              color: scheme.secondary),
                                        if (r.rvFriendly &&
                                            (filter.isEmpty ||
                                                filter.contains(_RestStopFilter
                                                    .rvFriendly)))
                                          Icon(Icons.rv_hookup,
                                              size: 14,
                                              color: scheme.secondary),
                                      ],
                                    ),
                                    // Secondary line: the backend-composed
                                    // reason. Only shown when the backend
                                    // sent one (skip for anonymous stops).
                                    if (r.reason != null &&
                                        r.reason!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Text(
                                          r.reason!,
                                          style: t.labelSmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _showRestStopWhy(context, r),
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              // Inline add-to-route toggle for rest stops.
                              if (onToggleRestStop != null) ...[
                                const SizedBox(width: 2),
                                _AddRouteIconButton(
                                  isAdded: addedRestStopKeys.contains(
                                    'reststop:${r.name ?? "noname"}:'
                                    '${r.coordinate.lat.toStringAsFixed(4)},'
                                    '${r.coordinate.lon.toStringAsFixed(4)}',
                                  ),
                                  onTap: () => onToggleRestStop!(r),
                                ),
                              ],
                            ],
                          ),
                        ),
                        ),
                    ],
                  );
                }),
                // Cheap fuel stops within this day's km range.
                // Only surfaces stations that are (a) inside the
                // day tramo, (b) cheaper than their country median.
                // Cap at 2 rows per day so the card doesn't
                // sprawl; tap opens the shared POI sheet.
                Consumer(builder: (context, ref, _) {
                  final ccy = ref.watch(currencyCodeProvider);
                  final candidates = fuelPrices.where((p) =>
                    p.distanceFromOriginKm >= d.fromKm &&
                    p.distanceFromOriginKm <= d.toKm &&
                    p.priceAvailable &&
                    (p.savingsVsCountryMedianEurPerL ?? 0) > 0,
                  ).toList()
                    ..sort((a, b) => (b.savingsVsCountryMedianEurPerL ?? 0)
                        .compareTo(a.savingsVsCountryMedianEurPerL ?? 0));
                  final top = candidates.take(2).toList();
                  if (top.isEmpty) {
                    if (enrichPending) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Row(children: [
                          SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6, color: scheme.primary)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            isEv ? l.enrichPulseChargers : l.enrichPulseFuel,
                            style: t.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic))),
                        ]),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Tokens.space8),
                      for (final p in top)
                        Builder(builder: (context) {
                          final coordSuffix = p.coordinate == null
                              ? ':nocoord'
                              : ':${p.coordinate!.lat.toStringAsFixed(4)},'
                                  '${p.coordinate!.lon.toStringAsFixed(4)}';
                          final fuelKey = 'fuel:${p.stationName}$coordSuffix';
                          final isAdded = addedFuelKeys.contains(fuelKey);
                          return InkWell(
                          onTap: p.coordinate == null ? null : () =>
                              showPoiDetailSheet(
                                context,
                                kind: PoiKind.fuel,
                                name: p.stationName,
                                subtitle:
                                    '${formatMoney(p.priceEurPerL, ccy, decimals: 3)}/L'
                                    '  ·  '
                                    '−${formatMoney(p.savingsVsCountryMedianEurPerL!, ccy, decimals: 3)}/L',
                                poi: p.coordinate!,
                                origin: origin ?? p.coordinate!,
                                destination: destination ?? p.coordinate!,
                                routeGeometry: routeGeometry,
                                attributes: p.attributes,
                                icon: p.isChargingStation
                                    ? Icons.electric_bolt
                                    : Icons.local_gas_station_outlined,
                                accent: scheme.primary,
                                isAdded: isAdded,
                                onAddToRoute: onToggleFuelPick == null
                                    ? null
                                    : () => onToggleFuelPick!(p),
                              ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  p.isChargingStation
                                      ? Icons.electric_bolt
                                      : Icons.local_gas_station_outlined,
                                  size: 14, color: scheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${p.stationName}  ·  '
                                    'km ${p.distanceFromOriginKm.toStringAsFixed(0)}  ·  '
                                    '${formatMoney(p.priceEurPerL, ccy, decimals: 3)}/L',
                                    style: t.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '−${formatMoney(p.savingsVsCountryMedianEurPerL!, ccy, decimals: 3)}/L',
                                    style: t.labelSmall?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                // Tank state chip: estimated fill + savings.
                                if (vehicleConsumptionL100km > 0 &&
                                    vehicleTankL > 0 &&
                                    (p.savingsVsCountryMedianEurPerL ?? 0) > 0) ...[
                                  const SizedBox(width: 4),
                                  Builder(builder: (ctx) {
                                    final state = _fuelStateAt(p);
                                    if (state.toFill < 1) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.primaryContainer
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Consumer(
                                        builder: (ctx, ref, _) {
                                          final ccy = ref.watch(currencyCodeProvider);
                                          return Text(
                                            '~${state.toFill.toStringAsFixed(0)} L'
                                            ' · ~${formatMoney(state.savings, ccy)}',
                                            style: t.labelSmall?.copyWith(
                                              color: scheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }),
                                ],
                                // Inline add-to-route toggle.
                                if (onToggleFuelPick != null &&
                                    p.coordinate != null) ...[
                                  const SizedBox(width: 4),
                                  _AddRouteIconButton(
                                    isAdded: isAdded,
                                    onTap: () => onToggleFuelPick!(p),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                        }),
                    ],
                  );
                }),
                if (d.sleepAt != null) ...[
                  const SizedBox(height: Tokens.space8),
                  () {
                    final isLastDay = d.dayIndex == days.length;
                    final icon = d.isDwellDay
                        ? Icons.hotel
                        : isLastDay
                            ? Icons.location_on
                            : Icons.bedtime;
                    final text = d.isDwellDay
                        ? l.daySleepStay(d.dwellLabel!)
                        : isLastDay
                            ? l.dayArrivalMarker(
                                timeFormat.format(d.sleepAt!.toLocal()))
                            : l.daySleepMarker(
                                timeFormat.format(d.sleepAt!.toLocal()));
                    final isSleepRow = !d.isDwellDay && !isLastDay;
                    final sleepEditTap =
                        isSleepRow && onEditDayEndTime != null && !replanning
                            ? () => onEditDayEndTime!(d.dayIndex)
                            : null;
                    final row = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14,
                            color: isSleepRow
                                ? const Color(0xFFF59E0B)
                                : scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          text,
                          style: t.labelMedium?.copyWith(
                            color: isSleepRow
                                ? const Color(0xFF10B981)
                                : scheme.primary,
                          ),
                        ),
                        if (sleepEditTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ],
                    );
                    return sleepEditTap != null
                        ? InkWell(
                            onTap: sleepEditTap,
                            borderRadius:
                                BorderRadius.circular(Tokens.radiusSm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 2, horizontal: 2),
                              child: row,
                            ),
                          )
                        : row;
                  }(),
                  // Cross-country hotel-price hint. Full banner on
                  // the FIRST affected day so the driver sees the
                  // savings framing; subsequent affected days get a
                  // one-line reminder to avoid banner fatigue on
                  // trips with 3+ nights in the pricier country.
                  if (hotelArbitrage != null &&
                      hotelArbitrage!.affectedDayIndices.contains(d.dayIndex)) ...[
                    const SizedBox(height: Tokens.space8),
                    if (hotelArbitrage!.affectedDayIndices.first == d.dayIndex)
                      HotelArbitrageBanner(
                        hint: hotelArbitrage!,
                        onTap: d.sleepCoord != null
                            ? () => showHotelPickerSheet(
                                  context,
                                  title: l.hotelsNearYourRoute,
                                  entries: _hotelsNear(d.sleepCoord!),
                                  currentHotel:
                                      selectedNightHotels[d.dayIndex],
                                  onPicked: (h) =>
                                      onToggleNightHotel!(d.dayIndex, h),
                                )
                            : null,
                      )
                    else
                      _HotelArbitrageMiniHint(hint: hotelArbitrage!),
                  ],
                  if (d.sleepCoord != null && showHotelSections) ...[
                    const SizedBox(height: Tokens.space8),
                    _SleepHotelsBlock(
                      entries: hotels.isEmpty
                          ? const []
                          : _hotelsNear(d.sleepCoord!),
                      hotelsPresent: hotels.isNotEmpty,
                      enrichPending: enrichPending || replanning,
                      hotelsRequested: hotelsRequested,
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
                    enrichPending: enrichPending || replanning,
                    hotelsRequested: hotelsRequested,
                    isDestination: true,
                    origin: origin,
                    destination: destination,
                    routeGeometry: routeGeometry,
                    dayIndex: d.dayIndex,
                    selectedHotel: selectedNightHotels[d.dayIndex],
                    onToggleHotel: onToggleNightHotel,
                  ),
                ],
                // Per-day tolls block. Rendered when this day's
                // km range intersects any partial toll skips
                // (booth-level). Same state as the standalone
                // toll-skips card — toggling here reflects there
                // and vice-versa because both write to the same
                // Set at ResultScreenState level.
                Builder(builder: (context) {
                  final dayTolls = <(int, PartialTollSkip)>[];
                  for (var i = 0;
                      i < partialTollSkips.length; i++) {
                    final s = partialTollSkips[i];
                    if (s.distanceFromOriginKm >= d.fromKm &&
                        s.distanceFromOriginKm <= d.toKm) {
                      dayTolls.add((i, s));
                    }
                  }
                  if (dayTolls.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: Tokens.space8),
                    child: _DayTollsBlock(
                      dayTolls: dayTolls,
                      enabledTollIndices: enabledTollIndices,
                      onToggleToll: onToggleToll,
                      hourlyReport: hourlyTollReport,
                      tripDepartureAt: tripDepartureAt,
                      routeFreeFlowMinutes: routeFreeFlowMinutes,
                      routeTotalKm: routeTotalKm,
                    ),
                  );
                }),
                // Short last-day warning: when the final leg is very
                // short the planner may want to skip the extra hotel.
                // Suppressed on single-day trips — the copy talks
                // about "advancing more the day before", which is
                // nonsense when there IS no day before (tester
                // report 2026-09-30).
                if (!d.isDwellDay &&
                    d.dayIndex == days.length &&
                    days.length > 1) ...[
                  Builder(builder: (ctx) {
                    final km = (d.toKm - d.fromKm).round();
                    if (km >= 150) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: Tokens.space8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 14,
                              color: scheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l.shortLastDayWarning('$km'),
                              style: t.bodySmall
                                  ?.copyWith(color: scheme.primary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                // User-added stops (hotels, restaurants, fuel)
                // that fall within this day's km range.
                Builder(builder: (context) {
                  final dayAdded = addedStops.where((s) =>
                    s.distanceFromOriginKm != null &&
                    s.distanceFromOriginKm! >= d.fromKm &&
                    s.distanceFromOriginKm! <= d.toKm,
                  ).toList();
                  if (dayAdded.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: Tokens.space8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in dayAdded)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(s.icon, size: 14,
                                    color: scheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: t.bodySmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space12),
    ];
  }
}

/// Row icon that hints at the shape of the stop — a coffee cup for
/// generic areas / unknown, a fuel pump for gas stations, etc. Kept
/// as a plain function (no state, no context) so it can be reused
/// from the "why this stop" sheet header too.
IconData _iconForRestStopType(RestStopType type) {
  switch (type) {
    case RestStopType.serviceArea:
      return Icons.local_cafe_outlined;
    case RestStopType.gasStation:
      return Icons.local_gas_station_outlined;
    case RestStopType.restArea:
      return Icons.park_outlined;
    case RestStopType.caravanSite:
      return Icons.rv_hookup;
    case RestStopType.parking:
      return Icons.local_parking_outlined;
    case RestStopType.unknown:
      return Icons.local_cafe_outlined;
  }
}

/// Opens the shared POI detail sheet (mini-map + amenity chips +
/// Google Maps CTA) for a rest stop. Fired when the driver taps the
/// row itself (as opposed to the `(i)` info icon, which surfaces
/// the concise "why this stop" WHY sheet via `_showRestStopWhy`).
/// Origin/destination default to the stop itself if the caller
/// didn't have them handy — the shared sheet only uses them for the
/// route polyline overlay and gracefully degrades to no polyline.
Future<void> _openRestStopSheet(
  BuildContext context,
  RestStop stop,
  LatLon? origin,
  LatLon? destination,
  List<LatLon> routeGeometry,
) {
  final scheme = Theme.of(context).colorScheme;
  // Build the attribute grid from the RestStop facts. Keys follow the
  // OSM-tag-style used by hotels/restaurants so the sheet's `_icons`
  // fallback + `_prettifyValue('yes')` logic reuses cleanly. Values
  // that need a unit are pre-formatted into human strings.
  final attributes = <String, String>{
    'km': stop.distanceFromOriginKm.toStringAsFixed(0),
    'driving':
        '${stop.cumulativeDrivingHours.toStringAsFixed(1)} h',
    'break': '${stop.recommendedBreakMinutes} min',
    'type': stop.stopType.code,
    if (stop.kidFriendly) 'kid_friendly': 'yes',
    if (stop.petFriendly) 'pet_friendly': 'yes',
    if (stop.rvFriendly) 'rv_friendly': 'yes',
    if (stop.reason != null && stop.reason!.isNotEmpty)
      'note': stop.reason!,
  };
  final safeOrigin = origin ?? stop.coordinate;
  final safeDestination = destination ?? stop.coordinate;
  // Fallback when the backend didn't match a named POI within the
  // search radius: anchor the sheet to a distance-based label so the
  // driver still gets a stable identifier.
  final displayName =
      stop.name ?? 'km ${stop.distanceFromOriginKm.toStringAsFixed(0)}';
  final subtitle =
      '${stop.distanceFromOriginKm.toStringAsFixed(0)} km  ·  '
      '${stop.recommendedBreakMinutes} min';
  return showPoiDetailSheet(
    context,
    kind: PoiKind.rest,
    name: displayName,
    subtitle: subtitle,
    poi: stop.coordinate,
    origin: safeOrigin,
    destination: safeDestination,
    routeGeometry: routeGeometry,
    attributes: attributes,
    icon: _iconForRestStopType(stop.stopType),
    accent: scheme.secondary,
  );
}

/// Opens a bottomsheet explaining WHY the backend picked this stop:
/// the amenity flags that matched (kid / pet / RV) and the safety
/// rationale (EU 561/2006 driving-hours guidance). Called from the
/// `Icons.info_outline` icon at the end of each rest-stop row.
Future<void> _showRestStopWhy(BuildContext context, RestStop stop) {
  final l = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final t = Theme.of(context).textTheme;

  final reasons = <(IconData, String)>[
    // Backend-composed WHY leads when present — it can reference user
    // prefs the client doesn't need to re-derive ("kid-friendly per
    // tu perfil", "gasolinera 12 c/L más barata").
    if (stop.reason != null && stop.reason!.isNotEmpty)
      (_iconForRestStopType(stop.stopType), stop.reason!),
    if (stop.kidFriendly) (Icons.child_care, l.restStopWhyKidFriendly),
    if (stop.petFriendly) (Icons.pets, l.restStopWhyPetFriendly),
    if (stop.rvFriendly) (Icons.rv_hookup, l.restStopWhyRvFriendly),
    (
      Icons.local_hospital_outlined,
      l.restStopWhySafety(
        stop.cumulativeDrivingHours.toStringAsFixed(1),
      ),
    ),
  ];

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space24, Tokens.space8, Tokens.space24, Tokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.restStopWhyTitle,
                style: t.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Tokens.space16),
            for (final (icon, reason) in reasons) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: Tokens.space12),
                  Expanded(
                    child: Text(reason,
                        style: t.bodyMedium?.copyWith(height: 1.4)),
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space12),
            ],
            const SizedBox(height: Tokens.space8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.restStopWhyClose),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Filter chip row displayed above the day cards when any rest
/// stop carries an OSM-tag amenity flag. Renders four toggles:
/// All / Familiar / Con mascota / Autocaravana. Selecting a
/// non-All chip hides rest stops that don't match the flag.
class _RestStopFilterChips extends StatelessWidget {
  const _RestStopFilterChips({
    required this.available,
    required this.active,
    required this.onToggle,
  });
  /// Which filter categories to render as chips — driven by the
  /// trip profile so a solo-traveller doesn't see a "kid friendly"
  /// filter they'd never use.
  final Set<_RestStopFilter> available;

  /// Currently-selected filters (multi-select).
  final Set<_RestStopFilter> active;

  /// Tap a chip → toggles it in the active set.
  final ValueChanged<_RestStopFilter> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget chip(_RestStopFilter f, String label, IconData icon) {
      final selected = active.contains(f);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label),
          avatar: Icon(icon,
              size: 16,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
          selected: selected,
          onSelected: (_) => onToggle(f),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          selectedColor: scheme.primary,
          checkmarkColor: scheme.onPrimary,
          labelStyle: TextStyle(
            color: selected ? scheme.onPrimary : scheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        if (available.contains(_RestStopFilter.kidFriendly))
          chip(_RestStopFilter.kidFriendly,
              l.restStopFilterKidFriendly, Icons.child_care),
        if (available.contains(_RestStopFilter.petFriendly))
          chip(_RestStopFilter.petFriendly,
              l.restStopFilterPetFriendly, Icons.pets),
        if (available.contains(_RestStopFilter.rvFriendly))
          chip(_RestStopFilter.rvFriendly,
              l.restStopFilterRvFriendly, Icons.rv_hookup),
      ]),
    );
  }
}

/// Collapsible "Peajes de este día" block. Shows a summary row
/// (total this day + count) that expands to a per-booth list
/// with individual toggles + delta (+min, +km, savings).
class _DayTollsBlock extends StatefulWidget {
  const _DayTollsBlock({
    required this.dayTolls,
    required this.enabledTollIndices,
    required this.onToggleToll,
    this.hourlyReport,
    this.tripDepartureAt,
    this.routeFreeFlowMinutes,
    this.routeTotalKm,
  });
  final List<(int, PartialTollSkip)> dayTolls;
  final Set<int> enabledTollIndices;
  final void Function(int index, bool enabled)? onToggleToll;
  final HourlyTollReport? hourlyReport;
  final DateTime? tripDepartureAt;
  final double? routeFreeFlowMinutes;
  final double? routeTotalKm;

  /// Compute the local-hour ETA at a booth given the trip's
  /// departure + free-flow minutes + total km. Returns null when
  /// any required datum is missing (older Premium-off responses).
  int? arrivalHourFor(PartialTollSkip s) {
    final departure = tripDepartureAt;
    final freeFlow = routeFreeFlowMinutes;
    final total = routeTotalKm;
    if (departure == null || freeFlow == null || total == null ||
        total <= 0) {
      return null;
    }
    final frac = (s.distanceFromOriginKm / total).clamp(0.0, 1.0);
    final eta = departure.add(
      Duration(minutes: (freeFlow * frac).round()),
    );
    return eta.toLocal().hour;
  }

  @override
  State<_DayTollsBlock> createState() => _DayTollsBlockState();
}

class _DayTollsBlockState extends State<_DayTollsBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    // Two computed totals so the collapsed header can preview the
    // impact even without expanding: `total` = billed if the
    // driver keeps ALL tolls, `savings` = what they'd save with
    // the current selection.
    var totalDayEur = 0.0;
    var currentSavingsEur = 0.0;
    var skippedCount = 0;
    for (final (idx, s) in widget.dayTolls) {
      totalDayEur += s.savingsEur; // savings_eur ≈ toll amount
      if (!widget.enabledTollIndices.contains(idx)) {
        currentSavingsEur += s.savingsEur;
        skippedCount++;
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(
          color: scheme.outlineVariant, width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space12, vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(Icons.toll_outlined,
                      size: 18, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.dayTollsHeader(
                        totalDayEur.toStringAsFixed(2),
                        widget.dayTolls.length,
                      ),
                      style: t.labelLarge,
                    ),
                  ),
                  if (currentSavingsEur > 0) ...[
                    Text(
                      '−${currentSavingsEur.toStringAsFixed(2)} €',
                      style: t.labelLarge?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(color: scheme.outlineVariant, height: 1),
            for (final (idx, s) in widget.dayTolls)
              _DayTollRow(
                skipIndex: idx,
                skip: s,
                skipped: !widget.enabledTollIndices.contains(idx),
                onToggle: widget.onToggleToll,
                arrivalHour: widget.arrivalHourFor(s),
                bestHours:
                    widget.hourlyReport?.bestHoursToSkip ?? const [],
                worstHours:
                    widget.hourlyReport?.worstHoursToSkip ?? const [],
              ),
            if (skippedCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space12, vertical: 8,
                ),
                child: Text(
                  l.dayTollsSavedSummary(
                    currentSavingsEur.toStringAsFixed(2),
                    skippedCount,
                  ),
                  style: t.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DayTollRow extends StatelessWidget {
  const _DayTollRow({
    required this.skipIndex,
    required this.skip,
    required this.skipped,
    required this.onToggle,
    this.arrivalHour,
    this.bestHours = const [],
    this.worstHours = const [],
  });
  final int skipIndex;
  final PartialTollSkip skip;
  final bool skipped;
  final void Function(int, bool)? onToggle;
  final int? arrivalHour;
  final List<int> bestHours;
  final List<int> worstHours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    // Hourly verdict badge: green if the ETA hour is in
    // `bestHours` (good time to skip), amber if in `worstHours`
    // (peak — better to pay). No chip if neither list contains
    // the hour OR if we don't have an ETA to test against.
    Widget? verdictChip;
    if (arrivalHour != null) {
      final hh = arrivalHour!.toString().padLeft(2, '0');
      if (bestHours.contains(arrivalHour)) {
        verdictChip = _TollHourChip(
          icon: Icons.trending_down,
          label: l.tollHourGoodToSkip(hh),
          color: Colors.green.shade700,
          bg: Colors.green.shade50,
        );
      } else if (worstHours.contains(arrivalHour)) {
        verdictChip = _TollHourChip(
          icon: Icons.trending_up,
          label: l.tollHourAvoidSkip(hh),
          color: Colors.orange.shade800,
          bg: Colors.orange.shade50,
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space12, vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.alt_route,
              size: 16,
              color: skipped ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skip.label,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: skipped
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${skip.savingsEur.toStringAsFixed(2)} €'
                  '  ·  +${skip.timePenaltyMinutes.round()} min'
                  '  ·  +${skip.extraDistanceKm.toStringAsFixed(1)} km',
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (verdictChip != null) ...[
                  const SizedBox(height: 4),
                  verdictChip,
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: !skipped,   // switch ON = paying (kept)
            onChanged: onToggle == null
                ? null
                : (v) => onToggle!(skipIndex, v),
          ),
        ],
      ),
    );
  }
}

class _TollHourChip extends StatelessWidget {
  const _TollHourChip({
    required this.icon, required this.label,
    required this.color, required this.bg,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
}

class _SleepHotelsBlock extends StatelessWidget {
  const _SleepHotelsBlock({
    required this.entries,
    required this.hotelsPresent,
    this.enrichPending = false,
    this.hotelsRequested = true,
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
  /// True while the /plan/enrich request is still in flight. Swaps the
  /// misleading "activa hoteles en preferencias" empty state for a
  /// live "buscando hoteles..." indicator so drivers know why the
  /// section is blank.
  final bool enrichPending;

  /// True when the user opted-in to hotel search (hotelMaxDetourMinutes
  /// > 0 on the plan form). When true + enrich finished + zero results,
  /// we show a "no hotels found on this route" hint instead of the
  /// prefs-off message. Defaults true because the parent screen already
  /// gates rendering of this block on the user having requested hotels.
  final bool hotelsRequested;
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
      // Three distinct empty states depending on WHY the block is
      // empty. Mixing them makes the app look broken.
      //   1. enrich in flight → "searching..."
      //   2. enrich finished + hotels requested → "no hotels on this
      //      route" (widen detour hint)
      //   3. hotels NOT requested → "enable hotels in prefs"
      // Case 3 is defensive — the parent gates rendering on
      // showHotelSections, so in practice we only fall into 1 or 2.
      if (enrichPending) {
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(children: [
            SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6, color: scheme.primary)),
            const SizedBox(width: 8),
            Expanded(child: Text(l.enrichPulseHotels,
              style: t.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic))),
          ]),
        );
      }
      if (!hotelsRequested) {
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
      // Hotels requested but none found — offer actionable path out.
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l.daySleepHotelsNotFound,
                style: t.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showHotelPrefsSheet(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                child: Text(
                  l.noHotelsAdjustPrefs,
                  style: t.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final label = isDestination
        ? l.daySleepHotelsLabelDestination
        : l.daySleepHotelsLabel;
    // Show the currently selected hotel (or the top-ranked one as a
    // default suggestion). The full ranked list is accessible via the
    // "Ver alternativas" button which opens the picker sheet.
    final displayHotel = selectedHotel != null
        ? entries.firstWhere(
            (e) => _isPicked(e.$1),
            orElse: () => entries.first,
          )
        : entries.first;
    final (topHotel, topKm) = displayHotel;
    final topPicked = _isPicked(topHotel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shimmer-like forest-green header stripe
        Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B4332), Colors.transparent],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Section header row: label + "Ver alternativas" button
        Row(
          children: [
            Icon(Icons.hotel_outlined, size: 14, color: scheme.tertiary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: t.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (dayIndex != null && onToggleHotel != null)
              TextButton(
                onPressed: () => showHotelPickerSheet(
                  context,
                  title: label,
                  entries: entries,
                  currentHotel: selectedHotel,
                  onPicked: (h) => onToggleHotel!(dayIndex!, h),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l.poiPickerHotels,
                  style: t.labelSmall?.copyWith(color: scheme.primary),
                ),
              ),
          ],
        ),
        // Top (or selected) hotel inline row — tappable for the detail sheet
        const SizedBox(height: 2),
        InkWell(
          onTap: () => showPoiDetailSheet(
            context,
            kind: PoiKind.hotel,
            name: topHotel.name,
            subtitle:
                '${topHotel.priceEurPerNight.toStringAsFixed(0)} €/night · '
                '${topKm.toStringAsFixed(1)} km',
            poi: topHotel.coordinate,
            origin: origin ?? topHotel.coordinate,
            destination: destination ?? topHotel.coordinate,
            routeGeometry: routeGeometry,
            attributes: topHotel.attributes,
            icon: Icons.hotel_outlined,
            accent: scheme.tertiary,
            photoUrl: topHotel.photoUrl,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (topHotel.photoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        topHotel.photoUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.hotel_outlined,
                          size: 14,
                          color: topPicked ? scheme.primary : scheme.tertiary,
                        ),
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : const Skeleton(width: 40, height: 40),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 1),
                    child: Icon(Icons.hotel_outlined, size: 14,
                        color: topPicked ? scheme.primary : scheme.tertiary),
                  ),
                Expanded(
                  child: Text(
                    '${topHotel.name}  ·  '
                    '${isDestination ? l.hotelDistFromDestination(topKm.toStringAsFixed(1)) : l.hotelDistFromStop(topKm.toStringAsFixed(1))}',
                    style: t.bodySmall?.copyWith(
                      fontWeight:
                          topPicked ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (dayIndex != null && onToggleHotel != null)
                  InkResponse(
                    onTap: () => onToggleHotel!(dayIndex!, topHotel),
                    radius: 18,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        topPicked
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        size: 20,
                        color: topPicked
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Icon(Icons.chevron_right, size: 16,
                      color: scheme.onSurfaceVariant),
              ],
            ),
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
    this.onAdd,
    this.isAdded = false,
  });
  final MealStopOpt mealStop;
  final DateFormat timeFormat;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final bool isAdded;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
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
          if (onAdd != null) ...[
            const SizedBox(height: Tokens.space8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(
                  isAdded ? Icons.check : Icons.add_location_alt_outlined,
                  size: 16,
                ),
                label: Text(isAdded ? l.addToRouteTooltip : l.addToRouteLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onPrimaryContainer,
                  side: BorderSide(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space12,
                    vertical: 6,
                  ),
                  textStyle: t.labelMedium,
                ),
                onPressed: onAdd,
              ),
            ),
          ],
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

/// Extracts the polyline slice between [fromKm] and [toKm] proportionally.
/// Used by `_showDayMap` to render the day's segment in the map sheet.
/// Was previously a static method on a `_DayRouteThumb` mini-map widget
/// that anchored the day header — the widget was removed when the header
/// swapped to a full-width hh:mm strip, so the slicer is now free-standing.
List<ll.LatLng> _daySliceGeometry(
  List<LatLon> geom, double fromKm, double toKm, double totalKm,
) {
  if (geom.isEmpty || totalKm <= 0) return [];
  final fromFrac = (fromKm / totalKm).clamp(0.0, 1.0);
  final toFrac = (toKm / totalKm).clamp(0.0, 1.0);
  final start = (fromFrac * (geom.length - 1)).round();
  final end = (toFrac * (geom.length - 1)).round();
  return geom
      .sublist(start.clamp(0, geom.length - 1),
          (end + 1).clamp(0, geom.length))
      .map((p) => ll.LatLng(p.lat, p.lon))
      .toList();
}

class _WaypointTimeline extends StatelessWidget {
  const _WaypointTimeline({
    required this.anchors,
    required this.dayFromKm,
  });

  final List<WaypointAnchor> anchors;
  final double dayFromKm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < anchors.length; i++)
          _WaypointTimelineRow(
            anchor: anchors[i],
            deltaKm: i == 0
                ? (anchors[i].km - dayFromKm).round()
                : (anchors[i].km - anchors[i - 1].km).round(),
            isFirst: i == 0,
            isLast: i == anchors.length - 1,
            lineColor: scheme.secondary,
            textStyle: t.bodySmall!,
            scheme: scheme,
          ),
      ],
    );
  }
}

class _WaypointTimelineRow extends StatelessWidget {
  const _WaypointTimelineRow({
    required this.anchor,
    required this.deltaKm,
    required this.isFirst,
    required this.isLast,
    required this.lineColor,
    required this.textStyle,
    required this.scheme,
  });

  final WaypointAnchor anchor;
  final int deltaKm;
  final bool isFirst;
  final bool isLast;
  final Color lineColor;
  final TextStyle textStyle;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const dotSize = 10.0;
    const lineWidth = 2.0;
    const leftColumnWidth = 28.0;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showWaypointSheet(context),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftColumnWidth,
              child: Column(
                children: [
                  if (!isFirst)
                    Expanded(
                      child: Container(
                        width: lineWidth,
                        color: lineColor.withValues(alpha: 0.4),
                      ),
                    ),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                      border: Border.all(color: lineColor, width: 2),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: lineWidth,
                        color: lineColor.withValues(alpha: 0.4),
                      ),
                    ),
                  if (isLast) const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      anchor.label,
                      style: textStyle.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (deltaKm > 0)
                      Text(
                        '+$deltaKm km',
                        style: textStyle.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16,
                color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showWaypointSheet(BuildContext context) {
    final t = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
            Tokens.space20, 0, Tokens.space20, Tokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(anchor.label, style: t.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space12),
            Text(
              'km ${anchor.km.toStringAsFixed(0)}',
              style: t.bodyMedium,
            ),
            if (anchor.lat != 0 && anchor.lon != 0) ...[
              const SizedBox(height: Tokens.space16),
              ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
                child: SizedBox(
                  height: 180,
                  child: fmap.FlutterMap(
                    options: fmap.MapOptions(
                      initialCenter: ll.LatLng(anchor.lat, anchor.lon),
                      initialZoom: 13,
                    ),
                    children: [
                      fmap.TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mytravelpal.travel',
                      ),
                      fmap.MarkerLayer(
                        markers: [
                          fmap.Marker(
                            point: ll.LatLng(anchor.lat, anchor.lon),
                            width: 32, height: 32,
                            child: const Icon(Icons.place,
                                color: Colors.red, size: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tiny anchored badge shown next to the pencil icon on a day header
/// while that day's per-day override re-plan is in flight. Combines
/// a spinner + "Recalculando..." label so the driver has a local
/// affordance in addition to the global LinearProgressIndicator
/// above the day plan section.
class _ReplanningPill extends StatelessWidget {
  const _ReplanningPill();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l.resultReplanning,
            style: t.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "+" / "✓" icon button used inline on day plan rows
/// (restaurants, fuel stations, rest stops) to add/remove a POI
/// from the planned route without opening the detail sheet.
class _AddRouteIconButton extends StatelessWidget {
  const _AddRouteIconButton({
    required this.isAdded,
    required this.onTap,
  });

  final bool isAdded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Icon(
          isAdded ? Icons.check_circle : Icons.add_circle_outline,
          size: 18,
          color: isAdded ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
