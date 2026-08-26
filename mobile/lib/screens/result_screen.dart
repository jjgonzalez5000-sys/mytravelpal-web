import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../domain/trip_profile.dart' show FuelType;
import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../utils/duration_format.dart';
import '../services/notifications.dart';
import '../services/review_prompter.dart';
import '../services/app_tutorial.dart';
import '../services/trip_sharing.dart';
import '../storage/saved_trip.dart';
import '../widgets/added_stops_map_sheet.dart';
import '../widgets/plan_loading_dialog.dart';
import '../widgets/aa_coach_dialog.dart';
import '../widgets/adverse_event_sheet.dart';
import '../widgets/battery_whitelist_dialog.dart';
import '../widgets/consistency_banner.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/hotel_preferences.dart' show HotelPreferences;
import '../widgets/trip_insights.dart';
import '../widgets/favorite_star_button.dart';
import '../widgets/poi_detail_sheet.dart';
import '../widgets/route_map.dart';
import '../widgets/time_window_chart.dart';
import 'narrative_screen.dart';
import 'trip_dashboard_screen.dart';

/// A trip leg the ResultScreen can jump to via an AppBar action —
/// used only for round-trip plans. When present, the screen shows a
/// swap-icon in the app bar that pushes a new ResultScreen with the
/// legs flipped (this leg becomes the "other" and vice-versa) so the
/// user can toggle between Ida and Vuelta with one tap and back
/// button to return.
///
/// Deliberately client-only: the backend still gets two independent
/// /plan requests. Keeping the state at this level avoids touching
/// the API contract.
class RoundTripLeg {
  const RoundTripLeg({
    required this.label,
    required this.request,
    required this.origin,
    required this.destination,
    required this.response,
    required this.desiredDepartureAt,
  });

  /// Localised label rendered in the AppBar pill and the swap CTA
  /// ("Ida" / "Vuelta" typically).
  final String label;
  final TripPlanRequest request;
  final GeocodeResult origin;
  final GeocodeResult destination;
  final TripPlanResponse response;
  final DateTime desiredDepartureAt;
}

