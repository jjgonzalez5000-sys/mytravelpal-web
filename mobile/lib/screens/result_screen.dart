import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:latlong2/latlong.dart' as fmap show LatLng;
import 'package:intl/intl.dart' as intl;
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../domain/trip_profile.dart' show FuelType;
import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../utils/duration_format.dart';
import '../services/currency_service.dart';
import '../services/notifications.dart';
import '../services/plan_foreground_task.dart';
import '../services/review_prompter.dart';
import '../services/app_tutorial.dart';
import '../services/toll_detour_waypoints.dart';
import '../services/trip_export.dart';
import '../services/trip_share_image.dart';
import '../services/trip_sharing.dart';
import '../storage/saved_trip.dart';
import '../widgets/added_stops_map_sheet.dart';
import '../widgets/companion_preflight_sheet.dart';
import '../widgets/plan_loading_dialog.dart';
import '../widgets/aa_coach_dialog.dart';
import '../widgets/adverse_event_sheet.dart';
import '../widgets/battery_whitelist_dialog.dart';
import '../widgets/consistency_banner.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/enrichment_progress.dart';
import '../widgets/hotel_preferences.dart' show HotelPreferences;
import '../widgets/restaurant_preferences.dart' show RestaurantPreferences;
import '../widgets/trip_insights.dart';
import '../widgets/favorite_star_button.dart';
import '../widgets/poi_detail_sheet.dart';
import '../widgets/route_map.dart';
import '../widgets/skeleton.dart';
import '../widgets/time_window_chart.dart';
import 'narrative_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'companion_drive_screen.dart';
// trip_dashboard_screen kept around as a fallback for direct
// deep-links; the "Tracking" button now routes to
// CompanionDriveScreen with trip context (unified view).
// ignore: unused_import
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

String _mealStopKey(MealStopOpt m) =>
    'opt_meal:${m.distanceFromOriginKm.toStringAsFixed(1)}';

