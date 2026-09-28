import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/car_bridge.dart';
import '../services/crash_detector.dart';
import '../services/notifications.dart';
import '../services/trip_foreground.dart';
import '../services/trip_progress.dart';
import '../services/trip_share_image.dart';
import '../widgets/crash_sos_modal.dart';

/// Active driving screen for the Companion mode. Once the driver
/// taps "Iniciar acompañante" on `CompanionScreen`, this screen
/// takes over: it starts GPS tracking, pings
/// `/v1/companion/tick` every 60 s with the current state, and
/// renders any returned recommendations as cards (with TTS for
/// high/critical ones).
///
/// Critical recommendations render as a modal overlay that blocks
/// the rest of the UI until the driver explicitly dismisses.
class CompanionDriveScreen extends ConsumerStatefulWidget {
  const CompanionDriveScreen({
    super.key,
    required this.breakIntervalHours,
    required this.suggestBreak,
    required this.fatigueStopSuggestion,
    required this.alertCriticalAdverse,
    required this.alertWeather,
    required this.alertFuel,
    required this.alertBorder,
    required this.alertToll,
    required this.alertHotel,
    required this.hasKids,
    required this.hasPets,
    required this.bedtimeHour,
    this.activeTrip,
    this.tripOrigin,
    this.tripDestination,
  });

  final double breakIntervalHours;
  final bool suggestBreak;
  final bool fatigueStopSuggestion;
  final bool alertCriticalAdverse;
  final bool alertWeather;
  final bool alertFuel;
  final bool alertBorder;
  final bool alertToll;
  final bool alertHotel;
  final bool hasKids;
  final bool hasPets;
  final int bedtimeHour;

  /// Optional trip context. When set, the screen unlocks the
  /// navigation-style hero: ETA, km remaining, next stop, %
  /// completed. Without it, Companion runs as a stand-alone
  /// assistant (speed + drive-time + recommendations only).
  final TripPlanResponse? activeTrip;
  final GeocodeResult? tripOrigin;
  final GeocodeResult? tripDestination;

  @override
  ConsumerState<CompanionDriveScreen> createState() =>
      _CompanionDriveScreenState();
}

