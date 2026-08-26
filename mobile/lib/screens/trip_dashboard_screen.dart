import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../services/car_bridge.dart';
import '../services/car_notification_bridge.dart';
import '../services/nav_deep_link.dart';
import '../services/notifications.dart';
import '../services/trip_alerts.dart';
import '../services/trip_foreground.dart';
import '../services/trip_progress.dart';
import '../services/trip_session_persistence.dart';
import '../widgets/osm_attribution.dart';

/// Phase-1 "trip execution" screen: the app-side copilot the driver
/// keeps open (in split-screen or by tabbing between apps) while
/// Google Maps / Waze does the actual turn-by-turn.
///
/// What this screen provides today:
/// - Live user position as a distinctive pin on the planned route.
/// - Countdown card to the first meal / sleep / rest stop from the
///   optimizer, updated when the position changes.
/// - Big "Continue in nav app" CTA that opens the deep-link picker.
///
/// What's deliberately NOT here yet (phased in later — see
/// `project_navigation_phase` memory):
/// - Route snapping / accurate progress percentage
/// - Push notifications when approaching a stop or when a new adverse
///   event enters the corridor ahead
/// - Recalculate-on-drift prompt
/// - Android foreground service so tracking survives when the app is
///   backgrounded (today only foreground GPS)
class TripDashboardScreen extends ConsumerStatefulWidget {
  const TripDashboardScreen({
    super.key,
    required this.request,
    required this.response,
    required this.origin,
    required this.destination,
  });

  final TripPlanRequest request;
  final TripPlanResponse response;
  final GeocodeResult origin;
  final GeocodeResult destination;

  @override
  ConsumerState<TripDashboardScreen> createState() =>
      _TripDashboardScreenState();
}

class _TripDashboardScreenState extends ConsumerState<TripDashboardScreen> {
  StreamSubscription<Position>? _positionSub;
  LatLng? _lastFix;
  MapController? _mapController;
  bool _autoCenter = true;
  bool _permissionDenied = false;
  bool _serviceDisabled = false;