String _sleepStopKey(SleepStopOpt s) =>
    'opt_sleep:${s.distanceFromOriginKm.toStringAsFixed(1)}';

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
    this.enrichFuture,
  });

  final TripPlanRequest request;
  final GeocodeResult origin;
  final GeocodeResult destination;
  final TripPlanResponse response;
  final DateTime desiredDepartureAt;

  /// Two-phase progressive loading: when non-null, the widget mounts
  /// immediately with `response` (the fast `/plan/core` result) and
  /// swaps in the merged full response as soon as this future
  /// resolves. Sections that depend on enrich-only data (hotels,
  /// restaurants, fuel, adverse events) render skeleton placeholders
  /// until then.
  ///
  /// Null on the classic single-shot flow (splash / history restore
  /// / internal re-plan) — `response` already carries everything.
  final Future<TripPlanResponse>? enrichFuture;

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

  /// Response actually rendered by the tree. Seeded from `widget.response`
  /// (the core, fast phase). When `widget.enrichFuture` resolves, the
  /// enrich response is merged in and `setState` swaps this field so
  /// hotels / restaurants / fuel / adverse events / weather /
  /// tollAlternative / hourlyTollReport / partialTollSkips /
  /// intraSectionSkips / fuelArbitrage light up in place.
  late TripPlanResponse _response;

  /// True while we're waiting on `widget.enrichFuture` to land. Drives
  /// the skeleton placeholders on sections that would otherwise render
  /// misleading empty states (e.g. "no restaurants found" before the
  /// enrich call has even returned).
  bool _enrichPending = false;

  /// Per-day overrides applied via the ResultScreen edit sheet (tap
  /// the pencil icon on a day header). Keyed by 1-based day index.
  /// Sent to `/plan` on the next re-plan; empty on first render.
  Map<int, DayOverride> _dayOverrides = {};

  /// True while a re-plan triggered by a day override is in flight.
  /// Shown as a small progress overlay on the affected day card so
  /// the driver knows the tap was heard.
  bool _replanning = false;

  // Hero landing moment: on the very first build after the plan
  // arrives, the top sections play a small staggered entrance and a
  // "plan ready" chip pops in for ~2s. Both are strictly one-shot —
  // any subsequent setState (toll toggle, hotel pick, replan) skips
  // the animations by checking `_firstShow`, so the UI never
  // re-teases the reward.
  bool _firstShow = true;
  bool _showSuccessChip = true;
  Timer? _successChipTimer;
  Timer? _firstShowResetTimer;

  /// Partial toll skip selection — held here so scroll recycling
  /// doesn't reset the user's picks (the old StatefulWidget inside
  /// the list re-ran initState on re-mount). Seeded from
  /// `worthIt` in `initState`.
  late Set<int> _tollSkipEnabled;

  // Coach-mark tutorial keys for result screen
  final _timeWindowKey = GlobalKey();
  final _tollKey = GlobalKey();
  final _hotelKey = GlobalKey();

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

  // Savings = sum of tolls the user UNCHECKED (skipped).
  // _tollSkipEnabled = indices the user KEEPS (pays).
  // So savings come from indices NOT in the set.
  double get _tollSkipSavingsEur {
    final skips = _response.partialTollSkips;
    var total = 0.0;
    for (var i = 0; i < skips.length; i++) {
      if (!_tollSkipEnabled.contains(i)) total += skips[i].savingsEur;
    }
    return total;
  }

  double get _tollSkipPenaltyMinutes {
    final skips = _response.partialTollSkips;
    var total = 0.0;
    for (var i = 0; i < skips.length; i++) {
      if (!_tollSkipEnabled.contains(i)) total += skips[i].timePenaltyMinutes;
    }
    return total;
  }

  bool _isPlausibleSleepTime(DateTime at) => isPlausibleSleepTime(at);

  /// Response hotels with the client-side stars / parking filter
  /// applied. Tolerant: hotels lacking the `stars` or `parking` tag
  /// pass through even when the user requested a filter — OSM data
  /// is patchy enough that strict enforcement would erase 80% of
  /// otherwise good candidates.
  List<Hotel> get _filteredHotels {
    final prefs = widget.hotelPrefs;
    if (prefs == null) return _response.hotels;
    return _response.hotels.where((h) {
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
    // Seed the rendered response with the core payload. Enrich
    // hydration below swaps in the merged view when it lands.
    _response = widget.response;
    _enrichPending = widget.enrichFuture != null;
    // All tolls CHECKED (= paid) by default. Savings start at 0.
    // As the driver unchecks a toll, it gets removed from the set,
    // savings grow, and the toll cost in the stats card drops.
    // On the two-phase flow the list starts empty (enrich hasn't
    // landed yet); we re-seed inside the enrichFuture callback
    // below once the real toll skips are known.
    _tollSkipEnabled = {
      for (var i = 0; i < _response.partialTollSkips.length; i++) i,
    };
    // Progressive hydration: swap enrich data into _response when the
    // second phase lands. Merge is idempotent (Core-owned fields come
    // from core, enrich-owned from enrich) so the visible route /
    // days / savings never flicker.
    final ef = widget.enrichFuture;
    if (ef != null) {
      ef.then((enrich) {
        if (!mounted) return;
        setState(() {
          _response = TripPlanResponse.merge(
            core: widget.response,
            enrich: enrich,
          );
          _enrichPending = false;
          // If the user hadn't unchecked any tolls yet (still empty
          // because core carried no partial skips), seed the set with
          // "all paid" now. If they already interacted (impossible
          // pre-enrich, but future-proof) preserve their picks.
          if (_tollSkipEnabled.isEmpty &&
              _response.partialTollSkips.isNotEmpty) {
            _tollSkipEnabled = {
              for (var i = 0;
                  i < _response.partialTollSkips.length;
                  i++)
                i,
            };
          }
        });
        // Now that partial toll skips (may) exist, offer the coach
        // mark. Wrapped in postFrame so the key targets have laid out.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_response.partialTollSkips.isNotEmpty) {
            showResultTutorial(
              context,
              timeWindowKey: _timeWindowKey,
              tollKey: _tollKey,
            );
          }
        });
      }).catchError((Object _) {
        if (!mounted) return;
        // Enrich fails silently: the core plan is already usable, so
        // we just drop the skeletons back to the true empty state.
        // A future iteration can surface a discreet retry banner.
        setState(() {
          _enrichPending = false;
        });
      });
    }
    Future.microtask(() {
      ReviewPrompter.instance.onPlanCompleted();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_response.partialTollSkips.isNotEmpty) {
        showResultTutorial(
          context,
          timeWindowKey: _timeWindowKey,
          tollKey: _tollKey,
        );
      }
    });
    // Success chip auto-dismiss after ~2s. AnimatedSwitcher below
    // handles the fade-out visual.
    _successChipTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _showSuccessChip = false);
    });
    // Flip `_firstShow` off once the hero entrance has had time to
    // play (fadeIn 240ms + max delay 350ms + safety margin). After
    // that, further rebuilds render the sections without the
    // Animate wrapper so nothing re-teases.
    _firstShowResetTimer =
        Timer(const Duration(milliseconds: 800), () {
      if (!mounted || !_firstShow) return;
      setState(() => _firstShow = false);
    });
  }

  @override
  void dispose() {
    _successChipTimer?.cancel();
    _firstShowResetTimer?.cancel();
    super.dispose();
  }

  /// User-added POI stops keyed by a stable id (name+coord for hotels
  /// and restaurants, station+coord for fuel). Value is the minutes we
  /// add to the trip total when the stop is selected — the physical
  /// detour for restaurants/hotels (round-trip off the corridor plus a
  /// small dwell) and a fixed refuel budget for fuel stops (no per-stop
  /// detour field on the backend yet).
  final Map<String, double> _addedStops = <String, double>{};

  /// Coordinates + labels of added stops that can be inserted as
  /// routing waypoints (restaurants, fuel — not hotels which are
  /// overnight anchors, not via-points).
  final Map<String, (LatLon, String)> _addedRouteWaypoints =
      <String, (LatLon, String)>{};

  /// Hotels the user "booked" for each night of the trip. Keyed by
  /// day index (1-based). When set, the total cost card sums these
  /// prices instead of just the backend-picked sleep_stop hotel,
  /// and the day view shows the picked hotel prominently.
  ///
  /// Kept as a plain field (not persisted) — the driver rebuilds
  /// the plan often and picks vary per session. If persistence is
  /// asked for later, snapshot into `TripSessionPersistence`.
  final Map<int, Hotel> _selectedNightHotels = <int, Hotel>{};

  static const double _fuelStopMinutes = 8.0;

  double get _addedMinutesTotal =>
      _addedStops.values.fold(0.0, (sum, v) => sum + v);

  bool _isAdded(String key) => _addedStops.containsKey(key);

  void _toggleStop(String key, double minutes,
      {LatLon? coord, String? label}) {
    setState(() {
      if (_addedStops.containsKey(key)) {
        _addedStops.remove(key);
        _addedRouteWaypoints.remove(key);
      } else {
        _addedStops[key] = minutes;
        if (coord != null && label != null) {
          _addedRouteWaypoints[key] = (coord, label);
        }
      }
    });
  }

  /// Build sorted waypoints from added routeable stops to include in replan.
  List<TripWaypoint> _buildAddedWaypoints() {
    final geometry = _response.route.geometry;
    final routeKm = _response.route.distanceKm;
    double kmAt(LatLon c) {
      if (geometry.isEmpty || routeKm <= 0) return 0;
      double bestD = double.infinity;
      int bestI = 0;
      for (var i = 0; i < geometry.length; i++) {
        final p = geometry[i];
        final dlat = p.lat - c.lat;
        final dlon = p.lon - c.lon;
        final d = dlat * dlat + dlon * dlon;
        if (d < bestD) {
          bestD = d;
          bestI = i;
        }
      }
      return (bestI / (geometry.length - 1).clamp(1, 999999)) * routeKm;
    }

    final stops = _addedRouteWaypoints.entries
        .map((e) => (km: kmAt(e.value.$1), coord: e.value.$1, label: e.value.$2))
        .toList()
      ..sort((a, b) => a.km.compareTo(b.km));
    return stops
        .map((s) => TripWaypoint(
              coordinate: s.coord,
              dwellNights: 0,
              label: s.label,
            ))
        .toList();
  }

  Future<void> _replanWithAddedStops() async {
    final extra = _buildAddedWaypoints();
    if (extra.isEmpty) return;
    final combined = [...widget.request.waypoints, ...extra];
    final replan = TripPlanRequest(
      origin: widget.request.origin,
      destination: widget.request.destination,
      desiredDepartureAt: widget.desiredDepartureAt,
      waypoints: combined,
      countries: widget.request.countries,
      hotelMaxDetourMinutes: widget.request.hotelMaxDetourMinutes,
      hotelPriceBand: widget.request.hotelPriceBand,
      hotelPriceBands: widget.request.hotelPriceBands,
      hotelMinStars: widget.request.hotelMinStars,
      hotelIncludeOther: widget.request.hotelIncludeOther,
      hotelDestinationRadiusKm: widget.request.hotelDestinationRadiusKm,
      hotelConditions: widget.request.hotelConditions,
      restaurantMaxDetourMinutes: widget.request.restaurantMaxDetourMinutes,
      restaurantPriceBand: widget.request.restaurantPriceBand,
      restaurantPriceBands: widget.request.restaurantPriceBands,
      restaurantCuisines: widget.request.restaurantCuisines,
      restaurantConditions: widget.request.restaurantConditions,
      includeAdverseEvents: widget.request.includeAdverseEvents,
      adverseEventsMaxDistanceKm: widget.request.adverseEventsMaxDistanceKm,
      includeTollAlternative: widget.request.includeTollAlternative,
      includeRouteComparison: widget.request.includeRouteComparison,
      includeHourlyTollAnalysis: widget.request.includeHourlyTollAnalysis,
      avoidMotorways: widget.request.avoidMotorways,
      preferScenic: widget.request.preferScenic,
      timeWindowSpanHours: widget.request.timeWindowSpanHours,
      timeWindowTopN: widget.request.timeWindowTopN,
      tripProfile: widget.request.tripProfile,
      includeParking: widget.request.includeParking,
    );
    await _replan(
        newDeparture: widget.desiredDepartureAt,
        avoidMotorways: widget.request.avoidMotorways,
        overrideRequest: replan);
  }

  /// Opens the per-day override sheet (pencil icon on a day header).
  /// Two pickers: preferred start hour + max driving hours (incl.
  /// pauses). On save, mutates `_dayOverrides` and re-fires /plan
  /// so every downstream field (arrival, meal stops, sleep stops,
  /// rest stops) updates coherently. In-place setState instead of
  /// pushReplacement so the driver keeps their scroll position and
  /// the hero doesn't re-tease.
  Future<void> _openDayEditSheet(int dayIndex) async {
    final l = AppLocalizations.of(context);
    final current = _dayOverrides[dayIndex];
    final defaultStart =
        widget.request.tripProfile?.preferredDrivingStartHour ??
            widget.request.tripProfile?.wakeHour ??
            8;
    final defaultCap =
        widget.request.tripProfile?.dailyDrivingCapHours ?? 8;
    int startHour = current?.startHour ?? defaultStart;
    int capHours = current?.dailyDrivingCapHours ?? defaultCap;
    final saved = await showModalBottomSheet<DayOverride?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Tokens.space24, Tokens.space8, Tokens.space24,
              MediaQuery.of(ctx).viewInsets.bottom + Tokens.space24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dayEditSheetTitle(dayIndex),
                  style: Theme.of(ctx).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Tokens.space16),
                Text(l.dayEditStartHour,
                    style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 4),
                DropdownButton<int>(
                  value: startHour,
                  isExpanded: true,
                  items: [
                    for (var h = 4; h <= 14; h++)
                      DropdownMenuItem(
                        value: h,
                        child: Text('${h.toString().padLeft(2, '0')}:00'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setSheetState(() => startHour = v);
                  },
                ),
                const SizedBox(height: Tokens.space16),
                Text(l.dayEditMaxDriving(capHours),
                    style: Theme.of(ctx).textTheme.labelMedium),
                Slider(
                  value: capHours.toDouble(),
                  min: 4, max: 14, divisions: 10,
                  label: '$capHours h',
                  onChanged: (v) =>
                      setSheetState(() => capHours = v.round()),
                ),
                const SizedBox(height: Tokens.space16),
                Row(
                  children: [
                    if (current != null) ...[
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(
                          DayOverride(dayIndex: dayIndex),
                        ),
                        child: Text(l.dayEditReset),
                      ),
                      const SizedBox(width: Tokens.space8),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: Text(l.dayEditCancel),
                    ),
                    const SizedBox(width: Tokens.space8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(
                        DayOverride(
                          dayIndex: dayIndex,
                          startHour: startHour,
                          dailyDrivingCapHours: capHours,
                        ),
                      ),
                      child: Text(l.dayEditSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == null) return;
    setState(() {
      // Reset returns a DayOverride with both fields null — treat as
      // "remove this day's override, go back to profile defaults".
      final isReset =
          saved.startHour == null && saved.dailyDrivingCapHours == null;
      if (isReset) {
        _dayOverrides.remove(dayIndex);
      } else {
        _dayOverrides[dayIndex] = saved;
      }
    });
    await _replanWithOverrides();
  }

  /// Fire a full /plan with the current `_dayOverrides` map. In-place
  /// swap of `_response` so scroll position + saved-hotel selection
  /// survive. Enrich landed data (hotels / restaurants / fuel) stays
  /// because we call `.planTrip` (monolithic endpoint) rather than
  /// the core/enrich split — user is willing to wait once for the
  /// full picture after an edit.
  Future<void> _replanWithOverrides() async {
    final api = ref.read(apiClientWithPremiumProvider);
    setState(() => _replanning = true);
    try {
      final replan = widget.request
          .withDayOverrides(_dayOverrides.values.toList());
      final response = await api.planTrip(replan);
      if (!mounted) return;
      setState(() {
        _response = response;
        _replanning = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _replanning = false);
      // TODO(dev): surface a discreet snackbar on replan failure.
    }
  }

  /// Toggle a night's picked hotel. Only one hotel per day — tapping
  /// a different one overwrites; tapping the same one un-picks.
  void _toggleNightHotel(int dayIndex, Hotel hotel) {
    setState(() {
      final current = _selectedNightHotels[dayIndex];
      if (current != null &&
          current.name == hotel.name &&
          current.coordinate.lat == hotel.coordinate.lat &&
          current.coordinate.lon == hotel.coordinate.lon) {
        _selectedNightHotels.remove(dayIndex);
      } else {
        _selectedNightHotels[dayIndex] = hotel;
      }
    });
  }

  /// Running € saved by the driver's chosen fuel stops. Currently
  /// wired only for the backend-suggested "cheapest in the refuel
  /// window" station: when the user taps "+ Add" on it, the
  /// pre-computed `suggestedSavingsEur` gets rolled into the trip
  /// savings receipt. Manual fuel-tile picks (non-suggested
  /// stations) don't carry a per-station savings figure yet — the
  /// backend only stamps `savings_vs_country_median_eur_per_l`,
  /// which is €/L not € total. Returns 0 when nothing eligible is
  /// added.
  double get _addedFuelSavingsEur {
    final rw = _response.refuelWindow;
    final s = rw?.suggestedStation;
    if (s == null || rw?.suggestedSavingsEur == null) return 0.0;
    final coordSuffix = s.coordinate == null
        ? ':nocoord'
        : ':${s.coordinate!.lat.toStringAsFixed(4)},'
            '${s.coordinate!.lon.toStringAsFixed(4)}';
    final key = 'fuel:${s.stationName}$coordSuffix';
    if (!_addedRouteWaypoints.containsKey(key)) return 0.0;
    return rw!.suggestedSavingsEur!;
  }

  /// Sum of picked-hotel prices across nights. Passed to the cost
  /// card so the total reflects the user's actual bookings, not
  /// just the algorithmically-chosen sleep_stop.
  double get _selectedHotelsCostEur {
    final pax = widget.request.tripProfile?.travellers ?? 1;
    final rooms = (pax.clamp(1, 20) / 2).ceil();
    return _selectedNightHotels.values
        .fold<double>(0.0, (sum, h) => sum + h.priceEurPerNight * rooms);
  }

  /// Return the cheapest `limit` fuel stations that have both a
  /// known price and a coordinate we can plot. Sorted ascending
  /// by price. Used to seed the fuel map layer without drowning
  /// long-corridor plans in every station along the road.
  static List<FuelPrice> _topCheapestFuel(
    List<FuelPrice> prices, int limit,
  ) {
    final withPrice = prices
        .where((f) => f.priceAvailable && f.coordinate != null)
        .toList()
      ..sort((a, b) => a.priceEurPerL.compareTo(b.priceEurPerL));
    return withPrice.take(limit).toList(growable: false);
  }

  void _clearAddedStops() {
    if (_addedStops.isEmpty) return;
    setState(() {
      _addedStops.clear();
      _addedRouteWaypoints.clear();
    });
  }

  /// Build the Google Maps export sheet input, then present it.
  ///
  /// Waypoint composition, in km-along-route order (Google visits them
  /// in insertion order, so the sort matters or the URL zig-zags):
  ///   1. Detour anchors from every toll the driver chose to SKIP
  ///      (i.e. the tolls NOT in `_tollSkipEnabled`). Prepended by
  ///      priority — they're the reason the export exists in the
  ///      "some tolls skipped" case.
  ///   2. Trip waypoints (intermediate stops from the plan form).
  ///   3. Route waypoints pinned on this screen (restaurants / fuel
  ///      added via "Añadir a la ruta").
  ///
  /// Then capped at 9 (Google Maps limit). When we'd overflow, detour
  /// anchors keep priority over restaurants — the toll skip only
  /// works if the detour point survives, whereas losing a restaurant
  /// just means Google won't route past that one POI.
  ///
  /// `avoid=tolls` semantics:
  ///   - All partial-toll skips enabled by the driver -> no avoid
  ///     (they want the tolled motorway everywhere).
  ///   - All partial-toll skips DISABLED -> add `avoid=tolls`
  ///     globally (Google picks the whole-route detour).
  ///   - Some subset -> DO NOT add `avoid=tolls` (that would drop the
  ///     motorway for the whole trip); rely on the injected detour
  ///     waypoints to route around the specific skipped booths.
  void _openExportSheet() {
    final skips = _response.partialTollSkips;
    final skippedIndices = <int>[
      for (var i = 0; i < skips.length; i++)
        if (!_tollSkipEnabled.contains(i)) i,
    ];

    // Compute km-along-route once per candidate so the sort stays O(n log n).
    final totalKm = _response.route.distanceKm;
    double kmOf(LatLon c) => _kmFromOrigin(c) ?? totalKm;

    // 1. Detour anchors from every skipped toll.
    final List<(LatLon, double)> detourPts = <(LatLon, double)>[];
    for (final i in skippedIndices) {
      for (final p in detourWaypointsFor(skips[i])) {
        detourPts.add((p, kmOf(p)));
      }
    }
    detourPts.sort((a, b) => a.$2.compareTo(b.$2));

    // 2. Trip waypoints from the plan request (intermediate stops).
    //    Use their request order and take their km straight from the
    //    route so a wonky reverse-geocode doesn't reshuffle them.
    final List<(LatLon, double)> tripPts = <(LatLon, double)>[
      for (final w in widget.request.waypoints)
        (w.coordinate, kmOf(w.coordinate)),
    ];

    // 3. Route waypoints added on this screen (restaurants / fuel).
    final List<(LatLon, double)> addedPts = <(LatLon, double)>[
      for (final entry in _addedRouteWaypoints.values)
        (entry.$1, kmOf(entry.$1)),
    ];

    // Merge & cap at 9. Priority: detours > trip stops > added POIs.
    const int maxWaypoints = 9;
    final List<(LatLon, double)> merged = <(LatLon, double)>[];
    void addBucket(List<(LatLon, double)> bucket) {
      for (final e in bucket) {
        if (merged.length >= maxWaypoints) return;
        merged.add(e);
      }
    }

    addBucket(detourPts);
    addBucket(tripPts);
    addBucket(addedPts);

    // Final sort — Google respects insertion order, so km ascending
    // keeps origin -> ... -> destination monotonic and prevents the
    // "figure-8" the app used to draw when a restaurant sat before a
    // trip waypoint.
    merged.sort((a, b) => a.$2.compareTo(b.$2));
    final waypoints = <LatLon>[for (final e in merged) e.$1];

    final noneSkipped = skippedIndices.isEmpty;
    final allSkipped = skips.isNotEmpty && skippedIndices.length == skips.length;
    final avoidTollsFlag = allSkipped; // only when EVERY toll is skipped

    // Debug trace so testers can eyeball the URL length + waypoint
    // count when reporting export bugs. Cheap and only fires on tap.
    // ignore: avoid_print
    debugPrint(
      '[TripExport] waypoints=${waypoints.length}/${maxWaypoints} '
      'detours=${detourPts.length} tripStops=${tripPts.length} '
      'added=${addedPts.length} '
      'avoidTolls=$avoidTollsFlag noneSkipped=$noneSkipped '
      'allSkipped=$allSkipped',
    );

    showExportSheet(
      context,
      origin: widget.request.origin,
      destination: widget.request.destination,
      waypoints: waypoints,
      avoidHighways: widget.request.avoidMotorways,
      avoidTolls: avoidTollsFlag,
    );
  }

  /// Estimates km-from-origin for [coord] by finding the nearest point
  /// in the route geometry and using its index fraction × totalKm.
  double? _kmFromOrigin(LatLon coord) {
    final geom = _response.route.geometry;
    final totalKm = _response.route.distanceKm;
    if (geom.isEmpty || totalKm <= 0) return null;
    var bestIndex = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < geom.length; i++) {
      final dlat = geom[i].lat - coord.lat;
      final dlon = geom[i].lon - coord.lon;
      final d = dlat * dlat + dlon * dlon; // squared — no need for sqrt
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }
    return (bestIndex / (geom.length - 1)) * totalKm;
  }

  /// Resolve the flat `_addedStops` map (keyed by string ids) into
  /// full `AddedStop` records with coord + label so the map sheet can
  /// plot markers. Order preserved from the API response so nearby
  /// tiles stay adjacent in the legend list.
  List<AddedStop> _resolveAddedStops() {
    if (_addedStops.isEmpty) return const [];
    final out = <AddedStop>[];
    for (final h in _response.hotels) {
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
          distanceFromOriginKm: _kmFromOrigin(h.coordinate),
        ));
      }
    }
    for (final r in _response.restaurants) {
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
          distanceFromOriginKm: _kmFromOrigin(r.coordinate),
        ));
      }
    }
    for (final p in _response.fuelPrices) {
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
              ? '${p.priceEurPerL.toStringAsFixed(3)} ${p.unitLabel} · '
                  '${p.distanceFromOriginKm.toStringAsFixed(0)} km'
              : '${p.distanceFromOriginKm.toStringAsFixed(0)} km',
          coordinate: p.coordinate!,
          distanceFromOriginKm: p.distanceFromOriginKm,
        ));
      }
    }
    // Meal + sleep stops the user pinned from the "Optimizado" section.
    for (final m in _response.optimizations?.mealStops
        ?? const <MealStopOpt>[]) {
      final key = _optMealKey(m);
      if (_addedStops.containsKey(key) && m.coordinate != null) {
        out.add(AddedStop(
          kind: AddedStopKind.restaurant,
          label: m.restaurantName ?? m.slot,
          subtitle: m.cityHint ?? '${m.distanceFromOriginKm.toStringAsFixed(0)} km',
          coordinate: m.coordinate!,
          distanceFromOriginKm: _kmFromOrigin(m.coordinate!),
        ));
      }
    }
    final sleep = _response.optimizations?.sleepStop;
    if (sleep != null) {
      final key = _optSleepKey(sleep);
      if (_addedStops.containsKey(key) && sleep.coordinate != null) {
        out.add(AddedStop(
          kind: AddedStopKind.hotel,
          label: sleep.hotelName ?? 'Sleep stop',
          subtitle: sleep.cityHint ?? '${sleep.distanceFromOriginKm.toStringAsFixed(0)} km',
          coordinate: sleep.coordinate!,
          distanceFromOriginKm: _kmFromOrigin(sleep.coordinate!),
        ));
      }
    }
    return out;
  }

  static String _optMealKey(MealStopOpt m) => _mealStopKey(m);

  static String _optSleepKey(SleepStopOpt s) => _sleepStopKey(s);

  void _openAddedStopsMap() {
    final stops = _resolveAddedStops();
    if (stops.isEmpty) return;
    showAddedStopsMapSheet(
      context,
      stops: stops,
      origin: widget.request.origin,
      destination: widget.request.destination,
      routeGeometry: _response.route.geometry,
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
  void _showAdverseEventsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space20),
          children: [
            for (final e in _response.adverseEvents)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space8),
                child: _AdverseEventTile(
                  event: e,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showAdverseEventSheet(
                      context,
                      event: e,
                      origin: widget.request.origin,
                      destination: widget.request.destination,
                      routeGeometry: _response.route.geometry,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

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
      loadingTitle: AppLocalizations.of(context).replanNewDepartureTitle,
    );
  }

  Future<void> _replan({
    required DateTime newDeparture,
    required bool avoidMotorways,
    TripPlanRequest? overrideRequest,
    String? loadingTitle,
  }) async {
    // Root navigator so a mid-flight MaterialApp rebuild
    // (DynamicColorBuilder returning wallpaper colours) cannot
    // detach the pop target and leave the loading dialog stuck.
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    var dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => PlanLoadingDialog(title: loadingTitle),
    ));
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final replan = overrideRequest ?? TripPlanRequest(
        origin: widget.request.origin,
        destination: widget.request.destination,
        desiredDepartureAt: newDeparture,
        waypoints: widget.request.waypoints,
        countries: widget.request.countries,
        hotelMaxDetourMinutes: widget.request.hotelMaxDetourMinutes,
        hotelPriceBand: widget.request.hotelPriceBand,
        hotelPriceBands: widget.request.hotelPriceBands,
        hotelMinStars: widget.request.hotelMinStars,
        hotelIncludeOther: widget.request.hotelIncludeOther,
        hotelDestinationRadiusKm: widget.request.hotelDestinationRadiusKm,
        hotelConditions: widget.request.hotelConditions,
        restaurantMaxDetourMinutes:
            widget.request.restaurantMaxDetourMinutes,
        restaurantPriceBand: widget.request.restaurantPriceBand,
        restaurantPriceBands: widget.request.restaurantPriceBands,
        restaurantCuisines: widget.request.restaurantCuisines,
        restaurantConditions: widget.request.restaurantConditions,
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
        includeParking: widget.request.includeParking,
      );
      // Foreground service pins the process so the user can
      // background the app mid-replan without Doze killing the
      // socket. Tray notification also flags "still working".
      final replanLabel =
          '${widget.origin.displayName} → ${widget.destination.displayName}';
      final fresh = await runInForeground(
        context,
        replanLabel,
        () => api.planTrip(replan),
      );
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
    final route = _response.route;
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
    final restaurants = _response.restaurants;
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
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
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
      onToggleAdd: () => _toggleStop(key, r.detourMinutes,
          coord: r.coordinate, label: r.name),
      onTap: () => showPoiDetailSheet(
        context,
        kind: PoiKind.restaurant,
        name: r.name,
        subtitle: '${r.country.displayName} · '
            '${AppLocalizations.of(context).pricePerMeal(r.priceEurPerMeal.toStringAsFixed(0))} · '
            '+${r.detourMinutes.toStringAsFixed(0)} min',
        poi: r.coordinate,
        origin: widget.request.origin,
        destination: widget.request.destination,
        routeGeometry: _response.route.geometry,
        attributes: r.attributes,
        icon: Icons.restaurant_outlined,
        accent: Theme.of(context).colorScheme.tertiary,
      ),
    );
  }

  TimeWindow? get _recommended {
    for (final w in _response.timeWindows) {
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
        distanceKm: _response.route.distanceKm,
        recommendedDepartureAt: recommended.departureAt,
        recommendedMinutes: recommended.estimatedMinutes,
        countriesCrossed: _response.route.countriesCrossed,
        savedMinutesVsDesired:
            _response.savings.timeSavedMinutesVsDesired,
        savedEurVsTolls: _response.savings.moneySavedEurVsTolls,
        fuelCostEur:
            _response.optimizations?.fuelCost.totalCostEur ?? 0,
        reminderMinutesBefore: reminderMinutes,
        notificationId: notificationId,
      );
      await storage.save(trip);
      // Schedule fuel arbitrage notification if the trip crosses
      // a border with a meaningful price difference. Fires 15 min
      // before departure so the driver sees "fill up in X before
      // crossing into Y" while still at home/hotel.
      final arb = _response.fuelArbitrage;
      if (arb != null && arb.estimatedTankSavingEur >= 5) {
        await NotificationService.instance.scheduleDepartureReminder(
          tripId: 'fuel:$id',
          departureLocal:
              recommended.departureAt.toLocal().subtract(
                const Duration(minutes: 15),
              ),
          minutesBefore: 0,
          title: l.fuelNotificationTitle,
          body: l.fuelNotificationBody(
            arb.cheaperCountry.displayName,
            arb.cheaperMedianEurPerL.toStringAsFixed(2),
            arb.pricierCountry.displayName,
            arb.estimatedTankSavingEur.toStringAsFixed(0),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _saved = true);
      // Snackbar augmented with a tiny Lottie check circle that
      // plays once (~1.5s). `errorBuilder` swaps in an inline icon
      // so a broken asset can't hide the confirmation copy.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1800),
          content: Row(
            children: [
              SizedBox(
                width: 28, height: 28,
                child: Lottie.asset(
                  'assets/lottie/saved_check.json',
                  width: 28, height: 28,
                  repeat: false,
                  errorBuilder: (context, error, stack) =>
                      const Icon(Icons.check_circle, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l.resultTripSaved)),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Two share modes. Text-only reuses the existing `shareTrip`
  /// with the deep link. Image mode renders a story-format card
  /// and hands it to the share sheet — perfect for Instagram
  /// Stories / WhatsApp / X.
  Future<void> _openShareMenu(AppLocalizations l) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l.shareCardOption),
              subtitle: Text(l.shareCardOptionSub),
              onTap: () => Navigator.of(context).pop('image'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l.shareLinkOption),
              subtitle: Text(l.shareLinkOptionSub),
              onTap: () => Navigator.of(context).pop('link'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'image') {
      await shareTripCard(
        context,
        originName: _shortName(widget.origin),
        destinationName: _shortName(widget.destination),
        route: _response.route,
        savedEur: _response.savings.moneySavedEurVsTolls,
        savedMinutes: _response.savings.timeSavedMinutesVsDesired,
      );
    } else {
      await shareTrip(
        l: l,
        localeName: Localizations.localeOf(context).toString(),
        originName: _shortName(widget.origin),
        destinationName: _shortName(widget.destination),
        route: _response.route,
        origin: widget.request.origin,
        destination: widget.request.destination,
        departureAt: widget.desiredDepartureAt,
        recommended: _recommended,
        tollAlt: _response.tollAlternative,
        hotels: _response.hotels,
        restaurants: _response.restaurants,
        fuelArbitrage: _response.fuelArbitrage,
      );
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
    final route = _response.route;
    final recommended = _recommended;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // User-selected display currency. Backend prices are EUR;
    // `formatMoney` converts and appends the right symbol.
    final ccy = ref.watch(currencyCodeProvider);
    // Honour the OS "reduce motion" preference — keeps the fadeIn
    // (it's cheap and low-vestibular) but drops the moveY / scale
    // choreography so the entrance isn't jarring for users who opted
    // out of animations.
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Scope tells the client which sections to surface. When absent
    // (request had no TripProfile), fall through to a permissive default.
    final scope = _response.recommendationScope;
    final showRestaurants = scope?.showRestaurants ?? true;
    final bedtimeHour = widget.request.tripProfile?.bedtimeHour ?? 22;

    // Hero widgets captured as locals so the ListView wrapper below
    // can identity-match them and apply the staggered landing
    // animation only to these four (not to spacers or later
    // sections). Keeping identity checks (vs. index bookkeeping)
    // stays robust when the sections list gets re-ordered.
    final Widget heroMapCard = _InteractiveMapCard(
      origin: widget.request.origin,
      destination: widget.request.destination,
      route: route,
      alternativeGeometry:
          _response.tollAlternative?.geometry ?? const [],
      hotels: _filteredHotels,
      restaurants: _response.restaurants,
      tollSkips: _response.partialTollSkips,
      fuelStations: _topCheapestFuel(_response.fuelPrices, 10),
      adverseEvents: _response.adverseEvents,
      mode: _mapMode,
      onModeChange: (m) => setState(() => _mapMode = m),
    );
    final Widget heroOriginDestRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
      child: Row(
        children: [
          Icon(Icons.trip_origin, size: 14, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.origin.displayName,
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 14,
                color: scheme.onSurfaceVariant),
          ),
          Icon(Icons.location_on, size: 14, color: Colors.red.shade700),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.destination.displayName,
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32, minHeight: 32,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: l.exportShareTitle,
            icon: const Icon(Icons.ios_share, size: 18),
            onPressed: _openExportSheet,
          ),
        ],
      ),
    );
    final Widget heroCompanionButton = SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        icon: const Icon(Icons.assistant_navigation, size: 20),
        label: Text(l.resultStartCompanion),
        onPressed: _startCompanion,
      ),
    );
    final Widget heroStatsCard = InkWell(
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
                  value: formatMoney(
                    (route.tollCostEur - _tollSkipSavingsEur)
                        .clamp(0.0, route.tollCostEur),
                    ccy,
                  ),
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
              if (_addedRouteWaypoints.isNotEmpty) ...[
                const SizedBox(height: Tokens.space8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _replanWithAddedStops,
                    icon: const Icon(Icons.route, size: 18),
                    label: Text(
                      AppLocalizations.of(context).replanWithStops,
                    ),
                  ),
                ),
              ],
            ],
            if (_response.days.isNotEmpty) ...[
              const SizedBox(height: Tokens.space12),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: Tokens.space4),
              for (final d in _response.days)
                _DayStripRow(day: d),
            ],
          ],
        ),
      ),
    );

    final sections = <Widget>[
      if (_response.adverseEvents.isNotEmpty)
        _AdverseEventsBanner(
          events: _response.adverseEvents,
          onTap: () => _showAdverseEventsSheet(context),
        )
      else if (widget.request.includeAdverseEvents && _enrichPending)
        // Pre-enrich: show a discreet "loading alerts" chip so the
        // driver knows we haven't confirmed the corridor is clear
        // yet. Prevents a jarring flip from "all clear" checkmark to
        // "wildfire near km 240" a couple of seconds later.
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.planLoadingStepAlerts,
                  style: t.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        )
      else if (widget.request.includeAdverseEvents)
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 16,
                  color: Colors.green.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.emptyAlertsTitle,
                  style: t.bodySmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Tokens.space20, 0, Tokens.space20, Tokens.space24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.emptyAlertsTitle,
                            style: t.titleMedium),
                        const SizedBox(height: Tokens.space8),
                        Text(l.emptyAlertsBody,
                            style: t.bodyMedium),
                      ],
                    ),
                  ),
                ),
                child: Icon(Icons.info_outline, size: 16,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      heroMapCard,
      const SizedBox(height: Tokens.space12),
      heroOriginDestRow,
      // Inline Companion CTA — same behaviour as the bottom FAB, but
      // reachable without scrolling to the bottom. Testers wanted a
      // one-tap entry near the trip summary.
      const SizedBox(height: Tokens.space8),
      heroCompanionButton,
      const SizedBox(height: Tokens.space12),
      heroStatsCard,
      // Progress card for the enrich phase — visible while /plan/enrich
      // is in flight, auto-fades when it lands. Renders as SizedBox
      // once done so it doesn't take vertical space.
      const SizedBox(height: Tokens.space12),
      EnrichmentProgress(
        pending: _enrichPending,
        hotelsRequested: (widget.request.hotelMaxDetourMinutes ?? 0) > 0,
        restaurantsRequested:
            (widget.request.restaurantMaxDetourMinutes ?? 0) > 0,
        adverseRequested: widget.request.includeAdverseEvents,
        hasHotels: _response.hotels.isNotEmpty,
        hasRestaurants: _response.restaurants.isNotEmpty,
        hasFuel: _response.fuelPrices.isNotEmpty,
        hasWeather: _response.weatherSegments.isNotEmpty,
        hasAdverse: _response.adverseEvents.isNotEmpty,
      ),
      if (_response.days.isNotEmpty) ...[
        const SizedBox(height: Tokens.space16),
        Container(
          key: _tollKey,
          child: DayPlanSection(
            days: _response.days,
            timeFormat: DateFormat.Hm(),
            hotels: _filteredHotels,
            destination: widget.request.destination,
            origin: widget.request.origin,
            originName: widget.origin.displayName,
            destinationName: widget.destination.displayName,
            routeGeometry: _response.route.geometry,
            selectedNightHotels: _selectedNightHotels,
            onToggleNightHotel: _toggleNightHotel,
            showHotelSections:
                widget.request.hotelMaxDetourMinutes != null &&
                    widget.request.hotelMaxDetourMinutes! > 0,
            partialTollSkips: _response.partialTollSkips,
            enabledTollIndices: _tollSkipEnabled,
            onToggleToll: (i, enabled) => setState(() {
              if (enabled) {
                _tollSkipEnabled.add(i);
              } else {
                _tollSkipEnabled.remove(i);
              }
            }),
            hourlyTollReport: _response.hourlyTollReport,
            tripDepartureAt: widget.desiredDepartureAt,
            routeFreeFlowMinutes: _response.route.freeFlowMinutes,
            routeTotalKm: _response.route.distanceKm,
            addedStops: _resolveAddedStops(),
            weatherSegments: _response.weatherSegments,
            enrichPending: _enrichPending,
            hotelsRequested:
                (widget.request.hotelMaxDetourMinutes ?? 0) > 0,
            onEditDay: _replanning ? null : _openDayEditSheet,
            overriddenDayIndices: _dayOverrides.keys.toSet(),
          ),
        ),
      ],
      const SizedBox(height: Tokens.space24),
      if (_response.consistencyIssues.isNotEmpty)
        ConsistencyBanner(issues: _response.consistencyIssues),
      // Trip cost hero: the first thing the user wants to know.
      if (_response.optimizations != null) ...[
        _TotalTripCostCard(
          fuelCostEur: _response.optimizations!.fuelCost.totalCostEur,
          tollCostEur: route.tollCostEur,
          mealStops: _response.optimizations!.mealStops,
          sleepStop: _response.optimizations!.sleepStop,
          tollSkipSavingsEur: _tollSkipSavingsEur,
          travellers: widget.request.tripProfile?.travellers ?? 1,
          tripDays: _response.days.length,
          pickedHotelsCostEur: _selectedNightHotels.isEmpty
              ? null
              : _selectedHotelsCostEur,
          pickedHotelsNights: _selectedNightHotels.length,
          savings: _response.savings.copyWith(
            fuelSavingsEur: _addedFuelSavingsEur > 0
                ? _addedFuelSavingsEur
                : null,
          ),
          tollSkipPenaltyMinutes: _tollSkipPenaltyMinutes,
          intraSectionSkips: _response.intraSectionSkips,
        ),
        const SizedBox(height: Tokens.space16),
      ],
      // Next-stop hero: pulls the first meal stop of the trip so the
      // driver always sees "next planned stop" up top without hunting
      // through the Optimizations section.
      if (_response.optimizations != null &&
          _response.optimizations!.mealStops.isNotEmpty) ...[
        Builder(builder: (context) {
          final meal = _response.optimizations!.mealStops.first;
          final coordSuffix = meal.restaurantCoordinate == null
              ? ':nocoord'
              : ':${meal.restaurantCoordinate!.lat.toStringAsFixed(4)},'
                  '${meal.restaurantCoordinate!.lon.toStringAsFixed(4)}';
          final stopKey = 'restaurant:${meal.restaurantName ?? ""}$coordSuffix';
          return NextStopHero(
            mealStop: meal,
            timeFormat: DateFormat.Hm(),
            isAdded: _isAdded(stopKey),
            onAdd: () => _toggleStop(stopKey, 0),
            onTap: meal.restaurantCoordinate == null
                ? null
                : () => showPoiDetailSheet(
                      context,
                      kind: PoiKind.restaurant,
                      name: meal.restaurantName ?? '—',
                      subtitle: [
                        DateFormat.Hm().format(meal.at.toLocal()),
                        if (meal.restaurantPriceEurPerMeal != null)
                          AppLocalizations.of(context).pricePerMeal(
                              meal.restaurantPriceEurPerMeal!.toStringAsFixed(0)),
                        AppLocalizations.of(context).kmFromOrigin(
                            meal.distanceFromOriginKm.toStringAsFixed(0)),
                      ].join(' · '),
                      poi: meal.restaurantCoordinate!,
                      origin: widget.request.origin,
                      destination: widget.request.destination,
                      routeGeometry: _response.route.geometry,
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
          onTap: () {
            final ctx = _hotelKey.currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          },
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
      if (_response.optimizations?.sleepStop != null &&
          _isPlausibleSleepTime(
            _response.optimizations!.sleepStop!.at,
          )) ...[
        _MultiDaySleepPreview(
          sleepStop: _response.optimizations!.sleepStop!,
          hotels: _response.hotels,
          origin: widget.request.origin,
          destination: widget.request.destination,
          routeGeometry: _response.route.geometry,
        ),
        const SizedBox(height: Tokens.space16),
      ],
      const SizedBox(height: Tokens.space16),
      _DepartureTimingSection(
        key: _timeWindowKey,
        recommended: recommended,
        desiredDepartureAt: widget.desiredDepartureAt,
        freeFlowMinutes: route.freeFlowMinutes,
        savedMinutesVsDesired:
            _response.savings.timeSavedMinutesVsDesired,
        initialWindows: _response.timeWindows,
        initialSpanHours: widget.request.timeWindowSpanHours,
        onFetch: _refetchWindows,
        onWindowSelect: _replanWithDeparture,
        onSelectRecommended: recommended != null
            ? () => _replanWithDeparture(recommended)
            : null,
      ),
      if (_response.routeVariants.length >= 2) ...[
        const SizedBox(height: Tokens.space24),
        _RouteVariantsSection(variants: _response.routeVariants),
      ],
      if (_response.optimizations != null) ...[
        const SizedBox(height: Tokens.space24),
        _OptimizationsSection(
          key: _hotelKey,
          opts: _response.optimizations!,
          // Ship the full pool; the section shows 3 up-front and
          // hides the rest behind a "Ver más" expander so the
          // standalone `_DestinationHotelsSection` below stops
          // duplicating this list.
          topHotels: _topDestinationHotels(30),
          origin: widget.request.origin,
          destination: widget.request.destination,
          originName: widget.origin.displayName,
          destinationName: widget.destination.displayName,
          routeGeometry: _response.route.geometry,
          addedKeys: _addedStops.keys.toSet(),
          weatherSegments: _response.weatherSegments,
          onAddMealStop: (m) => setState(() =>
              _toggleStop(_optMealKey(m), 0)),
          onAddSleepStop: (s) => setState(() =>
              _toggleStop(_optSleepKey(s), 0)),
        ),
      ],
      // The former standalone "_DestinationHotelsSection" was
      // removed 2026-08-30 — its content duplicated the hotel
      // list that now lives INSIDE `_OptimizationsSection`
      // ("Optimizado") with a 3-item preview + "Ver más" expander.
      // Multi-day trips still surface hotels per day via
      // DayPlanSection.
      // Alerts section moved to the top (after trip cost card).
      // Rest stops section removed (tester feedback): with meals +
      // sleep already surfaced per day, a separate "recommended
      // stops" list read as redundant noise. The domain data is
      // still emitted so day_plan / consistency checks work.
      // Weather along route — forecast conditions at 5 points.
      if (_response.weatherSegments.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        _WeatherStripCard(segments: _response.weatherSegments),
      ],
      // Parkings near destination — populated only when the user
      // ticked the "Parking" preference on the plan form.
      if (_response.parkings.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        _DestinationParkingSection(
          parkings: _response.parkings,
        ),
      ],
      // Flat hotel list removed (2026-08-26 tester feedback):
      // hotels are now shown per-day inside DayPlanSection,
      // grouped by overnight stop / destination. The promoted
      // _MultiDaySleepPreview card stays; the scrollable flat
      // list is gone.
      // Restaurants: while enrich is pending, show a skeleton so the
      // driver doesn't briefly see "no restaurants found" for a
      // request that IS going to return restaurants a few seconds
      // later. Once enrich lands the branch below decides between
      // populated list and the true empty state.
      if (showRestaurants &&
          widget.request.restaurantMaxDetourMinutes != null &&
          widget.request.restaurantMaxDetourMinutes! > 0 &&
          _response.restaurants.isEmpty &&
          _enrichPending) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultRestaurants, eyebrow: l.resultEyebrowNearRoute,
        ),
        const _EnrichListSkeleton(),
      ],
      if (showRestaurants &&
          widget.request.restaurantMaxDetourMinutes != null &&
          widget.request.restaurantMaxDetourMinutes! > 0 &&
          _response.restaurants.isEmpty &&
          !_enrichPending) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultRestaurants, eyebrow: l.resultEyebrowNearRoute,
        ),
        // Distinct copy from `emptyRestaurantsTitle` (which reads as
        // "no match on filters"): this one fires when the enrichment
        // finished with zero features from the provider, i.e. the
        // corridor itself has no restaurant coverage in Geoapify.
        EmptyStateCard(
          icon: Icons.restaurant_outlined,
          title: l.emptyRestaurantsNotFoundTitle,
          body: l.emptyRestaurantsNotFoundBody,
        ),
      ],
      if (showRestaurants && _response.restaurants.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            initiallyExpanded: false,
            title: Text(
              l.resultRestaurants,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              l.resultEyebrowNearRoute,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            leading: Icon(
              Icons.restaurant_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            children: _restaurantSectionsBySlot(l),
          ),
        ),
      ],
      // Fuel prices: same pattern as restaurants above. Show a
      // skeleton while enrich hasn't landed so the driver's mental
      // model is "loading" instead of "no data".
      if (_response.fuelPrices.isEmpty && _enrichPending) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultFuel,
          eyebrow: l.resultEyebrowNearRoute,
        ),
        const _EnrichListSkeleton(),
      ],
      // Fuel "no results" state: enrichment finished, provider had
      // nothing on this corridor (fuel is always "requested", there
      // is no per-user opt-out flag). Without this branch the whole
      // section vanished silently and the driver couldn't tell if
      // the search failed or was still loading.
      if (_response.fuelPrices.isEmpty && !_enrichPending) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultFuel,
          eyebrow: l.resultEyebrowNearRoute,
        ),
        EmptyStateCard(
          icon: Icons.local_gas_station_outlined,
          title: l.emptyFuelNotFoundTitle,
          body: l.emptyFuelNotFoundBody,
        ),
      ],
      if (_response.fuelPrices.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        if (_response.fuelArbitrage != null) ...[
          FuelArbitrageBanner(hint: _response.fuelArbitrage!),
          const SizedBox(height: Tokens.space12),
        ],
        // Proactive refuel-here-and-save card. Only rendered when
        // the backend flagged the tank as insufficient AND managed
        // to pre-pick a cheapest station on the window. Tapping
        // "+ Add" pipes into the same `_addedRouteWaypoints` flow
        // as manual fuel-tile picks.
        if (_response.refuelWindow?.suggestedStation != null) ...[
          Builder(builder: (context) {
            final suggested =
                _response.refuelWindow!.suggestedStation!;
            final coordSuffix = suggested.coordinate == null
                ? ':nocoord'
                : ':${suggested.coordinate!.lat.toStringAsFixed(4)},'
                    '${suggested.coordinate!.lon.toStringAsFixed(4)}';
            final key = 'fuel:${suggested.stationName}$coordSuffix';
            return _RefuelSuggestionCard(
              station: suggested,
              savingsEur:
                  _response.refuelWindow!.suggestedSavingsEur,
              isAdded: _isAdded(key),
              onToggleAdd: () {
                _toggleStop(
                  key,
                  _fuelStopMinutes,
                  coord: suggested.coordinate,
                  label: suggested.stationName,
                );
              },
            );
          }),
          const SizedBox(height: Tokens.space12),
        ],
        // Collapsible now — the top-10 cheapest are already on
        // the map; this list becomes an on-demand detailed view
        // for drivers who want to compare all stations.
        Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            initiallyExpanded: false,
            title: Text(
              l.resultFuel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              l.resultFuelCollapsedHint(
                _response.fuelPrices.length,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            leading: Icon(
              Icons.local_gas_station,
              color: Theme.of(context).colorScheme.primary,
            ),
            children: [
              // Sort by distance-from-origin so the list follows the
              // trip order — the driver sees stations in the sequence
              // they'll actually pass, not shuffled by price.
              ..._separated(
                (List<FuelPrice>.from(_response.fuelPrices)
                      ..sort((a, b) => a.distanceFromOriginKm
                          .compareTo(b.distanceFromOriginKm)))
                    .map((p) {
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
                                  '${p.priceEurPerL.toStringAsFixed(3)} ${p.unitLabel} · '
                                  '${p.distanceFromOriginKm.toStringAsFixed(0)} km',
                              poi: p.coordinate!,
                              origin: widget.request.origin,
                              destination: widget.request.destination,
                              routeGeometry:
                                  _response.route.geometry,
                              attributes: p.attributes,
                              icon: Icons.local_gas_station,
                              accent:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                  );
                }).toList(),
              ),
            ],
          ),
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
            onPressed: () => _openShareMenu(l),
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
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
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
                  _wrapSectionAnimated(
                    sections[i],
                    index: i,
                    reduceMotion: reduceMotion,
                    heroMap: sections[i] == heroMapCard,
                    heroOriginDest: sections[i] == heroOriginDestRow,
                    heroCompanion: sections[i] == heroCompanionButton,
                    heroStats: sections[i] == heroStatsCard,
                  ),
              ],
            ),
          ),
          // One-shot "plan ready" pill. Sits above the ListView so it
          // fades in/out without shifting the layout. IgnorePointer so
          // the taps on the AppBar / body still land.
          Positioned(
            top: Tokens.space8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedSwitcher(
                  duration: Tokens.motionBase,
                  switchInCurve: Tokens.curveOut,
                  switchOutCurve: Tokens.curveOut,
                  child: _showSuccessChip
                      ? _PlanReadyChip(
                          key: const ValueKey('plan_ready_chip'),
                          distanceKm: route.distanceKm,
                          minutes: route.freeFlowMinutes,
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('plan_ready_chip_gone'),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // Premium gate temporarily removed so we can dogfood Companion
      // during closed testing. Re-add `ref.watch(premiumProvider) ? … : null`
      // before public release / Play beta.
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.assistant_navigation),
        label: Text(l.resultStartCompanion),
        onPressed: _startCompanion,
      ),
    );
  }

  /// Wraps a section in a one-shot entrance animation on the first
  /// build after landing. Any subsequent rebuild (setState from a
  /// toll toggle, hotel pick, replan) short-circuits the wrapper by
  /// returning the child directly — that way the whole staircase
  /// doesn't re-play every time the driver taps something.
  ///
  /// The hero widgets (map, origin→destination row, stats card, and
  /// the inline Companion CTA) get their own delays so the landing
  /// reads like a staggered reveal instead of a synchronous blink.
  /// Non-hero sections keep the pre-existing 40*i cascade so nothing
  /// downstream regresses.
  Widget _wrapSectionAnimated(
    Widget child, {
    required int index,
    required bool reduceMotion,
    bool heroMap = false,
    bool heroOriginDest = false,
    bool heroCompanion = false,
    bool heroStats = false,
  }) {
    if (!_firstShow) return child;
    final Duration delay = heroMap
        ? Duration.zero
        : heroOriginDest
            ? const Duration(milliseconds: 100)
            : heroStats
                ? const Duration(milliseconds: 200)
                : heroCompanion
                    ? const Duration(milliseconds: 350)
                    : Duration(milliseconds: 40 * index);
    final base = child.animate().fadeIn(
          delay: delay,
          duration: Tokens.motionBase,
        );
    if (reduceMotion) return base;
    if (heroCompanion) {
      return base.scale(
        begin: const Offset(0.94, 0.94),
        end: const Offset(1.0, 1.0),
        duration: Tokens.motionBase,
        curve: Tokens.curveOut,
      );
    }
    if (heroMap) {
      return base.moveY(begin: 12, end: 0, curve: Tokens.curveOut);
    }
    return base.moveY(begin: 4, end: 0, curve: Tokens.curveOut);
  }

  /// Extracted so the same behaviour can be triggered from both the
  /// bottom FAB and any inline CTA (e.g. the button next to the
  /// origin→destination row).
  Future<void> _startCompanion() async {
    // 1) Pre-flight sheet — driver reviews meal times, detour tolerance,
    // budget bands before we push the drive screen. Cancelling the sheet
    // aborts the flow.
    final overrides = await showCompanionPreflightSheet(
      context,
      initialHotel: widget.hotelPrefs ?? HotelPreferences.enabledDefault,
      initialRestaurant: RestaurantPreferences(
        enabled: true,
        maxDetourMinutes:
            widget.request.restaurantMaxDetourMinutes ?? 20,
        priceBands: {
          ...?widget.request.restaurantPriceBands,
        }..removeWhere((b) => false),
      ),
      initialProfile: widget.request.tripProfile,
    );
    if (!mounted || overrides == null) return;

    // 2) One-time discoverability nags: Android Auto category coach +
    // battery whitelist. Each fires at most once per install.
    await AaCoachDialog.maybeShow(context);
    if (!mounted) return;
    await BatteryWhitelistDialog.maybeShow(context);
    if (!mounted) return;

    final profile = widget.request.tripProfile;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CompanionDriveScreen(
          breakIntervalHours: 2.0,
          suggestBreak: true,
          fatigueStopSuggestion: false,
          alertCriticalAdverse: true,
          alertWeather: true,
          alertFuel: true,
          alertBorder: true,
          alertToll: false,
          alertHotel: true,
          hasKids: profile?.hasKids ?? false,
          hasPets: profile?.hasPets ?? false,
          bedtimeHour: profile?.bedtimeHour ?? 23,
          activeTrip: widget.response,
          tripOrigin: widget.origin,
          tripDestination: widget.destination,
        ),
      ),
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

