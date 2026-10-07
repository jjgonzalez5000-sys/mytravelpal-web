import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../api/models.dart'
    show Country, GeocodeResult, LatLon, TripPlanRequest, TripPlanResponse;
import '../screens/passenger_companion_screen.dart';
import '../screens/plan_screen.dart';
import '../screens/result_screen.dart';
import 'maps_url_parser.dart';
import 'trip_sharing.dart';

/// Bootstraps `app_links` and routes any `mytravelpal://trip?...`
/// intents into a `PlanScreen` prefilled from the shared trip.
///
/// Also listens on the `mytravelpal/share` MethodChannel for
/// Android-share-sheet payloads (see `MainActivity.kt`). When a
/// shared text looks like a Google Maps URL we parse it via
/// [parseGoogleMapsUrl] and open PlanScreen the same way as the
/// deep-link path.
///
/// One instance is created in `main()` and kept alive by the app; the
/// stream subscription is torn down when `dispose()` is called on
/// process teardown.
class DeepLinkHandler {
  DeepLinkHandler(
    this._navigatorKey, {
    this.geocodeResolver,
    this.apiClientResolver,
  })  : _appLinks = AppLinks(),
        _shareChannel = const MethodChannel('mytravelpal/share');

  final GlobalKey<NavigatorState> _navigatorKey;
  final AppLinks _appLinks;
  final MethodChannel _shareChannel;
  StreamSubscription<Uri>? _sub;

  /// Lazy accessor for the app's geocode function — resolved on demand
  /// so we don't need Riverpod set up at construction time (this
  /// handler is built in `main()` before `runApp`). Kept nullable to
  /// keep tests trivial; when null we skip the share-sheet path.
  final GeocodeFn Function()? geocodeResolver;

  /// Lazy accessor for the API client — used to import shared trips
  /// via /join/{slug} deep-links. Null in tests.
  final ApiClient Function()? apiClientResolver;

  Future<void> start() async {
    // Cold-start: launched from a link.
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _dispatch(initial);
    // Warm links: while the app is already running.
    _sub = _appLinks.uriLinkStream.listen(_dispatch);

    // Register the share-sheet channel. Kotlin buffers a cold-start
    // share; ask for it now and process it if any.
    _shareChannel.setMethodCallHandler(_onShareChannelCall);
    try {
      final initialShared =
          await _shareChannel.invokeMethod<String>('getInitialSharedText');
      if (initialShared != null && initialShared.isNotEmpty) {
        // Fire-and-forget — no one awaits `start()` for shared-text
        // parsing, and network round-trips shouldn't block launch.
        // ignore: unawaited_futures
        _handleSharedText(initialShared);
      }
    } catch (_) {
      // Channel missing (e.g. hot-reload without a restart) — nothing
      // to grab; warm-share events will still flow once the channel
      // is up.
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _shareChannel.setMethodCallHandler(null);
  }

  Future<dynamic> _onShareChannelCall(MethodCall call) async {
    if (call.method == 'onSharedText') {
      final text = call.arguments as String?;
      if (text != null && text.isNotEmpty) {
        await _handleSharedText(text);
      }
    }
    return null;
  }

  void _dispatch(Uri uri) {
    // Group Companion join: mytravelpal://companion/{join_code}
    if (uri.scheme == 'mytravelpal' &&
        uri.host == 'companion' &&
        uri.pathSegments.isNotEmpty) {
      final code = uri.pathSegments.first.toUpperCase();
      _openPassengerCompanion(code);
      return;
    }
    // Handle shared trip import: https://mytravelpal.io/join/{slug}
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'mytravelpal.io' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'join') {
      final slug = uri.pathSegments[1];
      // ignore: unawaited_futures
      _importAndOpenSharedTrip(slug);
      return;
    }
    final shared = decodeTripLink(uri);
    if (shared == null) return;
    _openPlan(shared);
  }

