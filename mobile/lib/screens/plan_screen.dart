import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../domain/vehicle_labels.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/maps_url_parser.dart';
import '../services/trip_sharing.dart';
import '../widgets/hotel_preferences.dart';
import '../widgets/location_search_field.dart';
import '../widgets/plan_loading_dialog.dart';
import '../widgets/restaurant_preferences.dart';
import '../widgets/travel_style_chip.dart';
import '../widgets/weather_chip.dart';
import 'dashboard_screen.dart';
import 'favorites_screen.dart';
import 'mark_event_screen.dart';
import 'settings_screen.dart';
import 'inspire_screen.dart';
import 'parking_search_screen.dart';
import 'pick_location_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';
import '../services/app_tutorial.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({
    super.key,
    this.initialShared,
    this.initialStops = const [],
  });

  /// When arriving via a shared trip link, prefill the form with the
  /// origin / destination / departure so the user just taps Plan.
  final SharedTrip? initialShared;

  /// Intermediate stops to seed the plan form with. Currently
  /// used by the Trip Inspiration hand-off (`InspireScreen`) to
  /// turn a multi-day itinerary's cities into waypoints between
  /// origin and destination. Empty for the normal entry path.
  /// May contain [GeocodeResult] (legacy, dwell=0) or
  /// [PlannedStop] (place + dwell nights + optional label).
  /// Trip Inspiration hand-off passes places with dwell info
  /// embedded so multi-day itineraries land with the correct
  /// stay durations.
  final List<Object> initialStops;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  GeocodeResult? _origin;
  GeocodeResult? _destination;
  // Intermediate stops between origin and destination, in the
  // order the driver picked them. Empty = classic point-to-
  // point. Backend caps at 8.
  final List<PlannedStop> _stops = [];
  static const _maxStops = 8;
  late DateTime _departure = _defaultDeparture();

  // Coach-mark tutorial GlobalKeys
  final _originKey = GlobalKey();
  final _destinationKey = GlobalKey();
  final _preferencesKey = GlobalKey();
  // On-by-default so multi-day / overnight trips have hotel context
  // without asking the user to toggle first. The section still hides
  // when the toggle is off.
  HotelPreferences _hotelPrefs = HotelPreferences.enabledDefault;
  RestaurantPreferences _restaurantPrefs = RestaurantPreferences.disabled;
  // Two toggles now default-on (2026-08-26 tester ask): drivers
  // consistently forgot to enable adverse events + the toll
  // alternative and then wondered why the sections were missing.
  // On by default; the switches stay so users who don't want them
  // can opt out.
  bool _alertsEnabled = true;
  /// Parking search at the destination. When on, the result
  /// screen renders a "Parkings near destination" section. Off
  /// by default so plan responses stay light.
  bool _parkingEnabled = false;
  bool _tollAlternativeEnabled = true;
  // Hourly toll analysis is now IMPLICIT: whenever the toll
  // alternative is on we also request the hourly report. The
  // standalone user-facing selector is removed from the UI so
  // there's one less checkbox on the plan screen — the report
  // still ships in the result when premium/enabled.
  bool get _hourlyTollEnabled => _tollAlternativeEnabled;
  bool _routeComparisonEnabled = false;
  // Kept as fields (not consts) so the request builder keeps its
  // shape; a future iteration will re-expose the toggles or wire them
  // to the trip profile. Init default: don't alter routing.
  final bool _avoidMotorways = false;
  final bool _preferScenic = false;
  TripProfile? _overrideProfile;
  bool _loading = false;
  String? _error;

  /// Round-trip toggle. When ON the plan screen shows a second
  /// date+time picker for the return leg and the submit fires two
  /// `/plan` calls in parallel with reversed origin/destination.
  /// Defaults to the outbound date + 3 days so the picker has a
  /// sensible seed.
  bool _isRoundTrip = false;
  late DateTime _returnDeparture = _defaultReturnDeparture();

  /// Progressive disclosure: the three advanced toggles (alerts,
  /// toll-free, route-variants) collapse behind a "Más opciones"
  /// row by default so first-timers see only Hotels + Restaurants.
  /// Power users expand once; the state does NOT persist across
  /// launches — kept in memory only, per session.
  bool _advancedOptionsExpanded = false;

  DateTime _defaultReturnDeparture() =>
      _departure.add(const Duration(days: 3));

  static DateTime _defaultDeparture() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 8);
  }

  @override
  void initState() {
    super.initState();
    final incoming = widget.initialShared;
    if (incoming != null) {
      _origin = GeocodeResult(
        displayName: incoming.originName ?? 'Shared origin',
        coordinate: incoming.origin,
        country: _guessCountry(incoming.origin) ?? Country.fr,
      );
      _destination = GeocodeResult(
        displayName: incoming.destinationName ?? 'Shared destination',
        coordinate: incoming.destination,
        country: _guessCountry(incoming.destination) ?? Country.fr,
      );
      _departure = incoming.departureAt.toLocal();
      // Waypoints piggybacked on the shared trip (from a Google Maps
      // import, etc.) become pass-through stops. Names may be null
      // when the parser only had coords — fall back to a coord label.
      for (var i = 0; i < incoming.waypoints.length && i < _maxStops; i++) {
        final coord = incoming.waypoints[i];
        final name = i < incoming.waypointNames.length
            ? incoming.waypointNames[i]
            : null;
        _stops.add(PlannedStop(
          place: GeocodeResult(
            displayName: name
                ?? '${coord.lat.toStringAsFixed(3)}, ${coord.lon.toStringAsFixed(3)}',
            coordinate: coord,
            country: _guessCountry(coord) ?? Country.fr,
          ),
        ));
      }
      // Note: we don't auto-submit — user confirms with the CTA.
    }
    if (widget.initialStops.isNotEmpty) {
      // Capped at _maxStops so the router (backend) does not reject
      // an oversized waypoint list. Extras are silently dropped —
      // rare: LLM would need to propose >8 intermediate cities.
      for (final raw in widget.initialStops.take(_maxStops)) {
        if (raw is PlannedStop) {
          _stops.add(raw);
        } else if (raw is GeocodeResult) {
          _stops.add(PlannedStop(place: raw));
        }
      }
    }
    // Show the coach-mark tutorial after the first frame so
    // GlobalKeys have been attached. Fires once, SharedPreferences
    // gates subsequent launches.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showPlanTutorial(
        context,
        originKey: _originKey,
        destinationKey: _destinationKey,
        preferencesKey: _preferencesKey,
      );
    });
  }

  Country? _guessCountry(LatLon _) {
    // Country is only used for display in the search chip; the backend
    // re-detects from coordinates. Nothing to do beyond the fallback.
    return null;
  }

  Future<void> _pickDeparture() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departure),
    );
    if (time == null) return;
    setState(() {
      _departure =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      // Keep the return default sensible when the outbound moves —
      // only if the user hasn't already customised the return.
      if (_returnDeparture.isBefore(_departure)) {
        _returnDeparture = _defaultReturnDeparture();
      }
    });
  }

  Future<void> _pickReturnDeparture() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _returnDeparture,
      // Return must be at least the same day as outbound; no round-trip
      // that finishes before it starts.
      firstDate: _departure,
      lastDate: _departure.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_returnDeparture),
    );
    if (time == null) return;
    setState(() {
      _returnDeparture =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String? _buildHotelConditions() {
    final parts = <String>[];
    if (_hotelPrefs.requireParking) parts.add('fee');
    if (_hotelPrefs.requireWifi) parts.add('internet_access.free');
    if (_hotelPrefs.requireWheelchair) parts.add('wheelchair.yes');
    // Note: dogs.yes is NOT sent as a Geoapify condition — too few
    // OSM entries are tagged as dog-friendly so it empties the pool.
    // The profile's `has_pets` flag soft-ranks pet-unfriendly hotels
    // lower via `filter_hotels` penalty instead.
    return parts.isEmpty ? null : parts.join(',');
  }

  /// "Salir ya" one-tap flow. Skips the plan form: uses current
  /// GPS as origin, now as departure, current profile defaults.
  /// Prompts only for the destination in an inline sheet, plans
  /// in the background, then hands off to CompanionDriveScreen.
  ///
  /// Free users get a paywall preview instead of the actual flow
  /// (per model C monetisation — this CTA is the primary funnel).
  Future<void> _leaveNowQuickPlan() async {
    final l = AppLocalizations.of(context);
    final isPremium = ref.read(premiumProvider);
    if (!isPremium) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l.leaveNowPremiumTitle),
          content: Text(l.leaveNowPremiumBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.leaveNowPremiumDismiss),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.leaveNowPremiumCta),
            ),
          ],
        ),
      );
      return;
    }
    // If the form already has a destination filled in, ask the
    // driver whether they want to head there — one-tap confirm
    // beats forcing them to re-search a place they already picked.
    // Otherwise fall through to the full-screen picker.
    GeocodeResult? destination;
    if (_destination != null) {
      final choice = await showDialog<_LeaveNowChoice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.leaveNowConfirmTitle),
          content: Text(l.leaveNowConfirmBody(_destination!.displayName)),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_LeaveNowChoice.change),
              child: Text(l.leaveNowConfirmChange),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_LeaveNowChoice.go),
              child: Text(l.leaveNowConfirmCta),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == _LeaveNowChoice.go) {
        destination = _destination;
      }
    }
    destination ??= await Navigator.of(context).push<GeocodeResult>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          title: l.leaveNowSheetTitle,
          label: l.planTo,
          geocode: ref.read(apiClientWithPremiumProvider).geocode,
        ),
      ),
    );
    if (destination == null || !mounted) return;
    setState(() => _destination = destination);

    // Resolve current GPS as origin.
    final res = await ref.read(currentLocationServiceProvider).resolve();
    if (!mounted) return;
    if (res.place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.locationUnavailable)),
      );
      return;
    }
    setState(() {
      _origin = res.place;
      _departure = _defaultDeparture();
    });
    // Reuse the full plan flow — it already does loading dialog,
    // notifications, storage, everything.
    await _submit();
  }

  Future<void> _prepareDepartureNow() async {
    final l = AppLocalizations.of(context);
    final res = await ref.read(currentLocationServiceProvider).resolve();
    if (!mounted) return;
    if (res.place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.locationUnavailable)),
      );
      return;
    }
    setState(() {
      _origin = res.place;
      _departure = DateTime.now();
    });
  }

  /// Prompt the user for a Google Maps URL (optionally pre-filled from
  /// clipboard), parse it, and prefill the form with the resulting
  /// origin / stops / destination. Non-blocking on errors — a bad URL
  /// just surfaces a snackbar.
  Future<void> _importFromMaps() async {
    final l = AppLocalizations.of(context);
    final api = ref.read(apiClientWithPremiumProvider);
    final controller = TextEditingController();
    try {
      final clip = await Clipboard.getData('text/plain');
      final text = clip?.text?.trim() ?? '';
      if (text.contains('google.') || text.contains('goo.gl')) {
        controller.text = text;
      }
    } catch (_) {
      // Clipboard access can fail on some Android configurations —
      // no big deal, user pastes manually.
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    final url = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.importFromMapsTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l.importFromMapsHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final clip = await Clipboard.getData('text/plain');
              if (clip?.text != null) {
                controller.text = clip!.text!;
              }
            },
            child: Text(l.importFromMapsPaste),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: Text(l.importFromMapsImport),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty || !mounted) return;

    // Show a lightweight loading indicator — parsing may need a
    // shortlink expansion + a geocode round-trip each, ~1-3s total.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Tokens.space16),
            Expanded(child: Text(l.importFromMapsLoading)),
          ],
        ),
      ),
    );

    SharedTrip? trip;
    try {
      trip = await parseGoogleMapsUrl(url, geocode: api.geocode);
    } catch (_) {
      trip = null;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.importFromMapsError)),
      );
      return;
    }

    // Prefill directly rather than pushing a new PlanScreen — the
    // driver stays on the same form, just filled in.
    setState(() {
      _origin = GeocodeResult(
        displayName: trip!.originName ?? 'Origin',
        coordinate: trip.origin,
        country: _guessCountry(trip.origin) ?? Country.fr,
      );
      _destination = GeocodeResult(
        displayName: trip.destinationName ?? 'Destination',
        coordinate: trip.destination,
        country: _guessCountry(trip.destination) ?? Country.fr,
      );
      _stops.clear();
      for (var i = 0; i < trip.waypoints.length && i < _maxStops; i++) {
        final coord = trip.waypoints[i];
        final name = i < trip.waypointNames.length
            ? trip.waypointNames[i]
            : null;
        _stops.add(PlannedStop(
          place: GeocodeResult(
            displayName: name
                ?? '${coord.lat.toStringAsFixed(3)}, ${coord.lon.toStringAsFixed(3)}',
            coordinate: coord,
            country: _guessCountry(coord) ?? Country.fr,
          ),
        ));
      }
    });
  }

  /// Show a lightweight bottom sheet with a location picker so
  /// the driver adds an intermediate stop without leaving the
  /// plan form.
  Future<GeocodeResult?> _pickStop(
    BuildContext context,
    Future<List<GeocodeResult>> Function(String) geocode,
  ) async {
    final l = AppLocalizations.of(context);
    return Navigator.of(context).push<GeocodeResult>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          title: l.planAddStopTitle,
          label: l.planStopLabel(_stops.length + 1),
          geocode: geocode,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) {
      setState(() => _error =
          AppLocalizations.of(context).planErrorPickEndpoints);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    // Show the rotating "we're working" modal while the request is in
    // flight. It's non-dismissable so the user can't accidentally kill
    // the flow — the plan endpoint runs regardless. We pop it in the
    // `finally` so it disappears whether the plan succeeds, fails,
    // or the widget is disposed mid-request.
    // Capture the ROOT navigator BEFORE any async gap. When
    // MaterialApp rebuilds (e.g. DynamicColorBuilder returns
    // wallpaper colours mid-flight) `Navigator.of(context)` from
    // a stale build context may resolve to a detached navigator,
    // silently no-op'ing the dismiss. `rootNavigator: true`
    // guarantees we address the same navigator that owns the
    // dialog route.
    final rootNav = Navigator.of(context, rootNavigator: true);
    var dialogOpen = false;
    if (mounted) {
      dialogOpen = true;
      final steps = <PlanStep>[
        PlanStep.routing,
        PlanStep.traffic,
        PlanStep.fuel,
        if (_hotelPrefs.enabled) PlanStep.hotels,
        if (_restaurantPrefs.enabled) PlanStep.restaurants,
        if (_alertsEnabled) PlanStep.alerts,
        if (_tollAlternativeEnabled || _hourlyTollEnabled)
          PlanStep.tolls,
      ];
      unawaited(showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (_) => PlanLoadingDialog(steps: steps),
      ));
    }
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final request = TripPlanRequest(
        origin: origin.coordinate,
        destination: destination.coordinate,
        waypoints: _stops
            .map((s) => TripWaypoint(
                  coordinate: s.place.coordinate,
                  dwellNights: s.dwellNights < 0 ? 0 : s.dwellNights,
                  label: s.place.displayName,
                ))
            .toList(),
        desiredDepartureAt: _departure,
        hotelMaxDetourMinutes:
            _hotelPrefs.enabled ? _hotelPrefs.maxDetourMinutes : null,
        // Send both legacy single-band (for compat) and the multi-band
        // list. Backend prefers the list when present.
        hotelPriceBand: _hotelPrefs.enabled ? _hotelPrefs.priceBand : null,
        hotelPriceBands: _hotelPrefs.enabled
            ? _hotelPrefs.priceBands.toList()
            : null,
        hotelMinStars: _hotelPrefs.enabled && _hotelPrefs.minStars > 0
            ? _hotelPrefs.minStars
            : null,
        hotelIncludeOther: _hotelPrefs.enabled &&
            _hotelPrefs.includeOtherAccommodation,
        hotelDestinationRadiusKm: _hotelPrefs.enabled
            ? _hotelPrefs.destinationRadiusKm
            : null,
        hotelConditions: _hotelPrefs.enabled
            ? _buildHotelConditions()
            : null,
        restaurantConditions: _restaurantPrefs.enabled
            ? _restaurantPrefs.geoapifyConditions
            : null,
        restaurantMaxDetourMinutes: _restaurantPrefs.enabled
            ? _restaurantPrefs.maxDetourMinutes
            : null,
        restaurantPriceBand:
            _restaurantPrefs.enabled ? _restaurantPrefs.priceBand : null,
        restaurantPriceBands: _restaurantPrefs.enabled
            ? _restaurantPrefs.priceBands.toList()
            : null,
        restaurantCuisines: _restaurantPrefs.enabled
            ? cuisineOsmTagsFor(_restaurantPrefs.cuisines).toList()
            : null,
        includeAdverseEvents: _alertsEnabled,
        includeTollAlternative: _tollAlternativeEnabled,
        includeParking: _parkingEnabled,
        includeRouteComparison: _routeComparisonEnabled,
        includeHourlyTollAnalysis: _hourlyTollEnabled,
        avoidMotorways: _avoidMotorways,
        preferScenic: _preferScenic,
        tripProfile: _overrideProfile ?? ref.read(tripProfileProvider),
      );
      // Round-trip: fire two /plan calls in parallel — outbound
      // A→B on the chosen departure and return B→A on the return
      // departure. Both use the same profile / preferences so the
      // driver gets a consistent experience on either leg.
      TripPlanRequest? returnRequest;
      Future<TripPlanResponse>? returnFuture;
      if (_isRoundTrip) {
        returnRequest = TripPlanRequest(
          origin: destination.coordinate,
          destination: origin.coordinate,
          desiredDepartureAt: _returnDeparture,
          hotelMaxDetourMinutes:
              _hotelPrefs.enabled ? _hotelPrefs.maxDetourMinutes : null,
          hotelPriceBand: _hotelPrefs.enabled ? _hotelPrefs.priceBand : null,
          hotelPriceBands: _hotelPrefs.enabled
              ? _hotelPrefs.priceBands.toList()
              : null,
          hotelMinStars: _hotelPrefs.enabled && _hotelPrefs.minStars > 0
              ? _hotelPrefs.minStars
              : null,
          hotelIncludeOther: _hotelPrefs.enabled &&
              _hotelPrefs.includeOtherAccommodation,
          hotelConditions: _hotelPrefs.enabled
              ? _buildHotelConditions()
              : null,
          restaurantMaxDetourMinutes: _restaurantPrefs.enabled
              ? _restaurantPrefs.maxDetourMinutes
              : null,
          restaurantPriceBand: _restaurantPrefs.enabled
              ? _restaurantPrefs.priceBand : null,
          restaurantPriceBands: _restaurantPrefs.enabled
              ? _restaurantPrefs.priceBands.toList()
              : null,
          restaurantCuisines: _restaurantPrefs.enabled
              ? cuisineOsmTagsFor(_restaurantPrefs.cuisines).toList()
              : null,
          restaurantConditions: _restaurantPrefs.enabled
              ? _restaurantPrefs.geoapifyConditions
              : null,
          includeAdverseEvents: _alertsEnabled,
          includeTollAlternative: _tollAlternativeEnabled,
          includeParking: _parkingEnabled,
          includeRouteComparison: _routeComparisonEnabled,
          includeHourlyTollAnalysis: _hourlyTollEnabled,
          avoidMotorways: _avoidMotorways,
          preferScenic: _preferScenic,
          tripProfile: _overrideProfile ?? ref.read(tripProfileProvider),
        );
        returnFuture = api.planTrip(returnRequest);
      }
      final response = await api.planTrip(request);
      final returnResponse =
          returnFuture == null ? null : await returnFuture;
      if (!mounted) return;
      // Pop the loading dialog BEFORE pushing ResultScreen —
      // otherwise the dialog stays on top and blocks navigation.
      // Use the captured root navigator so a mid-flight MaterialApp
      // rebuild (DynamicColorBuilder) can't detach the pop target.
      if (dialogOpen) {
        rootNav.pop();
        dialogOpen = false;
      }
      final l = AppLocalizations.of(context);
      final outboundLabel = _isRoundTrip ? l.roundTripLegOutbound : null;
      final returnLeg = (returnRequest != null && returnResponse != null)
          ? RoundTripLeg(
              label: l.roundTripLegReturn,
              request: returnRequest,
              origin: destination,
              destination: origin,
              response: returnResponse,
              desiredDepartureAt: _returnDeparture,
            )
          : null;
      rootNav.push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            request: request,
            origin: origin,
            destination: destination,
            response: response,
            desiredDepartureAt: _departure,
            currentLegLabel: outboundLabel,
            otherLeg: returnLeg,
            hotelPrefs: _hotelPrefs.enabled ? _hotelPrefs : null,
          ),
        ),
      );
    } on ApiException catch (e) {
      // Deterministic 4xx bubbling up from the retry-aware client.
      // Map the common ones to human-friendly copy; anything else
      // falls through to a generic "algo fue mal" that still surfaces
      // the code so support can diagnose from a user screenshot.
      final l = AppLocalizations.of(context);
      setState(() => _error = switch (e.statusCode) {
        401 => l.planErrorAuth,
        402 => l.planErrorPremium,
        429 => l.planErrorRateLimit,
        _ => l.planErrorGeneric(e.statusCode),
      });
    } catch (e) {
      // 5xx exhausted retries or true network failure. The client
      // has already reintentado 3 veces silently, so at this point
      // it IS worth telling the user with a plain-language message.
      final l = AppLocalizations.of(context);
      setState(() => _error = l.planErrorNetwork);
    } finally {
      // Error path: pop the loading dialog via the same captured
      // root navigator we used on success. Skips silently when
      // the dialog has already been popped or when the navigator
      // has no more routes to pop.
      if (dialogOpen && rootNav.canPop()) {
        rootNav.pop();
        dialogOpen = false;
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientWithPremiumProvider);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // Pass the app locale so weekday + month names render in the
    // user's language ("lun, 15 sep" instead of "Mon, 15 Sep").
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat('EEE, d MMM · HH:mm', locale);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: true,
              expandedHeight: 40,
              titleSpacing: Tokens.space20,
              title: Row(
                children: [
                  Icon(Icons.explore_outlined, color: scheme.primary),
                  const SizedBox(width: Tokens.space8),
                  Text(l.appName, style: t.titleLarge),
                ],
              ),
              actions: [
                TravelStyleChip(
                  activeProfile: _overrideProfile
                      ?? ref.watch(tripProfileProvider)
                      ?? const TripProfile(),
                  savedProfile: ref.watch(tripProfileProvider),
                  isOverride: _overrideProfile != null,
                  onPresetPicked: (preset) {
                    final base = _overrideProfile
                        ?? ref.read(tripProfileProvider)
                        ?? const TripProfile();
                    setState(() => _overrideProfile = preset.apply(base));
                  },
                  onClearOverride: () =>
                      setState(() => _overrideProfile = null),
                ),
                IconButton(
                  tooltip: l.planTooltipDashboard,
                  icon: const Icon(Icons.dashboard_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DashboardScreen(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.planTooltipReport,
                  icon: const Icon(Icons.add_alert_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MarkEventScreen(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.planTooltipFavorites,
                  icon: const Icon(Icons.star_border),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FavoritesScreen(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.planTooltipSettings,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
                // Saved-trips icon removed from AppBar: now lives
                // as the "Mis viajes" bottom-nav tab in AppShell.
                const SizedBox(width: Tokens.space8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space20, Tokens.space8, Tokens.space20, Tokens.space32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Hero
                  Text(l.planEyebrow,
                      style: t.labelSmall?.copyWith(
                        color: scheme.tertiary, letterSpacing: 1.4,
                      )),
                  const SizedBox(height: Tokens.space8),
                  Builder(builder: (context) {
                    final auth = ref.watch(authProvider);
                    final name = auth.user?.displayName.split(' ').first;
                    final greeting = name != null && name.isNotEmpty
                        ? l.planHeroPersonal(name)
                        : l.planHero;
                    return Text(greeting, style: t.headlineMedium)
                        .animate()
                        .fadeIn(duration: Tokens.motionBase)
                        .moveY(begin: 8, end: 0, curve: Tokens.curveOut);
                  }),
                  const SizedBox(height: Tokens.space4),
                  Text(
                    l.planIntro,
                    style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Tokens.space12),
                  // Trip Inspiration entry — small, non-intrusive
                  // CTA below the intro. LLM-powered "give me an
                  // itinerary from a free-form prompt"; result
                  // hands off to this same PlanScreen with
                  // origin/destination/waypoints pre-filled.
                  Wrap(
                    spacing: Tokens.space8,
                    runSpacing: Tokens.space8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: Text(l.inspireTitle),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const InspireScreen(),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.my_location, size: 18),
                        label: Text(l.prepareDepartureNow),
                        onPressed: _prepareDepartureNow,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link, size: 18),
                        label: Text(l.importFromMaps),
                        onPressed: _importFromMaps,
                      ),
                    ],
                  ),
                  const SizedBox(height: Tokens.space16),
                  // Note: "Salir ya" quick-plan lives as a FAB
                  // now (see Scaffold.floatingActionButton) — the
                  // former inline hero card was eating above-the-
                  // fold real estate for a Premium-gated shortcut.
                  _ProfileChip(
                    profile: _overrideProfile
                        ?? ref.watch(tripProfileProvider),
                    isOverride: _overrideProfile != null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: Tokens.space8),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.tune, size: 16),
                        label: Text(
                          _overrideProfile != null
                              ? l.planProfileOverriding
                              : l.planProfileOverride,
                        ),
                        onPressed: () async {
                          final base = _overrideProfile
                              ?? ref.read(tripProfileProvider)
                              ?? const TripProfile();
                          final result = await Navigator.of(context)
                              .push<TripProfile?>(
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                mode: ProfileScreenMode.override_,
                                initial: base,
                              ),
                            ),
                          );
                          if (!mounted) return;
                          if (result != null) {
                            setState(() => _overrideProfile = result);
                          }
                        },
                      ),
                      if (_overrideProfile != null)
                        TextButton.icon(
                          icon: const Icon(Icons.clear, size: 16),
                          label: Text(l.planProfileClearOverride),
                          onPressed: () =>
                              setState(() => _overrideProfile = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: Tokens.space16),

                  // Route card
                  SoftCard(
                    padding: const EdgeInsets.all(Tokens.space16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: LocationSearchField(
                                key: _originKey,
                                label: l.planFrom,
                                geocode: api.geocode,
                                onUseCurrentLocation: () async {
                                  final res = await ref
                                      .read(currentLocationServiceProvider)
                                      .resolve();
                                  if (!context.mounted) return null;
                                  if (res.disabled || res.denied) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(
                                        res.disabled
                                            ? l.locationServiceOff
                                            : l.locationPermissionDenied,
                                      )),
                                    );
                                    return null;
                                  }
                                  if (res.timedOut || res.place == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l.locationUnavailable)),
                                    );
                                    return null;
                                  }
                                  return res.place;
                                },
                                onSelected: (r) {
                                  setState(() => _origin = r);
                                  if (r != null) {
                                    ref.read(recentSearchesProvider.notifier).push(r);
                                  }
                                },
                                initial: _origin,
                              ),
                            ),
                            // Weather chip inline (right of field).
                            // Zero-width when no coord picked yet.
                            if (_origin != null) ...[
                              const SizedBox(width: Tokens.space8),
                              WeatherChip(
                                lat: _origin!.coordinate.lat,
                                lon: _origin!.coordinate.lon,
                              ),
                            ],
                          ],
                        ),
                        // Intermediate stops — long-press + drag to
                        // reorder (like Google Maps). Uses
                        // ReorderableListView with shrinkWrap since
                        // it lives inside a Column, not a scrollable.
                        if (_stops.isNotEmpty)
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final moved = _stops.removeAt(oldIndex);
                                _stops.insert(newIndex, moved);
                              });
                            },
                            proxyDecorator: (child, index, animation) =>
                                Material(
                                  color: Colors.transparent,
                                  child: child,
                                ),
                            children: [
                              for (var i = 0; i < _stops.length; i++)
                                // Long-press anywhere on the row starts the
                                // drag — mirrors Google Maps' behaviour on
                                // its destination picker. The explicit drag
                                // handle stays for accessibility + discovery.
                                ReorderableDelayedDragStartListener(
                                  key: ValueKey('stop-row-$i-${_stops[i].place?.coordinate.lat}'),
                                  index: i,
                                  child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: Tokens.space12),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          ReorderableDragStartListener(
                                            index: i,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 10),
                                              margin: const EdgeInsets.only(
                                                  right: Tokens.space4),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.drag_indicator,
                                                size: 22,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: LocationSearchField(
                                              key: ValueKey('stop-field-$i'),
                                              label: l.planStopLabel(i + 1),
                                              geocode: api.geocode,
                                              onSelected: (r) {
                                                if (r == null) return;
                                                setState(() => _stops[i] =
                                                    _stops[i].copyWith(place: r));
                                              },
                                              initial: _stops[i].place,
                                            ),
                                          ),
                                          if (_stops[i].place != null) ...[
                                            const SizedBox(width: Tokens.space4),
                                            WeatherChip(
                                              lat: _stops[i].place!.coordinate.lat,
                                              lon: _stops[i].place!.coordinate.lon,
                                            ),
                                          ],
                                          IconButton(
                                            tooltip: l.planStopRemove,
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              setState(() => _stops.removeAt(i));
                                            },
                                          ),
                                        ],
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          icon: Icon(
                                            _dwellIcon(_stops[i].dwellNights),
                                            size: 16,
                                          ),
                                          label: Text(
                                              _dwellLabel(l, _stops[i].dwellNights)),
                                          onPressed: () async {
                                            final picked = await _pickDwellNights(
                                                context, _stops[i]);
                                            if (picked == null) return;
                                            setState(() => _stops[i] =
                                                _stops[i].copyWith(
                                                    dwellNights: picked));
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ),
                            ],
                          ),
                        if (_stops.length < _maxStops) ...[
                          const SizedBox(height: Tokens.space8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: Text(l.planAddStop),
                              onPressed: () async {
                                final picked =
                                    await _pickStop(context, api.geocode);
                                if (picked == null) return;
                                // Fresh stop defaults to dwell=0
                                // (pass-through). Driver taps the
                                // dwell chip below the field to
                                // upgrade to overnight if wanted.
                                setState(() => _stops.add(
                                      PlannedStop(place: picked),
                                    ));
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: Tokens.space12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: LocationSearchField(
                                key: _destinationKey,
                                label: l.planTo,
                                geocode: api.geocode,
                                onSelected: (r) {
                                  setState(() => _destination = r);
                                  if (r != null) {
                                    ref.read(recentSearchesProvider.notifier).push(r);
                                  }
                                },
                                initial: _destination,
                              ),
                            ),
                            if (_destination != null) ...[
                              const SizedBox(width: Tokens.space8),
                              WeatherChip(
                                lat: _destination!.coordinate.lat,
                                lon: _destination!.coordinate.lon,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: Tokens.space12),
                        Row(
                          children: [
                            Expanded(
                              child: _DepartureButton(
                                label: dateFmt.format(_departure),
                                onPressed: _pickDeparture,
                              ),
                            ),
                            const SizedBox(width: Tokens.space8),
                            FilterChip(
                              selected: _isRoundTrip,
                              avatar: Icon(
                                Icons.repeat,
                                size: 16,
                                color: _isRoundTrip
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                              label: Text(l.planRoundTripChip),
                              onSelected: (v) =>
                                  setState(() => _isRoundTrip = v),
                            ),
                          ],
                        ),
                        if (_isRoundTrip) ...[
                          const SizedBox(height: Tokens.space8),
                          _DepartureButton(
                            label: '↩ ${dateFmt.format(_returnDeparture)}',
                            onPressed: _pickReturnDeparture,
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(delay: 60.ms, duration: Tokens.motionBase),

                  const SizedBox(height: Tokens.space24),

                  // Preferences group
                  SectionHeader(
                    title: l.planSectionOptional,
                    eyebrow: l.planSectionOptionalEyebrow,
                  ),
                  SoftCard(
                    key: _preferencesKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Tokens.space12,
                      vertical: Tokens.space4,
                    ),
                    child: Column(
                      children: [
                        // Group 1: "En la ruta" — hotels & restaurants
                        // as ExpansionTiles so the sub-options
                        // (detour, stars, cuisines) only take space
                        // when actually configured. Alerts stay
                        // inline (no sub-options, always on by
                        // default).
                        _CompactExpandableToggle(
                          icon: Icons.hotel_outlined,
                          title: l.hotelPrefTitle,
                          value: _hotelPrefs.enabled,
                          onChanged: (v) => setState(
                            () => _hotelPrefs = _hotelPrefs.copyWith(enabled: v),
                          ),
                          expandedChild: HotelPreferencesSection(
                            value: _hotelPrefs,
                            onChanged: (v) => setState(() => _hotelPrefs = v),
                            hideMainSwitch: true,
                          ),
                        ),
                        _CompactExpandableToggle(
                          icon: Icons.restaurant_outlined,
                          title: l.restaurantPrefTitle,
                          value: _restaurantPrefs.enabled,
                          onChanged: (v) => setState(
                            () => _restaurantPrefs =
                                _restaurantPrefs.copyWith(enabled: v),
                          ),
                          expandedChild: RestaurantPreferencesSection(
                            value: _restaurantPrefs,
                            onChanged: (v) =>
                                setState(() => _restaurantPrefs = v),
                            hideMainSwitch: true,
                          ),
                        ),
                        _CompactToggle(
                          icon: Icons.local_parking_outlined,
                          title: l.parkingPrefTitle,
                          subtitle: l.parkingPrefSub,
                          value: _parkingEnabled,
                          onChanged: (v) =>
                              setState(() => _parkingEnabled = v),
                        ),
                        InkWell(
                          onTap: () => setState(
                            () => _advancedOptionsExpanded =
                                !_advancedOptionsExpanded,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Tokens.space12,
                              horizontal: Tokens.space4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _advancedOptionsExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 20,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: Tokens.space8),
                                Text(
                                  _advancedOptionsExpanded
                                      ? l.planLessOptions
                                      : l.planMoreOptions,
                                  style: t.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: Tokens.motionBase,
                          curve: Tokens.curveOut,
                          child: !_advancedOptionsExpanded
                              ? const SizedBox.shrink()
                              : Column(
                                  children: [
                                    _CompactToggle(
                                      icon: Icons.warning_amber_outlined,
                                      title: l.planOptAlertsTitle,
                                      subtitle: l.planOptAlertsSub,
                                      value: _alertsEnabled,
                                      onChanged: (v) => setState(
                                        () => _alertsEnabled = v,
                                      ),
                                    ),
                                    _CompactToggle(
                                      icon: Icons.euro,
                                      title: l.planOptTollFreeTitle,
                                      subtitle: l.planOptTollFreeSub,
                                      value: _tollAlternativeEnabled,
                                      onChanged: (v) => setState(
                                        () => _tollAlternativeEnabled = v,
                                      ),
                                    ),
                                    _CompactToggle(
                                      icon: Icons.alt_route,
                                      title: l.planOptRouteVariantsTitle,
                                      subtitle: l.planOptRouteVariantsSub,
                                      value: _routeComparisonEnabled,
                                      onChanged: (v) => setState(
                                        () => _routeComparisonEnabled = v,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 120.ms, duration: Tokens.motionBase),

                  const SizedBox(height: Tokens.space24),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Tokens.space12),
                      child: SoftCard(
                        background: scheme.errorContainer,
                        borderColor: scheme.error.withValues(alpha: 0.4),
                        padding: const EdgeInsets.all(Tokens.space16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: scheme.onErrorContainer),
                                const SizedBox(width: Tokens.space12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: t.bodyMedium?.copyWith(
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Tokens.space8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _loading ? null : _submit,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(l.planErrorRetry),
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  PrimaryCta(
                    label: _loading ? l.planCtaBusy : l.planCta,
                    icon: _loading ? null : Icons.arrow_forward,
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: Tokens.space12),
                  Center(
                    child: Text(l.planCountriesNote, style: t.bodySmall),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact preferences row — icon + title/subtitle + switch, all
/// on one line. Replaces the previous full-height SwitchListTile
/// stack. Denser, faster to scan. Used for toggles with no sub-
/// options (alerts / toll-free / route variants).
class _CompactToggle extends StatelessWidget {
  const _CompactToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4, vertical: Tokens.space8,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20,
                color: value ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: t.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: Tokens.space8),
            Transform.scale(
              scale: 0.85,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact toggle with an inline expansion — when `value` is
/// true, `expandedChild` renders below the toggle (typically
/// the nested detour / stars / cuisines options). When off,
/// only the compact row is visible. Divider below for visual
/// grouping with adjacent `_CompactToggle` rows.
class _CompactExpandableToggle extends StatelessWidget {
  const _CompactExpandableToggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.expandedChild,
  });
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget expandedChild;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4, vertical: Tokens.space8,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20,
                    color: value ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: Tokens.space12),
                Expanded(
                  child: Text(title,
                      style: t.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (value)
                  Icon(Icons.expand_less, size: 18,
                      color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.85,
                  child: Switch.adaptive(
                    value: value, onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (value)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              32, 0, 4, Tokens.space8,
            ),
            child: expandedChild,
          ),
      ],
    );
  }
}

// _SavedTripsBar removed — "Mis viajes" is now a bottom-nav tab.

/// Inline sheet asking only for the destination — used by the
/// "Salir ya" quick flow so the driver types one field instead
/// of filling the full plan form.
/// Return value of the "Leave now" confirmation dialog when the
/// plan form already has a destination. `go` = use the current
/// destination; `change` = open the picker to pick a different one.
enum _LeaveNowChoice { go, change }

/// Intermediate stop with an optional dwell duration. Backed by a
/// [GeocodeResult] (place info) plus `dwellNights`. Pass-through
/// stops have `dwellNights == 0`; overnight anchors have `>= 1`.
class PlannedStop {
  const PlannedStop({required this.place, this.dwellNights = 0});
  final GeocodeResult place;
  final int dwellNights;

  PlannedStop copyWith({GeocodeResult? place, int? dwellNights}) =>
      PlannedStop(
        place: place ?? this.place,
        dwellNights: dwellNights ?? this.dwellNights,
      );
}

String _dwellLabel(AppLocalizations l, int dwell) {
  if (dwell == 0) return l.planStopDwellPassThrough;
  if (dwell < 0) return l.planStopDwellHours(-dwell);
  if (dwell == 1) return l.planStopDwellOneNight;
  return l.planStopDwellNights(dwell);
}

IconData _dwellIcon(int dwell) {
  if (dwell == 0) return Icons.arrow_forward;
  if (dwell < 0) return Icons.schedule_outlined;
  return Icons.hotel_outlined;
}

Future<int?> _pickDwellNights(BuildContext context, PlannedStop stop) async {
  final l = AppLocalizations.of(context);
  final options = <int>[0, -1, -2, -4, -6, 1, 2, 3, 4, 5, 7];
  return showModalBottomSheet<int>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.planStopDwellTitle(stop.place.displayName),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          for (final n in options)
            ListTile(
              leading: Icon(_dwellIcon(n)),
              title: Text(_dwellLabel(l, n)),
              trailing: n == stop.dwellNights
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(n),
            ),
        ],
      ),
    ),
  );
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.profile,
    required this.onTap,
    this.isOverride = false,
  });

  final TripProfile? profile;
  final VoidCallback onTap;
  final bool isOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final hasProfile = profile != null;
    final children = <Widget>[
      Icon(
        isOverride
            ? Icons.tune
            : (hasProfile ? Icons.person_outline : Icons.person_add_alt_1),
        size: 18,
        color: isOverride ? scheme.tertiary : scheme.onSurfaceVariant,
      ),
      const SizedBox(width: Tokens.space8),
      Expanded(
        child: hasProfile
            ? _profileSummary(context, profile!, t, scheme, isOverride)
            : Text(
                AppLocalizations.of(context).profilePromptSetup,
                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
      ),
      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
    ];
    return SoftCard(
      onTap: onTap,
      borderColor: isOverride ? scheme.tertiary.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16, vertical: Tokens.space12,
      ),
      child: Row(children: children),
    );
  }

  Widget _profileSummary(
    BuildContext context,
    TripProfile p, TextTheme t, ColorScheme scheme, bool isOverride,
  ) {
    final l = AppLocalizations.of(context);
    final bits = <String>[
      vehicleTypeLabel(context, p.vehicle.type),
      fuelTypeLabel(context, p.vehicle.fuelType),
      if (p.travellers > 1) l.planProfileTravellers(p.travellers),
      if (p.hasKids) l.planProfileWithKids,
      if (p.hasPets) l.planProfileWithPets,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOverride)
          Text(
            l.planProfileOverrideActive,
            style: t.labelSmall
                ?.copyWith(color: scheme.tertiary, letterSpacing: 1.2),
          ),
        Text(
          bits.join(' · '),
          style: t.bodyMedium?.copyWith(color: scheme.onSurface),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _DepartureButton extends StatelessWidget {
  const _DepartureButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(labelText: l.planDepartureLabel),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: scheme.onSurfaceVariant, size: 18),
            const SizedBox(width: Tokens.space12),
            Expanded(child: Text(label, style: t.bodyLarge)),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
