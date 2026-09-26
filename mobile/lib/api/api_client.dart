import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/auth_user.dart';
import '../domain/vehicle_model.dart';
import 'config.dart';
import 'models.dart';

@immutable
class AuthSessionResponse {
  const AuthSessionResponse({required this.token, required this.user});
  final String token;
  final AuthUser user;

  factory AuthSessionResponse.fromJson(Map<String, dynamic> json) =>
      AuthSessionResponse(
        token: json['token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiClient {
  ApiClient({ApiConfig config = ApiConfig.fromEnv, http.Client? httpClient})
      : _baseUrl = config.baseUrl,
        _apiKey = (config.apiKey ?? '').isEmpty ? null : config.apiKey,
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final String? _apiKey;
  final http.Client _http;
  bool _premium = false;
  String? _authToken;

  /// Toggle whether outgoing requests should declare Premium status via
  /// the `X-MyTravelPal-Premium` header. Set by
  /// `apiClientWithPremiumProvider` from the current Riverpod state.
  void setPremium(bool value) => _premium = value;

  /// Set the bearer token to attach as `Authorization`. Passing null
  /// clears it. Wired through `apiClientWithPremiumProvider`.
  void setAuthToken(String? token) => _authToken = token;

  Map<String, String> _headers({
    String contentType = 'application/json',
    String? acceptLanguage,
  }) =>
      {
        'Content-Type': contentType,
        if (_apiKey != null) 'X-MyTravelPal-Api-Key': _apiKey,
        if (_premium) 'X-MyTravelPal-Premium': 'true',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        if (acceptLanguage != null) 'Accept-Language': acceptLanguage,
      };

  /// Trim a Flutter locale ("es", "es_ES", "pt-BR") down to a
  /// two-letter ISO 639-1 code the backend recognises. Returns null
  /// when the input is empty or clearly not a language code, so the
  /// backend defaults to English and existing callers stay unchanged.
  static String? _normalizeLocale(String? locale) {
    if (locale == null) return null;
    final trimmed = locale.trim();
    if (trimmed.isEmpty) return null;
    final code = trimmed
        .toLowerCase()
        .replaceAll('_', '-')
        .split('-')
        .first;
    if (code.length != 2 || !RegExp(r'^[a-z]{2}$').hasMatch(code)) {
      return null;
    }
    return code;
  }

  Future<TripPlanResponse> planTrip(TripPlanRequest request) async {
    final uri = Uri.parse('$_baseUrl/v1/trips/plan');
    final body = jsonEncode(request.toJson());
    // /plan fans out to routing, weather, POI providers and gov fuel
    // feeds — worst case ~15 s warm, more on cold-start. The default
    // Dart `http.Client` timeout is aggressive enough to abort those
    // legitimate slow calls as "Software caused connection abort",
    // so we override with a generous cap here.
    //
    // Retry chain: transient 5xx errors (Fly proxy blips, worker
    // restart mid-request) and network aborts should be invisible
    // to the user. We reissue the POST up to 3 total attempts with a
    // short backoff. 4xx responses short-circuit — they're deterministic
    // client-side problems (400 malformed, 401 no key, 402 premium,
    // 429 rate-limit) so retrying wastes the user's time.
    const attempts = 3;
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        final response = await _http
            .post(uri, headers: _headers(), body: body)
            .timeout(const Duration(seconds: 60));
        if (response.statusCode == 200) {
          return TripPlanResponse.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          );
        }
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw ApiException(response.statusCode, response.body);
        }
        // 5xx: transient — remember and retry.
        lastError = ApiException(response.statusCode, response.body);
      } on ApiException {
        // Deterministic 4xx re-raised above — propagate.
        rethrow;
      } catch (e) {
        // Network / timeout / socket abort — retry.
        lastError = e;
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    // Exhausted retries: surface the last thing that went wrong.
    if (lastError is Exception) throw lastError;
    throw Exception(lastError?.toString() ?? 'planTrip failed');
  }

