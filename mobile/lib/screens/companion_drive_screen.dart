import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/car_bridge.dart';
import '../services/crash_detector.dart';
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

  StreamSubscription<Position>? _positionSub;
  Timer? _tickTimer;
  Position? _lastPosition;
  DateTime? _sessionStart;
  DateTime? _lastStopAt;
  double _drivingHours = 0.0;

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
    }
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
                // Speed + driving time hero
                _HeroTile(
                  speedKmh: speedKmh.toDouble(),
                  drivingHours: hours,
                  drivingMinutes: minutes,
                ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                speedKmh.toStringAsFixed(0),
                style: t.displayLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('km/h', style: t.bodySmall),
            ],
          ),
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