/// Small one-shot "plan ready" pill shown at the top of the
/// ResultScreen for ~2s after landing. Kept intentionally tiny —
/// the point is a subtle reward, not a splash. The parent
/// `AnimatedSwitcher` fades this in and out; the chip itself only
/// worries about its own visuals + a quick spring on entry.
class _PlanReadyChip extends StatelessWidget {
  const _PlanReadyChip({
    super.key,
    required this.distanceKm,
    required this.minutes,
  });

  final double distanceKm;
  final double minutes;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final km = distanceKm.round();
    final h = (minutes / 60).floor();
    final m = (minutes % 60).round();
    final label = 'Plan listo  ·  ${km} km  ·  ${h}h ${m}m';
    final chip = Material(
      color: const Color(0xFF16A34A), // green-600
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
    if (reduceMotion) return chip;
    return chip
        .animate()
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: Tokens.motionBase,
          curve: Tokens.curveOut,
        );
  }
}

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
    this.fuelStations = const [],
    this.adverseEvents = const [],
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
  final List<FuelPrice> fuelStations;
  final List<AdverseEvent> adverseEvents;
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
            fuelMarkers: fuelStations,
            adverseEventMarkers: adverseEvents,
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
                          color: scheme.primary,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
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

class _TotalTripCostCard extends ConsumerWidget {
  const _TotalTripCostCard({
    required this.fuelCostEur,
    required this.tollCostEur,
    required this.mealStops,
    this.sleepStop,
    this.tollSkipSavingsEur = 0,
    this.travellers = 1,
    this.tripDays = 1,
    this.pickedHotelsCostEur,
    this.pickedHotelsNights = 0,
    this.savings,
    this.tollSkipPenaltyMinutes = 0,
    this.intraSectionSkips = const [],
  });
  final double fuelCostEur;
  final double tollCostEur;
  final List<MealStopOpt> mealStops;
  final SleepStopOpt? sleepStop;
  final double tollSkipSavingsEur;
  final int travellers;
  final int tripDays;
  final TripSavings? savings;
  final double tollSkipPenaltyMinutes;
  final List<IntraSectionSkip> intraSectionSkips;