  /// Exchange a provider ID token for an app JWT.
  Future<AuthSessionResponse> createSession({
    required String provider,
    required String idToken,
    String? demoEmail,
    String? demoName,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/auth/session');
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'provider': provider,
        'id_token': idToken,
        if (demoEmail != null) 'demo_email': demoEmail,
        if (demoName != null) 'demo_name': demoName,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return AuthSessionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<NarrativeResponse> tripNarrative({
    required TripPlanRequest planRequest,
    required String originName,
    required String destinationName,
    String? locale,
  }) async {
    // Locale is sent on three redundant channels so the backend can
    // localise the LLM output no matter which one an intermediate
    // proxy might strip: Accept-Language header, ?lang= query param,
    // and a `lang` field in the JSON body. Tester bug: Spanish user
    // was getting English narratives because none of the channels
    // was populated. Pattern mirrors `geocode()` / `reverseGeocode()`.
    final normalizedLocale = _normalizeLocale(locale);
    final uri = Uri.parse('$_baseUrl/v1/trips/narrative').replace(
      queryParameters: {
        if (normalizedLocale != null) 'lang': normalizedLocale,
      },
    );
    final response = await _http.post(
      uri,
      headers: _headers(acceptLanguage: normalizedLocale),
      body: jsonEncode({
        'plan_request': planRequest.toJson(),
        'origin_name': originName,
        'destination_name': destinationName,
        if (normalizedLocale != null) 'lang': normalizedLocale,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return NarrativeResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> submitAdverseEvent({
    required AdverseEventType type,
    required AdverseEventSeverity severity,
    required double lat,
    required double lon,
    required String description,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/adverse-events');
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'type': type.code,
        'severity': severity.code,
        'lat': lat,
        'lon': lon,
        'description': description,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<GeocodeResult>> geocode(
    String query, {
    int limit = 5,
    String? locale,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    // Pass locale as an explicit `lang` query param — most reliable
    // signal for the backend, no dependence on client HTTP defaults
    // sending an `Accept-Language` header. Tester bug: typing
    // "Toledo" from the ES-locale app used to come back as "Tolède"
    // because the backend defaulted to English.
    final normalizedLocale = _normalizeLocale(locale);
    final uri = Uri.parse('$_baseUrl/v1/geocode').replace(queryParameters: {
      'q': trimmed,
      'limit': '$limit',
      if (normalizedLocale != null) 'lang': normalizedLocale,
    });
    final response = await _http.get(
      uri,
      headers: _headers(acceptLanguage: normalizedLocale),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>;
    return results
        .map((r) => GeocodeResult.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Fetch the user's server-side profile (requires auth token).
  Future<Map<String, dynamic>?> fetchProfile() async {
    final uri = Uri.parse('$_baseUrl/v1/profile');
    try {
      final response = await _http.get(uri, headers: _headers());
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['profile'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Save the user's profile to the server (requires auth token).
  Future<bool> saveProfile(Map<String, dynamic> profile) async {
    final uri = Uri.parse('$_baseUrl/v1/profile');
    try {
      final response = await _http.put(
        uri,
        headers: _headers(),
        body: jsonEncode({'profile': profile}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch saved trips from server (cloud backup).
  Future<List<Map<String, dynamic>>> fetchTrips() async {
    final uri = Uri.parse('$_baseUrl/v1/profile/trips');
    try {
      final response = await _http.get(uri, headers: _headers());
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['trips'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// GDPR "delete my account" — hits the same endpoint the profile
  /// DELETE uses, which now cascades to saved trips. Returns true on
  /// 200, false on any HTTP or transport error. The caller signs the
  /// user out afterwards regardless of the result so local state is
  /// wiped even when the server rejects (unauth) or is unreachable.
  Future<bool> deleteAccount() async {
    final uri = Uri.parse('$_baseUrl/v1/profile');
    try {
      // 10s cap — the backend delete cascade normally settles under
      // 500 ms; anything past this and we want to release the UI
      // (loading dialog) rather than hang forever, so local wipe +
      // logout can still land.
      final response = await _http
          .delete(uri, headers: _headers())
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// GDPR portability — pull EVERY row the server holds for this
  /// user as a single JSON blob. Returns null on any failure so the
  /// caller can show a snackbar instead of crashing.
  Future<Map<String, dynamic>?> exportProfile() async {
    final uri = Uri.parse('$_baseUrl/v1/profile/export');
    try {
      final response = await _http.get(uri, headers: _headers());
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Search parking near a coordinate. Used both from the plan
  /// waypoint flow ("necesito parking aquí") and from the
  /// standalone event-parking home entry.
  Future<List<Parking>> searchParking({
    required double lat,
    required double lon,
    double radiusKm = 2.0,
    int limit = 20,
    ParkingFilters filters = const ParkingFilters(),
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/pois/parking').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'radius_km': radiusKm.toString(),
        'limit': limit.toString(),
        ...filters.toQueryParams(),
      },
    );
    final response = await _http.post(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['parkings'] as List<dynamic>? ?? const [])
        .map((p) => Parking.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Ask the Trip Inspiration LLM for a proposed itinerary. Long
  /// timeout — Haiku output at 2k tokens can take 5-15 s.
  /// Throws `ApiException` on 4xx/5xx so the UI can distinguish
  /// "LLM refused / bad output" from "no network".
  /// Turn-by-turn refinement of an existing itinerary. Sends
  /// the previous JSON + conversation history + the new user
  /// message; backend returns an updated itinerary that includes
  /// a short `assistantNote` explaining what changed.
  Future<InspireItinerary> refineTrip({
    required String prompt,
    required InspireItinerary previous,
    List<InspireChatTurn> history = const [],
    String? locale,
  }) async {
    final normalizedLocale = _normalizeLocale(locale);
    final uri = Uri.parse('$_baseUrl/v1/trips/inspire/refine').replace(
      queryParameters: {
        if (normalizedLocale != null) 'lang': normalizedLocale,
      },
    );
    final now = DateTime.now();
    final todayIso =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final body = jsonEncode({
      'prompt': prompt,
      'previous_itinerary': previous.toJson(),
      'history': history.map((m) => m.toJson()).toList(),
      if (normalizedLocale != null) 'locale': normalizedLocale,
      'today_iso': todayIso,
    });
    final response = await _http
        .post(uri, headers: _headers(acceptLanguage: normalizedLocale), body: body)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return InspireItinerary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<InspireItinerary> inspireTrip({
    required String prompt,
    LatLon? origin,
    String? locale,
  }) async {
    final normalizedLocale = _normalizeLocale(locale);
    final uri = Uri.parse('$_baseUrl/v1/trips/inspire').replace(
      queryParameters: {
        if (normalizedLocale != null) 'lang': normalizedLocale,
      },
    );
    // Send the client's LOCAL date as ISO. Prevents the LLM from
    // treating server-UTC date as "today" when the user is
    // planning late at night in a west-of-UTC locale.
    final now = DateTime.now();
    final todayIso =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final body = jsonEncode({
      'prompt': prompt,
      if (origin != null) 'origin': origin.toJson(),
      if (normalizedLocale != null) 'locale': normalizedLocale,
      'today_iso': todayIso,
    });
    final response = await _http
        .post(uri, headers: _headers(acceptLanguage: normalizedLocale), body: body)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return InspireItinerary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Current weather + 7-day forecast for a point. Returns null on
  /// any transport failure — the chip widget just hides then, so
  /// silent-fail is fine.
  Future<WeatherPoint?> weatherPoint({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/weather/point?lat=$lat&lon=$lon',
    );
    try {
      final response = await _http.get(uri, headers: _headers());
      if (response.statusCode != 200) return null;
      return WeatherPoint.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Companion mode tick: send driver state → get recommendations.
  /// Returns an empty list when the engine has nothing to surface
  /// or on any transport error (Companion cards are best-effort —
  /// silence is better than fabricated warnings).
  Future<List<CompanionRecommendation>> companionTick(
    CompanionTickRequest state,
  ) async {
    final uri = Uri.parse('$_baseUrl/v1/companion/tick');
    try {
      final response = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode(state.toJson()),
      );
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (body['recommendations'] as List<dynamic>? ?? const []);
      return list
          .map((r) => CompanionRecommendation.fromJson(
                r as Map<String, dynamic>,
              ))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Live re-scan of adverse events for the corridor slice ahead of
  /// the driver. Called by Companion every ~15 min so new fires /
  /// thunderstorms / quakes that develop mid-drive surface as fresh
  /// notifications instead of the frozen plan-time snapshot.
  ///
  /// Returns an empty list on any transport failure — the drive
  /// session must never crash because the refresh call timed out;
  /// the driver's original plan-time events stay visible either way.
  Future<List<AdverseEvent>> refreshAdverseEvents({
    required List<LatLon> geometry,
    required double currentKm,
    double lookAheadKm = 200.0,
    List<Country> countries = const [],
  }) async {
    if (geometry.length < 2) return const [];
    final uri = Uri.parse('$_baseUrl/v1/trips/adverse-refresh');
    try {
      final response = await _http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'geometry': geometry
                  .map((p) => {'lat': p.lat, 'lon': p.lon})
                  .toList(),
              'current_km': currentKm,
              'look_ahead_km': lookAheadKm,
              if (countries.isNotEmpty)
                'countries': countries.map((c) => c.code).toList(),
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (body['events'] as List<dynamic>? ?? const []);
      return list
          .map((e) => AdverseEvent.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Companion-mode live weather-hazards probe: send sample coords
  /// along the next ~200 km, get back typed hazard alerts (heavy
  /// rain, hail, thunder, high wind, dense fog, freezing rain,
  /// snow). Best-effort — returns empty on any failure. Coverage
  /// caveat: RainViewer confirmation only across Europe + North
  /// America; elsewhere the response falls back to Open-Meteo
  /// forecast alone (`radar_confirmed = false`).
  Future<List<WeatherHazard>> weatherHazardsCheck({
    required List<({double lat, double lon, double? kmAhead})> coords,
  }) async {
    if (coords.isEmpty) return const [];
    final uri = Uri.parse('$_baseUrl/v1/trips/weather-hazards-check');
    try {
      final response = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'coords': [
            for (final c in coords)
              {
                'lat': c.lat,
                'lon': c.lon,
                if (c.kmAhead != null) 'km_ahead': c.kmAhead,
              },
          ],
        }),
      );
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (body['hazards'] as List<dynamic>? ?? const []);
      return list
          .map((h) => WeatherHazard.fromJson(h as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Push saved trips to server (cloud backup).
  Future<bool> saveTrips(List<Map<String, dynamic>> trips) async {
    final uri = Uri.parse('$_baseUrl/v1/profile/trips');
    try {
      final response = await _http.put(
        uri,
        headers: _headers(),
        body: jsonEncode({'trips': trips}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Reverse-geocode a coordinate to the nearest supported-country place.
  ///
  /// Returns null when the backend responds 404 (open sea, wilderness,
  /// outside supported countries) or on any HTTP failure — the "Use my
  /// location" UI treats both cases the same way (fall back to raw
  /// coordinates).
  Future<GeocodeResult?> reverseGeocode({
    required double lat,
    required double lon,
    String? locale,
  }) async {
    final normalizedLocale = _normalizeLocale(locale);
    final uri = Uri.parse('$_baseUrl/v1/geocode/reverse').replace(
      queryParameters: {
        'lat': '$lat',
        'lon': '$lon',
        if (normalizedLocale != null) 'lang': normalizedLocale,
      },
    );
    try {
      final response = await _http.get(
        uri,
        headers: _headers(acceptLanguage: normalizedLocale),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw ApiException(response.statusCode, response.body);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return GeocodeResult.fromJson(body);
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the attribution catalogue served by the backend at
  /// `/v1/attributions`. Returns raw items so the UI can group them —
  /// we don't try to model each field in a strong type because new
  /// entries land server-side without a client rebuild.
  Future<List<Map<String, dynamic>>> attributions() async {
    final uri = Uri.parse('$_baseUrl/v1/attributions');
    final response = await _http.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = (body['items'] as List<dynamic>?) ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Pull the curated top-EU vehicle catalogue (make / model / tank /
  /// consumption). Small payload (~50 rows). Cached on the server for
  /// 24 h — callers should cache client-side too (Riverpod
  /// `FutureProvider` in `providers.dart` does the honours).
  Future<List<VehicleModel>> listVehicles() async {
    final uri = Uri.parse('$_baseUrl/v1/vehicles');
    final response = await _http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = (body['vehicles'] as List<dynamic>?) ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(VehicleModel.fromJson)
        .toList(growable: false);
  }

  void dispose() => _http.close();
}