/// A backend sleep-stop timestamp is only worth surfacing when it
/// reads like night. Between 20:00 and 06:00 local the preview
/// makes sense; outside that window the underlying algorithm has
/// picked a rest stop at a time no driver would call "overnight",
/// so we hide the card rather than display "sleep at 16:00"
/// nonsense. Top-level so both the promoted card and the
/// Optimizations-section row share the exact same gate.
bool isPlausibleSleepTime(DateTime at) {
  final localHour = at.toLocal().hour;
  return localHour >= 20 || localHour <= 6;
}

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    super.key,
    required this.request,
    required this.origin,
    required this.destination,
    required this.response,
    required this.desiredDepartureAt,
    this.currentLegLabel,
    this.otherLeg,
    this.hotelPrefs,
  });

  final TripPlanRequest request;
  final GeocodeResult origin;
  final GeocodeResult destination;
  final TripPlanResponse response;
  final DateTime desiredDepartureAt;

  /// Non-null when this screen is showing one leg of a round-trip.
  /// Rendered as a small pill next to the app title so the driver
  /// always knows which leg they're looking at.
  final String? currentLegLabel;

  /// The other leg of the round-trip, if any. Populated for both
  /// legs so the swap action is symmetric.
  final RoundTripLeg? otherLeg;

  /// Client-side hotel filter (stars, parking). We apply it here
  /// instead of the backend because OSM's tag coverage is spotty —
  /// a strict backend filter would erase most results. The client
  /// filter is tolerant: hotels missing the tag PASS through, only
  /// hotels that explicitly fail the tag are dropped.
  final HotelPreferences? hotelPrefs;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saved = false;
  bool _saving = false;

  /// Partial toll skip selection — held here so scroll recycling
  /// doesn't reset the user's picks (the old StatefulWidget inside
  /// the list re-ran initState on re-mount). Seeded from
  /// `worthIt` in `initState`.
  late Set<int> _tollSkipEnabled;

  // Coach-mark tutorial keys for result screen
  final _timeWindowKey = GlobalKey();
  final _tollKey = GlobalKey();

  _MapMode _mapMode = _MapMode.normal;

  List<(Hotel, double)> _topDestinationHotels(int count) {
    final dest = widget.request.destination;
    final scored = <(Hotel, double)>[];
    for (final h in _filteredHotels) {
      final km = _haversineStatic(dest, h.coordinate);
      if (km <= 60) scored.add((h, km));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return scored.take(count).toList();
  }

  static double _haversineStatic(LatLon a, LatLon b) {
    const r = 6371.0;
    final dLat = (b.lat - a.lat) * math.pi / 180;
    final dLon = (b.lon - a.lon) * math.pi / 180;
    final aLat = a.lat * math.pi / 180;
    final bLat = b.lat * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(aLat) * math.cos(bLat) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  double get _tollSkipSavingsEur {
    final skips = widget.response.partialTollSkips;
    return _tollSkipEnabled.fold(
      0.0, (sum, i) => sum + skips[i].savingsEur,
    );
  }

  double get _tollSkipPenaltyMinutes {
    final skips = widget.response.partialTollSkips;
    return _tollSkipEnabled.fold(
      0.0, (sum, i) => sum + skips[i].timePenaltyMinutes,
    );
  }

  bool _isPlausibleSleepTime(DateTime at) => isPlausibleSleepTime(at);

  /// Response hotels with the client-side stars / parking filter
  /// applied. Tolerant: hotels lacking the `stars` or `parking` tag
  /// pass through even when the user requested a filter — OSM data
  /// is patchy enough that strict enforcement would erase 80% of
  /// otherwise good candidates.
  List<Hotel> get _filteredHotels {
    final prefs = widget.hotelPrefs;
    if (prefs == null) return widget.response.hotels;
    return widget.response.hotels.where((h) {
      if (prefs.minStars > 0) {
        final raw = h.attributes['stars'];
        final stars = raw == null ? null : int.tryParse(raw);
        if (stars != null && stars < prefs.minStars) return false;
      }
      if (prefs.requireParking) {
        final p = h.attributes['parking']?.toLowerCase();
        if (p == 'no' || p == 'none') return false;
      }
      return true;
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _tollSkipEnabled = {
      for (var i = 0; i < widget.response.partialTollSkips.length; i++)
        if (widget.response.partialTollSkips[i].worthIt) i,
    };
    Future.microtask(() {
      ReviewPrompter.instance.onPlanCompleted();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.response.partialTollSkips.isNotEmpty) {
        showResultTutorial(
          context,
          timeWindowKey: _timeWindowKey,
          tollKey: _tollKey,
        );
      }
    });
  }

  /// User-added POI stops keyed by a stable id (name+coord for hotels
  /// and restaurants, station+coord for fuel). Value is the minutes we
  /// add to the trip total when the stop is selected — the physical
  /// detour for restaurants/hotels (round-trip off the corridor plus a
  /// small dwell) and a fixed refuel budget for fuel stops (no per-stop
  /// detour field on the backend yet).
  final Map<String, double> _addedStops = <String, double>{};

  static const double _fuelStopMinutes = 8.0;

  double get _addedMinutesTotal =>
      _addedStops.values.fold(0.0, (sum, v) => sum + v);

  bool _isAdded(String key) => _addedStops.containsKey(key);

  void _toggleStop(String key, double minutes) {
    setState(() {
      if (_addedStops.containsKey(key)) {
        _addedStops.remove(key);
      } else {
        _addedStops[key] = minutes;
      }
    });
  }

  void _clearAddedStops() {
    if (_addedStops.isEmpty) return;
    setState(_addedStops.clear);
  }

  /// Resolve the flat `_addedStops` map (keyed by string ids) into
  /// full `AddedStop` records with coord + label so the map sheet can
  /// plot markers. Order preserved from the API response so nearby
  /// tiles stay adjacent in the legend list.
  List<AddedStop> _resolveAddedStops() {
    if (_addedStops.isEmpty) return const [];
    final out = <AddedStop>[];
    for (final h in widget.response.hotels) {
      final key = 'hotel:${h.name}:'
          '${h.coordinate.lat.toStringAsFixed(4)},'
          '${h.coordinate.lon.toStringAsFixed(4)}';
      if (_addedStops.containsKey(key)) {
        out.add(AddedStop(
          kind: AddedStopKind.hotel,
          label: h.name,
          subtitle: '+${h.detourMinutes.toStringAsFixed(0)} min · '
              '${h.priceEurPerNight.toStringAsFixed(0)} €',
          coordinate: h.coordinate,
        ));
      }
    }
    for (final r in widget.response.restaurants) {
      final key = 'restaurant:${r.name}:'
          '${r.coordinate.lat.toStringAsFixed(4)},'
          '${r.coordinate.lon.toStringAsFixed(4)}';
      if (_addedStops.containsKey(key)) {
        out.add(AddedStop(
          kind: AddedStopKind.restaurant,
          label: r.name,
          subtitle: '+${r.detourMinutes.toStringAsFixed(0)} min · '
              '${r.priceEurPerMeal.toStringAsFixed(0)} €',
          coordinate: r.coordinate,
        ));
      }
    }
    for (final p in widget.response.fuelPrices) {
      final coordSuffix = p.coordinate == null
          ? ':nocoord'
          : ':${p.coordinate!.lat.toStringAsFixed(4)},'
              '${p.coordinate!.lon.toStringAsFixed(4)}';
      final key = 'fuel:${p.stationName}$coordSuffix';
      if (_addedStops.containsKey(key) && p.coordinate != null) {
        out.add(AddedStop(
          kind: AddedStopKind.fuel,
          label: p.stationName,
          subtitle: p.priceAvailable
              ? '${p.priceEurPerL.toStringAsFixed(3)} €/L · '
                  '${p.distanceFromOriginKm.toStringAsFixed(0)} km'
              : '${p.distanceFromOriginKm.toStringAsFixed(0)} km',
          coordinate: p.coordinate!,
        ));
      }
    }
    return out;
  }

  void _openAddedStopsMap() {
    final stops = _resolveAddedStops();
    if (stops.isEmpty) return;
    showAddedStopsMapSheet(
      context,
      stops: stops,
      origin: widget.request.origin,
      destination: widget.request.destination,
      routeGeometry: widget.response.route.geometry,
    );
  }

  /// Refetch the time-window slice with a wider ±span (bound to
  /// the slider in the departure-window card). Only re-hits /plan for
  /// the fresh windows; the rest of the response we already have
  /// keeps working. Number of candidates scales roughly with span so
  /// the chart gets denser as the driver widens it.
  Future<List<TimeWindow>> _refetchWindows(int spanHours) async {
    final api = ref.read(apiClientWithPremiumProvider);
    // 5 slots at ±3h, up to ~16 at ±12h (one every ~1.5h).
    final topN = (spanHours * 2 + 4).clamp(5, 24);
    final tuned = TripPlanRequest(
      origin: widget.request.origin,
      destination: widget.request.destination,
      desiredDepartureAt: widget.request.desiredDepartureAt,
      countries: widget.request.countries,
      // No POI expansion here — we only care about time windows.
      hotelMaxDetourMinutes: null,
      restaurantMaxDetourMinutes: null,
      includeAdverseEvents: false,
      includeTollAlternative: false,
      includeRouteComparison: false,
      includeHourlyTollAnalysis: false,
      avoidMotorways: widget.request.avoidMotorways,
      preferScenic: widget.request.preferScenic,
      timeWindowSpanHours: spanHours,
      timeWindowTopN: topN,
      tripProfile: widget.request.tripProfile,
    );
    final response = await api.planTrip(tuned);
    return response.timeWindows;
  }

  /// Tap-a-time-slot handler: replan the whole trip with the
  /// picked window as the new desired departure. We re-fire the
  /// full request (POI, tolls, adverse events, everything the
  /// current request had enabled) so the result screen the driver
  /// lands on is a real, complete plan for the new time — not a
  /// mutated view of the old one.
  ///
  /// Uses `pushReplacement` rather than `setState`-ing the current
  /// screen because too much state (persistence, notifications,
  /// TripSession, share prefs) is tied to the response's identity;
  /// swapping fields in place risks stale references. The loading
  /// dialog gives the driver feedback while the request runs.
  /// Flip `avoidMotorways` and replan. Same shape as
  /// `_replanWithDeparture` — the toll toggle in the alternative
  /// card fires this, and the driver lands on a fresh plan whose
  /// route + toll cost + optimisations all reflect the new
  /// choice.
  Future<void> _replanWithSkipTolls(bool enabled) async {
    if (enabled == widget.request.avoidMotorways) return;
    await _replan(
      newDeparture: widget.desiredDepartureAt,
      avoidMotorways: enabled,
    );
  }

  Future<void> _replanWithDeparture(TimeWindow window) async {
    // Guard: tapping the row that's already the current departure
    // is a no-op — no point burning another /plan call.
    final delta =
        window.departureAt.difference(widget.desiredDepartureAt).inMinutes.abs();
    if (delta < 1) return;
    await _replan(
      newDeparture: window.departureAt,
      avoidMotorways: widget.request.avoidMotorways,
    );
  }

  Future<void> _replan({
    required DateTime newDeparture,
    required bool avoidMotorways,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PlanLoadingDialog(),
    ));
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      // Reuse the exact request that landed us here; only the
      // desired departure changes. Downstream sections (POI,
      // optimisations, day plan) recompute against the new time.
      final replan = TripPlanRequest(
        origin: widget.request.origin,
        destination: widget.request.destination,
        desiredDepartureAt: newDeparture,
        countries: widget.request.countries,
        hotelMaxDetourMinutes: widget.request.hotelMaxDetourMinutes,
        hotelPriceBand: widget.request.hotelPriceBand,
        hotelPriceBands: widget.request.hotelPriceBands,
        hotelMinStars: widget.request.hotelMinStars,
        restaurantMaxDetourMinutes:
            widget.request.restaurantMaxDetourMinutes,
        restaurantPriceBand: widget.request.restaurantPriceBand,
        restaurantPriceBands: widget.request.restaurantPriceBands,
        restaurantCuisines: widget.request.restaurantCuisines,
        includeAdverseEvents: widget.request.includeAdverseEvents,
        adverseEventsMaxDistanceKm:
            widget.request.adverseEventsMaxDistanceKm,
        includeTollAlternative: widget.request.includeTollAlternative,
        includeRouteComparison: widget.request.includeRouteComparison,
        includeHourlyTollAnalysis:
            widget.request.includeHourlyTollAnalysis,
        avoidMotorways: avoidMotorways,
        preferScenic: widget.request.preferScenic,
        timeWindowSpanHours: widget.request.timeWindowSpanHours,
        timeWindowTopN: widget.request.timeWindowTopN,
        tripProfile: widget.request.tripProfile,
      );
      final fresh = await api.planTrip(replan);
      if (!mounted) return;
      if (dialogOpen) {
        navigator.pop();
        dialogOpen = false;
      }
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            request: replan,
            origin: widget.origin,
            destination: widget.destination,
            response: fresh,
            desiredDepartureAt: newDeparture,
            currentLegLabel: widget.currentLegLabel,
            otherLeg: widget.otherLeg,
            hotelPrefs: widget.hotelPrefs,
          ),
        ),
      );
    } catch (_) {
      if (dialogOpen && mounted) navigator.pop();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).planErrorNetwork,
            ),
          ),
        );
      }
    }
  }

  /// Which meal slots does the trip actually cross? A 10 AM → 2 PM
  /// weekend hop only crosses lunch; a Madrid→Paris overnight covers
  /// all three. We use the user's profile hours as the meal-clock and
  /// simply check whether each hour falls inside the departure→arrival
  /// window (with day-wrap for overnight trips).
  Set<MealSlot> _slotsCoveredByTrip() {
    final route = widget.response.route;
    final start = widget.desiredDepartureAt;
    final end = start.add(Duration(minutes: route.freeFlowMinutes.round()));
    final prefs = widget.request.tripProfile?.meals;
    final breakfastH = prefs?.breakfastHour ?? 8;
    final lunchH = prefs?.lunchHour ?? 13;
    final dinnerH = prefs?.dinnerHour ?? 20;
    final crossed = <MealSlot>{};
    for (final (slot, hour) in [
      (MealSlot.breakfast, breakfastH),
      (MealSlot.lunch, lunchH),
      (MealSlot.dinner, dinnerH),
    ]) {
      final candidate = DateTime(
        start.year, start.month, start.day, hour, 0,
      ).toUtc();
      // Walk one day at a time until we pass arrival — covers
      // multi-day trips where lunch repeats across days.
      var probe = candidate;
      while (probe.isBefore(end.add(const Duration(days: 1)))) {
        if (!probe.isBefore(start) && !probe.isAfter(end)) {
          crossed.add(slot);
          break;
        }
        probe = probe.add(const Duration(days: 1));
      }
    }
    return crossed;
  }

  List<Widget> _restaurantSectionsBySlot(AppLocalizations l) {
    final restaurants = widget.response.restaurants;
    final crossed = _slotsCoveredByTrip();
    // Bucket each restaurant into the first slot that (a) it advertises
    // AND (b) the trip actually crosses. Falls through to "other" if it
    // matches nothing useful.
    final buckets = <MealSlot?, List<Restaurant>>{
      MealSlot.breakfast: [],
      MealSlot.lunch: [],
      MealSlot.dinner: [],
      null: [],  // "other"
    };
    for (final r in restaurants) {
      MealSlot? placed;
      for (final s in [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner]) {
        if (crossed.contains(s) && r.openMealSlots.contains(s)) {
          placed = s;
          break;
        }
      }
      buckets[placed]!.add(r);
    }
    final out = <Widget>[];
    void addSection(String title, List<Restaurant> rows) {
      if (rows.isEmpty) return;
      out.add(Padding(
        padding: const EdgeInsets.only(top: Tokens.space16, bottom: 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ));
      out.addAll(_separated(rows.map(_restaurantTileFor).toList()));
    }

    addSection(l.mealSlotBreakfast, buckets[MealSlot.breakfast]!);
    addSection(l.mealSlotLunch, buckets[MealSlot.lunch]!);
    addSection(l.mealSlotDinner, buckets[MealSlot.dinner]!);
    addSection(l.mealSlotOther, buckets[null]!);
    return out;
  }

  Widget _restaurantTileFor(Restaurant r) {
    final key = 'restaurant:${r.name}:'
        '${r.coordinate.lat.toStringAsFixed(4)},'
        '${r.coordinate.lon.toStringAsFixed(4)}';
    return _RestaurantTile(
      restaurant: r,
      isAdded: _isAdded(key),
      onToggleAdd: () => _toggleStop(key, r.detourMinutes),
      onTap: () => showPoiDetailSheet(
        context,
        kind: PoiKind.restaurant,
        name: r.name,
        subtitle: '${r.country.displayName} · '
            '${r.priceEurPerMeal.toStringAsFixed(0)} €/meal · '
            '+${r.detourMinutes.toStringAsFixed(0)} min',
        poi: r.coordinate,
        origin: widget.request.origin,
        destination: widget.request.destination,
        routeGeometry: widget.response.route.geometry,
        attributes: r.attributes,
        icon: Icons.restaurant_outlined,
        accent: Theme.of(context).colorScheme.tertiary,
      ),
    );
  }

  TimeWindow? get _recommended {
    for (final w in widget.response.timeWindows) {
      if (w.recommended) return w;
    }
    return null;
  }

  Future<void> _save() async {
    final recommended = _recommended;
    if (recommended == null || _saving) return;
    setState(() => _saving = true);
    try {
      final storage = ref.read(tripStorageProvider);
      final profile = ref.read(tripProfileProvider);
      final l = AppLocalizations.of(context);
      final reminderMinutes = profile?.meals.reminderMinutesBefore ?? 0;
      final id = '${widget.origin.displayName}|${widget.destination.displayName}|'
          '${widget.desiredDepartureAt.toIso8601String()}';
      final notificationId = reminderMinutes > 0
          ? await NotificationService.instance.scheduleDepartureReminder(
              tripId: id,
              departureLocal: recommended.departureAt.toLocal(),
              minutesBefore: reminderMinutes,
              title: l.notificationsLeaveSoonTitle,
              body:
                  '${_shortName(widget.origin)} → ${_shortName(widget.destination)}'
                  ' · leave in $reminderMinutes min',
            )
          : null;
      final trip = SavedTrip(
        id: id,
        origin: widget.origin,
        destination: widget.destination,
        desiredDepartureAt: widget.desiredDepartureAt,
        savedAt: DateTime.now(),
        distanceKm: widget.response.route.distanceKm,
        recommendedDepartureAt: recommended.departureAt,
        recommendedMinutes: recommended.estimatedMinutes,
        countriesCrossed: widget.response.route.countriesCrossed,
        savedMinutesVsDesired:
            widget.response.savings.timeSavedMinutesVsDesired,
        savedEurVsTolls: widget.response.savings.moneySavedEurVsTolls,
        fuelCostEur:
            widget.response.optimizations?.fuelCost.totalCostEur ?? 0,
        reminderMinutesBefore: reminderMinutes,
        notificationId: notificationId,
      );
      await storage.save(trip);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.resultTripSaved)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openNarrative() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NarrativeScreen(
          planRequest: widget.request,
          originName: _shortName(widget.origin),
          destinationName: _shortName(widget.destination),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.response.route;
    final recommended = _recommended;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    // Scope tells the client which sections to surface. When absent
    // (request had no TripProfile), fall through to a permissive default.
    final scope = widget.response.recommendationScope;
    final showRestaurants = scope?.showRestaurants ?? true;
    final bedtimeHour = widget.request.tripProfile?.bedtimeHour ?? 22;

    final sections = <Widget>[
      _InteractiveMapCard(
        origin: widget.request.origin,
        destination: widget.request.destination,
        route: route,
        alternativeGeometry:
            widget.response.tollAlternative?.geometry ?? const [],
        hotels: _filteredHotels,
        restaurants: widget.response.restaurants,
        tollSkips: widget.response.partialTollSkips,
        mode: _mapMode,
        onModeChange: (m) => setState(() => _mapMode = m),
      ),
      const SizedBox(height: Tokens.space24),
      if (widget.response.consistencyIssues.isNotEmpty)
        ConsistencyBanner(issues: widget.response.consistencyIssues),
      // Next-stop hero: pulls the first meal stop of the trip so the
      // driver always sees "next planned stop" up top without hunting
      // through the Optimizations section.
      if (widget.response.optimizations != null &&
          widget.response.optimizations!.mealStops.isNotEmpty) ...[
        Builder(builder: (context) {
          final meal = widget.response.optimizations!.mealStops.first;
          return NextStopHero(
            mealStop: meal,
            timeFormat: DateFormat.Hm(),
            onTap: meal.restaurantCoordinate == null
                ? null
                : () => showPoiDetailSheet(
                      context,
                      kind: PoiKind.restaurant,
                      name: meal.restaurantName ?? '—',
                      subtitle: [
                        DateFormat.Hm().format(meal.at.toLocal()),
                        if (meal.restaurantPriceEurPerMeal != null)
                          '${meal.restaurantPriceEurPerMeal!
                                  .toStringAsFixed(0)} €/meal',
                        '${meal.distanceFromOriginKm
                                .toStringAsFixed(0)} km from origin',
                      ].join(' · '),
                      poi: meal.restaurantCoordinate!,
                      origin: widget.request.origin,
                      destination: widget.request.destination,
                      routeGeometry: widget.response.route.geometry,
                      attributes: const {},
                      icon: Icons.restaurant_menu,
                      accent: Theme.of(context).colorScheme.primary,
                    ),
          );
        }),
        const SizedBox(height: Tokens.space16),
      ],
      if (scope != null && scope.arrivalAfterBedtime) ...[
        _ArrivalHintCard(
          arrivalHour: scope.arrivalLocalHour,
          bedtimeHour: bedtimeHour,
          requiresOvernight: scope.requiresOvernight,
        ),
        const SizedBox(height: Tokens.space16),
      ],
      // Multi-day hint: promote the sleep stop only when its time
      // makes sense as a NIGHT stop. Backend occasionally emits a
      // sleep-stop at 16:00 on very long trips (Zurich→Bucharest
      // reported by a tester) because the nearest-rest-stop
      // fallback can land far from the 22:00 target. Filtering
      // client-side avoids showing garbage until the backend
      // logic is tightened.
      if (widget.response.optimizations?.sleepStop != null &&
          _isPlausibleSleepTime(
            widget.response.optimizations!.sleepStop!.at,
          )) ...[
        _MultiDaySleepPreview(
          sleepStop: widget.response.optimizations!.sleepStop!,
          hotels: widget.response.hotels,
          origin: widget.request.origin,
          destination: widget.request.destination,
          routeGeometry: widget.response.route.geometry,
        ),
        const SizedBox(height: Tokens.space16),
      ],
      if (widget.response.savings.timeSavedMinutesVsDesired > 0 ||
          widget.response.savings.moneySavedEurVsTolls > 0 ||
          _tollSkipSavingsEur > 0) ...[
        _SavingsSummaryCard(
          savings: widget.response.savings,
          tollSkipSavingsEur: _tollSkipSavingsEur,
          tollSkipPenaltyMinutes: _tollSkipPenaltyMinutes,
        ),
        const SizedBox(height: Tokens.space16),
      ],
      // Toll skips right after savings — the two are directly
      // related (skipping tolls changes the savings number above).
      if (widget.response.partialTollSkips.isNotEmpty) ...[
        Container(
          key: _tollKey,
          child: _PartialTollSkipsCard(
            skips: widget.response.partialTollSkips,
            origin: widget.request.origin,
            destination: widget.request.destination,
            routeGeometry: widget.response.route.geometry,
            enabledIndices: _tollSkipEnabled,
            hourlyReport: widget.response.hourlyTollReport,
            onToggle: (i, v) => setState(() {
              if (v) {
                _tollSkipEnabled.add(i);
              } else {
                _tollSkipEnabled.remove(i);
              }
            }),
            onToggleAll: (v) => setState(() {
              if (v) {
                _tollSkipEnabled = {
                  for (var i = 0;
                      i < widget.response.partialTollSkips.length; i++)
                    i,
                };
              } else {
                _tollSkipEnabled = {};
              }
            }),
          ),
        ),
        const SizedBox(height: Tokens.space16),
      ],
      // Tap-through: when any stops have been added, tapping this card
      // opens a bottom sheet with a map showing the route plus a pin
      // per added stop, so the driver can identify which POI they
      // toggled without scrolling back through the sections list.
      InkWell(
        onTap: _addedStops.isNotEmpty ? _openAddedStopsMap : null,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space20, vertical: Tokens.space20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(builder: (context) {
                    final fmt = ref.watch(unitFormatterProvider);
                    return StatTile(
                      label: l.resultStatDistance,
                      value: fmt.distance(route.distanceKm),
                    );
                  }),
                  StatTile(
                    label: l.resultStatFreeFlow,
                    value: _hhmm(
                      route.freeFlowMinutes + _addedMinutesTotal,
                    ),
                  ),
                  StatTile(
                    label: l.resultStatTolls,
                    value: '€${route.tollCostEur.toStringAsFixed(0)}',
                  ),
                ],
              ),
              if (_addedStops.isNotEmpty) ...[
                const SizedBox(height: Tokens.space12),
                _AddedStopsChip(
                  count: _addedStops.length,
                  minutes: _addedMinutesTotal,
                  onClear: _clearAddedStops,
                  onTap: _openAddedStopsMap,
                ),
              ],
            ],
          ),
        ),
      ),
      // Total trip cost breakdown — the answer to "how much will
      // this trip actually cost me?" Shows fuel + tolls + meals +
      // hotel in one glanceable card.
      if (widget.response.optimizations != null) ...[
        const SizedBox(height: Tokens.space16),
        _TotalTripCostCard(
          fuelCostEur: widget.response.optimizations!.fuelCost.totalCostEur,
          tollCostEur: route.tollCostEur,
          mealStops: widget.response.optimizations!.mealStops,
          sleepStop: widget.response.optimizations!.sleepStop,
          tollSkipSavingsEur: _tollSkipSavingsEur,
        ),
      ],
      // Departure section: recommendation hero + time window chart
      // merged into one visual block. The user sees "best time to
      // leave" + the chart rows they can tap to replan, all in one
      // place without a separate section header.
      if (recommended != null) ...[
        const SizedBox(height: Tokens.space24),
        _RecommendationHero(
          recommended: recommended,
          desired: widget.desiredDepartureAt,
          freeFlowMinutes: route.freeFlowMinutes,
          savedMinutesVsDesired:
              widget.response.savings.timeSavedMinutesVsDesired,
        ),
      ],
      const SizedBox(height: Tokens.space12),
      Container(
        key: _timeWindowKey,
        child: _TimeWindowExpandableCard(
          initialWindows: widget.response.timeWindows,
          desiredDepartureAt: widget.desiredDepartureAt,
          initialSpanHours: widget.request.timeWindowSpanHours,
          onFetch: _refetchWindows,
          onWindowSelect: _replanWithDeparture,
        ),
      ),
      if (widget.response.routeVariants.length >= 2) ...[
        const SizedBox(height: Tokens.space24),
        _RouteVariantsSection(variants: widget.response.routeVariants),
      ],
      if (widget.response.optimizations != null) ...[
        const SizedBox(height: Tokens.space24),
        _OptimizationsSection(
          opts: widget.response.optimizations!,
          topHotels: _topDestinationHotels(2),
          origin: widget.request.origin,
          destination: widget.request.destination,
          routeGeometry: widget.response.route.geometry,
        ),
      ],
      // Multi-day breakdown — only emitted by the backend for trips
      // that exceed the driver's daily cap or cross their bedtime.
      // Slotted between Optimisations and the Toll cards so the day
      // structure stays visible above the details.
      if (widget.response.days.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        DayPlanSection(
          days: widget.response.days,
          timeFormat: DateFormat.Hm(),
          hotels: _filteredHotels,
          destination: widget.request.destination,
          origin: widget.request.origin,
          routeGeometry: widget.response.route.geometry,
        ),
      ],
      // Single-day trips with hotels enabled: show a compact
      // "Hotels near destination" block so the user who toggled
      // on hotel search doesn't see nothing. Multi-day trips
      // already surface hotels per day via DayPlanSection.
      if (widget.response.days.isEmpty &&
          widget.hotelPrefs != null &&
          widget.hotelPrefs!.enabled &&
          _filteredHotels.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        _DestinationHotelsSection(
          hotels: _filteredHotels,
          destination: widget.request.destination,
          origin: widget.request.origin,
          routeGeometry: widget.response.route.geometry,
        ),
      ],
      // (Toll cards promoted above the day plan.)
      // Alerts section: renders the "all clear" empty state when the
      // user asked for alerts but the corridor has none — reassures
      // the driver instead of silently hiding the section.
      if (widget.request.includeAdverseEvents) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultAlerts,
          eyebrow: l.resultEyebrowAlongRoute,
          description: l.alertsAlongYourRouteDesc,
        ),
        if (widget.response.adverseEvents.isEmpty)
          EmptyStateCard(
            icon: Icons.check_circle_outline,
            title: l.emptyAlertsTitle,
            body: l.emptyAlertsBody,
            tint: scheme.tertiary,
          ),
      ],
      if (widget.response.adverseEvents.isNotEmpty) ...[
        ..._separated(
          widget.response.adverseEvents
              .map((e) => _AdverseEventTile(
                    event: e,
                    onTap: () => showAdverseEventSheet(
                      context,
                      event: e,
                      origin: widget.request.origin,
                      destination: widget.request.destination,
                      routeGeometry: widget.response.route.geometry,
                    ),
                  ))
              .toList(),
        ),
      ],
      // Rest stops section removed (tester feedback): with meals +
      // sleep already surfaced per day, a separate "recommended
      // stops" list read as redundant noise. The domain data is
      // still emitted so day_plan / consistency checks work.
      // Flat hotel list removed (2026-08-26 tester feedback):
      // hotels are now shown per-day inside DayPlanSection,
      // grouped by overnight stop / destination. The promoted
      // _MultiDaySleepPreview card stays; the scrollable flat
      // list is gone.
      if (showRestaurants &&
          widget.request.restaurantMaxDetourMinutes != null &&
          widget.request.restaurantMaxDetourMinutes! > 0 &&
          widget.response.restaurants.isEmpty) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultRestaurants, eyebrow: l.resultEyebrowNearRoute,
        ),
        EmptyStateCard(
          icon: Icons.restaurant_outlined,
          title: l.emptyRestaurantsTitle,
          body: l.emptyRestaurantsBody,
        ),
      ],
      if (showRestaurants && widget.response.restaurants.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultRestaurants, eyebrow: l.resultEyebrowNearRoute,
        ),
        ..._restaurantSectionsBySlot(l),
      ],
      if (widget.response.fuelPrices.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        if (widget.response.fuelArbitrage != null) ...[
          FuelArbitrageBanner(hint: widget.response.fuelArbitrage!),
          const SizedBox(height: Tokens.space12),
        ],
        SectionHeader(
          title: l.resultFuel, eyebrow: l.resultEyebrowAlongRoute,
        ),
        ..._separated(
          widget.response.fuelPrices.map((p) {
            final coordSuffix = p.coordinate == null
                ? ':nocoord'
                : ':${p.coordinate!.lat.toStringAsFixed(4)},'
                    '${p.coordinate!.lon.toStringAsFixed(4)}';
            final key = 'fuel:${p.stationName}$coordSuffix';
            return _FuelTile(
                    price: p,
                    isAdded: _isAdded(key),
                    onToggleAdd: () => _toggleStop(key, _fuelStopMinutes),
                    onTap: p.coordinate == null
                        ? null
                        : () => showPoiDetailSheet(
                              context,
                              kind: PoiKind.fuel,
                              name: p.stationName,
                              subtitle:
                                  '${p.country.displayName} · '
                                  '${p.priceEurPerL.toStringAsFixed(3)} €/L · '
                                  '${p.distanceFromOriginKm.toStringAsFixed(0)} km',
                              poi: p.coordinate!,
                              origin: widget.request.origin,
                              destination: widget.request.destination,
                              routeGeometry: widget.response.route.geometry,
                              attributes: p.attributes,
                              icon: Icons.local_gas_station,
                              accent:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                  );
          }).toList(),
        ),
      ],
      const SizedBox(height: Tokens.space32),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: BackButton(color: scheme.onSurface),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_shortName(widget.origin), style: t.bodySmall),
                if (widget.currentLegLabel != null) ...[
                  const SizedBox(width: 6),
                  _LegPill(label: widget.currentLegLabel!),
                ],
              ],
            ),
            Text(
              '→ ${_shortName(widget.destination)}',
              style: t.titleMedium,
            ),
          ],
        ),
        actions: [
          if (widget.otherLeg != null)
            IconButton(
              tooltip: l.roundTripSwapTo(widget.otherLeg!.label),
              icon: const Icon(Icons.swap_horiz),
              onPressed: () {
                // Push (not replace) so the user can back-swipe to
                // the previous leg. Each ResultScreen keeps its own
                // state (added stops, share prefs) so toggling
                // doesn't wipe interactions on either side.
                final other = widget.otherLeg!;
                final backLeg = RoundTripLeg(
                  label: widget.currentLegLabel ?? '—',
                  request: widget.request,
                  origin: widget.origin,
                  destination: widget.destination,
                  response: widget.response,
                  desiredDepartureAt: widget.desiredDepartureAt,
                );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResultScreen(
                      request: other.request,
                      origin: other.origin,
                      destination: other.destination,
                      response: other.response,
                      desiredDepartureAt: other.desiredDepartureAt,
                      currentLegLabel: other.label,
                      otherLeg: backLeg,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: l.resultShareTooltip,
            icon: const Icon(Icons.ios_share),
            onPressed: () => shareTrip(
              l: l,
              localeName: Localizations.localeOf(context).toString(),
              originName: _shortName(widget.origin),
              destinationName: _shortName(widget.destination),
              route: widget.response.route,
              origin: widget.request.origin,
              destination: widget.request.destination,
              departureAt: widget.desiredDepartureAt,
              recommended: _recommended,
              tollAlt: widget.response.tollAlternative,
              hotels: widget.response.hotels,
              restaurants: widget.response.restaurants,
              fuelArbitrage: widget.response.fuelArbitrage,
            ),
          ),
          IconButton(
            tooltip: l.resultExplainTooltip,
            icon: Icon(Icons.auto_awesome, color: scheme.tertiary),
            onPressed: _openNarrative,
          ),
          IconButton(
            tooltip: _saved ? l.resultSavedTooltip : l.resultSaveTooltip,
            icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: _saved || _saving ? null : _save,
          ),
          const SizedBox(width: Tokens.space8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space20,
          Tokens.space16,
          Tokens.space20,
          // Extra bottom padding so the "Start trip" FAB doesn't
          // cover the last card in the section list.
          Tokens.space64 + Tokens.space16,
        ),
        children: [
          for (var i = 0; i < sections.length; i++)
            sections[i]
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 40 * i),
                  duration: Tokens.motionBase,
                )
                .moveY(begin: 4, end: 0, curve: Tokens.curveOut),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ref.watch(premiumProvider)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow),
              label: Text(l.resultStartTrip),
              onPressed: () async {
                // Show the AA discoverability coach the first time
                // the user starts a trip. Testers repeatedly missed
                // that MyTravelPal lives in the POI category on AA,
                // not next to Google Maps — one dialog saves the
                // support ticket.
                await AaCoachDialog.maybeShow(context);
                if (!context.mounted) return;
                // Second nag: battery-optimisation whitelist. Only
                // fires once per install (own SharedPreferences
                // flag) so we don't spam the driver every trip.
                await BatteryWhitelistDialog.maybeShow(context);
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TripDashboardScreen(
                      request: widget.request,
                      response: widget.response,
                      origin: widget.origin,
                      destination: widget.destination,
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  static String _shortName(GeocodeResult r) => r.displayName.split(',').first;

  // Kept as an alias so callsites don't churn; delegates to the shared
  // formatter which handles day rollover (long EV trips, ferry legs).
  static String _hhmm(double minutes) => durationCompact(minutes);

  List<Widget> _separated(List<Widget> tiles) {
    final scheme = Theme.of(context).colorScheme;
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(Divider(height: 1, color: scheme.outlineVariant));
      }
    }
    return [
      SoftCard(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space16, vertical: Tokens.space4,
          ),
          child: Column(children: out),
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

enum _MapMode { collapsed, normal, fullscreen }

class _InteractiveMapCard extends StatelessWidget {
  const _InteractiveMapCard({
    required this.origin,
    required this.destination,
    required this.route,
    this.alternativeGeometry = const [],
    this.hotels = const [],
    this.restaurants = const [],
    this.tollSkips = const [],
    required this.mode,
    required this.onModeChange,
  });

  final LatLon origin;
  final LatLon destination;
  final RouteInfo route;
  final List<LatLon> alternativeGeometry;
  final List<Hotel> hotels;
  final List<Restaurant> restaurants;
  final List<PartialTollSkip> tollSkips;
  final _MapMode mode;
  final ValueChanged<_MapMode> onModeChange;

  Widget _buildMap(BuildContext context, {double? height}) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: RouteMap(
            origin: origin,
            destination: destination,
            geometry: route.geometry,
            alternativeGeometry: alternativeGeometry,
            hotelMarkers: hotels,
            restaurantMarkers: restaurants,
            tollMarkers: tollSkips,
          ),
        ),
        Positioned(
          left: Tokens.space12,
          top: Tokens.space12,
          child: Wrap(
            spacing: Tokens.space8,
            children: [
              for (final c in route.countriesCrossed)
                SoftBadge(
                  label: c.displayName,
                  icon: Icons.public,
                  background: scheme.surface.withValues(alpha: 0.95),
                ),
            ],
          ),
        ),
        Positioned(
          right: Tokens.space8,
          top: Tokens.space8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mode == _MapMode.normal) ...[
                _MapControlButton(
                  icon: Icons.fullscreen,
                  onTap: () => _openFullscreen(context),
                ),
                const SizedBox(height: 4),
                _MapControlButton(
                  icon: Icons.keyboard_arrow_up,
                  onTap: () => onModeChange(_MapMode.collapsed),
                ),
              ],
            ],
          ),
        ),
        if (route.geometry.isEmpty)
          Positioned(
            right: Tokens.space12,
            bottom: Tokens.space12,
            child: SoftBadge(
              label: AppLocalizations.of(context).resultCompareStraightApprox,
              icon: Icons.timeline,
              background: scheme.surface.withValues(alpha: 0.95),
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              '${route.distanceKm.toStringAsFixed(0)} km',
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: _buildMap(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (mode == _MapMode.collapsed) {
      return InkWell(
        onTap: () => onModeChange(_MapMode.normal),
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space16, vertical: Tokens.space12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 18,
                  color: scheme.onSurfaceVariant),
              const SizedBox(width: Tokens.space8),
              Text(l.mapShowLabel,
                  style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              Icon(Icons.keyboard_arrow_down, size: 18,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }
    return _buildMap(context, height: 260);
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: scheme.onSurface),
      ),
    );
  }
}