class _CompanionDriveScreenState
    extends ConsumerState<CompanionDriveScreen> {
  static const _tickInterval = Duration(seconds: 60);
  // Adverse-event re-scan cadence. 15 min balances "fresh enough to
  // catch a new fire cell before the driver reaches it" against
  // provider costs (EFFIS / Open-Meteo). Refresh always runs on
  // Companion start too so the driver isn't blind for the first 15 min.
  static const _adversePollInterval = Duration(minutes: 15);
  // How far along the polyline to look ahead for new events. 200 km
  // is ~2 h of highway driving — long enough to notify with warning,
  // short enough to keep the query cheap.
  static const _adverseLookAheadKm = 200.0;

  StreamSubscription<Position>? _positionSub;
  Timer? _tickTimer;
  Timer? _advTimer;
  Position? _lastPosition;
  DateTime? _sessionStart;
  DateTime? _lastStopAt;
  double _drivingHours = 0.0;

  /// Stable identifiers of adverse events we've already surfaced as
  /// a local notification. Prevents the 15-min poll from re-alerting
  /// the driver about the same fire on every tick. Key format is
  /// `${type}:${lat.toFixed(3)}:${lon.toFixed(3)}` — coordinate-based
  /// so FIRMS' rotating pixel ids don't cause duplicate notifications
  /// for the same fire.
  final Set<String> _lastKnownEventIds = <String>{};
  // Rolling cache of ALL live adverse events (pre-trip + refreshed).
  // Pushed to CarBridge on every refresh so the AA alerts tray
  // reflects the current state.
  final List<AdverseEvent> _activeAdverseEvents = [];

  final List<CompanionRecommendation> _recs = [];
  final Set<String> _dismissed = {};
  CompanionRecommendation? _blockingRec;

  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  final CrashDetector _crashDetector = CrashDetector();
  StreamSubscription<CrashEvent>? _crashSub;

  // Trip context (when Companion was launched from a real plan).
  // Precomputed once so every position fix reuses it without
  // re-summing haversines along the polyline.
  RouteReference? _routeRef;
  final SpeedTracker _speedTracker = SpeedTracker();
  TripProgress? _tripProgress;
  DateTime? _plannedArrival;
  bool get _hasActiveTrip => widget.activeTrip != null;

  // Flag flipped to true just before we programmatically pop the
  // route. Without it, PopScope(canPop:false) re-blocks the pop
  // triggered from `onPopInvokedWithResult` after the user
  // confirms "end session", trapping them on the screen.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    // Signal companion active so AppShell can show a taskbar badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companionActiveProvider.notifier).state = true;
    });
    _initTts();
    _initTracking();
    // Precompute the route reference + planned arrival once when
    // Companion is anchored to a real plan. Skip when no active
    // trip — assistant-only mode still runs speed + rec tick.
    final trip = widget.activeTrip;
    if (trip != null && widget.tripOrigin != null &&
        widget.tripDestination != null) {
      final geom = trip.route.geometry;
      _routeRef = RouteReference.build(
        geom.isNotEmpty
            ? geom
            : [
                widget.tripOrigin!.coordinate,
                widget.tripDestination!.coordinate,
              ],
      );
      _plannedArrival = DateTime.now().add(Duration(
        minutes: trip.route.freeFlowMinutes.round(),
      ));
      // Seed the "already-seen" set with the plan-time events so the
      // first refresh doesn't fire duplicate notifications for the
      // hazards the driver already saw on the result screen.
      for (final e in trip.adverseEvents) {
        _lastKnownEventIds.add(_eventFingerprint(e));
        _activeAdverseEvents.add(e);
      }
      // Kick off the live re-scan loop. Fire one refresh IMMEDIATELY
      // so recent events show up right after starting Companion,
      // then poll every 15 min.
      _advTimer = Timer.periodic(
        _adversePollInterval, (_) {
          unawaited(_pollAdverse());
          // Weather-hazards check runs on the same cadence so a
          // squall line, sudden fog bank or wind gust the plan-time
          // Open-Meteo snapshot missed still surfaces mid-drive.
          // Reuses `_advTimer` — cheaper than a second Timer and
          // keeps polling aligned with the adverse-refresh window.
          unawaited(_pollWeatherHazards());
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_pollAdverse());
        unawaited(_pollWeatherHazards());
      });
    }
  }

  /// Coordinate-based fingerprint so the same fire reported under
  /// rotating FIRMS pixel ids (or the same open-meteo cell across
  /// polls) doesn't spam the driver with a fresh notification each
  /// tick.
  String _eventFingerprint(AdverseEvent e) =>
      '${e.type.name}:${e.coordinate.lat.toStringAsFixed(3)}:'
      '${e.coordinate.lon.toStringAsFixed(3)}';

  /// Snap `me` onto the precomputed route and return km-from-origin.
  /// Returns 0 when no route reference is set (assistant-only mode).
  double _kmAtPosition(LatLon me) {
    final ref = _routeRef;
    if (ref == null) return 0.0;
    final snapped = snapToRoute(me, ref);
    return snapped.progressMeters / 1000.0;
  }

  /// Live re-scan of adverse events. Called on session start and
  /// every 15 min while Companion is running against a real plan.
  /// Silently no-ops when no position is available yet — the next
  /// tick will retry with a fresh fix.
  Future<void> _pollAdverse() async {
    if (!mounted) return;
    final trip = widget.activeTrip;
    final route = _routeRef;
    final pos = _lastPosition;
    if (trip == null || route == null || pos == null) return;
    final me = LatLon(lat: pos.latitude, lon: pos.longitude);
    final km = _kmAtPosition(me);
    final api = ref.read(apiClientWithPremiumProvider);
    final events = await api.refreshAdverseEvents(
      geometry: trip.route.geometry,
      currentKm: km,
      lookAheadKm: _adverseLookAheadKm,
      countries: trip.route.countriesCrossed,
    );
    if (!mounted) return;
    // Diff against what we've already surfaced. Fingerprint on
    // (type, lat, lon) so rotating provider ids don't re-alert.
    final freshEvents = <AdverseEvent>[];
    for (final e in events) {
      final fp = _eventFingerprint(e);
      if (_lastKnownEventIds.add(fp)) {
        freshEvents.add(e);
      }
    }
    // Notify for each brand-new event. Severity maps to notification
    // priority via `NotificationService.showTripAlert`'s built-in
    // channel (already high-importance).
    for (final e in freshEvents) {
      final title = _adverseNotificationTitle(e);
      final body = e.description.isNotEmpty
          ? e.description
          : e.type.name;
      unawaited(
        NotificationService.instance.showTripAlert(
          stableId: 'adverse:${_eventFingerprint(e)}',
          title: title,
          body: body,
        ),
      );
    }
    // Merge into the live cache and push the snapshot to Android
    // Auto. Fingerprint-based dedup keeps the list clean.
    final seen = <String>{};
    final merged = <AdverseEvent>[];
    for (final e in [..._activeAdverseEvents, ...events]) {
      if (seen.add(_eventFingerprint(e))) merged.add(e);
    }
    _activeAdverseEvents
      ..clear()
      ..addAll(merged);
    unawaited(CarBridge.instance.updateAlertsQueue(merged));
  }

  /// Dedup set for the weather-hazards poll. Fingerprint is
  /// `${type}:${sampleIndex}` so a hazard at the same sample coord
  /// only notifies once per Companion session even if it lingers
  /// across polls. Cleared when Companion ends (state disposed).
  final Set<String> _hazardFingerprints = <String>{};

  /// Latest weather-hazards snapshot rendered by the horizontal
  /// upcoming-weather row. Refreshed every poll so the tiles
  /// reflect the freshest 5-6 hazards ahead. Empty means either
  /// the first poll hasn't landed yet or the backend returned
  /// nothing along the sampled corridor.
  List<WeatherHazard> _upcomingHazards = const [];

  /// Live weather-hazards check. Samples 5 coords along the next
  /// 200 km of the route and hits `/v1/trips/weather-hazards-check`
  /// (Open-Meteo forecast + RainViewer radar cross-check). Fires
  /// a local notification for any brand-new WARNING or CRITICAL
  /// hazard so the driver hears about heavy rain / hail / thunder
  /// / high wind / dense fog / freezing rain / snow that developed
  /// after the plan was computed.
  ///
  /// Silently no-ops in assistant-only mode (no route reference) —
  /// there is no polyline to sample from.
  Future<void> _pollWeatherHazards() async {
    if (!mounted) return;
    final trip = widget.activeTrip;
    final route = _routeRef;
    final pos = _lastPosition;
    if (trip == null || route == null || pos == null) return;
    final me = LatLon(lat: pos.latitude, lon: pos.longitude);
    final currentKm = _kmAtPosition(me);
    // 5 evenly spaced samples over the next 200 km. Fewer coords
    // keep the RainViewer tile fetches under the polite ~1 req/s
    // guideline; 5 is enough to catch a squall line at any point
    // along a 2 h corridor.
    const sampleCount = 5;
    const stepKm = _adverseLookAheadKm / sampleCount;
    final samples = <({double lat, double lon, double? kmAhead})>[];
    for (int i = 1; i <= sampleCount; i++) {
      final targetKm = currentKm + stepKm * i;
      final coord = _coordAtKm(trip.route.geometry, targetKm);
      if (coord == null) break;
      samples.add((
        lat: coord.lat,
        lon: coord.lon,
        kmAhead: stepKm * i,
      ));
    }
    if (samples.isEmpty) return;

    final api = ref.read(apiClientWithPremiumProvider);
    final hazards = await api.weatherHazardsCheck(coords: samples);
    if (!mounted) return;

    // Refresh the upcoming-weather row snapshot on every poll so
    // stale tiles clear out when the driver moves past a hazard.
    // Sorted by distance-ahead so the row reads left-to-right in
    // travel order.
    final sorted = [...hazards]
      ..sort((a, b) {
        final da = a.etaKmAhead ?? double.infinity;
        final db = b.etaKmAhead ?? double.infinity;
        return da.compareTo(db);
      });
    setState(() => _upcomingHazards = sorted);

    if (hazards.isEmpty) return;

    // Notify for brand-new hazards only. Skip INFO severity to
    // avoid noise — the driver only needs to hear about actionable
    // warnings.
    for (int i = 0; i < hazards.length; i++) {
      final h = hazards[i];
      if (h.severity == AdverseEventSeverity.info) continue;
      // Fingerprint by (type, coarse coord) so a lingering storm
      // over the same cell doesn't re-alert every 15 min.
      final fp = '${h.type.code}:'
          '${h.lat.toStringAsFixed(2)}:'
          '${h.lon.toStringAsFixed(2)}';
      if (!_hazardFingerprints.add(fp)) continue;
      final l = AppLocalizations.of(context);
      final typeName = h.type.localized(l);
      final etaSuffix = h.etaKmAhead != null
          ? ' (~${h.etaKmAhead!.toStringAsFixed(0)} km)'
          : '';
      unawaited(
        NotificationService.instance.showTripAlert(
          stableId: 'hazard:$fp',
          title: '$typeName$etaSuffix',
          body: h.description,
        ),
      );
    }
  }

  /// Linear interpolation along the route polyline to a coord at
  /// `targetKm` from origin. Returns null when the target is past
  /// the destination.
  LatLon? _coordAtKm(List<LatLon> geom, double targetKm) {
    if (geom.length < 2 || targetKm <= 0) {
      return geom.isNotEmpty ? geom.first : null;
    }
    double acc = 0.0;
    for (int i = 1; i < geom.length; i++) {
      final segKm = _haversineKm(geom[i - 1], geom[i]);
      if (acc + segKm >= targetKm) {
        final ratio = segKm > 0 ? (targetKm - acc) / segKm : 0.0;
        final a = geom[i - 1];
        final b = geom[i];
        return LatLon(
          lat: a.lat + (b.lat - a.lat) * ratio,
          lon: a.lon + (b.lon - a.lon) * ratio,
        );
      }
      acc += segKm;
    }
    return null;
  }

  double _haversineKm(LatLon a, LatLon b) {
    const r = 6371.0;
    final dLat = (b.lat - a.lat) * math.pi / 180.0;
    final dLon = (b.lon - a.lon) * math.pi / 180.0;
    final la1 = a.lat * math.pi / 180.0;
    final la2 = b.lat * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// User-visible notification title. Severity determines the
  /// wording ("Peligro" for critical, "Aviso" for warning) but the
  /// actual translation is deferred to a future localisation pass —
  /// for now we ship English + the event type name so the string is
  /// self-explanatory.
  String _adverseNotificationTitle(AdverseEvent e) {
    final prefix = e.severity == AdverseEventSeverity.critical
        ? 'Alert'
        : 'Warning';
    return '$prefix: ${e.type.name} ahead';
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      final locale = Localizations.localeOf(context).toLanguageTag();
      await _tts.setLanguage(locale);
      _ttsReady = true;
    } catch (_) {
      // TTS is best-effort; ignore failures.
    }
  }

  Future<void> _initTracking() async {
    // Foreground service so GPS keeps running with screen off.
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    await TripForegroundService.instance.start(
      title: l.companionDriveTitle,
      body: l.companionForegroundBody,
    );

    // Permission ladder — request "while in use"; upgrade to
    // "always" only if the OS asks for it (Android 10+).
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)
              .companionLocationDenied)),
        );
      }
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // metres between updates — battery-friendly
      ),
    ).listen(_onPosition);

    // Crash detector runs in parallel to the rec loop. It has
    // its own accelerometer + position streams; a fired event
    // pops the SOS modal on top of whatever the driver was
    // looking at.
    _crashDetector.start();
    _crashSub = _crashDetector.events.listen(_onCrash);

    // Fire an immediate tick + start the periodic loop so the
    // driver sees the first rec (e.g. adverse events already in
    // the area) within the first 5 s instead of after 60.
    _tickTimer = Timer.periodic(_tickInterval, (_) => _tick());
    unawaited(_tick());
  }

  /// Share the current drive as a story-format image. Reverse-
  /// geocodes the current position for a human-readable city
  /// label; falls back to coords when the network is down.
  Future<void> _shareLive() async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final p = _lastPosition;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.companionLocationDenied)),
      );
      return;
    }
    // Try reverse for a city label; fallback to coords string.
    String cityLabel;
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final r = await api.reverseGeocode(
        lat: p.latitude,
        lon: p.longitude,
        locale: Localizations.localeOf(context).languageCode,
      );
      cityLabel = r?.displayName.split(',').last.trim()
          ?? '${p.latitude.toStringAsFixed(3)}, '
              '${p.longitude.toStringAsFixed(3)}';
    } catch (_) {
      cityLabel = '${p.latitude.toStringAsFixed(3)}, '
          '${p.longitude.toStringAsFixed(3)}';
    }
    if (!mounted) return;
    // Approx km covered — we don't track a real trail so use
    // driving time × 90 km/h motorway average as a floor. Users
    // can tell it's a rough figure; the share card leaves it
    // out entirely if we can't estimate.
    final approxKm = _drivingHours > 0 ? _drivingHours * 90.0 : null;
    await shareCompanionCard(
      context,
      currentCity: cityLabel,
      drivingHours: _drivingHours > 0 ? _drivingHours : null,
      kmSoFar: approxKm,
    );
  }

  Future<void> _onCrash(CrashEvent event) async {
    if (!mounted) return;
    // Read contacts fresh (user may have added one right before
    // starting the drive).
    final contacts = ref.read(appPrefsProvider).emergencyContacts;
    await CrashSosModal.show(
      context,
      event: event,
      contacts: contacts,
    );
  }

  void _onPosition(Position p) {
    // Advance driving time counter when moving > 5 km/h. A stop
    // longer than 5 min resets `_lastStopAt` and effectively
    // subtracts idle time from the running total, matching what
    // the backend expects in `driving_time_hours`.
    final now = DateTime.now();
    final prev = _lastPosition;
    _lastPosition = p;
    if (prev == null) return;
    final speedKmh = (p.speed) * 3.6;
    if (speedKmh > 5.0) {
      final dt = now.difference(_lastStopAt ?? prev.timestamp);
      _drivingHours += dt.inSeconds / 3600.0;
      _lastStopAt = null;
    } else {
      // Stopped or below 5 km/h → mark last stop for the next
      // moving sample to know how much idle time to skip.
      _lastStopAt ??= now;
      final idle = now.difference(_lastStopAt!);
      if (idle > const Duration(minutes: 5)) {
        // Long stop resets the "since last real break" counter.
        _drivingHours = 0.0;
        _lastStopAt = now;
      }
    }
    // Update trip progress when Companion is anchored to a plan.
    // Same helper the (now-legacy) TripDashboardScreen used, so
    // ETA + km-remaining calculations stay identical.
    final route = _routeRef;
    if (route != null && widget.activeTrip != null) {
      final fixLL = LatLon(lat: p.latitude, lon: p.longitude);
      _speedTracker.addFix(fixLL, now, speedKmh: speedKmh);
      final next = _nextStop();
      final progress = computeProgress(
        route: route,
        fix: fixLL,
        now: now,
        speedTracker: _speedTracker,
        plannedTotalMinutes: widget.activeTrip!.route.freeFlowMinutes,
        nextStopAt: next?.at,
        nextStopKm: next?.distanceFromOriginKm,
        fuelPrices: widget.activeTrip!.fuelPrices,
      );
      setState(() => _tripProgress = progress);
      // Push snapshot to the Android Auto bridge — the head unit
      // re-invalidates its own templates every ~5 s and reads from
      // SharedPreferences, so fire-and-forget is fine. Skip on
      // assistant-only sessions where there's no plan to render.
      unawaited(CarBridge.instance.updateTrip(
        progress: progress,
        me: fixLL,
        destination: widget.tripDestination?.coordinate,
        nextStop: next,
        fuelStations: widget.activeTrip!.fuelPrices,
        restaurants: widget.activeTrip!.restaurants,
      ));
    }
  }

  /// Nearest not-yet-reached meal stop for the ETA/next-stop card.
  /// Returns null when the plan has no meal stops or all are behind
  /// the current position.
  MealStopOpt? _nextStop() {
    final stops = widget.activeTrip?.optimizations?.mealStops ?? const [];
    if (stops.isEmpty) return null;
    final progressKm = _tripProgress?.progressKm ?? 0.0;
    for (final s in stops) {
      if (s.distanceFromOriginKm > progressKm) return s;
    }
    return null;
  }

  Future<void> _tick() async {
    final p = _lastPosition;
    if (p == null) return;
    final api = ref.read(apiClientWithPremiumProvider);
    final recs = await api.companionTick(
      CompanionTickRequest(
        lat: p.latitude,
        lon: p.longitude,
        speedKmh: p.speed * 3.6,
        headingDeg: p.heading,
        drivingTimeHours: _drivingHours,
        breakIntervalHours: widget.breakIntervalHours,
        suggestBreak: widget.suggestBreak,
        fatigueStopSuggestion: widget.fatigueStopSuggestion,
        alertCriticalAdverse: widget.alertCriticalAdverse,
        alertWeather: widget.alertWeather,
        alertFuel: widget.alertFuel,
        alertBorder: widget.alertBorder,
        alertToll: widget.alertToll,
        alertHotel: widget.alertHotel,
        hasKids: widget.hasKids,
        hasPets: widget.hasPets,
        bedtimeHour: widget.bedtimeHour,
        dismissedKinds: _dismissed.toList(),
      ),
    );
    if (!mounted) return;

    // Dedup: skip recs already in the list (same kind + title).
    final fresh = recs.where((r) => !_recs.any(
          (existing) =>
              existing.kind == r.kind && existing.title == r.title,
        )).toList();
    if (fresh.isEmpty) return;

    // Speak the highest-priority fresh rec.
    final speakable = fresh.firstWhere(
      (r) => r.isCritical || r.priority == 'high',
      orElse: () => fresh.first,
    );
    if (_ttsReady && (speakable.isCritical || speakable.priority == 'high')) {
      unawaited(_tts.speak(speakable.speech ?? speakable.title));
    }

    setState(() {
      _recs.insertAll(0, fresh);
      // First critical becomes blocking. If one is already
      // blocking, keep it — the new one will surface once the
      // current is dismissed.
      _blockingRec ??=
          fresh.firstWhere((r) => r.isCritical, orElse: () => _blockingRec!);
    });
  }

  void _dismissRec(CompanionRecommendation rec) {
    setState(() {
      _recs.remove(rec);
      _dismissed.add(rec.kind);
      if (identical(_blockingRec, rec)) {
        // Promote the next critical, if any, else clear.
        _blockingRec = _recs.firstWhere(
          (r) => r.isCritical,
          orElse: () => _empty,
        );
        if (identical(_blockingRec, _empty)) _blockingRec = null;
      }
    });
  }

  static final CompanionRecommendation _empty =
      const CompanionRecommendation(
    kind: '_empty',
    priority: 'low',
    title: '',
    body: '',
  );

  Future<void> _handleAction(
    CompanionRecommendation rec,
    CompanionAction action,
  ) async {
    switch (action.kind) {
      case 'dismiss':
        _dismissRec(rec);
      case 'later':
        // Push it back to the bottom, mark dismissed for 15 min
        // (simplified: just remove; server re-emits after cooldown).
        _dismissRec(rec);
      case 'open_maps':
        final lat = action.payload['lat'];
        final lon = action.payload['lon'];
        if (lat != null && lon != null) {
          final uri = Uri.parse('geo:$lat,$lon?q=$lat,$lon');
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            // Ignore.
          }
        }
      case 'call':
        // Reserved for future emergency-call action.
        break;
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _advTimer?.cancel();
    _positionSub?.cancel();
    _crashSub?.cancel();
    unawaited(_crashDetector.dispose());
    unawaited(_tts.stop());
    unawaited(TripForegroundService.instance.stop());
    // Clear the Android Auto bridge so the head unit reverts to
    // the idle "no active trip" template when the driver ends
    // the session. Only meaningful when the session HAD a plan
    // attached; assistant-only sessions never touched the bridge.
    if (_hasActiveTrip) {
      unawaited(CarBridge.instance.clearTrip());
    }
    // Companion session ended — clear badge in AppShell.
    ref.read(companionActiveProvider.notifier).state = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final p = _lastPosition;
    final speedKmh = p != null ? (p.speed * 3.6).clamp(0.0, 300.0) : 0.0;
    final hours = _drivingHours.floor();
    final minutes = ((_drivingHours - hours) * 60).round();

    return PopScope(
      // Confirm before leaving the drive session. `canPop`
      // flips to true when the user confirms — otherwise the
      // programmatic pop below would be re-blocked and the
      // callback would loop.
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          useRootNavigator: false,
          builder: (dialogCtx) => AlertDialog(
            title: Text(l.companionEndTitle),
            content: Text(l.companionEndBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(l.companionEndKeep),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(l.companionEndConfirm),
              ),
            ],
          ),
        );
        if (leave == true && mounted) {
          setState(() => _leaving = true);
          // Give the frame a tick to pick up `canPop: true`
          // before we pop, then leave the route.
          await Future<void>.delayed(Duration.zero);
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.companionDriveTitle),
          actions: [
            IconButton(
              tooltip: l.shareCardOption,
              icon: const Icon(Icons.ios_share),
              onPressed: _shareLive,
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(Tokens.space20),
              children: [
                // Live mini-map at the top — only when Companion is
                // anchored to a real plan (assistant-only sessions
                // have no route to render). Shows remaining polyline,
                // pulsing current-position dot, and next-stop pin.
                if (_hasActiveTrip &&
                    widget.activeTrip!.route.geometry.isNotEmpty) ...[
                  _CompanionLiveMap(
                    route: widget.activeTrip!.route.geometry,
                    currentPosition: p != null
                        ? LatLon(lat: p.latitude, lon: p.longitude)
                        : null,
                    nextStop: _nextStop()?.coordinate ??
                        widget.tripDestination?.coordinate,
                    nextStopName: _nextStop()?.restaurantName ??
                        widget.tripDestination?.displayName,
                  ),
                  const SizedBox(height: Tokens.space12),
                ],
                // Speed + driving time hero
                _HeroTile(
                  speedKmh: speedKmh.toDouble(),
                  drivingHours: hours,
                  drivingMinutes: minutes,
                ),
                // Horizontal row of upcoming weather along the
                // next stretch of route. Rendered only when
                // Companion is anchored to a plan — the sample
                // corridor is meaningless in assistant-only mode.
                if (_hasActiveTrip) ...[
                  const SizedBox(height: Tokens.space12),
                  _UpcomingWeatherRow(
                    hazards: _upcomingHazards,
                    currentPosition: p != null
                        ? LatLon(lat: p.latitude, lon: p.longitude)
                        : null,
                  ),
                ],
                // Trip progress card — only when Companion runs
                // against a real plan (ETA, km remaining, next
                // stop, % complete). Assistant-only sessions
                // (no active trip) don't have this data so the
                // block is skipped, keeping the screen minimal.
                if (_hasActiveTrip && _tripProgress != null) ...[
                  const SizedBox(height: Tokens.space12),
                  _TripProgressCard(
                    progress: _tripProgress!,
                    nextStop: _nextStop(),
                    destinationName: widget.tripDestination?.displayName,
                  ),
                ],
                const SizedBox(height: Tokens.space24),
                if (_recs.where((r) => !r.isCritical).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: Tokens.space32),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: scheme.onSurfaceVariant),
                        const SizedBox(height: Tokens.space12),
                        Text(l.companionAllGood, style: t.bodyMedium),
                      ],
                    ),
                  ),
                for (final rec
                    in _recs.where((r) => !r.isCritical))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space12),
                    child: _RecCard(
                      rec: rec,
                      onAction: (a) => _handleAction(rec, a),
                    ),
                  ),
              ],
            ),
            if (_blockingRec != null)
              _CriticalOverlay(
                rec: _blockingRec!,
                onAction: (a) => _handleAction(_blockingRec!, a),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
    required this.speedKmh,
    required this.drivingHours,
    required this.drivingMinutes,
  });

  final double speedKmh;
  final int drivingHours;
  final int drivingMinutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.space20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      // Wrap allows the drive-time chip to fall below the gauge on
      // narrow devices instead of overflowing the Row.
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Tokens.space16,
        runSpacing: Tokens.space16,
        children: [
          // Analog speedometer replaces the previous plain-text
          // speed value. `limitKph` is null today (no road-limit
          // source wired yet); painter falls back to a neutral
          // single-tone arc when that's the case.
          _Speedometer(speedKph: speedKmh),
          Column(
            children: [
              Text(
                '${drivingHours}h ${drivingMinutes}m',
                style: t.displaySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                AppLocalizations.of(context).companionDriving,
                style: t.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Big circular analog speedometer for the Companion HUD. Renders
/// a 200 dp gauge with a 270° arc sweeping from bottom-left through
/// top to bottom-right, tick marks every 20 km/h, and a triangular
/// needle whose rotation is tween-animated between GPS samples.
///
/// When `limitKph` is provided, the arc is split into green
/// (0 → limit), amber (limit → limit+15) and red (> limit+15)
/// zones. When null (current state — road-limit ingest isn't wired
/// yet) the arc paints as a single neutral tone.
class _Speedometer extends StatelessWidget {
  const _Speedometer({required this.speedKph, this.limitKph});

  final double speedKph;
  final double? limitKph;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Max scale: limit+40 when known, otherwise 140 (typical EU
    // motorway ceiling of 130 plus a small headroom). Rounded to
    // the next multiple of 20 so tick labels land cleanly.
    final rawMax = (limitKph ?? 100) + 40;
    final maxKph = (rawMax / 20).ceil() * 20.0;
    final clampedSpeed = speedKph.clamp(0.0, maxKph);
    return SizedBox(
      width: 200,
      height: 200,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: clampedSpeed, end: clampedSpeed),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, animatedNeedle, child) {
          return CustomPaint(
            painter: _SpeedometerPainter(
              needleValue: animatedNeedle,
              limitKph: limitKph,
              maxKph: maxKph,
              arcColor: scheme.primary,
              trackColor: scheme.surfaceContainerHighest,
              tickColor: scheme.onPrimaryContainer.withOpacity(0.75),
              labelColor: scheme.onPrimaryContainer.withOpacity(0.85),
              needleColor: scheme.primary,
              hubColor: scheme.onPrimaryContainer,
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speedKph.toStringAsFixed(0),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'km/h',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onPrimaryContainer.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  _SpeedometerPainter({
    required this.needleValue,
    required this.limitKph,
    required this.maxKph,
    required this.arcColor,
    required this.trackColor,
    required this.tickColor,
    required this.labelColor,
    required this.needleColor,
    required this.hubColor,
  });

  final double needleValue;
  final double? limitKph;
  final double maxKph;
  final Color arcColor;
  final Color trackColor;
  final Color tickColor;
  final Color labelColor;
  final Color needleColor;
  final Color hubColor;

  // Canvas 0 rad points to 3 o'clock and rotates clockwise. Start
  // at 135° (bottom-left) and sweep 270° so the gauge ends at 45°
  // (bottom-right), leaving the bottom quadrant open.
  static final double _startAngle = 135.0 * math.pi / 180.0;
  static final double _sweepAngle = 270.0 * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeWidth = 10.0;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Background track (full arc).
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, trackPaint);

    // Colored arc — zoned when limit is known, single-tone otherwise.
    if (limitKph != null) {
      final l = limitKph!;
      final greenEnd = (l / maxKph).clamp(0.0, 1.0);
      final amberEnd = ((l + 15.0) / maxKph).clamp(0.0, 1.0);
      _paintSegment(canvas, arcRect, 0.0, greenEnd,
          const Color(0xFF34A853), strokeWidth);
      _paintSegment(canvas, arcRect, greenEnd, amberEnd,
          const Color(0xFFF9AB00), strokeWidth);
      _paintSegment(canvas, arcRect, amberEnd, 1.0,
          const Color(0xFFEA4335), strokeWidth);
    } else {
      _paintSegment(canvas, arcRect, 0.0, 1.0, arcColor, strokeWidth);
    }

    // Tick marks + numeric labels every 20 km/h.
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final steps = (maxKph / 20).round();
    for (int i = 0; i <= steps; i++) {
      final v = i * 20.0;
      final t = (v / maxKph).clamp(0.0, 1.0);
      final angle = _startAngle + t * _sweepAngle;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final outer = Offset(
          center.dx + radius * cos, center.dy + radius * sin);
      final inner = Offset(
        center.dx + (radius - 10) * cos,
        center.dy + (radius - 10) * sin,
      );
      canvas.drawLine(inner, outer, tickPaint);

      final labelR = radius - 22;
      final labelCenter = Offset(
        center.dx + labelR * cos,
        center.dy + labelR * sin,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(0),
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        labelCenter - Offset(tp.width / 2, tp.height / 2),
      );
    }

    // Needle — triangular pointer rotated via matrix so we can
    // draw it in local coordinates and let the canvas handle the
    // rotation math cleanly.
    final needleT =
        (needleValue.clamp(0.0, maxKph) / maxKph).clamp(0.0, 1.0);
    final needleAngle = _startAngle + needleT * _sweepAngle;
    final needleLen = radius - 14;
    const halfBase = 7.0;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Canvas rotation angle: needle tip should point along
    // `needleAngle`. Triangle is drawn pointing "up" (-y) before
    // rotation, so add π/2 to align.
    canvas.rotate(needleAngle + math.pi / 2);
    final needlePath = Path()
      ..moveTo(0, -needleLen)
      ..lineTo(-halfBase, 6)
      ..lineTo(halfBase, 6)
      ..close();
    canvas.drawPath(needlePath, Paint()..color = needleColor);
    canvas.restore();

    // Center hub.
    canvas.drawCircle(center, 7, Paint()..color = hubColor);
    canvas.drawCircle(
        center, 3, Paint()..color = needleColor);
  }

  void _paintSegment(
    Canvas canvas,
    Rect rect,
    double t0,
    double t1,
    Color color,
    double strokeWidth,
  ) {
    if (t1 <= t0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = color;
    canvas.drawArc(
      rect,
      _startAngle + t0 * _sweepAngle,
      (t1 - t0) * _sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter old) {
    return old.needleValue != needleValue ||
        old.limitKph != limitKph ||
        old.maxKph != maxKph ||
        old.arcColor != arcColor ||
        old.trackColor != trackColor ||
        old.tickColor != tickColor ||
        old.labelColor != labelColor ||
        old.needleColor != needleColor ||
        old.hubColor != hubColor;
  }
}

/// Trip-aware progress hero. Renders only when Companion is
/// launched with an active plan attached: destination name, ETA
/// (wall-clock), km remaining, next stop label + km-to-go, and a
/// linear progress bar.
class _TripProgressCard extends StatelessWidget {
  const _TripProgressCard({
    required this.progress,
    required this.nextStop,
    required this.destinationName,
  });
  final TripProgress progress;
  final MealStopOpt? nextStop;
  final String? destinationName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final total = progress.totalKm <= 0 ? 1.0 : progress.totalKm;
    final percent =
        (progress.progressKm / total).clamp(0.0, 1.0);
    final etaText =
        '${progress.etaToDestination.hour.toString().padLeft(2, "0")}:'
        '${progress.etaToDestination.minute.toString().padLeft(2, "0")}';
    // Only render the ring once we have real progress; before the
    // first snapped fix `progressKm == 0` and a full-track empty
    // circle just looks like a broken skeleton, so we fall back to
    // the compact "flag + ETA" row.
    final showRing = progress.progressKm > 0.0;
    return Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: scheme.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  destinationName ?? '',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!showRing)
                Text(
                  etaText,
                  style: t.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (showRing) ...[
            const SizedBox(height: Tokens.space12),
            Center(
              child: _ProgressRingHero(
                progress: percent,
                etaText: etaText,
                progressKm: progress.progressKm,
                remainingKm: progress.remainingKm,
              ),
            ),
          ] else ...[
            const SizedBox(height: Tokens.space8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
            const SizedBox(height: Tokens.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.progressKm.toStringAsFixed(0)} / '
                  '${progress.totalKm.toStringAsFixed(0)} km',
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  '${progress.remainingKm.toStringAsFixed(0)} km left',
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
          if (nextStop != null) ...[
            const SizedBox(height: Tokens.space8),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: Tokens.space8),
            Row(
              children: [
                Icon(Icons.restaurant_outlined, size: 16,
                    color: scheme.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Next stop · km '
                    '${nextStop!.distanceFromOriginKm.toStringAsFixed(0)}'
                    '${nextStop!.restaurantName != null ? "  ·  ${nextStop!.restaurantName}" : ""}',
                    style: t.bodySmall,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
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

/// Circular progress ring wrapping the ETA hero — visualises `%`
/// of the trip completed so a glance at the dashboard tells the
/// driver both when they'll arrive AND how far along they are.
/// Rendered only when we actually have live progress
/// (`progressKm > 0`); before the first snapped GPS fix the parent
/// falls back to the linear bar layout.
class _ProgressRingHero extends StatefulWidget {
  const _ProgressRingHero({
    required this.progress,
    required this.etaText,
    required this.progressKm,
    required this.remainingKm,
  });

  /// Normalised 0..1 fraction of the polyline covered.
  final double progress;
  /// Wall-clock ETA (`"18:29"` etc.) rendered dead-center.
  final String etaText;
  final double progressKm;
  final double remainingKm;

  @override
  State<_ProgressRingHero> createState() => _ProgressRingHeroState();
}

class _ProgressRingHeroState extends State<_ProgressRingHero> {
  // Previous target we animated toward. `TweenAnimationBuilder`
  // picks up the delta on rebuild and glides — no jitter on every
  // GPS tick.
  double _lastProgress = 0.0;
  // Milestone bucket last displayed (0 pre-25 %, 1 at 25, 2 at 50,
  // 3 at 75). When it changes we replay the flourish by rotating
  // the `Animate` key.
  int _lastMilestone = 0;
  int _flourishSeed = 0;

  static const double _ringDiameter = 148.0;
  static const double _ringStroke = 9.0;

  int _milestoneBucketFor(double p) {
    if (p >= 0.75) return 3;
    if (p >= 0.50) return 2;
    if (p >= 0.25) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _lastProgress = widget.progress;
    _lastMilestone = _milestoneBucketFor(widget.progress);
  }

  @override
  void didUpdateWidget(covariant _ProgressRingHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newMilestone = _milestoneBucketFor(widget.progress);
    if (newMilestone > _lastMilestone) {
      _lastMilestone = newMilestone;
      _flourishSeed++;
    } else {
      _lastMilestone = newMilestone;
    }
    _lastProgress = oldWidget.progress;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final trackColor = scheme.primaryContainer.withValues(alpha: 0.30);
    final fillColor = scheme.primary.withValues(alpha: 0.90);
    final ring = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _lastProgress, end: widget.progress),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return SizedBox(
          width: _ringDiameter,
          height: _ringDiameter,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: value,
              trackColor: trackColor,
              fillColor: fillColor,
              stroke: _ringStroke,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.etaText,
                    style: t.displaySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      fontFeatures:
                          const [FontFeature.tabularFigures()],
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(value * 100).round()}%',
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures:
                          const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    // `key` changes every time we cross a 25/50/75 % milestone, so
    // flutter_animate replays the scale-up + fade flourish. Without
    // the key the animation would only fire on first build.
    final flourishing = Animate(
      key: ValueKey<int>(_flourishSeed),
      effects: [
        ScaleEffect(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1.0, 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
        ),
        FadeEffect(
          begin: 0.85,
          end: 1.0,
          duration: const Duration(milliseconds: 200),
        ),
      ],
      child: ring,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        flourishing,
        const SizedBox(height: Tokens.space12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RingCaption(
              value: '${widget.progressKm.toStringAsFixed(0)} km',
              label: 'recorridos',
              color: scheme.primary,
            ),
            const SizedBox(width: Tokens.space20),
            Container(
              width: 1,
              height: 24,
              color: scheme.outlineVariant,
            ),
            const SizedBox(width: Tokens.space20),
            _RingCaption(
              value: '${widget.remainingKm.toStringAsFixed(0)} km',
              label: 'restantes',
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }
}

class _RingCaption extends StatelessWidget {
  const _RingCaption({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          value,
          style: t.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: t.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Paints the ring: a full-circle track and a filled arc that
/// starts at 12 o'clock and sweeps clockwise proportional to
/// `progress` (0..1). Kept private + stateless so `TweenAnimationBuilder`
/// can rebuild it every frame cheaply.
class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.stroke,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = fillColor;
      // -90° puts the arc origin at 12 o'clock; sweep clockwise.
      const startAngle = -math.pi / 2;
      final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(rect, startAngle, sweep, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor ||
      old.stroke != stroke;
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.rec, required this.onAction});

  final CompanionRecommendation rec;
  final ValueChanged<CompanionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = rec.priority == 'high'
        ? scheme.error
        : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rec.title,
              style: t.titleSmall
                  ?.copyWith(color: accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: Tokens.space4),
          Text(rec.body, style: t.bodyMedium),
          if (rec.actions.isNotEmpty) ...[
            const SizedBox(height: Tokens.space12),
            Wrap(
              spacing: Tokens.space8,
              children: [
                for (final a in rec.actions)
                  OutlinedButton(
                    onPressed: () => onAction(a),
                    child: Text(a.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CriticalOverlay extends StatelessWidget {
  const _CriticalOverlay({required this.rec, required this.onAction});

  final CompanionRecommendation rec;
  final ValueChanged<CompanionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space20),
            child: Container(
              padding: const EdgeInsets.all(Tokens.space24),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                border: Border.all(color: scheme.error, width: 2),
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.title,
                    style: t.headlineSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: Tokens.space12),
                  Text(
                    rec.body,
                    style: t.bodyLarge
                        ?.copyWith(color: scheme.onErrorContainer),
                  ),
                  if (rec.distanceKm != null) ...[
                    const SizedBox(height: Tokens.space8),
                    Text(
                      '${rec.distanceKm!.toStringAsFixed(0)} km',
                      style: t.headlineMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: Tokens.space20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final a in rec.actions)
                        Padding(
                          padding: const EdgeInsets.only(
                              left: Tokens.space8),
                          child: FilledButton(
                            onPressed: () => onAction(a),
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                              minimumSize: const Size(120, 48),
                            ),
                            child: Text(a.label),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of weather tiles for the next stretch of the
/// route. Renders whatever `_upcomingHazards` was set to by the
/// latest `_pollWeatherHazards()` call — takes the freshest 5-6
/// entries ordered by distance-ahead. Falls back to a compact
/// "clear ahead" chip when nothing is queued (initial state or
/// backend returned empty).
///
/// Each tile is 90 dp wide with three lines: km-ahead label,
/// weather icon, temperature (skipped — WeatherHazard model has
/// no temperature field; kept in the layout so the row height
/// stays stable when a temperature source lands later).
class _UpcomingWeatherRow extends StatelessWidget {
  const _UpcomingWeatherRow({
    required this.hazards,
    required this.currentPosition,
  });

  final List<WeatherHazard> hazards;
  final LatLon? currentPosition;

  static const double _tileWidth = 90;
  static const double _rowHeight = 72;
  static const int _maxTiles = 6;

  double _distanceAheadKm(WeatherHazard h) {
    if (h.etaKmAhead != null) return h.etaKmAhead!;
    final me = currentPosition;
    if (me == null) return double.nan;
    // Haversine — same formula used elsewhere in this screen for
    // route sampling. Skips the tile when the coord is missing.
    const r = 6371.0;
    final dLat = (h.lat - me.lat) * math.pi / 180.0;
    final dLon = (h.lon - me.lon) * math.pi / 180.0;
    final la1 = me.lat * math.pi / 180.0;
    final la2 = h.lat * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  IconData _iconFor(AdverseEventType type) => switch (type) {
        AdverseEventType.heavyRain => Icons.grain,
        AdverseEventType.freezingRain => Icons.grain,
        AdverseEventType.snow => Icons.ac_unit,
        AdverseEventType.avalanche => Icons.ac_unit,
        AdverseEventType.thunderstorm => Icons.thunderstorm,
        AdverseEventType.hail => Icons.thunderstorm,
        AdverseEventType.highWind => Icons.air,
        AdverseEventType.denseFog => Icons.visibility_off,
        AdverseEventType.weather => Icons.cloud,
        AdverseEventType.heatwave => Icons.wb_sunny,
        _ => Icons.wb_sunny,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Empty state — compact chip so the row doesn't collapse.
    if (hazards.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space12,
          vertical: Tokens.space8,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: Tokens.space8),
            Flexible(
              child: Text(
                l.companionWeatherRowEmpty,
                style: t.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Build tiles. Skip entries with no computable distance or
    // an unmappable type. Keep the freshest 5-6 in travel order.
    final tiles = <_UpcomingWeatherTileData>[];
    for (final h in hazards) {
      final km = _distanceAheadKm(h);
      if (km.isNaN || km.isInfinite || km < 0) continue;
      tiles.add(_UpcomingWeatherTileData(
        distanceKm: km,
        icon: _iconFor(h.type),
        hazard: h,
      ));
    }
    if (tiles.isEmpty) {
      // Everything was skippable — fall through to the empty chip.
      return _UpcomingWeatherRow(
        hazards: const [],
        currentPosition: currentPosition,
      ).build(context);
    }
    tiles.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final visible = tiles.take(_maxTiles).toList();

    return SizedBox(
      height: _rowHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            for (final td in visible)
              Padding(
                padding: const EdgeInsets.only(right: Tokens.space8),
                child: _UpcomingWeatherTile(
                  width: _tileWidth,
                  data: td,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _UpcomingWeatherTileData {
  const _UpcomingWeatherTileData({
    required this.distanceKm,
    required this.icon,
    required this.hazard,
  });
  final double distanceKm;
  final IconData icon;
  final WeatherHazard hazard;
}

class _UpcomingWeatherTile extends StatelessWidget {
  const _UpcomingWeatherTile({
    required this.width,
    required this.data,
  });

  final double width;
  final _UpcomingWeatherTileData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    // Severity-tinted border so critical hazards (thunderstorms,
    // ice) pop compared to informational ones.
    final accent = switch (data.hazard.severity) {
      AdverseEventSeverity.critical => scheme.error,
      AdverseEventSeverity.warning => scheme.tertiary,
      _ => scheme.outlineVariant,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      onTap: () {
        final desc = data.hazard.description.isNotEmpty
            ? data.hazard.description
            : data.hazard.type.localized(AppLocalizations.of(context));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(desc)));
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          border: Border.all(color: accent.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '+${data.distanceKm.toStringAsFixed(0)} km',
              style: t.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Icon(data.icon, size: 22, color: accent),
            // Temperature row reserved — WeatherHazard has no
            // temp field yet, so we render an empty spacer to
            // keep the tile height stable when a temp source
            // lands later.
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Small live mini-map at the top of the Companion drive screen.
/// Renders only when Companion is anchored to a real trip
/// (`activeTrip != null` on the parent). Shows:
///   - the REMAINING slice of the polyline (already-traveled portion
///     is trimmed by snapping the current GPS fix onto the route),
///   - a pulsing blue dot at the current position,
///   - a red pin at the next stop (meal stop when planned, otherwise
///     the trip destination).
/// Camera re-fits to the remaining bounds when the extent changes
/// significantly (>5%); otherwise it just recenters on the driver
/// so the map doesn't jitter zoom-in/zoom-out at every GPS tick.
class _CompanionLiveMap extends StatefulWidget {
  const _CompanionLiveMap({
    required this.route,
    required this.currentPosition,
    this.nextStop,
    this.nextStopName,
  });

  final List<LatLon> route;
  final LatLon? currentPosition;
  final LatLon? nextStop;
  final String? nextStopName;

  @override
  State<_CompanionLiveMap> createState() => _CompanionLiveMapState();
}

class _CompanionLiveMapState extends State<_CompanionLiveMap>
    with SingleTickerProviderStateMixin {
  final fmap.MapController _mapController = fmap.MapController();
  late final AnimationController _pulseController;
  // Cache of the last polyline "extent" (a length proxy: sum of the
  // lat+lon spans of the remaining slice) so we can decide whether
  // the bounds shifted enough to justify a full re-fit vs. a cheap
  // recenter. Threshold is 5% relative delta.
  double? _lastExtent;
  // Precomputed cumulative distances for the input route, used to
  // snap the current GPS fix and slice the remaining polyline. Built
  // once per widget instance and rebuilt only when the input route
  // reference changes.
  RouteReference? _routeRef;
  List<LatLon>? _routeCache;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _routeCache = widget.route;
    _routeRef = widget.route.length >= 2
        ? RouteReference.build(widget.route)
        : null;
  }

  @override
  void didUpdateWidget(covariant _CompanionLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.route, _routeCache)) {
      _routeCache = widget.route;
      _routeRef = widget.route.length >= 2
          ? RouteReference.build(widget.route)
          : null;
      _lastExtent = null; // force a re-fit on next frame
    }
    // Recentre / re-fit whenever the GPS fix advances. Deferred to
    // a post-frame callback because the map's render box has to be
    // laid out before `move`/`fitCamera` can compute pixel positions.
    if (oldWidget.currentPosition != widget.currentPosition) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCamera();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Remaining slice of the route from the current position onward.
  /// Snaps the GPS fix onto the polyline to find its segment index,
  /// then inserts the fix itself as the head of the slice so the
  /// polyline starts exactly where the driver is (not at the nearest
  /// polyline vertex behind them). Falls back to the full route when
  /// there's no fix yet.
  List<LatLon> _remainingSlice() {
    final route = widget.route;
    final me = widget.currentPosition;
    final ref = _routeRef;
    if (route.length < 2) return route;
    if (me == null || ref == null) return route;
    final snapped = snapToRoute(me, ref);
    final startIdx = (snapped.segmentIndex + 1)
        .clamp(0, route.length);
    final tail = route.sublist(startIdx);
    return [me, ...tail];
  }

  double _extentOf(List<LatLon> pts) {
    if (pts.isEmpty) return 0.0;
    var minLat = pts.first.lat, maxLat = pts.first.lat;
    var minLon = pts.first.lon, maxLon = pts.first.lon;
    for (final p in pts) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }
    return (maxLat - minLat) + (maxLon - minLon);
  }

  void _syncCamera() {
    final remaining = _remainingSlice();
    if (remaining.length < 2) {
      // Not enough points to bound — just centre on driver.
      final me = widget.currentPosition;
      if (me != null) {
        _mapController.move(
          ll.LatLng(me.lat, me.lon),
          _mapController.camera.zoom,
        );
      }
      return;
    }
    final extent = _extentOf(remaining);
    final prev = _lastExtent;
    final significantShift = prev == null ||
        prev == 0 ||
        ((extent - prev).abs() / prev) > 0.05;
    if (significantShift) {
      _lastExtent = extent;
      final pts = remaining
          .map((p) => ll.LatLng(p.lat, p.lon))
          .toList(growable: false);
      _mapController.fitCamera(
        fmap.CameraFit.bounds(
          bounds: fmap.LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(28),
        ),
      );
    } else {
      final me = widget.currentPosition;
      if (me != null) {
        _mapController.move(
          ll.LatLng(me.lat, me.lon),
          _mapController.camera.zoom,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingSlice();
    final polylinePts = remaining
        .map((p) => ll.LatLng(p.lat, p.lon))
        .toList(growable: false);
    // Initial camera fit on first paint — subsequent updates go
    // through `_syncCamera` triggered from `didUpdateWidget`.
    final initialFit = polylinePts.length >= 2
        ? fmap.CameraFit.bounds(
            bounds: fmap.LatLngBounds.fromPoints(polylinePts),
            padding: const EdgeInsets.all(28),
          )
        : null;
    final markers = <fmap.Marker>[];
    final me = widget.currentPosition;
    if (me != null) {
      markers.add(
        fmap.Marker(
          point: ll.LatLng(me.lat, me.lon),
          width: 24,
          height: 24,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              // Pulse 8 → 14 px on a smooth sine curve.
              final t = _pulseController.value;
              final size = 8.0 + (14.0 - 8.0) * t;
              return Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    final next = widget.nextStop;
    if (next != null) {
      markers.add(
        fmap.Marker(
          point: ll.LatLng(next.lat, next.lon),
          width: 32,
          height: 32,
          child: Icon(
            Icons.location_on,
            size: 32,
            color: Colors.red.shade700,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: fmap.FlutterMap(
          mapController: _mapController,
          options: fmap.MapOptions(
            initialCameraFit: initialFit,
            initialCenter: initialFit == null && me != null
                ? ll.LatLng(me.lat, me.lon)
                : const ll.LatLng(48.8566, 2.3522),
            initialZoom: 10,
            interactionOptions: const fmap.InteractionOptions(
              flags:
                  fmap.InteractiveFlag.pinchZoom | fmap.InteractiveFlag.drag,
            ),
          ),
          children: [
            fmap.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mytravelpal.travel',
            ),
            if (polylinePts.length >= 2)
              fmap.PolylineLayer(
                polylines: [
                  fmap.Polyline(
                    points: polylinePts,
                    color: Colors.blue.shade700,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
            if (markers.isNotEmpty) fmap.MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