  /// When non-null, overrides the algorithmic sleep_stop hotel
  /// cost with the user-picked hotels sum. Set when the user has
  /// tapped "+ hotel" on at least one night in the day view; the
  /// picks span multiple nights, so the value is already
  /// multiplied by rooms and summed across days.
  final double? pickedHotelsCostEur;

  /// Nights the user has picked. Drives the row label ("Hoteles ×2")
  /// so the driver sees the picks reflected in the receipt.
  final int pickedHotelsNights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final ccy = ref.watch(currencyCodeProvider);

    final pax = travellers.clamp(1, 20);
    final lunchCostPerPerson = mealStops.fold<double>(
      0.0, (sum, m) => sum + (m.restaurantPriceEurPerMeal ?? 15.0),
    );
    final extraMealsPerDay = tripDays > 1 ? 2 : 0;
    final extraMealsCostPerPerson = extraMealsPerDay * 12.0 * (tripDays - 1);
    final mealsCost = (lunchCostPerPerson + extraMealsCostPerPerson) * pax;
    // Hotel line: user picks (multi-night) override the
    // algorithmic single-night sleep_stop. Falls back to the
    // sleep_stop estimate when the user hasn't picked anything —
    // that way the receipt shows a plausible night even before
    // they interact.
    final rooms = (pax / 2).ceil();
    final double hotelCost;
    final int hotelNights;
    if (pickedHotelsCostEur != null) {
      hotelCost = pickedHotelsCostEur!;
      hotelNights = pickedHotelsNights;
    } else {
      final hotelPerNight = sleepStop?.hotelPriceEurPerNight ?? 0.0;
      hotelCost = hotelPerNight * rooms;
      hotelNights = hotelPerNight > 0 ? 1 : 0;
    }
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space16),
          _CostRow(label: l.tripCostFuel,
              value: fuelCostEur, scheme: scheme, t: t),
          _CostRow(
            label: l.tripCostTolls,
            value: effectiveTolls,
            scheme: scheme, t: t,
            // Strikethrough the original toll when the driver
            // has skipped at least one booth. Concrete visual
            // proof that the toggle work is paying off.
            originalValue:
                tollSkipSavingsEur > 0 ? tollCostEur : null,
          ),
          if (mealsCost > 0)
            _CostRow(
              label: () {
                final totalMeals = mealStops.length +
                    (tripDays > 1 ? extraMealsPerDay * (tripDays - 1) : 0);
                return pax > 1
                    ? '${l.tripCostMeals} ($totalMeals × $pax)'
                    : '${l.tripCostMeals} (×$totalMeals)';
              }(),
              value: mealsCost, scheme: scheme, t: t,
            ),
          if (hotelCost > 0)
            _CostRow(
              label: () {
                // Multi-night picks: "Hoteles (×N nights [× R rooms])".
                // Single algorithmic pick: keep the existing rooms-only
                // label so the copy is stable when the user hasn't
                // interacted yet.
                if (hotelNights > 1) {
                  final base = rooms > 1
                      ? '${l.tripCostHotel} (×$hotelNights × $rooms)'
                      : '${l.tripCostHotel} (×$hotelNights)';
                  return base;
                }
                return rooms > 1
                    ? '${l.tripCostHotel} (×$rooms)'
                    : l.tripCostHotel;
              }(),
              value: hotelCost, scheme: scheme, t: t,
            ),
          const SizedBox(height: Tokens.space8),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: Tokens.space8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.tripCostTotal,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                formatMoney(total, ccy),
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          if (savings != null) ...[
            () {
              final savedTime = savings!.timeSavedMinutesVsDesired -
                  tollSkipPenaltyMinutes;
              final savedEur = tollSkipSavingsEur;
              final fuelSavedEur = savings!.fuelSavingsEur ?? 0.0;
              if (savedTime <= 0 && savedEur <= 0 && fuelSavedEur <= 0) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Tokens.space8),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: Tokens.space8),
                  Row(
                    children: [
                      Icon(Icons.savings_outlined, size: 14,
                          color: scheme.tertiary),
                      const SizedBox(width: 6),
                      Text(
                        l.resultTripSavings.toUpperCase(),
                        style: t.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.tertiary,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Tokens.space8),
                  Row(
                    children: [
                      if (savedTime > 0) ...[
                        Icon(Icons.access_time, size: 13,
                            color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          durationCompact(savedTime),
                          style: t.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (savedEur > 0) ...[
                        Icon(Icons.savings_outlined, size: 13,
                            color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          formatMoney(savedEur, ccy),
                          style: t.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (fuelSavedEur > 0) ...[
                        Icon(Icons.local_gas_station, size: 13,
                            color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          formatMoney(fuelSavedEur, ccy),
                          style: t.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // When toll detour adds net time (savedTime < 0),
                      // show the time cost as a trade-off note so the
                      // user understands why time isn't shown as a saving.
                      if (tollSkipPenaltyMinutes > 0 && savedTime < 0) ...[
                        Icon(Icons.timelapse, size: 13,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '+${durationCompact(tollSkipPenaltyMinutes)}',
                          style: t.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            }(),
          ],
        ],
      ),
    );
  }
}

/// Proactive "refuel here to save" callout rendered above the
/// collapsible fuel list. Backend picks the cheapest station within
/// the driver's remaining range and stamps the €-savings vs the
/// route's median price. Tapping "+ Add" pipes into the same
/// `_addedRouteWaypoints` map as manual fuel-tile picks — the trip
/// receipt then reflects the fuel savings.
class _RefuelSuggestionCard extends StatelessWidget {
  const _RefuelSuggestionCard({
    required this.station,
    required this.isAdded,
    required this.onToggleAdd,
    this.savingsEur,
  });

  final FuelPrice station;
  final bool isAdded;
  final VoidCallback onToggleAdd;

  /// Server-computed € vs route median. When null or ≤ 0 the
  /// savings chip is suppressed (an at-median suggestion is still
  /// useful — you'll refuel somewhere — but shouting a "0 €" figure
  /// undermines trust).
  final double? savingsEur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final hasSavings = (savingsEur ?? 0) > 0.01;
    return Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_gas_station,
                  size: 18, color: scheme.primary),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: Text(
                  l.refuelSuggestionTitle,
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            l.refuelSuggestionBody(
              station.stationName,
              station.distanceFromOriginKm.toStringAsFixed(0),
              station.priceEurPerL.toStringAsFixed(3),
            ),
            style: t.bodyMedium,
          ),
          if (hasSavings) ...[
            const SizedBox(height: Tokens.space4),
            Text(
              l.refuelSuggestionSavings(savingsEur!.toStringAsFixed(2)),
              style: t.bodySmall?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: Tokens.space12),
          Align(
            alignment: Alignment.centerRight,
            child: _AddToRouteButton(
              isAdded: isAdded,
              onPressed: onToggleAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends ConsumerWidget {
  const _CostRow({
    required this.label,
    required this.value,
    required this.scheme,
    required this.t,
    this.originalValue,
  });
  final String label;
  final double value;
  final ColorScheme scheme;
  final TextTheme t;
  /// When non-null and greater than [value], the row shows the
  /// original amount struck through next to the discounted new
  /// value. Used by the toll row when the driver skipped booths.
  final double? originalValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ccy = ref.watch(currencyCodeProvider);
    final hasStrike =
        originalValue != null && originalValue! > value + 0.001;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: t.bodyMedium),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasStrike) ...[
                Text(
                  formatMoney(originalValue!, ccy),
                  style: t.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                formatMoney(value, ccy),
                style: t.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasStrike ? Colors.green.shade700 : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
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
    this.intraSectionSkips = const [],
  });
  final TripSavings savings;
  final double tollSkipSavingsEur;
  final double tollSkipPenaltyMinutes;
  final List<IntraSectionSkip> intraSectionSkips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final savedTime =
        savings.timeSavedMinutesVsDesired - tollSkipPenaltyMinutes;
    final savedEur = tollSkipSavingsEur;

    // Best intra-section bypass across all worth-it skips.
    final worthIt = intraSectionSkips.where((s) => s.worthIt).toList();
    final maxBypassSavings = worthIt.isEmpty
        ? 0.0
        : worthIt.map((s) => s.savingsEur).reduce((a, b) => a > b ? a : b);
    final maxBypassPenalty = worthIt.isEmpty
        ? 0.0
        : worthIt
            .where((s) => s.savingsEur == maxBypassSavings)
            .first
            .timePenaltyMinutes;

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
                  color: scheme.tertiary,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
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
          if (maxBypassSavings >= 2.0) ...[
            const SizedBox(height: Tokens.space8),
            const Divider(height: 1),
            const SizedBox(height: Tokens.space8),
            Row(
              children: [
                Icon(
                  Icons.alt_route,
                  size: 14,
                  color: scheme.onTertiaryContainer.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l.resultBypassSavingsPrefix,
                        style: t.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' €${maxBypassSavings.toStringAsFixed(0)} ',
                        style: t.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: l.resultBypassSavingsSuffix(
                          maxBypassPenalty.toStringAsFixed(0),
                        ),
                        style: t.bodySmall?.copyWith(
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
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
    this.onSelect,
  });

  final TimeWindow recommended;
  final DateTime desired;
  final double freeFlowMinutes;
  final double savedMinutesVsDesired;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    final shift = recommended.departureAt.toLocal().difference(desired.toLocal());
    final savedVsDesired =
        _minutesShiftedForBetterTraffic(shift, recommended, l);
    final shiftLabel = _formatShift(shift);
    final dateFmt = DateFormat(
      'EEE, d MMM · HH:mm',
      Localizations.localeOf(context).toString(),
    );

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
                  fontWeight: FontWeight.w700,
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
                label: l.resultArrival,
                value: DateFormat.Hm().format(
                  recommended.departureAt.toLocal().add(
                    Duration(minutes: recommended.estimatedMinutes.round()),
                  ),
                ),
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
          if (onSelect != null) ...[
            const SizedBox(height: Tokens.space12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(l.timeWindowApplyLabel(
                  DateFormat.Hm().format(recommended.departureAt.toLocal()),
                )),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onPrimaryContainer,
                  side: BorderSide(
                    color: scheme.onPrimaryContainer.withOpacity(0.5),
                  ),
                ),
                onPressed: onSelect,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _minutesShiftedForBetterTraffic(
    Duration shift, TimeWindow recommended, AppLocalizations l,
  ) {
    final delta = recommended.estimatedMinutes - freeFlowMinutes;
    final sign = delta >= 0 ? '+' : '';
    final vs = l.resultBestTimeVsFreeFlow(
      '$sign${delta.toStringAsFixed(0)}',
    );
    final abs = shift.inMinutes.abs();
    final rel = shift.isNegative
        ? l.resultBestTimeEarlier(abs)
        : l.resultBestTimeLater(abs);
    return '$vs · $rel';
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
            AppLocalizations.of(context)
                .resultHeroSavedBadge(magnitude),
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

class _OptimizationsSection extends StatefulWidget {
  const _OptimizationsSection({
    super.key,
    required this.opts,
    this.topHotels = const [],
    this.origin,
    this.destination,
    this.originName,
    this.destinationName,
    this.routeGeometry = const [],
    this.addedKeys = const {},
    this.weatherSegments = const [],
    this.onAddMealStop,
    this.onAddSleepStop,
  });
  final Optimizations opts;
  final List<(Hotel, double)> topHotels;
  final LatLon? origin;
  final LatLon? destination;
  /// Origin / destination display names (city + country). Used to
  /// render the "Madrid → Toledo" line under the section header
  /// so a driver reading the "Optimizado" card knows which leg it
  /// summarises without scrolling back to the hero.
  final String? originName;
  final String? destinationName;
  final List<LatLon> routeGeometry;
  final Set<String> addedKeys;
  final List<WeatherSegment> weatherSegments;
  final void Function(MealStopOpt)? onAddMealStop;
  final void Function(SleepStopOpt)? onAddSleepStop;

  @override
  State<_OptimizationsSection> createState() => _OptimizationsSectionState();
}

class _OptimizationsSectionState extends State<_OptimizationsSection> {
  /// How many hotels we show before the driver taps "Ver más".
  /// 3 matches the tester ask — enough to compare + one extra —
  /// without eating half the screen inside the "Optimizado"
  /// card.
  static const _kInitialHotelCount = 3;
  bool _hotelsExpanded = false;

  Optimizations get opts => widget.opts;
  List<(Hotel, double)> get topHotels => widget.topHotels;
  LatLon? get origin => widget.origin;
  LatLon? get destination => widget.destination;
  List<LatLon> get routeGeometry => widget.routeGeometry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Según tu perfil" section header removed 2026-09-26 —
        // everything below is already computed against the user's
        // profile, so the eyebrow / description read as redundant
        // noise. The functional card stays.
        SoftCard(
          padding: const EdgeInsets.all(Tokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.weatherSegments.isNotEmpty) ...[
                _WeatherInlineRow(segments: widget.weatherSegments),
                const SizedBox(height: Tokens.space12),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: Tokens.space12),
              ],
              _FuelCostRow(cost: opts.fuelCost),
              if (opts.mealStops.isNotEmpty) ...[
                const SizedBox(height: Tokens.space16),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: Tokens.space16),
                for (final m in opts.mealStops)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space12),
                    child: InkWell(
                      onTap: m.coordinate == null ? null : () {
                        showPoiDetailSheet(
                          context,
                          kind: PoiKind.restaurant,
                          name: m.restaurantName ?? '—',
                          subtitle: [
                            if (m.restaurantPriceEurPerMeal != null)
                              AppLocalizations.of(context).pricePerMeal(
                                  m.restaurantPriceEurPerMeal!.toStringAsFixed(0)),
                            if (m.cityHint != null) m.cityHint!,
                          ].join(' · '),
                          poi: m.coordinate!,
                          origin: origin ?? m.coordinate!,
                          destination: destination ?? m.coordinate!,
                          routeGeometry: routeGeometry,
                          attributes: const {},
                          icon: Icons.restaurant_outlined,
                          accent: scheme.tertiary,
                          isAdded: widget.addedKeys.contains(_mealStopKey(m)),
                          onAddToRoute: widget.onAddMealStop != null
                              ? () => widget.onAddMealStop!(m)
                              : null,
                        );
                      },
                      child: _MealStopRow(stop: m),
                    ),
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
                InkWell(
                  onTap: opts.sleepStop!.coordinate == null ? null : () {
                    showPoiDetailSheet(
                      context,
                      kind: PoiKind.hotel,
                      name: opts.sleepStop!.hotelName ?? '—',
                      subtitle: [
                        if (opts.sleepStop!.hotelPriceEurPerNight != null)
                          '${opts.sleepStop!.hotelPriceEurPerNight!.toStringAsFixed(0)} €/night',
                        if (opts.sleepStop!.cityHint != null)
                          opts.sleepStop!.cityHint!,
                      ].join(' · '),
                      poi: opts.sleepStop!.coordinate!,
                      origin: origin ?? opts.sleepStop!.coordinate!,
                      destination: destination ?? opts.sleepStop!.coordinate!,
                      routeGeometry: routeGeometry,
                      attributes: const {},
                      icon: Icons.hotel_outlined,
                      accent: scheme.tertiary,
                      isAdded: widget.addedKeys.contains(
                          _sleepStopKey(opts.sleepStop!)),
                      onAddToRoute: widget.onAddSleepStop != null
                          ? () => widget.onAddSleepStop!(opts.sleepStop!)
                          : null,
                    );
                  },
                  child: _SleepStopRow(stop: opts.sleepStop!),
                ),
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
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }),
                const SizedBox(height: Tokens.space8),
                // Show 3 up-front then hide the tail behind a
                // "Show N more" toggle so this card doesn't sprawl.
                Builder(builder: (context) {
                  final l = AppLocalizations.of(context);
                  final visible = _hotelsExpanded
                      ? topHotels
                      : topHotels.take(_kInitialHotelCount).toList();
                  final hidden = topHotels.length - visible.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (h, km) in visible)
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
                      if (topHotels.length > _kInitialHotelCount)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: Icon(
                              _hotelsExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                            ),
                            label: Text(
                              _hotelsExpanded
                                  ? l.commonShowLess
                                  : l.commonShowNMore(hidden),
                            ),
                            onPressed: () => setState(
                              () => _hotelsExpanded = !_hotelsExpanded,
                            ),
                          ),
                        ),
                    ],
                  );
                }),
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
    // Prefer official star classification when OSM has it —
    // otherwise fall back to the Google Places review rating
    // (numeric mean, e.g. "4.3 ★ 128") which the backend enricher
    // stamps into `attributes.rating` + `attributes.rating_count`
    // for the top hotels. The two are semantically different
    // (classification vs. crowd rating) so we render them
    // differently: `4★` for classification, `4.3 · 128` for
    // review rating. Full official-stars coverage arrives with
    // the Booking Content API once the affiliate is approved.
    final stars = h.attributes['stars'];
    if (stars != null && stars.isNotEmpty) {
      parts.add('$stars★');
    } else {
      final rating = h.attributes['rating'];
      final count = h.attributes['rating_count'];
      if (rating != null && rating.isNotEmpty) {
        parts.add(count != null && count.isNotEmpty
            ? '★ $rating ($count)'
            : '★ $rating');
      }
    }
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

class _FuelCostRow extends ConsumerWidget {
  const _FuelCostRow({required this.cost});
  final FuelCost cost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ccy = ref.watch(currencyCodeProvider);
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
                formatMoney(cost.totalCostEur, ccy),
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
    // "5 km · Cerca de Toledo" if we have a city hint, else the
    // legacy "5 km del origen" text.
    final locationLine = stop.cityHint != null
        ? '${stop.distanceFromOriginKm.toStringAsFixed(0)} km · '
            '${l.resultCityHint(stop.cityHint!)}'
        : '${stop.distanceFromOriginKm.toStringAsFixed(0)} km';
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
                        '${AppLocalizations.of(context).pricePerMeal(stop.restaurantPriceEurPerMeal?.toStringAsFixed(0) ?? '?')} · '
                        '$locationLine'
                    : locationLine,
                style: t.bodySmall,
              ),
            ],
          ),
        ),
        if (stop.coordinate != null) ...[
          const SizedBox(width: Tokens.space8),
          _MiniMapThumb(coord: stop.coordinate!, tint: scheme.tertiary),
        ],
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
    final l = AppLocalizations.of(context);
    final locationLine = stop.cityHint != null
        ? '${stop.distanceFromOriginKm.toStringAsFixed(0)} km · '
            '${l.resultCityHint(stop.cityHint!)}'
        : '${stop.distanceFromOriginKm.toStringAsFixed(0)} km';
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
              Text(
                l.resultSleepAt(dateFmt.format(stop.at.toLocal())),
                style: t.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                stop.hotelName != null
                    ? '${stop.hotelName} · '
                        '${stop.hotelPriceEurPerNight?.toStringAsFixed(0)} €/night · '
                        '$locationLine'
                    : l.resultNoHotelHere(
                        stop.distanceFromOriginKm.toStringAsFixed(0),
                      ),
                style: t.bodySmall,
              ),
            ],
          ),
        ),
        if (stop.coordinate != null) ...[
          const SizedBox(width: Tokens.space8),
          _MiniMapThumb(coord: stop.coordinate!, tint: scheme.secondary),
        ],
      ],
    );
  }
}

