import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'added_stops_map_sheet.dart';
import 'poi_detail_sheet.dart';
import 'skeleton.dart';

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

/// Filter buckets for the rest-stops row inside `DayPlanSection`.
/// `all` shows every stop the backend returned; the other three
/// hide stops that don't carry the matching OSM-tag-derived flag.
enum _RestStopFilter { all, kidFriendly, petFriendly, rvFriendly }

/// Does this stop pass the current filter? `all` always passes.
bool _restStopMatchesFilter(RestStop r, _RestStopFilter f) => switch (f) {
      _RestStopFilter.all => true,
      _RestStopFilter.kidFriendly => r.kidFriendly,
      _RestStopFilter.petFriendly => r.petFriendly,
      _RestStopFilter.rvFriendly => r.rvFriendly,
    };

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
    this.overriddenDayIndices = const {},
    this.activeReplanDayIndex,
    this.fuelPrices = const [],
  });

  /// Fuel stations along the whole route. The day card filters this
  /// list by its own `fromKm..toKm` range and renders up to 2 rows
  /// per day (cheapest by savings-vs-median). Empty = no fuel row
  /// on the day card. Kept plan-wide so the day cards stay in sync
  /// when enrich fires a swap.
  final List<FuelPrice> fuelPrices;
  final List<DayPlan> days;
  final DateFormat timeFormat;

  /// Fired when the driver taps the pencil icon on a day header —
  /// parent opens the per-day override sheet + re-plans. `null` hides
  /// the icon entirely.
  final void Function(int dayIndex)? onEditDay;

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

  // Widened from 60 → 90 km (2026-08-31) so multi-day trips
  // through sparse regions (interior Iberia, Massif Central,
  // Ardèche) still surface at least a handful of overnight
  // options. The backend densifies with the same widened radius.
  static const double _maxHotelKmFromSleep = 90.0;

  String _dayHeaderLabel(AppLocalizations l, DayPlan d, int totalDays) {
    final isFirst = d.dayIndex == 1;
    final isLast = d.dayIndex == totalDays;
    final from = d.fromName
        ?? (isFirst ? originName : null)
        ?? _cityFromDay(d, useTo: false);
    final to = d.toName
        ?? (isLast ? destinationName : null)
        ?? _cityFromDay(d, useTo: true);
    if (from != null && to != null) {
      return l.dayHeaderCity(d.dayIndex, from, to);
    }
    if (from != null) {
      return l.dayHeaderCity(d.dayIndex, from, 'km ${d.toKm.toStringAsFixed(0)}');
    }
    if (to != null) {
      return l.dayHeaderCity(d.dayIndex, 'km ${d.fromKm.toStringAsFixed(0)}', to);
    }
    return l.dayHeaderRange(
      d.dayIndex,
      d.fromKm.toStringAsFixed(0),
      d.toKm.toStringAsFixed(0),
    );
  }

  /// Returns a rough city label for the start or end of a day, derived
  /// from meal-stop city hints when the backend didn't provide named
  /// endpoints. [useTo] = true picks from the last stop (day's end).
  String? _cityFromDay(DayPlan d, {required bool useTo}) {
    if (d.mealStops.isEmpty) return null;
    final stop = useTo ? d.mealStops.last : d.mealStops.first;
    return stop.cityHint;
  }

  void _showDayMap(BuildContext context, DayPlan d) {
    final slice = _DayRouteThumb._sliceGeometry(routeGeometry, d.fromKm, d.toKm, days.last.toKm);
    if (slice.isEmpty) return;
    final scheme = Theme.of(context).colorScheme;
    final boundsPoints = <ll.LatLng>[...slice];
    if (d.sleepCoord != null) {
      boundsPoints.add(ll.LatLng(d.sleepCoord!.lat, d.sleepCoord!.lon));
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
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
              userAgentPackageName: 'com.mytravelpal.mytravelpal',
            ),
            fmap.PolylineLayer(
              polylines: [
                fmap.Polyline(
                  points: slice,
                  color: Colors.blue.shade700,
                  strokeWidth: 4.0,
                ),
              ],
            ),
            if (d.sleepCoord != null)
              fmap.MarkerLayer(
                markers: [
                  fmap.Marker(
                    point: ll.LatLng(d.sleepCoord!.lat, d.sleepCoord!.lon),
                    width: 28, height: 28,
                    child: Icon(Icons.bedtime, color: scheme.primary, size: 28),
                  ),
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

    return StatefulBuilder(
      builder: (context, setState) {
        _RestStopFilter filter = _restStopFilter;
        void setFilter(_RestStopFilter f) {
          setState(() {
            _restStopFilter = f;
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (anyFlagged) ...[
              _RestStopFilterChips(
                current: filter,
                onChanged: setFilter,
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
  // the same ResultScreen frame. This is intentionally a mutable
  // field on a StatelessWidget: DayPlanSection is only reconstructed
  // when the plan itself changes, at which point resetting to "all"
  // is the right behaviour (the driver re-planned).
  static _RestStopFilter _restStopFilter = _RestStopFilter.all;

  /// Split day-card composition out of `build` so `StatefulBuilder`
  /// can call it repeatedly on filter change without duplicating
  /// the (large) inline layout code below.
  List<Widget> _buildDay(
    BuildContext context,
    AppLocalizations l,
    ColorScheme scheme,
    TextTheme t,
    DayPlan d,
    _RestStopFilter filter,
  ) {
    // Original body inlined below unchanged. The `filter` parameter
    // is applied at the rest-stops loop only.
    return [
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.isDwellDay
                                ? l.dayHeaderDwell(d.dayIndex, d.dwellLabel!)
                                : _dayHeaderLabel(l, d, days.length),
                            style: t.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
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
                          ),
                          // Show start + end times on EVERY driving day.
                          // Previously only day 1 showed the departure
                          // ("wake_hour is a constant, not news") — but
                          // testers reported they still had to scroll
                          // back up to remember when each day starts /
                          // ends. Showing it inline per day makes each
                          // card self-contained.
                          if (!d.isDwellDay) ...[
                            const SizedBox(height: 2),
                            Text(
                              l.dayDriveWindow(
                                timeFormat.format(d.startAt.toLocal()),
                                timeFormat.format(
                                  (d.sleepAt ?? d.endAt).toLocal(),
                                ),
                              ),
                              style: t.bodySmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
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
                          Icons.edit_outlined,
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
                      const SizedBox(width: Tokens.space8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showDayMap(context, d),
                        child: _DayRouteThumb(
                          routeGeometry: routeGeometry,
                          fromKm: d.fromKm,
                          toKm: d.toKm,
                          totalKm: days.last.toKm,
                          pinCoord: d.sleepCoord,
                        ),
                      ),
                    ],
                  ],
                ),
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
                  for (final m in d.mealStops)
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
                          ? () => showPoiDetailSheet(
                                context,
                                kind: PoiKind.restaurant,
                                name: m.restaurantName!,
                                subtitle: _mealSubtitle(l, m),
                                poi: m.restaurantCoordinate!,
                                origin: origin ?? m.restaurantCoordinate!,
                                destination:
                                    destination ?? m.restaurantCoordinate!,
                                routeGeometry: routeGeometry,
                                attributes: _mealAttributes(l, m),
                                icon: Icons.restaurant,
                                accent: scheme.tertiary,
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.restaurant, size: 14,
                              color: m.restaurantName == null && enrichPending
                                  ? scheme.tertiary.withValues(alpha: 0.4)
                                  : scheme.tertiary),
                          const SizedBox(width: 6),
                          if (m.restaurantName == null && enrichPending)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${timeFormat.format(m.at.toLocal())}  ·  ${_slotLabel(l, m.slot)}',
                                    style: t.bodySmall,
                                  ),
                                  const SizedBox(height: 3),
                                  Skeleton(
                                    width: 160,
                                    height: 10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            )
                          else Expanded(
                            child: Text(
                              // Time is now the row's anchor (driver
                              // scans clock-first). Fall back to the
                              // meal slot name when no restaurant was
                              // picked; append the km / city and slot
                              // label as secondary context.
                              () {
                                final time =
                                    timeFormat.format(m.at.toLocal());
                                final primaryName = m.restaurantName
                                    ?? _slotLabel(l, m.slot);
                                final where = m.cityHint != null
                                    ? l.resultCityHint(m.cityHint!)
                                    : 'km ${m.distanceFromOriginKm.toStringAsFixed(0)}';
                                final base = l.dayMealStopAt(
                                  time, primaryName,
                                );
                                // Add the "cerca de X" / km hint and
                                // the slot label only when they add
                                // signal (i.e. we already showed a
                                // restaurant name; otherwise the slot
                                // label is already the primary).
                                if (m.restaurantName != null) {
                                  return '$base  ·  $where  ·  '
                                      '${_slotLabel(l, m.slot)}';
                                }
                                return '$base  ·  $where';
                              }(),
                              style: t.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
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
                  final visibleRests = d.restStops
                      .where((r) => _restStopMatchesFilter(r, filter))
                      .toList();
                  if (visibleRests.isEmpty) {
                    // While enrich is still fetching, show a subtle
                    // 2-row skeleton so the driver sees the section
                    // exists AND is loading — instead of the day
                    // card silently omitting rest stops until data
                    // arrives.
                    if (enrichPending) {
                      return Padding(
                        padding: const EdgeInsets.only(top: Tokens.space8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < 2; i++) ...[
                              Row(
                                children: [
                                  Icon(Icons.local_cafe_outlined,
                                      size: 14,
                                      color: scheme.secondary
                                          .withValues(alpha: 0.35)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Skeleton(
                                          width: double.infinity, height: 12,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        const SizedBox(height: 4),
                                        Skeleton(
                                          width: 180, height: 10,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (i == 0) const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Tokens.space8),
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
                              Icon(
                                _iconForRestStopType(r.stopType),
                                size: 16,
                                color: scheme.secondary,
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
                                        if (r.kidFriendly)
                                          Icon(Icons.child_care,
                                              size: 14,
                                              color: scheme.secondary),
                                        if (r.petFriendly)
                                          Icon(Icons.pets,
                                              size: 14,
                                              color: scheme.secondary),
                                        if (r.rvFriendly)
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
                Builder(builder: (context) {
                  final candidates = fuelPrices.where((p) =>
                    p.distanceFromOriginKm >= d.fromKm &&
                    p.distanceFromOriginKm <= d.toKm &&
                    p.priceAvailable &&
                    (p.savingsVsCountryMedianEurPerL ?? 0) > 0,
                  ).toList()
                    ..sort((a, b) => (b.savingsVsCountryMedianEurPerL ?? 0)
                        .compareTo(a.savingsVsCountryMedianEurPerL ?? 0));
                  final top = candidates.take(2).toList();
                  if (top.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Tokens.space8),
                      for (final p in top)
                        InkWell(
                          onTap: p.coordinate == null ? null : () =>
                              showPoiDetailSheet(
                                context,
                                kind: PoiKind.fuel,
                                name: p.stationName,
                                subtitle:
                                    '${p.priceEurPerL.toStringAsFixed(3)} ${p.unitLabel}'
                                    '  ·  '
                                    '−${p.savingsVsCountryMedianEurPerL!.toStringAsFixed(2)} ${p.unitLabel}',
                                poi: p.coordinate!,
                                origin: origin ?? p.coordinate!,
                                destination: destination ?? p.coordinate!,
                                routeGeometry: routeGeometry,
                                attributes: p.attributes,
                                icon: p.isChargingStation
                                    ? Icons.electric_bolt
                                    : Icons.local_gas_station_outlined,
                                accent: scheme.primary,
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
                                    '${p.priceEurPerL.toStringAsFixed(3)} ${p.unitLabel}',
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
                                    '−${p.savingsVsCountryMedianEurPerL!.toStringAsFixed(2)} ${p.unitLabel}',
                                    style: t.labelSmall?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                    return Row(
                      children: [
                        Icon(icon, size: 14, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          text,
                          style: t.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    );
                  }(),
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
                if (!d.isDwellDay && d.dayIndex == days.length) ...[
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
    required this.current,
    required this.onChanged,
  });
  final _RestStopFilter current;
  final ValueChanged<_RestStopFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget chip(_RestStopFilter f, String label, IconData? icon) {
      final selected = f == current;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label),
          avatar: icon != null
              ? Icon(icon, size: 16, color: scheme.onSurfaceVariant)
              : null,
          selected: selected,
          onSelected: (_) => onChanged(f),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip(_RestStopFilter.all, l.restStopFilterAll, null),
        chip(_RestStopFilter.kidFriendly,
            l.restStopFilterKidFriendly, Icons.child_care),
        chip(_RestStopFilter.petFriendly,
            l.restStopFilterPetFriendly, Icons.pets),
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
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.daySleepHotelsSearching,
                  style: t.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          hotelsRequested
              ? l.daySleepHotelsNotFound
              : l.daySleepHotelsEmpty,
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
    final hotelRows = [
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
    ];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: false,
        leading: Icon(Icons.hotel_outlined, size: 16, color: scheme.tertiary),
        title: Text(
          label,
          style: t.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
        subtitle: selectedHotel != null
            ? Text(
                selectedHotel!.name,
                style: t.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                '${entries.length} opciones',
                style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
        children: hotelRows,
      ),
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
                    color: scheme.onPrimaryContainer.withOpacity(0.5),
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

/// 80×56 px non-interactive route thumbnail for a single day's segment.
/// Extracts the polyline slice between [fromKm] and [toKm] proportionally,
/// fits the camera to those points, and optionally drops a pin at [pinCoord].
class _DayRouteThumb extends StatelessWidget {
  const _DayRouteThumb({
    required this.routeGeometry,
    required this.fromKm,
    required this.toKm,
    required this.totalKm,
    this.pinCoord,
  });

  final List<LatLon> routeGeometry;
  final double fromKm;
  final double toKm;
  final double totalKm;
  final LatLon? pinCoord;

  static List<ll.LatLng> _sliceGeometry(
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

  List<ll.LatLng> _slice() =>
      _sliceGeometry(routeGeometry, fromKm, toKm, totalKm);

  @override
  Widget build(BuildContext context) {
    final slice = _slice();
    if (slice.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final center = slice[slice.length ~/ 2];
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: IgnorePointer(
      child: SizedBox(
        width: 80, height: 56,
        child: fmap.FlutterMap(
          options: fmap.MapOptions(
            initialCenter: center,
            initialZoom: 8,
            interactionOptions: const fmap.InteractionOptions(
              flags: fmap.InteractiveFlag.none,
            ),
          ),
          children: [
            fmap.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mytravelpal.mytravelpal',
            ),
            fmap.PolylineLayer(
              polylines: [
                fmap.Polyline(
                  points: slice,
                  color: scheme.primary,
                  strokeWidth: 2.5,
                ),
              ],
            ),
            if (pinCoord != null)
              fmap.MarkerLayer(
                markers: [
                  fmap.Marker(
                    point: ll.LatLng(pinCoord!.lat, pinCoord!.lon),
                    width: 18, height: 18,
                    child: Icon(Icons.bedtime, color: scheme.primary, size: 18),
                  ),
                ],
              ),
          ],
        ),
      ),
      ),
    );
  }
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
                        userAgentPackageName: 'com.mytravelpal.mytravelpal',
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
