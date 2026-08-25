import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/auth_user.dart';
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
  }) =>
      {
        'Content-Type': contentType,
        if (_apiKey != null) 'X-MyTravelPal-Api-Key': _apiKey,
        if (_premium) 'X-MyTravelPal-Premium': 'true',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

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
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/trips/narrative');
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'plan_request': planRequest.toJson(),
        'origin_name': originName,
        'destination_name': destinationName,
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

  Future<List<GeocodeResult>> geocode(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final uri = Uri.parse('$_baseUrl/v1/geocode').replace(queryParameters: {
      'q': trimmed,
      'limit': '$limit',
    });
    final response = await _http.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>;
    return results
        .map((r) => GeocodeResult.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
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
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/geocode/reverse').replace(
      queryParameters: {'lat': '$lat', 'lon': '$lon'},
    );
    try {
      final response = await _http.get(uri, headers: _headers());
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

  void dispose() => _http.close();
}