/// Tiny 72×72 map thumbnail with a single pin at [coord]. Uses
/// the same OSM tile layer as the main route map. `IgnorePointer`
/// wraps the map so taps bubble up to a parent InkWell/GestureDetector
/// rather than being consumed by the map widget.
class _MiniMapThumb extends StatelessWidget {
  const _MiniMapThumb({required this.coord, required this.tint});
  final LatLon coord;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: IgnorePointer(
      child: SizedBox(
        width: 72, height: 72,
        child: fmap.FlutterMap(
          options: fmap.MapOptions(
            initialCenter: fmap.LatLng(coord.lat, coord.lon),
            initialZoom: 12,
            interactionOptions: const fmap.InteractionOptions(
              flags: fmap.InteractiveFlag.none,
            ),
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
                  point: fmap.LatLng(coord.lat, coord.lon),
                  width: 24, height: 24,
                  child: Icon(Icons.place, color: tint, size: 24),
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
                    color: scheme.tertiary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  )),
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

class _PartialTollSkipsCard extends ConsumerWidget {
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

  // enabledIndices = tolls the user PAYS. Savings/penalty come
  // from UNCHECKED indices (the ones they skip).
  double get _totalSavings {
    var total = 0.0;
    for (var i = 0; i < skips.length; i++) {
      if (!enabledIndices.contains(i)) total += skips[i].savingsEur;
    }
    return total;
  }

  double get _totalPenaltyMinutes {
    var total = 0.0;
    for (var i = 0; i < skips.length; i++) {
      if (!enabledIndices.contains(i)) total += skips[i].timePenaltyMinutes;
    }
    return total;
  }

  double get _totalExtraKm {
    var total = 0.0;
    for (var i = 0; i < skips.length; i++) {
      if (!enabledIndices.contains(i)) total += skips[i].extraDistanceKm;
    }
    return total;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final ccy = ref.watch(currencyCodeProvider);
    final hasSavings = _totalSavings > 0;
    final accent = hasSavings ? scheme.tertiary : scheme.onSurfaceVariant;
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
                    color: scheme.tertiary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
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
          const SizedBox(height: 6),
          // CTA pointing the driver at the per-day tolls view.
          // Same state is shared — toggling here or there updates
          // both surfaces at once.
          Text(
            l.partialTollsPerDayHint,
            style: t.bodySmall?.copyWith(
              color: scheme.primary, fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Tokens.space12),
          RichText(
            text: TextSpan(
              style: t.headlineSmall?.copyWith(color: scheme.onSurface),
              children: [
                TextSpan(text: l.resultSaveExactly),
                TextSpan(
                  text: formatMoney(_totalSavings, ccy),
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

class _AdverseEventsBanner extends StatelessWidget {
  const _AdverseEventsBanner({required this.events, this.onTap});
  final List<AdverseEvent> events;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final hasCritical =
        events.any((e) => e.severity == AdverseEventSeverity.critical);
    final bg = hasCritical
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final fg = hasCritical
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space16, vertical: Tokens.space12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: fg),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: Text(
                    l.adverseEventsBannerCount(events.length),
                    style: t.bodySmall?.copyWith(
                        color: fg, fontWeight: FontWeight.w600),
                  ),
                ),
                for (final e in events.take(4))
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(e.type.icon, size: 16, color: fg),
                  ),
                const SizedBox(width: Tokens.space8),
                Icon(Icons.chevron_right, size: 18, color: fg),
              ],
            ),
          ),
        ),
      ),
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
      subtitle: Text(event.displayText(AppLocalizations.of(context))),
      isThreeLine: event
              .displayText(AppLocalizations.of(context))
              .length >
          60,
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

/// Section that lists parking options near the trip destination.
/// Populated only when the driver ticked the "Parking" preference
/// on the plan form. Tap a row → open Google Maps at the exact
/// coord (no name search).
class _DestinationParkingSection extends StatelessWidget {
  const _DestinationParkingSection({required this.parkings});
  final List<PlanParking> parkings;

  Future<void> _openMaps(PlanParking p) async {
    final label = Uri.encodeComponent(p.name.trim());
    final geo = Uri.parse(
      'geo:${p.coordinate.lat},${p.coordinate.lon}'
      '?q=${p.coordinate.lat},${p.coordinate.lon}($label)',
    );
    try {
      final ok =
          await launchUrl(geo, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}
    await launchUrl(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${p.coordinate.lat},${p.coordinate.lon}',
      }),
      mode: LaunchMode.platformDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: false,
        leading: Icon(Icons.local_parking_outlined, color: scheme.primary),
        title: Text(l.parkingResultTitle, style: t.titleMedium),
        subtitle: Text(
          '${parkings.length} opciones',
          style: t.bodySmall,
        ),
        children: [
          for (final p in parkings)
            InkWell(
              onTap: () => _openMaps(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.local_parking, size: 14,
                        color: scheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.name}  ·  '
                            '${(p.distanceFromDestinationKm * 1000).round()} m',
                            style: t.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Wrap(
                            spacing: 6, runSpacing: 4,
                            children: [
                              if (p.priceEurPerHour != null)
                                _TinyChip(
                                  icon: Icons.euro,
                                  label:
                                      '${p.priceEurPerHour!.toStringAsFixed(2)}/h',
                                ),
                              if (p.covered == true)
                                _TinyChip(
                                  icon: Icons.house_outlined,
                                  label: l.parkingCovered,
                                ),
                              if (p.kidFriendly == true)
                                _TinyChip(
                                  icon: Icons.child_friendly,
                                  label: l.parkingFilterKids,
                                ),
                              if (p.dogsAllowed == true)
                                _TinyChip(
                                  icon: Icons.pets,
                                  label: l.parkingFilterDogs,
                                ),
                              if (p.evCharging == true)
                                _TinyChip(
                                  icon: Icons.electric_car,
                                  label: l.parkingFilterEv,
                                ),
                              if (p.rvFriendly == true)
                                _TinyChip(
                                  icon: Icons.rv_hookup,
                                  label: l.parkingFilterRv,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.navigation, size: 16,
                        color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

/// Compact horizontal row showing weather icons + temp per segment.
/// Used inside the Optimizado card so weather is visible for all trip
/// types (including single-day where DayPlanSection doesn't render).
class _WeatherInlineRow extends StatelessWidget {
  const _WeatherInlineRow({required this.segments});
  final List<WeatherSegment> segments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(Icons.wb_cloudy_outlined, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          for (int i = 0; i < segments.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(width: 4),
              Text('·', style: t.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
            ],
            Icon(segments[i].iconData, size: 15,
                color: scheme.onSurface),
            const SizedBox(width: 3),
            Text(
              segments[i].temperatureC != null
                  ? '${segments[i].temperatureC!.round()}°'
                  : segments[i].localizedLabel(l),
              style: t.bodySmall,
            ),
            const SizedBox(width: 3),
            Text(
              'km ${segments[i].fromKm.toStringAsFixed(0)}-${segments[i].toKm.toStringAsFixed(0)}',
              style: t.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherStripCard extends StatelessWidget {
  const _WeatherStripCard({required this.segments});
  final List<WeatherSegment> segments;

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
              Icon(Icons.wb_cloudy_outlined, size: 18,
                  color: scheme.primary),
              const SizedBox(width: Tokens.space8),
              Text(
                l.weatherAlongRouteTitle,
                style: t.labelSmall?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          for (final s in segments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(s.iconData, size: 18, color: scheme.onSurface),
                  const SizedBox(width: Tokens.space8),
                  Expanded(
                    child: Text(
                      'km ${s.fromKm.toStringAsFixed(0)}-${s.toKm.toStringAsFixed(0)}  ·  ${s.localizedLabel(AppLocalizations.of(context))}'
                      '${s.temperatureC != null ? '  ·  ${s.temperatureC!.toStringAsFixed(0)}°C' : ''}',
                      style: t.bodySmall,
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
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
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
        '${AppLocalizations.of(context).pricePerMeal(restaurant.priceEurPerMeal.toStringAsFixed(0))} · '
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
        ? '${price.priceEurPerL.toStringAsFixed(3)} ${price.unitLabel} · '
              '${l.kmFromOrigin(price.distanceFromOriginKm.toStringAsFixed(0))}'
        : '${l.fuelPriceUnavailable} · '
              '${l.kmFromOrigin(price.distanceFromOriginKm.toStringAsFixed(0))}';
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
class _DepartureTimingSection extends StatelessWidget {
  const _DepartureTimingSection({
    super.key,
    required this.recommended,
    required this.desiredDepartureAt,
    required this.freeFlowMinutes,
    required this.savedMinutesVsDesired,
    required this.initialWindows,
    required this.initialSpanHours,
    required this.onFetch,
    this.onWindowSelect,
    this.onSelectRecommended,
  });

  final TimeWindow? recommended;
  final DateTime desiredDepartureAt;
  final double freeFlowMinutes;
  final double savedMinutesVsDesired;
  final List<TimeWindow> initialWindows;
  final int initialSpanHours;
  final Future<List<TimeWindow>> Function(int spanHours) onFetch;
  final ValueChanged<TimeWindow>? onWindowSelect;
  final VoidCallback? onSelectRecommended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    final isOptimal = recommended != null &&
        recommended!.departureAt.toLocal()
                .difference(desiredDepartureAt.toLocal())
                .abs()
                .inMinutes <
            10;
    final savedMin = savedMinutesVsDesired.abs().round();
    final summaryText = isOptimal
        ? l.resultOptimalDeparture
        : savedMin > 0
            ? '${l.resultBestTimeToLeave} · ${durationCompact(savedMinutesVsDesired.abs())} ${l.resultTimeSavedLabel}'
            : l.resultBestTimeToLeave;
    final summaryColor = isOptimal ? Colors.green.shade700 : scheme.primary;

    return SoftCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
              horizontal: Tokens.space16, vertical: Tokens.space4),
          title: Row(
            children: [
              Icon(
                isOptimal ? Icons.check_circle : Icons.schedule_outlined,
                size: 18,
                color: summaryColor,
              ),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: Text(
                  summaryText,
                  style: t.bodyMedium?.copyWith(
                    color: summaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isOptimal && savedMin > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '-${durationCompact(savedMinutesVsDesired.abs())}',
                    style: t.labelSmall?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
              Tokens.space16, 0, Tokens.space16, Tokens.space16),
          children: [
            if (recommended != null && !isOptimal) ...[
              _RecommendationHero(
                recommended: recommended!,
                desired: desiredDepartureAt,
                freeFlowMinutes: freeFlowMinutes,
                savedMinutesVsDesired: savedMinutesVsDesired,
                onSelect: onSelectRecommended,
              ),
              const SizedBox(height: Tokens.space16),
            ],
            if (isOptimal)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      l.resultOptimalDeparture,
                      style: t.bodySmall?.copyWith(
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            _TimeWindowExpandableCard(
              initialWindows: initialWindows,
              desiredDepartureAt: desiredDepartureAt,
              initialSpanHours: initialSpanHours,
              onFetch: onFetch,
              onWindowSelect: onWindowSelect,
            ),
          ],
        ),
      ),
    );
  }
}

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
  TimeWindow? _pendingWindow;

  @override
  void initState() {
    super.initState();
    _span = widget.initialSpanHours.clamp(1, 12);
    _windows = widget.initialWindows;
    _lastFetchedSpan = _span;
  }

  void _onBarSelect(TimeWindow window) {
    setState(() => _pendingWindow = window);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: Tokens.space8),
                Text(
                  l.resultBestTimeToLeave,
                  style: t.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space8),
            Stack(
              children: [
                TimeWindowChart(
                  windows: _windows,
                  desiredDepartureAt: widget.desiredDepartureAt,
                  onSelect: widget.onWindowSelect != null ? _onBarSelect : null,
                  selectedWindow: _pendingWindow,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onWindowSelect != null && _pendingWindow == null)
                  Row(
                    children: [
                      Icon(Icons.touch_app_outlined, size: 13,
                          color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        l.timeWindowTapHint,
                        style: t.bodySmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ),
                if (_pendingWindow != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Tokens.space8),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l.timeWindowApplyLabel(
                        DateFormat.Hm().format(
                          _pendingWindow!.departureAt.toLocal(),
                        ),
                      )),
                      onPressed: () {
                        widget.onWindowSelect!(_pendingWindow!);
                        setState(() => _pendingWindow = null);
                      },
                    ),
                  ),
                Text(
                  l.timeWindowSpanHelper,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
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
/// Shows "AÑADIDO" chip when added, add icon when not.
class _AddToRouteButton extends StatelessWidget {
  const _AddToRouteButton({required this.isAdded, required this.onPressed});
  final bool isAdded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    if (isAdded) {
      return GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 13, color: scheme.onPrimaryContainer),
              const SizedBox(width: 4),
              Text(
                l.addedToRouteLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      );
    }
    return IconButton(
      tooltip: l.addToRouteTooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        Icons.add_circle_outline,
        color: scheme.onSurfaceVariant,
      ),
      onPressed: onPressed,
    );
  }
}

/// Compact summary of the stops the user has added, rendered under the
/// stats row. Explains where the "+X min" delta on the free-flow tile
/// comes from and offers a one-tap reset.
class _DayStripRow extends StatelessWidget {
  const _DayStripRow({required this.day});
  final DayPlan day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat('EEE d MMM', locale)
        .format(day.startAt.toLocal());
    final km = (day.toKm - day.fromKm).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.dayIndex}',
              style: t.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: Tokens.space8),
          Expanded(
            child: Text(
              dateLabel,
              style: t.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$km km',
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

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
    this.onTap,
  });

  final int arrivalHour;
  final int bedtimeHour;
  final bool requiresOvernight;
  final VoidCallback? onTap;

  String _fmt(int hour) => hour.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final card = Container(
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
          if (onTap != null) ...[
            const SizedBox(width: Tokens.space8),
            Icon(Icons.hotel_outlined,
                color: scheme.onTertiaryContainer, size: 20),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: card),
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
      DateFormat(
        'EEE d MMM · HH:mm',
        Localizations.localeOf(context).toString(),
      ).format(sleepStop.at.toLocal()),
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
                    color: scheme.onTertiaryContainer,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
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

/// Skeleton tile row for enrich-only sections (hotels / restaurants /
/// fuel / adverse events). Three fake tiles under the section header
/// keep the layout height stable so the eventual real list doesn't
/// yank the scroll offset when it arrives.
///
/// Deliberately minimal — no icons, no shimmer knobs — because the
/// enrich phase usually settles in 1-4 s on a warm backend and
/// anything more elaborate would out-live its purpose.
class _EnrichListSkeleton extends StatelessWidget {
  const _EnrichListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space8),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Row(
              children: [
                const Skeleton(width: 40, height: 40),
                const SizedBox(width: Tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(
                        width: double.infinity,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      Skeleton(
                        width: 150,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i < 2) const SizedBox(height: Tokens.space16),
          ],
        ],
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
