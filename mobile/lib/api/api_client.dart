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
    final response = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return TripPlanResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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

  void dispose() => _http.close();
}