class _TollAlternativeCard extends StatelessWidget {
  const _TollAlternativeCard({
    required this.alt,
    required this.skipEnabled,
    required this.onToggleSkip,
  });
  final TollAlternative alt;
  /// Whether the driver has ACTUALLY chosen to skip tolls. When
  /// false the displayed savings collapse to 0 € — the number
  /// only reflects savings the driver has already committed to,
  /// not hypothetical "you could save" figures which testers
  /// found misleading.
  final bool skipEnabled;
  final ValueChanged<bool> onToggleSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    // Highlight the card only when skip is ON AND worth it. When
    // skip is off we render neutral — this is now an actionable
    // toggle, not a "verdict" card.
    final active = skipEnabled && alt.worthIt;
    final accent = active ? scheme.tertiary : scheme.onSurfaceVariant;
    final containerBg = active
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerLow;
    final onContainer = active
        ? scheme.onTertiaryContainer
        : scheme.onSurface;
    final displayedSavings = skipEnabled ? alt.savingsEur : 0.0;
    final displayedPenalty = skipEnabled ? alt.timePenaltyMinutes : 0.0;

    return Container(
      padding: const EdgeInsets.all(Tokens.space20),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.toll_outlined, color: accent, size: 18),
              const SizedBox(width: Tokens.space8),
              Text(
                l.resultTollAlternativeEyebrow,
                style: t.labelSmall
                    ?.copyWith(color: accent, letterSpacing: 1.4),
              ),
              const Spacer(),
              // Toggle inline: driver flips skip on/off and the
              // parent replans. Positioned in place of the old
              // "verdict" badge — a switch communicates
              // interactivity more clearly than a label.
              Switch.adaptive(
                value: skipEnabled,
                onChanged: onToggleSkip,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          RichText(
            text: TextSpan(
              style: t.headlineMedium?.copyWith(color: onContainer),
              children: [
                TextSpan(text: l.resultSaveExactly),
                TextSpan(
                  text: '€${displayedSavings.toStringAsFixed(0)}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: '+${displayedPenalty.toStringAsFixed(0)} min',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Text(
            '${alt.distanceKm.toStringAsFixed(0)} km · '
            '+${alt.extraDistanceKm.toStringAsFixed(0)} km · '
            '${l.resultStatTolls.toLowerCase()}: 0',
            style: t.bodySmall?.copyWith(color: onContainer),
          ),
          if (alt.geometry.isNotEmpty) ...[
            const SizedBox(height: Tokens.space8),
            Row(
              children: [
                Container(width: 20, height: 3, color: accent),
                const SizedBox(width: Tokens.space8),
                Text(
                  l.resultVariantDashed,
                  style: t.bodySmall?.copyWith(color: onContainer),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteVariantsSection extends StatelessWidget {
  const _RouteVariantsSection({required this.variants});
  final List<RouteVariant> variants;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(builder: (context) {
          final l = AppLocalizations.of(context);
          return SectionHeader(
            title: l.resultCompareTitle,
            eyebrow: l.resultCompareEyebrow,
            description: l.resultCompareDescription,
          );
        }),
        SoftCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space16, vertical: Tokens.space8,
          ),
          child: Column(
            children: [
              for (var i = 0; i < variants.length; i++) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                _RouteVariantRow(
                  variant: variants[i],
                  isPrimary: variants[i].key == 'fastest',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteVariantRow extends StatelessWidget {
  const _RouteVariantRow({required this.variant, required this.isPrimary});
  final RouteVariant variant;
  final bool isPrimary;

  IconData get _icon => switch (variant.key) {
        'fastest' => Icons.speed,
        'toll_free' => Icons.savings_outlined,
        'scenic' => Icons.landscape_outlined,
        _ => Icons.alt_route,
      };

  String _label(AppLocalizations l) => switch (variant.key) {
        'fastest' => l.routeVariantFastest,
        'toll_free' => l.routeVariantTollFree,
        'scenic' => l.routeVariantScenic,
        // Unknown key from a future backend: keep the server label so
        // we degrade gracefully instead of showing an empty string.
        _ => variant.label,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final accent = isPrimary ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isPrimary
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            child: Icon(_icon, size: 18, color: accent),
          ),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_label(l), style: t.titleSmall),
                    if (isPrimary) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· PRIMARY',
                        style: t.labelSmall?.copyWith(
                          color: scheme.primary, letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${variant.distanceKm.toStringAsFixed(0)} km · '
                  '${_hhmm(variant.freeFlowMinutes)} · '
                  'tolls €${variant.tollCostEur.toStringAsFixed(0)}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hhmm(double minutes) => durationCompact(minutes);
}

class _TotalTripCostCard extends StatelessWidget {
  const _TotalTripCostCard({
    required this.fuelCostEur,
    required this.tollCostEur,
    required this.mealStops,
    this.sleepStop,
    this.tollSkipSavingsEur = 0,
  });
  final double fuelCostEur;
  final double tollCostEur;
  final List<MealStopOpt> mealStops;
  final SleepStopOpt? sleepStop;
  final double tollSkipSavingsEur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    final mealsCost = mealStops.fold<double>(
      0.0, (sum, m) => sum + (m.restaurantPriceEurPerMeal ?? 15.0),
    );
    final hotelCost = sleepStop?.hotelPriceEurPerNight ?? 0.0;
    final effectiveTolls = (tollCostEur - tollSkipSavingsEur).clamp(0.0, tollCostEur);
    final total = fuelCostEur + effectiveTolls + mealsCost + hotelCost;

    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 18,
                  color: scheme.primary),
              const SizedBox(width: Tokens.space8),
              Text(
                l.tripCostTitle,
                style: t.labelSmall?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space16),
          _CostRow(label: l.tripCostFuel,
              value: fuelCostEur, scheme: scheme, t: t),
          _CostRow(label: l.tripCostTolls,
              value: effectiveTolls, scheme: scheme, t: t),
          if (mealsCost > 0)
            _CostRow(label: '${l.tripCostMeals} (×${mealStops.length})',
                value: mealsCost, scheme: scheme, t: t),
          if (hotelCost > 0)
            _CostRow(label: l.tripCostHotel,
                value: hotelCost, scheme: scheme, t: t),
          const SizedBox(height: Tokens.space8),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: Tokens.space8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.tripCostTotal,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                '€${total.toStringAsFixed(0)}',
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.label,
    required this.value,
    required this.scheme,
    required this.t,
  });
  final String label;
  final double value;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: t.bodyMedium),
          Text(
            '€${value.toStringAsFixed(0)}',
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsSummaryCard extends StatelessWidget {
  const _SavingsSummaryCard({
    required this.savings,
    this.tollSkipSavingsEur = 0,
    this.tollSkipPenaltyMinutes = 0,
  });
  final TripSavings savings;
  final double tollSkipSavingsEur;
  final double tollSkipPenaltyMinutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final savedTime =
        savings.timeSavedMinutesVsDesired - tollSkipPenaltyMinutes;
    final savedEur =
        savings.moneySavedEurVsTolls + tollSkipSavingsEur;
    return Container(
      padding: const EdgeInsets.all(Tokens.space20),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, size: 18, color: scheme.tertiary),
              const SizedBox(width: Tokens.space8),
              Text(
                l.resultTripSavings,
                style: t.labelSmall?.copyWith(
                  color: scheme.tertiary, letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SavingsStat(
                icon: Icons.access_time,
                value: durationCompact(savedTime.abs()),
                label: savedTime >= 0
                    ? l.resultTimeSavedLabel
                    : l.resultExtraTimeLabel,
                positive: savedTime > 0,
                foreground: scheme.onTertiaryContainer,
              ),
              _SavingsStat(
                icon: Icons.euro,
                value: savedEur.toStringAsFixed(0),
                label: l.resultMoneySavedLabel,
                positive: savedEur > 0,
                foreground: scheme.onTertiaryContainer,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            savedTime > 0 && savedEur > 0
                ? l.resultSavingsShiftAndSkip
                : savedTime > 0
                    ? l.resultSavingsShift
                    : savedEur > 0
                        ? l.resultSavingsSkip
                        : l.resultSavingsNone,
            style: t.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
          ),
        ],
      ),
    );
  }
}

class _SavingsStat extends StatelessWidget {
  const _SavingsStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.positive,
    required this.foreground,
  });
  final IconData icon;
  final String value;
  final String label;
  final bool positive;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 4),
            Text(
              value,
              style: t.headlineMedium?.copyWith(
                color: foreground,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: t.labelSmall?.copyWith(
            color: foreground,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _RecommendationHero extends StatelessWidget {
  const _RecommendationHero({
    required this.recommended,
    required this.desired,
    required this.freeFlowMinutes,
    required this.savedMinutesVsDesired,
  });

  final TimeWindow recommended;
  final DateTime desired;
  final double freeFlowMinutes;
  final double savedMinutesVsDesired;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    final shift = recommended.departureAt.difference(desired);
    final savedVsDesired = _minutesShiftedForBetterTraffic(shift, recommended);
    final shiftLabel = _formatShift(shift);
    final dateFmt = DateFormat('EEE, d MMM · HH:mm');

    return Container(
      padding: const EdgeInsets.all(Tokens.space24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: Tokens.space8),
              Text(
                l.resultBestTimeToLeave,
                style: t.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (savedMinutesVsDesired > 0)
                _HeroSavingsBadge(
                  minutes: savedMinutesVsDesired,
                  fg: scheme.onPrimaryContainer,
                ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          Text(
            dateFmt.format(recommended.departureAt),
            style: t.displaySmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Text(
            savedVsDesired,
            style: t.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: Tokens.space16),
          Row(
            children: [
              _HeroChip(
                label: l.resultShift,
                value: shiftLabel,
                fg: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: Tokens.space16),
              _HeroChip(
                label: l.resultTraffic,
                value: '×${recommended.trafficFactor.toStringAsFixed(2)}',
                fg: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: Tokens.space16),
              _HeroChip(
                label: l.resultTotal,
                value: _hhmm(recommended.estimatedMinutes),
                fg: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _minutesShiftedForBetterTraffic(
    Duration shift, TimeWindow recommended,
  ) {
    final delta = recommended.estimatedMinutes - freeFlowMinutes;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(0)} min vs free flow · '
        '${shift.inMinutes.abs()} min ${shift.isNegative ? 'earlier' : 'later'} '
        'than your target';
  }

  String _formatShift(Duration d) {
    if (d.inMinutes == 0) return 'ON TIME';
    final abs = d.inMinutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    final magnitude = h > 0
        ? (m > 0 ? '${h}h ${m}m' : '${h}h')
        : '${m}m';
    return d.isNegative ? '-$magnitude' : '+$magnitude';
  }

  String _hhmm(double minutes) => durationCompact(minutes);
}

class _HeroSavingsBadge extends StatelessWidget {
  const _HeroSavingsBadge({required this.minutes, required this.fg});
  final double minutes;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final abs = minutes.abs();
    final hours = abs ~/ 60;
    final mins = (abs % 60).round();
    final magnitude = hours > 0
        ? (mins > 0 ? '${hours}h ${mins}m' : '${hours}h')
        : '${mins}m';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space12, vertical: 6,
      ),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_down, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            '$magnitude saved',
            style: t.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value, required this.fg});
  final String label;
  final String value;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.labelSmall?.copyWith(color: fg.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: t.titleMedium?.copyWith(
            color: fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _OptimizationsSection extends StatelessWidget {
  const _OptimizationsSection({
    required this.opts,
    this.topHotels = const [],
    this.origin,
    this.destination,
    this.routeGeometry = const [],
  });
  final Optimizations opts;
  final List<(Hotel, double)> topHotels;
  final LatLon? origin;
  final LatLon? destination;
  final List<LatLon> routeGeometry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(builder: (context) {
          final l = AppLocalizations.of(context);
          return SectionHeader(
            title: l.resultOptimized,
            eyebrow: l.resultOptimizedEyebrow,
            description: l.resultOptimizedDescription,
          );
        }),
        SoftCard(
          padding: const EdgeInsets.all(Tokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FuelCostRow(cost: opts.fuelCost),
              if (opts.mealStops.isNotEmpty) ...[
                const SizedBox(height: Tokens.space16),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: Tokens.space16),
                for (final m in opts.mealStops)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space12),
                    child: _MealStopRow(stop: m),
                  ),
              ],
              // Only render the sleep row when the backend picked a
              // plausible night time. Same gate the promoted card
              // uses — a bogus "sleep at 16:00" from either the
              // response or a resumed session gets suppressed at
              // both surfaces.
              if (opts.sleepStop != null &&
                  isPlausibleSleepTime(opts.sleepStop!.at)) ...[
                const SizedBox(height: Tokens.space4),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: Tokens.space16),
                _SleepStopRow(stop: opts.sleepStop!),
              ],
              const SizedBox(height: Tokens.space8),
              if (opts.fuelCost.notes.isNotEmpty) ...[
                const SizedBox(height: Tokens.space12),
                for (final n in opts.fuelCost.notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: scheme.tertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(n,
                              style: t.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              )),
                        ),
                      ],
                    ),
                  ),
              ],
              if (topHotels.isNotEmpty) ...[
                const SizedBox(height: Tokens.space4),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: Tokens.space12),
                Builder(builder: (context) {
                  final l = AppLocalizations.of(context);
                  return Text(
                    l.daySleepHotelsLabelDestination.toUpperCase(),
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                    ),
                  );
                }),
                const SizedBox(height: Tokens.space8),
                for (final (h, km) in topHotels)
                  InkWell(
                    onTap: () => showPoiDetailSheet(
                      context,
                      kind: PoiKind.hotel,
                      name: h.name,
                      subtitle: _hotelSubtitle(h),
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
                        children: [
                          Icon(Icons.hotel_outlined, size: 14,
                              color: scheme.tertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${h.name}  ·  '
                              '${h.priceEurPerNight.toStringAsFixed(0)} €  ·  '
                              '${km.toStringAsFixed(1)} km',
                              style: t.bodySmall,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _hotelSubtitle(Hotel h) {
    final parts = <String>[
      '${h.priceEurPerNight.toStringAsFixed(0)} €/night',
    ];
    final stars = h.attributes['stars'];
    if (stars != null && stars.isNotEmpty) parts.add('$stars★');
    if (h.attributes['internet_access'] == 'yes' ||
        h.attributes['internet_access'] == 'wlan') {
      parts.add('WiFi');
    }
    if (h.attributes['parking'] != null &&
        h.attributes['parking'] != 'no') {
      parts.add('Parking');
    }
    if (h.attributes['wheelchair'] == 'yes') parts.add('♿');
    return parts.join(' · ');
  }
}

class _FuelCostRow extends StatelessWidget {
  const _FuelCostRow({required this.cost});
  final FuelCost cost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
          ),
          child: Icon(
            cost.fuelType == FuelType.electric
                ? Icons.electric_bolt
                : Icons.local_gas_station,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: Tokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).resultOptimizedFuelBudget,
                  style: t.labelSmall?.copyWith(letterSpacing: 1.1)),
              const SizedBox(height: 2),
              Text(
                '€${cost.totalCostEur.toStringAsFixed(0)}',
                style: t.headlineMedium?.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${cost.fuelUnits.toStringAsFixed(1)} ${cost.unitLabel} · '
                '${cost.averageUnitPriceEur.toStringAsFixed(3)} €/${cost.unitLabel}',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MealStopRow extends StatelessWidget {
  const _MealStopRow({required this.stop});
  final MealStopOpt stop;

  IconData get _icon => switch (stop.slot) {
        'breakfast' => Icons.free_breakfast_outlined,
        'lunch' => Icons.lunch_dining_outlined,
        'dinner' => Icons.dinner_dining_outlined,
        _ => Icons.restaurant_outlined,
      };

  String _label(AppLocalizations l) => switch (stop.slot) {
        'breakfast' => l.profileBreakfast,
        'lunch' => l.profileLunch,
        'dinner' => l.profileDinner,
        _ => l.resultMealFallback,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final dateFmt = intl.DateFormat.Hm();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.tertiaryContainer,
          child: Icon(_icon, size: 18, color: scheme.onTertiaryContainer),
        ),
        const SizedBox(width: Tokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_label(l)} · ${dateFmt.format(stop.at.toLocal())}',
                style: t.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                stop.restaurantName != null
                    ? '${stop.restaurantName} · '
                        '${stop.restaurantPriceEurPerMeal?.toStringAsFixed(0)} €/meal · '
                        '${stop.distanceFromOriginKm.toStringAsFixed(0)} km'
                    : l.resultRestStopNoRestaurant(
                        stop.distanceFromOriginKm.toStringAsFixed(0),
                      ),
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SleepStopRow extends StatelessWidget {
  const _SleepStopRow({required this.stop});
  final SleepStopOpt stop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dateFmt = intl.DateFormat.Hm();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.secondaryContainer,
          child: Icon(Icons.hotel_outlined, size: 18,
              color: scheme.onSecondaryContainer),
        ),
        const SizedBox(width: Tokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) {
                final l = AppLocalizations.of(context);
                return Text(
                  l.resultSleepAt(dateFmt.format(stop.at.toLocal())),
                  style: t.titleMedium,
                );
              }),
              const SizedBox(height: 2),
              Text(
                stop.hotelName != null
                    ? '${stop.hotelName} · '
                        '${stop.hotelPriceEurPerNight?.toStringAsFixed(0)} €/night · '
                        '${stop.distanceFromOriginKm.toStringAsFixed(0)} km'
                    : AppLocalizations.of(context).resultNoHotelHere(
                        stop.distanceFromOriginKm.toStringAsFixed(0),
                      ),
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourlyTollCard extends StatelessWidget {
  const _HourlyTollCard({required this.report});
  final HourlyTollReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: scheme.tertiary),
              const SizedBox(width: Tokens.space8),
              Text(l.resultHourlyTollEyebrow,
                  style: t.labelSmall?.copyWith(
                      color: scheme.tertiary, letterSpacing: 1.4)),
              const Spacer(),
              SoftBadge(
                label: l.narrativePremiumBadge,
                color: scheme.onPrimaryContainer,
                background: scheme.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          Text(
            '${l.hourlyBestHours}: '
            '${report.bestHoursToSkip.map((h) => '${h.toString().padLeft(2, '0')}:00').join(' · ')}',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${l.hourlyWorstHours}: '
            '${report.worstHoursToSkip.map((h) => '${h.toString().padLeft(2, '0')}:00').join(' · ')}',
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space16),
          _HourStrip(verdicts: report.verdicts),
        ],
      ),
    );
  }
}

class _HourStrip extends StatelessWidget {
  const _HourStrip({required this.verdicts});
  final List<HourlyTollVerdict> verdicts;

  Color _colorFor(BuildContext context, String rec) {
    final scheme = Theme.of(context).colorScheme;
    return switch (rec) {
      'skip_tolls' => scheme.tertiary,
      'keep_tolls' => scheme.primary,
      _ => scheme.outlineVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final v in verdicts)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 1),
              height: 22,
              color: _colorFor(context, v.recommendation),
              alignment: Alignment.center,
              child: v.hour % 3 == 0
                  ? Text(
                      '${v.hour}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

class _PartialTollSkipsCard extends StatelessWidget {
  const _PartialTollSkipsCard({
    required this.skips,
    required this.origin,
    required this.destination,
    required this.routeGeometry,
    required this.enabledIndices,
    required this.onToggle,
    required this.onToggleAll,
    this.hourlyReport,
  });
  final List<PartialTollSkip> skips;
  final LatLon origin;
  final LatLon destination;
  final List<LatLon> routeGeometry;
  final Set<int> enabledIndices;
  final HourlyTollReport? hourlyReport;
  final void Function(int index, bool value) onToggle;
  final void Function(bool selectAll) onToggleAll;

  double get _totalSavings => enabledIndices.fold(
        0.0, (sum, i) => sum + skips[i].savingsEur,
      );

  double get _totalPenaltyMinutes => enabledIndices.fold(
        0.0, (sum, i) => sum + skips[i].timePenaltyMinutes,
      );

  double get _totalExtraKm => enabledIndices.fold(
        0.0, (sum, i) => sum + skips[i].extraDistanceKm,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final accent = enabledIndices.isEmpty
        ? scheme.onSurfaceVariant
        : scheme.tertiary;
    final allSelected = enabledIndices.length == skips.length;
    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, size: 18, color: scheme.tertiary),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: Text(
                  l.partialTollSkipsTitle.toUpperCase(),
                  style: t.labelSmall?.copyWith(
                    color: scheme.tertiary, letterSpacing: 1.4,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onToggleAll(!allSelected),
                child: Text(
                  allSelected
                      ? l.commonClear
                      : l.tollSkipSelectAll,
                  style: t.labelSmall?.copyWith(color: scheme.tertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.resultHourlyExplainer, style: t.bodySmall),
          const SizedBox(height: Tokens.space12),
          RichText(
            text: TextSpan(
              style: t.headlineSmall?.copyWith(color: scheme.onSurface),
              children: [
                TextSpan(text: l.resultSaveExactly),
                TextSpan(
                  text: '€${_totalSavings.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: accent, fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: '+${_totalPenaltyMinutes.toStringAsFixed(0)} min',
                  style: TextStyle(
                    color: accent, fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: '+${_totalExtraKm.toStringAsFixed(0)} km',
                  style: TextStyle(
                    color: accent, fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space16),
          for (var i = 0; i < skips.length; i++)
            _PartialTollSkipRow(
              skip: skips[i],
              enabled: enabledIndices.contains(i),
              onToggle: (v) => onToggle(i, v),
              onTap: () => _openSkipDetail(context, i),
            ),
          if (hourlyReport != null) ...[
            const SizedBox(height: Tokens.space16),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: Tokens.space12),
            Text(
              '${l.hourlyBestHours}: '
              '${hourlyReport!.bestHoursToSkip.map((h) => '${h.toString().padLeft(2, '0')}:00').join(' · ')}',
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${l.hourlyWorstHours}: '
              '${hourlyReport!.worstHoursToSkip.map((h) => '${h.toString().padLeft(2, '0')}:00').join(' · ')}',
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Tokens.space8),
            _HourStrip(verdicts: hourlyReport!.verdicts),
          ],
        ],
      ),
    );
  }

  void _openSkipDetail(BuildContext context, int index) {
    final skip = skips[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PartialTollSkipSheet(
        skip: skip,
        origin: origin,
        destination: destination,
        routeGeometry: routeGeometry,
      ),
    );
  }
}

class _PartialTollSkipRow extends StatelessWidget {
  const _PartialTollSkipRow({
    required this.skip,
    required this.enabled,
    required this.onToggle,
    required this.onTap,
  });
  final PartialTollSkip skip;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = enabled ? scheme.tertiary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Icon(
                enabled ? Icons.check : Icons.remove,
                color: accent, size: 18,
              ),
            ),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skip.localizedLabel(AppLocalizations.of(context)),
                    style: t.titleSmall,
                  ),
                  Text(
                    'km ${skip.distanceFromOriginKm.toStringAsFixed(0)} · '
                    '€${skip.savingsEur.toStringAsFixed(0)} · '
                    '+${skip.timePenaltyMinutes.toStringAsFixed(0)} min · '
                    '+${skip.extraDistanceKm.toStringAsFixed(0)} km',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _PartialTollSkipSheet extends StatelessWidget {
  const _PartialTollSkipSheet({
    required this.skip,
    required this.origin,
    required this.destination,
    required this.routeGeometry,
  });
  final PartialTollSkip skip;
  final LatLon origin;
  final LatLon destination;
  final List<LatLon> routeGeometry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(Tokens.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skip.localizedLabel(l),
              style: t.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'km ${skip.distanceFromOriginKm.toStringAsFixed(0)}',
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Tokens.space16),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
                // Full trip polyline as context, with the toll
                // booth marked. We could OSRM a targeted alt
                // route per skip later — for MVP the location
                // + numbers are what the driver needs.
                child: RouteMap(
                  origin: origin,
                  destination: destination,
                  geometry: routeGeometry,
                ),
              ),
            ),
            const SizedBox(height: Tokens.space20),
            _SkipMetricRow(
              icon: Icons.savings_outlined,
              label: l.resultSaveExactly,
              value: '€${skip.savingsEur.toStringAsFixed(0)}',
              accent: scheme.tertiary,
            ),
            const SizedBox(height: Tokens.space8),
            _SkipMetricRow(
              icon: Icons.schedule,
              label: '+',
              value:
                  '${skip.timePenaltyMinutes.toStringAsFixed(0)} min',
              accent: scheme.onSurface,
            ),
            const SizedBox(height: Tokens.space8),
            _SkipMetricRow(
              icon: Icons.straighten,
              label: '+',
              value: '${skip.extraDistanceKm.toStringAsFixed(0)} km',
              accent: scheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

class _SkipMetricRow extends StatelessWidget {
  const _SkipMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: Tokens.space12),
        Expanded(child: Text(label, style: t.bodyMedium)),
        Text(
          value,
          style: t.titleMedium?.copyWith(
            color: accent, fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AdverseEventTile extends StatelessWidget {
  const _AdverseEventTile({required this.event, this.onTap});
  final AdverseEvent event;
  final VoidCallback? onTap;

  Color _severityColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (event.severity) {
      AdverseEventSeverity.critical => scheme.error,
      AdverseEventSeverity.warning => scheme.tertiary,
      AdverseEventSeverity.info => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(event.type.icon, color: color, size: 18),
      ),
      title: Text(event.type.localized(AppLocalizations.of(context))),
      subtitle: Text(event.description),
      isThreeLine: event.description.length > 60,
      trailing: SoftBadge(
        label: event.severity.localized(AppLocalizations.of(context)),
        color: color,
        background: color.withValues(alpha: 0.10),
        borderColor: color.withValues(alpha: 0.3),
      ),
      onTap: onTap,
    );
  }
}

class _DestinationHotelsSection extends StatelessWidget {
  const _DestinationHotelsSection({
    required this.hotels,
    required this.destination,
    this.origin,
    this.routeGeometry = const [],
  });
  final List<Hotel> hotels;
  final LatLon destination;
  final LatLon? origin;
  final List<LatLon> routeGeometry;

  static const _maxShow = 5;
  static const _maxDistKm = 60.0;

  static double _haversine(LatLon a, LatLon b) {
    const r = 6371.0;
    final dLat = (b.lat - a.lat) * math.pi / 180;
    final dLon = (b.lon - a.lon) * math.pi / 180;
    final aLat = a.lat * math.pi / 180;
    final bLat = b.lat * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(aLat) * math.cos(bLat) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final scored = <(Hotel, double)>[];
    for (final h in hotels) {
      final km = _haversine(destination, h.coordinate);
      if (km <= _maxDistKm) scored.add((h, km));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    final top = scored.take(_maxShow).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.daySleepHotelsLabelDestination.toUpperCase(),
          style: t.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: Tokens.space8),
        for (final (h, km) in top)
          InkWell(
            onTap: () => showPoiDetailSheet(
              context,
              kind: PoiKind.hotel,
              name: h.name,
              subtitle: '${h.priceEurPerNight.toStringAsFixed(0)} €/night · '
                  '${km.toStringAsFixed(1)} km',
              poi: h.coordinate,
              origin: origin ?? destination,
              destination: destination,
              routeGeometry: routeGeometry,
              attributes: h.attributes,
              icon: Icons.hotel_outlined,
              accent: scheme.tertiary,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.hotel_outlined, size: 14,
                      color: scheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${h.name}  ·  '
                      '${h.priceEurPerNight.toStringAsFixed(0)} €/night  ·  '
                      '${l.hotelDistFromDestination(km.toStringAsFixed(1))}',
                      style: t.bodySmall,
                    ),
                  ),
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

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({
    required this.restaurant,
    this.onTap,
    this.isAdded = false,
    this.onToggleAdd,
  });
  final Restaurant restaurant;
  final VoidCallback? onTap;
  final bool isAdded;
  final VoidCallback? onToggleAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.tertiaryContainer,
        child: Icon(Icons.restaurant_outlined,
            color: scheme.onTertiaryContainer, size: 18),
      ),
      title: Text(restaurant.name),
      subtitle: Text(
        '${restaurant.country.displayName} · '
        '${restaurant.priceEurPerMeal.toStringAsFixed(0)} €/meal · '
        '${AppLocalizations.of(context).poiDistanceKm(
          restaurant.distanceFromRouteKm.toStringAsFixed(1),
          restaurant.detourMinutes.toStringAsFixed(0),
        )}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SoftBadge(label: restaurant.priceBand.symbol),
          const SizedBox(width: 4),
          if (onToggleAdd != null)
            _AddToRouteButton(
              isAdded: isAdded, onPressed: onToggleAdd!,
            ),
          FavoriteStarButton(
            id: restaurant.favoriteId,
            isRestaurant: true,
            payload: restaurant.toFavoriteJson(),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _FuelTile extends StatelessWidget {
  const _FuelTile({
    required this.price,
    this.onTap,
    this.isAdded = false,
    this.onToggleAdd,
  });
  final FuelPrice price;
  final VoidCallback? onTap;
  final bool isAdded;
  final VoidCallback? onToggleAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final subtitle = price.priceAvailable
        ? '${price.priceEurPerL.toStringAsFixed(3)} €/L · '
              '${price.distanceFromOriginKm.toStringAsFixed(0)} km from origin'
        : '${l.fuelPriceUnavailable} · '
              '${price.distanceFromOriginKm.toStringAsFixed(0)} km from origin';
    // Show a small green (cheap) / red (dear) chip when the backend
    // computed a per-country delta. Threshold of 2 cents avoids
    // shouting about noise-level differences.
    final savings = price.savingsVsCountryMedianEurPerL;
    final Widget? savingsChip = (savings != null && savings.abs() >= 0.02)
        ? _SavingsChip(deltaEurPerL: savings)
        : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.surfaceContainerHigh,
        child: Icon(Icons.local_gas_station,
            color: scheme.onSurface, size: 18),
      ),
      title: Text('${price.stationName} · ${price.country.code}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: price.priceAvailable
                ? null
                : TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (savingsChip != null) ...[
            const SizedBox(height: 4),
            savingsChip,
          ],
        ],
      ),
      isThreeLine: savingsChip != null,
      trailing: onToggleAdd == null
          ? null
          : _AddToRouteButton(
              isAdded: isAdded, onPressed: onToggleAdd!,
            ),
      onTap: onTap,
    );
  }
}

/// Departure-window card with an inline slider that lets the driver
/// widen the sampled range beyond the default ±3h up to ±12h. On
/// slider release we refetch the plan's `time_windows` slice (nothing
/// else is re-computed) so the chart updates in ~1-2 s. The current
/// slots are kept visible during the fetch with a subtle progress
/// overlay — no flashing empty state.
class _TimeWindowExpandableCard extends StatefulWidget {
  const _TimeWindowExpandableCard({
    required this.initialWindows,
    required this.desiredDepartureAt,
    required this.initialSpanHours,
    required this.onFetch,
    this.onWindowSelect,
  });

  final List<TimeWindow> initialWindows;
  final DateTime desiredDepartureAt;
  final int initialSpanHours;
  final Future<List<TimeWindow>> Function(int spanHours) onFetch;

  /// Optional: fires when the driver taps one of the time-window
  /// rows. Parent replans the whole trip with that departure.
  final ValueChanged<TimeWindow>? onWindowSelect;

  @override
  State<_TimeWindowExpandableCard> createState() =>
      _TimeWindowExpandableCardState();
}

class _TimeWindowExpandableCardState
    extends State<_TimeWindowExpandableCard> {
  late int _span;
  late List<TimeWindow> _windows;
  bool _loading = false;
  int _lastFetchedSpan = 0;

  @override
  void initState() {
    super.initState();
    _span = widget.initialSpanHours.clamp(1, 12);
    _windows = widget.initialWindows;
    _lastFetchedSpan = _span;
  }

  Future<void> _applySpan(int newSpan) async {
    if (newSpan == _lastFetchedSpan || _loading) return;
    setState(() => _loading = true);
    try {
      final fresh = await widget.onFetch(newSpan);
      if (!mounted) return;
      setState(() {
        _windows = fresh;
        _lastFetchedSpan = newSpan;
      });
    } catch (_) {
      // Silent — keep the last known windows on network error.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space8, Tokens.space16, Tokens.space16, Tokens.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              TimeWindowChart(
                windows: _windows,
                desiredDepartureAt: widget.desiredDepartureAt,
                onSelect: widget.onWindowSelect,
              ),
              if (_loading)
                const Positioned(
                  top: 0, right: 0,
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space8),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16,
                    color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  l.timeWindowSpanLabel(_span),
                  style: t.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: _span.toDouble(),
            min: 1, max: 12,
            divisions: 11,
            label: '±${_span}h',
            onChanged: (v) => setState(() => _span = v.round()),
            onChangeEnd: (v) => _applySpan(v.round()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space8),
            child: Text(
              l.timeWindowSpanHelper,
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact chip rendered under a fuel tile when the backend produced
/// a per-country savings signal. Green + minus sign when this station
/// is cheaper than the country median, orange + plus sign when pricier.
class _SavingsChip extends StatelessWidget {
  const _SavingsChip({required this.deltaEurPerL});
  final double deltaEurPerL;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isCheap = deltaEurPerL > 0;
    final color = isCheap
        ? const Color(0xFF16A34A)
        : scheme.tertiary;
    final text = isCheap
        ? l.fuelSavingsChipCheap(deltaEurPerL.abs().toStringAsFixed(2))
        : l.fuelSavingsChipDear(deltaEurPerL.abs().toStringAsFixed(2));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Round icon button on the right of an add-to-route-capable tile.
/// Filled when the POI is already added so state is obvious at a glance.
class _AddToRouteButton extends StatelessWidget {
  const _AddToRouteButton({required this.isAdded, required this.onPressed});
  final bool isAdded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return IconButton(
      tooltip: isAdded ? l.removeFromRouteTooltip : l.addToRouteTooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        isAdded ? Icons.check_circle : Icons.add_circle_outline,
        color: isAdded ? scheme.primary : scheme.onSurfaceVariant,
      ),
      onPressed: onPressed,
    );
  }
}

/// Compact summary of the stops the user has added, rendered under the
/// stats row. Explains where the "+X min" delta on the free-flow tile
/// comes from and offers a one-tap reset.
class _AddedStopsChip extends StatelessWidget {
  const _AddedStopsChip({
    required this.count,
    required this.minutes,
    required this.onClear,
    this.onTap,
  });
  final int count;
  final double minutes;
  final VoidCallback onClear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    // The whole chip is tappable when a handler is provided so
    // hitting either the label or the small map icon opens the sheet
    // — small chip, small target, big value.
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space12, vertical: 6,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_road, size: 16, color: scheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l.addedStopsChip(count, minutes.toStringAsFixed(0)),
              style: t.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.map_outlined,
                size: 14, color: scheme.onPrimaryContainer),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2,
              ),
              child: Text(
                l.addedStopsClear,
                style: t.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // Wrap in InkWell only when a tap handler is provided so the ripple
    // stays contained to the rounded chip shape.
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: chip),
    );
  }
}

// _RestStopTile removed — rest stops section hidden per tester feedback.

/// Hint card that fires when the projected arrival lands after the
/// user's configured bedtime. Suggests an overnight stop with a link
/// down to the hotels section.
class _ArrivalHintCard extends StatelessWidget {
  const _ArrivalHintCard({
    required this.arrivalHour,
    required this.bedtimeHour,
    required this.requiresOvernight,
  });

  final int arrivalHour;
  final int bedtimeHour;
  final bool requiresOvernight;

  String _fmt(int hour) => hour.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.nights_stay_outlined,
              color: scheme.onTertiaryContainer, size: 24),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.arrivalHintTitle(_fmt(arrivalHour)),
                  style: t.titleMedium?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.arrivalHintBody(_fmt(bedtimeHour)),
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
          if (requiresOvernight) ...[
            const SizedBox(width: Tokens.space8),
            Icon(Icons.priority_high, color: scheme.error, size: 20),
          ],
        ],
      ),
    );
  }
}

/// Promoted "you'll be sleeping here" card shown near the top of the
/// result screen when the plan requires an overnight stop. Answers the
/// most anxious question a driver has on a long trip ("¿dónde
/// duermo?") without making them scroll through fuel + restaurants
/// first. Taps open the POI detail sheet with the recommended hotel
/// pinned on a mini-map.
class _MultiDaySleepPreview extends StatelessWidget {
  const _MultiDaySleepPreview({
    required this.sleepStop,
    required this.hotels,
    required this.origin,
    required this.destination,
    required this.routeGeometry,
  });

  final SleepStopOpt sleepStop;
  final List<Hotel> hotels;
  final LatLon origin;
  final LatLon destination;
  final List<LatLon> routeGeometry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final name = sleepStop.hotelName;
    final coord = sleepStop.hotelCoordinate;
    final canOpen = name != null && coord != null;
    final subtitle = [
      // Include short date so day-2 sleep stops are unambiguous.
      DateFormat('EEE d MMM · HH:mm').format(sleepStop.at.toLocal()),
      if (sleepStop.hotelPriceEurPerNight != null)
        '${sleepStop.hotelPriceEurPerNight!.toStringAsFixed(0)} €/night',
      '${sleepStop.distanceFromOriginKm.toStringAsFixed(0)} km',
    ].join(' · ');

    final card = Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.hotel_outlined, color: scheme.tertiary, size: 26),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.multiDaySleepLabel.toUpperCase(),
                  style: t.labelSmall?.copyWith(
                    color: scheme.onTertiaryContainer, letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name ?? l.multiDaySleepNoHotel,
                  style: t.titleMedium?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
          if (canOpen)
            Icon(Icons.chevron_right,
                color: scheme.onTertiaryContainer, size: 22),
        ],
      ),
    );

    if (!canOpen) return card;
    // Wrap in Material+InkWell so the tap ripple respects rounded
    // corners and we can navigate to the POI detail sheet.
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
    );
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Prefer the exact Hotel object when we still have it in
          // the response so attributes carry through the sheet;
          // fall through to the sleep-stop scalar fields otherwise.
          final matching = hotels.firstWhere(
            (h) => h.name == name,
            orElse: () => Hotel(
              // `canOpen` guarantees non-null name / coord at this
              // callsite (see check above where the InkWell is
              // wired).
              name: name,
              country: Country.es,
              priceEurPerNight: sleepStop.hotelPriceEurPerNight ?? 0,
              priceBand: PriceBand.mid,
              detourMinutes: 0,
              distanceFromRouteKm: 0,
              coordinate: coord,
              attributes: const {},
            ),
          );
          showPoiDetailSheet(
            context,
            kind: PoiKind.hotel,
            name: matching.name,
            subtitle: subtitle,
            poi: matching.coordinate,
            origin: origin,
            destination: destination,
            routeGeometry: routeGeometry,
            attributes: matching.attributes,
            icon: Icons.hotel_outlined,
            accent: Theme.of(context).colorScheme.tertiary,
          );
        },
        child: Ink(decoration: decoration, child: card),
      ),
    );
  }
}

/// Tiny label pill for the AppBar showing which round-trip leg the
/// user is currently on ("Ida" / "Vuelta"). Rendered next to the
/// origin name so it doesn't crowd the small mobile header.
class _LegPill extends StatelessWidget {
  const _LegPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}
