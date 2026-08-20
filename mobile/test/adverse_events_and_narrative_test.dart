import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/config.dart';
import 'package:mytravelpal/api/models.dart';

void main() {
  group('AdverseEventType', () {
    test('roundtrips known codes', () {
      for (final t in AdverseEventType.values) {
        expect(AdverseEventType.fromCode(t.code), t);
      }
    });

    test('falls back to other on unknown codes', () {
      expect(AdverseEventType.fromCode('meteorite'), AdverseEventType.other);
    });
  });

  group('AdverseEvent.fromJson', () {
    test('parses a full payload', () {
      final raw = jsonDecode('''
        {
          "id": "mock:0",
          "type": "strike",
          "severity": "warning",
          "source": "mock",
          "description": "Rail workers strike.",
          "reported_at": "2026-08-20T10:00:00Z",
          "expires_at": "2026-08-21T10:00:00Z",
          "lat": 48.85, "lon": 2.35,
          "country": "FR"
        }
      ''') as Map<String, dynamic>;
      final e = AdverseEvent.fromJson(raw);
      expect(e.type, AdverseEventType.strike);
      expect(e.severity, AdverseEventSeverity.warning);
      expect(e.source, 'mock');
      expect(e.country, Country.fr);
      expect(e.coordinate.lat, 48.85);
    });

    test('accepts null country', () {
      final raw = jsonDecode('''
        {
          "id": "u:1", "type": "fire", "severity": "critical",
          "source": "user", "description": "d",
          "reported_at": "2026-08-20T10:00:00Z",
          "expires_at": "2026-08-21T10:00:00Z",
          "lat": 44.0, "lon": -0.5, "country": null
        }
      ''') as Map<String, dynamic>;
      expect(AdverseEvent.fromJson(raw).country, isNull);
    });
  });

  group('TripPlanRequest.toJson', () {
    test('includes adverse-event params when enabled', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        includeAdverseEvents: true,
      );
      final json = req.toJson();
      expect(json['include_adverse_events'], true);
      expect(json['adverse_events_max_distance_km'], 25.0);
    });

    test('omits adverse-event params when disabled', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
      );
      expect(req.toJson().containsKey('include_adverse_events'), isFalse);
    });
  });

  group('TripPlanResponse.fromJson', () {
    test('parses response with adverse events', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": [], "hotels": [], "restaurants": [], "rest_stops": [],
          "adverse_events": [
            {"id": "e1", "type": "fire", "severity": "critical", "source": "mock",
             "description": "d", "reported_at": "2026-08-20T10:00:00Z",
             "expires_at": "2026-08-21T10:00:00Z", "lat": 44, "lon": -0.5, "country": "FR"}
          ]
        }
      ''') as Map<String, dynamic>;
      final parsed = TripPlanResponse.fromJson(raw);
      expect(parsed.adverseEvents, hasLength(1));
      expect(parsed.adverseEvents.single.severity, AdverseEventSeverity.critical);
    });

    test('defaults adverseEvents to empty when field is missing', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": []
        }
      ''') as Map<String, dynamic>;
      expect(TripPlanResponse.fromJson(raw).adverseEvents, isEmpty);
    });
  });

  group('NarrativeResponse.fromJson', () {
    test('parses a narrative payload', () {
      final raw = jsonDecode('''
        {
          "narrative": "Long-form trip briefing…",
          "origin_name": "Paris",
          "destination_name": "Madrid",
          "generated_at": "2026-08-24T08:15:00Z"
        }
      ''') as Map<String, dynamic>;
      final n = NarrativeResponse.fromJson(raw);
      expect(n.narrative, startsWith('Long-form'));
      expect(n.originName, 'Paris');
      expect(n.destinationName, 'Madrid');
    });
  });

  group('ApiClient', () {
    test('submitAdverseEvent posts JSON to /v1/adverse-events', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'id': 'x',
            'type': 'fire',
            'severity': 'critical',
            'lat': 44.0,
            'lon': -0.5,
            'description': 'ok',
            'reported_at': '2026-08-20T10:00:00Z',
            'expires_at': '2026-08-21T10:00:00Z',
            'country': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://test.local'),
        httpClient: mock,
      );
      final result = await client.submitAdverseEvent(
        type: AdverseEventType.fire,
        severity: AdverseEventSeverity.critical,
        lat: 44.0, lon: -0.5,
        description: 'ok',
      );
      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1/adverse-events');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['type'], 'fire');
      expect(body['severity'], 'critical');
      expect(result['id'], 'x');
    });

    test('tripNarrative posts nested request and parses NarrativeResponse',
        () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'narrative': 'A friendly briefing.',
            'origin_name': 'Paris',
            'destination_name': 'Madrid',
            'generated_at': '2026-08-24T08:15:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://test.local'),
        httpClient: mock,
      );
      final resp = await client.tripNarrative(
        planRequest: TripPlanRequest(
          origin: const LatLon(lat: 48, lon: 2),
          destination: const LatLon(lat: 40, lon: -3),
          desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        ),
        originName: 'Paris',
        destinationName: 'Madrid',
      );
      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1/trips/narrative');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['origin_name'], 'Paris');
      expect(body['plan_request'], isA<Map<String, dynamic>>());
      expect(resp.narrative, 'A friendly briefing.');
    });
  });
}
