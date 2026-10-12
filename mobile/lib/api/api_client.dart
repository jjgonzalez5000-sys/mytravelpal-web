import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

import '../domain/auth_user.dart';
import '../domain/garage_vehicle.dart';
import '../domain/plan_gates.dart';
import '../domain/stop_suggestion.dart';
import '../domain/vehicle_model.dart';
import 'config.dart';

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
  TierCaps _caps = TierCaps.unrestricted;
  String? _authToken;

  /// Toggle whether outgoing requests should declare Premium status via
  /// the `X-MyTravelPal-Premium` header. Set by
  /// `apiClientWithPremiumProvider` from the current Riverpod state.
  void setPremium(bool value) => _premium = value;

  /// What the current plan unlocks; every plan request is sanitised with it
  /// so a stale gated option never reaches the server.
  void setCaps(TierCaps caps) => _caps = caps;

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

  /// Two-phase progressive plan: FAST phase.
  ///
  /// Returns the subset the ResultScreen needs to render the map +
  /// hero + day cards immediately (route, days, savings, time
  /// windows, optimizations). Hotels, restaurants, fuel, weather,
  /// adverse events, toll alternative come back as empty defaults
  /// so `TripPlanResponse.fromJson` parses cleanly — the caller
  /// then fires [planTripEnrich] and hydrates the placeholders.
  ///
  /// Same 120 s cap + 3-attempt retry chain as [planTrip] — a
  /// long-haul plan still fans out server-side and can take tens of
  /// seconds when the backend is on a cold Fly machine.
  Future<TripPlanResponse> planTripCore(
    TripPlanRequest request, {
    String? locale,
  }) =>
      _postPlanVariant(request, '/v1/trips/plan/core', locale: locale);

  /// Two-phase progressive plan: SLOWER phase.
  ///
  /// Returns hotels + restaurants + fuel + weather + adverse events
  /// + toll alternative. Core fields (route, days, savings) come
  /// back zeroed — the client already has them from [planTripCore].
  ///
  /// Shares the server-side `plan_cache` with [planTripCore], so
  /// firing this right after `planTripCore` for the same request
  /// pays the compute cost ONCE (the second call is a cache hit).
  Future<TripPlanResponse> planTripEnrich(
    TripPlanRequest request, {
    String? locale,
  }) =>
      _postPlanVariant(request, '/v1/trips/plan/enrich', locale: locale);

  /// SSE streaming plan — connects to /plan/stream, fires [onProgress]
  /// for each "progress" event (pct 0-100, label string), and returns
  /// the merged TripPlanResponse from the final "result" event.
  ///
  /// Use this instead of [planTripCore] + [planTripEnrich] when you
  /// want a real progress bar rather than a time-based estimate. Falls
  /// back to the caller's discretion — this method throws on any error
  /// so the caller can catch and retry via the two-phase path.
  Future<TripPlanResponse> streamPlan(
    TripPlanRequest request, {
    String? locale,
    void Function(int pct, String label)? onProgress,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/trips/plan/stream');
    final req = http.Request('POST', uri)
      ..headers.addAll(_headers(acceptLanguage: locale))
      ..body = jsonEncode(sanitizeForTier(request, _caps).toJson());

    final streamed = await _http
        .send(req)
        .timeout(const Duration(seconds: 30)); // connection timeout

    if (streamed.statusCode >= 400) {
      final body = await streamed.stream.bytesToString();
      throw ApiException(streamed.statusCode, body);
    }

    TripPlanResponse? result;
    var buffer = '';

    await for (final chunk in streamed.stream
        .transform(utf8.decoder)
        .timeout(const Duration(seconds: 180))) {
      buffer += chunk;
      // Process all complete lines in the buffer.
      while (buffer.contains('\n')) {
        final idx = buffer.indexOf('\n');
        final line = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);
        if (!line.startsWith('data: ')) continue;
        final Map<String, dynamic> data;
        try {
          data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final event = data['event'] as String?;
        if (event == 'progress') {
          onProgress?.call(
            (data['pct'] as num).toInt(),
            (data['label'] as String?) ?? '',
          );
        } else if (event == 'result') {
          result = TripPlanResponse.fromJson(
            data['plan'] as Map<String, dynamic>,
          );
        } else if (event == 'done') {
          break;
        } else if (event == 'error') {
          throw ApiException(
            500,
            (data['message'] as String?) ?? 'stream error',
          );
        }
      }
      if (result != null) break; // done event may arrive after result
    }

    if (result == null) {
      throw Exception('streamPlan: stream ended without a result event');
    }
    return result;
  }

  Future<TripPlanResponse> _postPlanVariant(
    TripPlanRequest request,
    String pathSuffix, {
    String? locale,
  }) async {
    final uri = Uri.parse('$_baseUrl$pathSuffix');
    final body = jsonEncode(sanitizeForTier(request, _caps).toJson());
    const attempts = 3;
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        final response = await _http
            .post(uri, headers: _headers(acceptLanguage: locale), body: body)
            .timeout(const Duration(seconds: 120));
        if (response.statusCode == 200) {
          return TripPlanResponse.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          );
        }
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw ApiException(response.statusCode, response.body);
        }
        lastError = ApiException(response.statusCode, response.body);
      } on ApiException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    if (lastError is Exception) throw lastError;
    throw Exception(lastError?.toString() ?? 'plan variant failed');
  }

  Future<TripPlanResponse> planTrip(
    TripPlanRequest request, {
    String? locale,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/trips/plan');
    final body = jsonEncode(sanitizeForTier(request, _caps).toJson());
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
            .post(uri, headers: _headers(acceptLanguage: locale), body: body)
            // 120s per attempt — long cross-country plans (e.g.
            // Switzerland → Toledo, ~2000 km) hit ~70-90 s on the
            // backend fanning weather/POI/fuel across 4-5 countries.
            // 60 s was aborting mid-flight and retrying, so the
            // backend saw 3× POSTs for the same trip while the user
            // waited nearly 3 minutes.
            .timeout(const Duration(seconds: 120));
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
        'plan_request': sanitizeForTier(planRequest, _caps).toJson(),
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

  /// POST /v1/trips/narrative/audio — synthesize [narrativeText] to MP3
  /// using OpenAI TTS on the backend. Returns base64-encoded MP3 bytes,
  /// or null when the backend has no OPENAI_API_KEY (client should fall
  /// back to device TTS in that case).
  Future<String?> narrativeAudio({
    required String narrativeText,
    String voice = 'nova',
    double speed = 1.0,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/trips/narrative/audio');
    try {
      final response = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'narrative_text': narrativeText,
          'voice': voice,
          'speed': speed,
        }),
      );
      if (response.statusCode != 200) return null;
      final j = jsonDecode(response.body) as Map<String, dynamic>;
      return j['audio_base64'] as String?;
    } catch (_) {
      return null;
    }
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

  /// Check whether a Hall of Fame nick is available (not taken by
  /// another user). Returns null on any network/parse error so the
  /// caller can treat it as "unknown" and allow saving anyway.
  Future<bool?> checkNickAvailable(String nick) async {
    final uri = Uri.parse('$_baseUrl/v1/profile/check-nick')
        .replace(queryParameters: {'nick': nick});
    try {
      final response = await _http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['available'] as bool?;
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

  /// Premium: real places near [route] that fit [freeMinutes], picked and
  /// explained by the model. 402 means the account is not Premium, 429 that
  /// the daily AI cap is used up.
  Future<StopSuggestionsResult> suggestStops({
    required List<LatLon> route,
    required int freeMinutes,
    List<String> interests = const [],
    int travellers = 1,
    bool hasKids = false,
    bool hasPets = false,
    int limit = 5,
    List<String> excludeNames = const [],
    String? locale,
  }) async {
    final normalizedLocale = _normalizeLocale(locale);
    final uri = Uri.parse('$_baseUrl/v1/trips/suggest-stops').replace(
      queryParameters: {
        if (normalizedLocale != null) 'lang': normalizedLocale,
      },
    );
    final body = jsonEncode({
      'route': [for (final p in route) {'lat': p.lat, 'lon': p.lon}],
      'free_minutes': freeMinutes,
      'interests': interests,
      'travellers': travellers,
      'has_kids': hasKids,
      'has_pets': hasPets,
      'limit': limit,
      'exclude_names': excludeNames,
      if (normalizedLocale != null) 'locale': normalizedLocale,
    });
    final response = await _http
        .post(uri,
            headers: _headers(acceptLanguage: normalizedLocale), body: body)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return StopSuggestionsResult.fromJson(
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

  /// Fetch the user's saved garage (multi-vehicle list). Returns an
  /// empty list on any failure so the picker UI can show "empty
  /// state" instead of a spinner-of-doom.
  Future<List<GarageVehicle>> fetchGarage() async {
    final uri = Uri.parse('$_baseUrl/v1/profile/garage');
    try {
      final response = await _http.get(uri, headers: _headers());
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = (body['vehicles'] as List<dynamic>?) ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(GarageVehicle.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Add a vehicle to the user's garage. Backend generates the uuid
  /// and returns the fully-formed entry. Throws [ApiException] so
  /// the caller can surface a snackbar on a 400 (unknown model_id).
  Future<GarageVehicle> addGarageVehicle({
    required String name,
    required String modelId,
    int defaultTankPercent = 100,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/profile/garage');
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'model_id': modelId,
        'default_tank_percent': defaultTankPercent,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return GarageVehicle.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Update the mutable fields of a garage vehicle. The catalogue
  /// `model_id` is intentionally not editable — swap-my-car means
  /// delete + re-add so the id stays semantically stable.
  Future<GarageVehicle> updateGarageVehicle({
    required String id,
    String? name,
    int? defaultTankPercent,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/profile/garage/$id');
    final response = await _http.put(
      uri,
      headers: _headers(),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (defaultTankPercent != null)
          'default_tank_percent': defaultTankPercent,
        if (notes != null) 'notes': notes,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return GarageVehicle.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Remove a vehicle from the garage. Returns true on 200 / 404
  /// (idempotent — a gone vehicle is a fine end-state).
  Future<bool> deleteGarageVehicle(String id) async {
    final uri = Uri.parse('$_baseUrl/v1/profile/garage/$id');
    try {
      final response = await _http.delete(uri, headers: _headers());
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  // --------------- User Learning / AI Profile ---------------

  /// GET /v1/profile/learning — fetch the stored learning blob.
  /// Returns an empty map on any failure (including 401 — not logged in).
  Future<Map<String, dynamic>> getUserLearning() async {
    final uri = Uri.parse('$_baseUrl/v1/profile/learning');
    try {
      final response = await _http.get(uri, headers: _headers());
      if (response.statusCode != 200) return const {};
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['learning'] as Map<String, dynamic>?) ?? const {};
    } catch (_) {
      return const {};
    }
  }

  /// PUT /v1/profile/learning — merge learning updates.
  /// Fire-and-forget: callers swallow errors.
  Future<void> putUserLearning(Map<String, dynamic> learning) async {
    final uri = Uri.parse('$_baseUrl/v1/profile/learning');
    try {
      await _http.put(
        uri,
        headers: _headers(),
        body: jsonEncode({'learning': learning}),
      );
    } catch (_) {
      // Fire-and-forget.
    }
  }

  /// GET /v1/profile/ai-context — returns a short LLM context string
  /// summarising the user's learning profile. Returns empty string
  /// on any failure.
  Future<String> getAiContext() async {
    final uri = Uri.parse('$_baseUrl/v1/profile/ai-context');
    try {
      final response = await _http.get(uri, headers: _headers());
      if (response.statusCode != 200) return '';
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['context'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// POST /v1/companion/chat — single-turn driving assistant query.
  /// Returns the AI reply and an optional action slug. Both
  /// transport errors and backend 5xx yield a safe fallback reply.
  Future<({String reply, String? action})> sendCompanionChat({
    required String message,
    Map<String, dynamic>? tripContext,
    String lang = 'en',
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/companion/chat');
    try {
      final response = await _http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'message': message,
              'lang': lang,
              if (tripContext != null) 'trip_context': tripContext,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return (reply: 'Sorry, something went wrong.', action: null);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        reply: (body['reply'] as String?) ?? '',
        action: body['action'] as String?,
      );
    } catch (_) {
      return (reply: 'Could not reach the assistant.', action: null);
    }
  }

  /// POST /v1/companion/session/{sessionId}/suggest — proactive stop tip.
  /// Called every 5 km. Returns a one-sentence suggestion and an action slug.
  /// Returns null on network error or when the backend fires no tip.
  Future<({String suggestion, String? action})?> sendCompanionSuggest({
    required String sessionId,
    required double currentKm,
    required List<Map<String, dynamic>> stops,
    String lang = 'en',
  }) async {
    final uri = Uri.parse(
        '$_baseUrl/v1/companion/session/$sessionId/suggest');
    try {
      final response = await _http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({
              'current_km': currentKm,
              'stops': stops,
              'lang': lang,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final s = body['suggestion'] as String?;
      if (s == null || s.isEmpty) return null;
      return (suggestion: s, action: body['action'] as String?);
    } catch (_) {
      return null;
    }
  }

  // --------------- Feedback ---------------

  /// POST /v1/feedback — send a free-form suggestion. Returns the
  /// backend-generated id on success. Reply email is optional; when
  /// set, the user opted in to "quiero respuesta".
  Future<int> submitFeedback({
    required String bodyText,
    required String appVersion,
    required String locale,
    String? replyEmail,
    String category = 'suggestion',
    String platform = 'android',
    List<String> attachments = const [],
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/feedback');
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'body_text': bodyText,
        'app_version': appVersion,
        'locale': locale,
        'category': category,
        'platform': platform,
        if (replyEmail != null && replyEmail.isNotEmpty)
          'reply_email': replyEmail,
        if (attachments.isNotEmpty)
          'attachments': attachments,
      }),
    );
    if (response.statusCode != 201) {
      throw ApiException(response.statusCode, response.body);
    }
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    return (j['id'] as num).toInt();
  }

  /// Validate a Play Billing purchase receipt with the backend.
  ///
  /// [purchaseToken] is the token returned by Play Billing after a
  /// successful purchase. [productId] is the SKU (e.g.
  /// `mytravelpal_premium_yearly`). Returns the resolved tier string
  /// ("essential" / "premium") on success or throws [ApiException].
  Future<String> validatePurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/billing/validate');
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'purchase_token': purchaseToken,
        'product_id': productId,
        'platform': 'android',
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    return (j['tier'] as String?) ?? 'premium';
  }

  /// Fetch speed cameras along a route corridor from the backend.
  /// Returns an empty list on any network or parse error — the
  /// caller treats absence of cameras as "no data" rather than an
  /// error so the Companion still starts normally.
  Future<List<SpeedCamera>> getRadarsAlongRoute({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  }) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/v1/trips/radars').replace(queryParameters: {
        'origin_lat': originLat.toString(),
        'origin_lon': originLon.toString(),
        'dest_lat': destLat.toString(),
        'dest_lon': destLon.toString(),
      });
      final response = await _http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['cameras'] as List<dynamic>? ?? [])
          .map((c) => SpeedCamera.fromJson(c as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<({String slug, String url})> shareTrip({
    required TripPlanResponse plan,
    required TripPlanRequest request,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/trips/share');
    final body = jsonEncode({
      'plan': plan.rawJson ?? {},
      'request': request.toJson(),
    });
    final response = await _http
        .post(uri, headers: _headers(), body: body)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      slug: json['slug'] as String,
      url: json['url'] as String,
    );
  }

  Future<({TripPlanResponse plan, Map<String, dynamic> requestJson})>
      importSharedTrip(String slug) async {
    final uri = Uri.parse('$_baseUrl/v1/trips/share/$slug');
    final response = await _http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      plan: TripPlanResponse.fromJson(json['plan'] as Map<String, dynamic>),
      requestJson: json['request'] as Map<String, dynamic>,
    );
  }

  // ---------------------------------------------------------------------------
  // Group Companion session — driver creates / pushes, passengers poll.
  // ---------------------------------------------------------------------------

  /// Driver creates a group session. Returns sessionId + joinCode (6-char).
  /// Throws [ApiException] on failure.
  Future<({String sessionId, String joinCode})> createCompanionSession() async {
    final uri = Uri.parse('$_baseUrl/v1/companion/session');
    final response = await _http
        .post(uri, headers: _headers(), body: '{}')
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(response.statusCode, response.body);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      sessionId: json['session_id'] as String,
      joinCode: json['join_code'] as String,
    );
  }

  /// Driver pushes current state to the session every 10 s.
  /// Silently ignores errors — best-effort synchronisation.
  Future<void> updateCompanionSession(
    String sessionId,
    CompanionSessionState state,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/v1/companion/session/$sessionId');
      await _http
          .put(uri, headers: _headers(), body: jsonEncode(state.toJson()))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort
    }
  }

  /// Passenger polls. Returns the raw JSON payload (lat, lon, next_stop,
  /// eta_minutes, radar_ahead_km, etc.) or null on any error.
  Future<Map<String, dynamic>?> getCompanionSession(String joinCode) async {
    try {
      final uri = Uri.parse('$_baseUrl/v1/companion/session/$joinCode');
      final response = await _http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Driver ends the group session.
  Future<void> deleteCompanionSession(String sessionId) async {
    try {
      final uri = Uri.parse('$_baseUrl/v1/companion/session/$sessionId');
      await _http
          .delete(uri, headers: _headers())
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort
    }
  }

  void dispose() => _http.close();
}
