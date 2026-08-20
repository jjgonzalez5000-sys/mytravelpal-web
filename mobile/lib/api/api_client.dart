import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

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
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  Future<TripPlanResponse> planTrip(TripPlanRequest request) async {
    final uri = Uri.parse('$_baseUrl/v1/trips/plan');
    final response = await _http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return TripPlanResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<GeocodeResult>> geocode(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final uri = Uri.parse('$_baseUrl/v1/geocode').replace(queryParameters: {
      'q': trimmed,
      'limit': '$limit',
    });
    final response = await _http.get(uri);
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>;
    return results
        .map((r) => GeocodeResult.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  void dispose() => _http.close();
}
