import 'dart:async';

import 'package:flutter/material.dart';
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
import '../services/trip_sharing.dart';
import '../widgets/hotel_preferences.dart';
import '../widgets/location_search_field.dart';
import '../widgets/plan_loading_dialog.dart';
import '../widgets/restaurant_preferences.dart';
import '../widgets/travel_style_chip.dart';
import 'dashboard_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'mark_event_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'result_screen.dart';
import '../services/app_tutorial.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key, this.initialShared});

  /// When arriving via a shared trip link, prefill the form with the
  /// origin / destination / departure so the user just taps Plan.
  final SharedTrip? initialShared;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  GeocodeResult? _origin;
  GeocodeResult? _destination;
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
      // Note: we don't auto-submit — user confirms with the CTA.
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
    var dialogOpen = false;
    if (mounted) {
      dialogOpen = true;
      // Build the step list from the ACTUAL request the user just
      // submitted so we never claim to be "searching hotels" on a
      // trip that isn't asking for any. Routing + traffic + fuel
      // always run server-side; the rest are gated.
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
      // Fire-and-forget: `showDialog` returns a Future that resolves
      // when the dialog closes; we don't await it.
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PlanLoadingDialog(steps: steps),
      ));
    }
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final request = TripPlanRequest(
        origin: origin.coordinate,
        destination: destination.coordinate,
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
      // Pop the loading dialog BEFORE pushing ResultScreen — otherwise
      // the dialog stays underneath in the route stack and the later
      // finally-pop would pop ResultScreen instead.
      if (dialogOpen) {
        Navigator.of(context).pop();
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
      Navigator.of(context).push(
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
      // Only pops here on the ERROR path — success already popped
      // above before the ResultScreen push.
      if (mounted && dialogOpen && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
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
    final dateFmt = DateFormat('EEE, d MMM · HH:mm');

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
                IconButton(
                  tooltip: l.planTooltipSaved,
                  icon: const Icon(Icons.bookmark_outline),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryScreen(),
                    ),
                  ),
                ),
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
                  const SizedBox(height: Tokens.space16),
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
                          label: const Text('Clear override'),
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
                        LocationSearchField(
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
                        const SizedBox(height: Tokens.space12),
                        LocationSearchField(
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
                        const SizedBox(height: Tokens.space12),
                        _DepartureButton(
                          label: dateFmt.format(_departure),
                          onPressed: _pickDeparture,
                        ),
                        const SizedBox(height: Tokens.space8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.planRoundTripTitle),
                          subtitle: Text(
                            l.planRoundTripSubtitle,
                            style: t.bodySmall,
                          ),
                          value: _isRoundTrip,
                          onChanged: (v) =>
                              setState(() => _isRoundTrip = v),
                        ),
                        if (_isRoundTrip) ...[
                          const SizedBox(height: Tokens.space4),
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
                      horizontal: Tokens.space16,
                      vertical: Tokens.space8,
                    ),
                    child: Column(
                      children: [
                        HotelPreferencesSection(
                          value: _hotelPrefs,
                          onChanged: (v) => setState(() => _hotelPrefs = v),
                        ),
                        const Divider(height: Tokens.space16),
                        RestaurantPreferencesSection(
                          value: _restaurantPrefs,
                          onChanged: (v) => setState(() => _restaurantPrefs = v),
                        ),
                        const Divider(height: Tokens.space16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.planOptAlertsTitle,
                            style: t.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(l.planOptAlertsSub, style: t.bodySmall),
                          ),
                          value: _alertsEnabled,
                          onChanged: (v) => setState(() => _alertsEnabled = v),
                        ),
                        const Divider(height: Tokens.space16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.planOptTollFreeTitle,
                            style: t.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(l.planOptTollFreeSub, style: t.bodySmall),
                          ),
                          value: _tollAlternativeEnabled,
                          onChanged: (v) => setState(() {
                            _tollAlternativeEnabled = v;
                          }),
                        ),
                        // Hourly toll analysis selector removed: now
                        // implicit when the toll alternative toggle
                        // is on. See `_hourlyTollEnabled` getter.
                        const Divider(height: Tokens.space16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.planOptRouteVariantsTitle, style: t.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              l.planOptRouteVariantsSub, style: t.bodySmall,
                            ),
                          ),
                          value: _routeComparisonEnabled,
                          onChanged: (v) =>
                              setState(() => _routeComparisonEnabled = v),
                        ),
                        // "Avoid motorways" + "Prefer scenic" toggles
                        // hidden for the beta — routing quality on
                        // those variants isn't consistent yet and
                        // exposing the switches confused testers.
                        // They stay on the model side (flags default
                        // false in _submit) so we can re-enable via
                        // the trip profile in a later iteration.
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
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Desired departure'),
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