  late final RouteReference _routeRef;
  late final TripAlertsEvaluator _alerts;
  late final Set<String> _preTripEventIds;
  final SpeedTracker _speedTracker = SpeedTracker();
  TripProgress? _progress;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Precompute the cumulative polyline distances once — every fix
    // reuses this without re-summing haversines.
    final geom = widget.response.route.geometry;
    _routeRef = RouteReference.build(
      geom.isNotEmpty
          ? geom
          : [widget.origin.coordinate, widget.destination.coordinate],
    );
    // Snapshot the events the user already saw pre-trip so we don't
    // re-notify them mid-drive. Only NEW events entering the plan
    // (a fresh fire reported after departure) should trigger push.
    _preTripEventIds =
        widget.response.adverseEvents.map((e) => e.id).toSet();
    _alerts = TripAlertsEvaluator(
      // Planned arrival = desired departure + free-flow minutes.
      // Using the response's own reference clock keeps the "behind
      // schedule" comparison meaningful even if the user starts the
      // dashboard hours after planning.
      plannedArrival: widget.request.desiredDepartureAt.add(
        Duration(
          minutes: widget.response.route.freeFlowMinutes.round(),
        ),
      ),
    );
    _startPositionStream();
    _acquireWakelock();
    _showActiveTripNotification();
    // Persist the initial trip snapshot so that if Android reclaims
    // the app before we ever get a GPS fix, the user can still
    // resume where they left off with the plan we already have.
    unawaited(TripSessionPersistence.instance.save(
      request: widget.request,
      response: widget.response,
      origin: widget.origin,
      destination: widget.destination,
      desiredDepartureAt: widget.request.desiredDepartureAt,
    ));
  }

  Future<void> _acquireWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Non-fatal — some emulators reject the call. Real devices are fine.
    }
  }

  Future<void> _showActiveTripNotification() async {
    // Start the Android foreground service — this is what actually
    // stops the OS from OOM-killing MyTravelPal when the driver
    // switches to Google Maps for turn-by-turn. The persistent
    // notification is a required side-effect (foreground services
    // MUST show a notification) but it also carries the driver-
    // facing "trip active" hint we used to fire via the local
    // notifications plugin.
    final l = AppLocalizations.of(context);
    await TripForegroundService.instance.start(
      title: l.tripDashboardActiveNotifTitle,
      body: l.tripDashboardActiveNotifBody,
    );
  }

  /// Current distanceFilter (metres) applied to the geolocator stream.
  /// Recomputed from the rolling speed so the fix cadence adapts to
  /// driving context — city (~30 m every ~3 s) vs highway (~100 m
  /// every ~4 s). Prevents burning GPS every 15 m on a 130 km/h
  /// motorway stretch.
  int _currentDistanceFilter = 20;

  Future<void> _startPositionStream() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _serviceDisabled = true);
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    _subscribeWithFilter(_currentDistanceFilter);
  }

  void _subscribeWithFilter(int distanceFilterMeters) {
    _positionSub?.cancel();
    _currentDistanceFilter = distanceFilterMeters;
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (Object _) {
      // Swallow transient errors; the stream recovers on the next fix.
    });
  }

  /// Map current speed (km/h) to a sensible distance filter. Buckets
  /// are wide so we don't churn the geolocator subscription every
  /// couple of fixes. Tuned so at each cadence a fresh fix arrives
  /// roughly every 3-4 s of driving.
  int _distanceFilterForSpeed(double kmh) {
    if (kmh < 30) return 15;   // urban / traffic
    if (kmh < 90) return 40;   // secondary roads
    return 100;                // motorway
  }

  void _onPosition(Position p) {
    final fix = LatLng(p.latitude, p.longitude);
    if (!mounted) return;
    final fixLL = LatLon(lat: p.latitude, lon: p.longitude);
    _speedTracker.addFix(
      fixLL,
      p.timestamp,
      // geolocator reports speed in m/s; only trust it when the
      // accuracy is decent (< 5 m/s ~ 18 km/h uncertainty).
      speedKmh: p.speedAccuracy < 5 && p.speed >= 0 ? p.speed * 3.6 : null,
    );
    final next = _nextStop;
    final progress = computeProgress(
      route: _routeRef,
      fix: fixLL,
      now: DateTime.now(),
      speedTracker: _speedTracker,
      plannedTotalMinutes: widget.response.route.freeFlowMinutes,
      nextStopAt: next?.at,
      nextStopKm: next?.distanceFromOriginKm,
      fuelPrices: widget.response.fuelPrices,
    );
    setState(() {
      _lastFix = fix;
      _progress = progress;
    });
    if (_autoCenter) {
      _mapController?.move(fix, 13.5);
    }
    // Adapt the GPS distance filter every few fixes based on current
    // speed. Only re-subscribe when the target changes bucket — the
    // subscription rebuild has a small cost that would defeat the
    // purpose if we did it on every tick.
    final target = _distanceFilterForSpeed(progress.currentSpeedKmh);
    if (target != _currentDistanceFilter) {
      _subscribeWithFilter(target);
    }
    // Push the summary to the Android Auto bridge so the head unit
    // stays in sync. Fire-and-forget: worst case AA renders slightly
    // stale numbers for one tick.
    unawaited(CarBridge.instance.updateTrip(
      progress: progress,
      me: fixLL,
      destination: widget.destination.coordinate,
      nextStop: next,
      fuelStations: widget.response.fuelPrices,
      restaurants: widget.response.restaurants,
    ));
    final newAlerts = _alerts.evaluate(
      progress: progress,
      mealStops: widget.response.optimizations?.mealStops ?? const [],
      sleepStop: widget.response.optimizations?.sleepStop,
      adverseEvents: widget.response.adverseEvents,
      preTripEventIds: _preTripEventIds,
    );
    if (newAlerts.isNotEmpty) {
      _dispatchAlerts(newAlerts);
    }
    // Refresh the foreground notification so a driver glancing at
    // the shade sees current km driven / ETA — otherwise it just
    // says "trip active" forever. `updateNotification` is cheap and
    // safe to call every tick.
    unawaited(_refreshForegroundNotif(progress, next));
  }

  Future<void> _refreshForegroundNotif(
    TripProgress progress, MealStopOpt? next,
  ) async {
    final l = AppLocalizations.of(context);
    final done = progress.progressKm.toStringAsFixed(0);
    final total = progress.totalKm.toStringAsFixed(0);
    final body = next?.restaurantName != null
        ? l.tripDashboardForegroundBodyWithStop(
            done, total, next!.restaurantName!,
          )
        : l.tripDashboardForegroundBodyBare(done, total);
    await TripForegroundService.instance.updateNotification(
      title: l.tripDashboardActiveNotifTitle,
      body: body,
    );
  }

  void _dispatchAlerts(List<TripAlert> alerts) {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    for (final a in alerts) {
      final (title, body) = _renderAlert(l, a);
      // In-app: a persistent snackbar so a driver glancing at the
      // dashboard sees the alert even if the push was silenced.
      messenger?.showSnackBar(
        SnackBar(
          content: Text(body, maxLines: 3),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Fire-and-forget: notification service handles the platform
      // gate (available? permission granted?) internally.
      unawaited(NotificationService.instance.showTripAlert(
        stableId: a.id,
        title: title,
        body: body,
      ));
      // Native car-extended notification so the same alert shows up
      // on the Android Auto head unit. Uses the same numeric id as
      // the phone notif so both surfaces get one, coherent card.
      unawaited(CarNotificationBridge.instance.postAlert(
        id: NotificationService.notificationIdFor('trip_alert:${a.id}'),
        title: title,
        body: body,
      ));
    }
  }

  (String title, String body) _renderAlert(
    AppLocalizations l, TripAlert a,
  ) {
    switch (a.kind) {
      case TripAlertKind.approachingStop:
        final slotArg = a.args[0] as String;
        final label = _localiseSlot(l, slotArg);
        final name = a.args[1] as String;
        final mins = a.args[2] as int;
        return (
          l.alertApproachingStopTitle,
          l.alertApproachingStopBody(label, name, mins),
        );
      case TripAlertKind.newAlertAhead:
        final type = a.args[0] as String;
        final km = a.args[1] as String;
        return (
          l.alertNewAdverseAheadTitle,
          l.alertNewAdverseAheadBody(type, km),
        );
      case TripAlertKind.driftDetected:
        final off = a.args[0] as String;
        return (
          l.alertDriftDetectedTitle,
          l.alertDriftDetectedBody(off),
        );
      case TripAlertKind.behindSchedule:
        final slip = a.args[0] as int;
        return (
          l.alertBehindScheduleTitle,
          l.alertBehindScheduleBody(slip),
        );
    }
  }

  String _localiseSlot(AppLocalizations l, String slot) {
    switch (slot) {
      case 'breakfast':
        return l.profileBreakfast;
      case 'lunch':
        return l.profileLunch;
      case 'dinner':
        return l.profileDinner;
      case 'sleep':
        return l.tripDashboardSleepStopLabel;
      default:
        return slot;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    // Clear the AA bridge so the head unit falls back to the idle
    // screen instead of showing stale ETA / cheaper-fuel data.
    unawaited(CarBridge.instance.clearTrip());
    // Release the wake lock so the phone can dim / sleep normally
    // once the driver leaves the dashboard.
    WakelockPlus.disable().catchError((_) => false);
    // Tear down the foreground service — this dismisses the ongoing
    // notification and lets Android reclaim MyTravelPal normally.
    unawaited(TripForegroundService.instance.stop());
    // Clear the persisted session — user explicitly left the
    // dashboard so there's nothing to resume.
    unawaited(TripSessionPersistence.instance.clear());
    super.dispose();
  }

  MealStopOpt? get _nextStop {
    final stops = widget.response.optimizations?.mealStops ?? const [];
    if (stops.isEmpty) return null;
    final now = DateTime.now();
    // First meal stop still in the future; fall back to first meal
    // stop overall if all timestamps are past (edge case: user
    // launches trip late).
    for (final s in stops) {
      if (s.at.isAfter(now)) return s;
    }
    return stops.first;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final geometry = widget.response.route.geometry;
    final polyline = geometry.isNotEmpty
        ? geometry.map((c) => LatLng(c.lat, c.lon)).toList(growable: false)
        : <LatLng>[
            LatLng(widget.origin.coordinate.lat, widget.origin.coordinate.lon),
            LatLng(
              widget.destination.coordinate.lat,
              widget.destination.coordinate.lon,
            ),
          ];
    final destination = LatLng(
      widget.destination.coordinate.lat,
      widget.destination.coordinate.lon,
    );
    final next = _nextStop;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tripDashboardTitle),
        actions: [
          IconButton(
            tooltip: l.tripDashboardCenterOnMe,
            icon: Icon(
              _autoCenter ? Icons.my_location : Icons.location_searching,
              color: _autoCenter ? scheme.primary : null,
            ),
            onPressed: () {
              setState(() => _autoCenter = !_autoCenter);
              if (_autoCenter && _lastFix != null) {
                _mapController?.move(_lastFix!, 13.5);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints([
                        for (final p in polyline) p,
                        destination,
                        if (_lastFix != null) _lastFix!,
                      ]),
                      padding: const EdgeInsets.all(48),
                    ),
                    // Any gesture disables auto-centre so the user can
                    // pan around without us fighting them.
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture && _autoCenter) {
                        setState(() => _autoCenter = false);
                      }
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mytravelpal.app',
                      maxZoom: 19,
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: polyline,
                          strokeWidth: 5,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: destination,
                          width: 40, height: 40,
                          alignment: Alignment.topCenter,
                          child: _flagPin(scheme),
                        ),
                        if (next?.restaurantCoordinate != null)
                          Marker(
                            point: LatLng(
                              next!.restaurantCoordinate!.lat,
                              next.restaurantCoordinate!.lon,
                            ),
                            width: 34, height: 34,
                            alignment: Alignment.topCenter,
                            child: _stopPin(
                              scheme, Icons.restaurant_menu,
                            ),
                          ),
                        if (_lastFix != null)
                          Marker(
                            point: _lastFix!,
                            width: 26, height: 26,
                            child: _hereDot(scheme),
                          ),
                      ],
                    ),
                    const OsmAttribution(),
                  ],
                ),
                if (_permissionDenied || _serviceDisabled)
                  Positioned(
                    top: Tokens.space12,
                    left: Tokens.space12,
                    right: Tokens.space12,
                    child: _WarningBanner(
                      text: _permissionDenied
                          ? l.tripDashboardPermissionDenied
                          : l.tripDashboardServiceDisabled,
                    ),
                  ),
              ],
            ),
          ),
          _BottomPanel(
            nextStop: next,
            progress: _progress,
            onOpenNav: () => showNavAppPicker(
              context,
              destination: widget.destination.coordinate,
              origin: widget.origin.coordinate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagPin(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.flag, color: Colors.white, size: 18),
    );
  }

  Widget _stopPin(ColorScheme scheme, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.tertiary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _hereDot(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.nextStop,
    required this.progress,
    required this.onOpenNav,
  });

  final MealStopOpt? nextStop;
  final TripProgress? progress;
  final VoidCallback onOpenNav;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        Tokens.space16,
        Tokens.space16,
        Tokens.space16,
        Tokens.space12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null) ...[
            _ProgressStrip(progress: progress!),
            const SizedBox(height: Tokens.space12),
          ],
          if (progress?.cheaperFuelAhead != null) ...[
            _CheaperFuelChip(hint: progress!.cheaperFuelAhead!),
            const SizedBox(height: Tokens.space12),
          ],
          if (nextStop != null)
            _NextStopCard(stop: nextStop!, progress: progress),
          if (nextStop != null) const SizedBox(height: Tokens.space12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              icon: const Icon(Icons.navigation_outlined),
              label: Text(l.tripDashboardOpenNav),
              onPressed: onOpenNav,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress bar + text summary "142 / 850 km · ETA 17:42". Renders
/// once we have at least one GPS fix so the numbers are meaningful.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.progress});
  final TripProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          child: LinearProgressIndicator(
            value: progress.progressFraction,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(scheme.primary),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.tripDashboardProgressLine(
                progress.progressKm.toStringAsFixed(0),
                progress.totalKm.toStringAsFixed(0),
              ),
              style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              l.tripDashboardEta(
                DateFormat.Hm().format(progress.etaToDestination.toLocal()),
              ),
              style: t.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheaperFuelChip extends StatelessWidget {
  const _CheaperFuelChip({required this.hint});
  final CheaperFuelHint hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space12, vertical: Tokens.space8,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.local_gas_station,
              size: 20, color: scheme.onTertiaryContainer),
          const SizedBox(width: Tokens.space8),
          Expanded(
            child: Text(
              l.tripDashboardCheaperFuel(
                hint.station.stationName,
                hint.aheadKm.toStringAsFixed(0),
                (hint.savingsEurPerL * 100).toStringAsFixed(0),
              ),
              style: t.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStopCard extends StatelessWidget {
  const _NextStopCard({required this.stop, this.progress});
  final MealStopOpt stop;
  final TripProgress? progress;

  String _slotLabel(AppLocalizations l) {
    switch (stop.slot) {
      case 'breakfast':
        return l.profileBreakfast;
      case 'lunch':
        return l.profileLunch;
      case 'dinner':
        return l.profileDinner;
      default:
        return stop.slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final atLocal = stop.at.toLocal();
    // Prefer the live ETA computed from GPS + rolling speed — the
    // planned wall-clock time diverges as soon as the driver hits
    // traffic. Fall back to the planned time when there's no GPS
    // signal yet.
    final referenceAt =
        progress?.etaToNextStop?.toLocal() ?? atLocal;
    final minutesAway =
        referenceAt.difference(DateTime.now()).inMinutes;
    return Container(
      padding: const EdgeInsets.all(Tokens.space12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant_menu, color: scheme.primary, size: 22),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.tripDashboardNextStopLabel(_slotLabel(l)),
                  style: t.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${stop.restaurantName ?? '—'} · '
                  '${DateFormat.Hm().format(referenceAt)}'
                  '${minutesAway > 0 ? " · ${l.tripDashboardInMinutes(minutesAway)}" : ""}',
                  style: t.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
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

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space12, vertical: Tokens.space8,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
          const SizedBox(width: Tokens.space8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