  void _openPassengerCompanion(String joinCode) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PassengerCompanionScreen(joinCode: joinCode),
      ),
    );
  }

  Future<void> _importAndOpenSharedTrip(String slug) async {
    final resolver = apiClientResolver;
    if (resolver == null) return;
    final api = resolver();
    try {
      final result = await api.importSharedTrip(slug);
      _openSharedResult(result.plan, result.requestJson);
    } catch (_) {
      // If the slug is invalid or network fails, silently ignore —
      // the user lands on the home screen as normal.
    }
  }

  void _openSharedResult(
      TripPlanResponse plan, Map<String, dynamic> requestJson) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    // Extract origin/destination from request JSON — only lat/lon needed
    // to build the GeocodeResult stubs for the ResultScreen header.
    final originLat =
        (requestJson['origin']?['lat'] as num?)?.toDouble() ?? 0.0;
    final originLon =
        (requestJson['origin']?['lon'] as num?)?.toDouble() ?? 0.0;
    final destLat =
        (requestJson['destination']?['lat'] as num?)?.toDouble() ?? 0.0;
    final destLon =
        (requestJson['destination']?['lon'] as num?)?.toDouble() ?? 0.0;
    final departureStr = requestJson['desired_departure_at'] as String?;
    final departure =
        departureStr != null ? DateTime.parse(departureStr) : DateTime.now();

    // Build minimal stub GeocodeResults — coordinates used as display names;
    // the plan route already carries the full geometry so this is cosmetic.
    final originCoord = LatLon(lat: originLat, lon: originLon);
    final destCoord = LatLon(lat: destLat, lon: destLon);
    final originResult = GeocodeResult(
      displayName: '${originLat.toStringAsFixed(4)}, ${originLon.toStringAsFixed(4)}',
      coordinate: originCoord,
      country: Country.es,
    );
    final destResult = GeocodeResult(
      displayName: '${destLat.toStringAsFixed(4)}, ${destLon.toStringAsFixed(4)}',
      coordinate: destCoord,
      country: Country.es,
    );

    // Reconstruct a minimal TripPlanRequest for the ResultScreen. Only the
    // fields that ResultScreen reads directly are populated; the rest default.
    // A full fromJson would need mirroring every optional field — not worth
    // it for a read-only imported view.
    final request = _minimalRequest(requestJson, originCoord, destCoord, departure);

    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          request: request,
          origin: originResult,
          destination: destResult,
          response: plan,
          desiredDepartureAt: departure,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _handleSharedText(String text) async {
    // The share sheet may hand us anything — a plain message, a
    // WhatsApp forward, a random webpage. Quick shape check so we
    // don't kick off a geocode round-trip for arbitrary strings.
    final lower = text.toLowerCase();
    final looksLikeMaps = lower.contains('google.') ||
        lower.contains('goo.gl') ||
        lower.contains('g.co');
    if (!looksLikeMaps) return;

    final resolver = geocodeResolver;
    if (resolver == null) return;

    // Some sharers prefix the URL with a title / newline / label —
    // pull out the first http(s) URL from the payload.
    final url = _extractFirstUrl(text);
    if (url == null) return;

    SharedTrip? trip;
    try {
      trip = await parseGoogleMapsUrl(url, geocode: resolver());
    } catch (_) {
      trip = null;
    }
    if (trip == null) return;
    _openPlan(trip);
  }

  void _openPlan(SharedTrip shared) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => PlanScreen(initialShared: shared),
      ),
      (route) => route.isFirst,
    );
  }

  /// Build a minimal [TripPlanRequest] from the raw JSON returned by the
  /// share endpoint. Only origin/destination/departure are essential for
  /// the imported ResultScreen to display correctly; all other fields
  /// default to their constructor defaults so re-planning works but
  /// with the original preferences missing.
  static TripPlanRequest _minimalRequest(
    Map<String, dynamic> json,
    LatLon origin,
    LatLon destination,
    DateTime departure,
  ) =>
      TripPlanRequest(
        origin: origin,
        destination: destination,
        desiredDepartureAt: departure,
        includeAdverseEvents: json['include_adverse_events'] as bool? ?? false,
        includeTollAlternative:
            json['include_toll_alternative'] as bool? ?? false,
        includeRouteComparison:
            json['include_route_comparison'] as bool? ?? false,
        includeHourlyTollAnalysis:
            json['include_hourly_toll_analysis'] as bool? ?? false,
        avoidMotorways: json['avoid_motorways'] as bool? ?? false,
        preferScenic: json['prefer_scenic'] as bool? ?? false,
        timeWindowSpanHours: json['time_window_span_hours'] as int? ?? 3,
        timeWindowTopN: json['time_window_top_n'] as int? ?? 5,
        hotelMaxDetourMinutes: json['hotel_max_detour_minutes'] as int?,
        restaurantMaxDetourMinutes:
            json['restaurant_max_detour_minutes'] as int?,
        adverseEventsMaxDistanceKm:
            (json['adverse_events_max_distance_km'] as num?)?.toDouble() ??
                50.0,
      );

  static final _urlPattern = RegExp(r'https?://\S+');

  static String? _extractFirstUrl(String text) {
    final match = _urlPattern.firstMatch(text);
    return match?.group(0);
  }
}
