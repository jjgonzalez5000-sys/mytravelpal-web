import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart' show LatLon;
import 'package:mytravelpal/domain/my_place.dart';
import 'package:mytravelpal/domain/plan_gates.dart';
import 'package:mytravelpal/domain/stop_suggestion.dart';
import 'package:mytravelpal/services/route_slice.dart';
import 'package:mytravelpal/widgets/stop_suggestions_sheet.dart'
    show placeKey, suggestionKey;

List<LatLon> _line(int n) =>
    [for (var i = 0; i < n; i++) LatLon(lat: 40.0, lon: -4.0 + i * 0.01)];

void main() {
  group('sliceRoute', () {
    test('keeps only the requested stretch', () {
      final line = _line(101); // 100 km, one point per km
      final out = sliceRoute(line, 100, fromKm: 20, toKm: 60);
      expect(out.first, line[20]);
      expect(out.last, line[60]);
      expect(out.length, 41);
    });

    test('thins a long stretch but keeps both ends', () {
      final line = _line(1001);
      final out = sliceRoute(line, 1000, fromKm: 0, toKm: 1000, maxPoints: 100);
      expect(out.length, lessThanOrEqualTo(101));
      expect(out.first, line.first);
      expect(out.last, line.last);
    });

    test('a stay-put day still yields a usable line', () {
      final line = _line(101);
      final out = sliceRoute(line, 100, fromKm: 50, toKm: 50);
      expect(out.length, greaterThanOrEqualTo(2));
    });

    test('swapped bounds are tolerated', () {
      final line = _line(101);
      final out = sliceRoute(line, 100, fromKm: 60, toKm: 20);
      expect(out.first, line[20]);
      expect(out.last, line[60]);
    });

    test('nothing to slice gives an empty list', () {
      expect(sliceRoute(const [], 100, fromKm: 0, toKm: 10), isEmpty);
      expect(sliceRoute(_line(5), 0, fromKm: 0, toKm: 10), isEmpty);
    });
  });

  group('StopSuggestionsResult', () {
    test('parses suggestions and skips malformed rows', () {
      final res = StopSuggestionsResult.fromJson({
        'ai': true,
        'window_minutes': 90,
        'used_minutes': 55,
        'suggestions': [
          {
            'id': 'c1',
            'name': 'Mirador',
            'lat': 40.1,
            'lon': -3.9,
            'category': 'tourism.attraction.viewpoint',
            'why': 'Vistas',
            'visit_minutes': 30,
            'detour_minutes': 10,
            'distance_from_route_km': 4.2,
            'along_km': 33.0,
            'fits_window': true,
          },
          {'id': 'c2', 'name': 'Sin posicion'},
          'garbage',
        ],
      });
      expect(res.suggestions.length, 1);
      expect(res.suggestions.first.totalMinutes, 40);
      expect(res.ai, isTrue);
      expect(res.usedMinutes, 55);
    });

    test('provider categories map to our own', () {
      StopSuggestion s(String cat) => StopSuggestion.fromJson({
            'id': 'c1', 'name': 'X', 'lat': 1.0, 'lon': 2.0, 'category': cat,
          });
      expect(s('catering.restaurant').placeCategory, MyPlaceCategory.food);
      expect(s('entertainment.zoo').placeCategory, MyPlaceCategory.kids);
      expect(s('entertainment.museum').placeCategory, MyPlaceCategory.culture);
      expect(s('tourism.sights').placeCategory, MyPlaceCategory.viewpoint);
      expect(s('leisure.park').placeCategory, MyPlaceCategory.nature);
      expect(s('whatever').placeCategory, MyPlaceCategory.other);
    });

    test('a suggestion and the saved place made from it share a key', () {
      final s = StopSuggestion.fromJson({
        'id': 'c1', 'name': 'Mirador', 'lat': 40.1234, 'lon': -3.9876,
      });
      expect(
        suggestionKey(s),
        placeKey('MIRADOR', LatLon(lat: 40.1234, lon: -3.9876)),
      );
    });
  });

  group('effectiveAiSuggest', () {
    test('only a Premium driver who asked for it gets it', () {
      expect(effectiveAiSuggest(wanted: true, premium: true), isTrue);
      expect(effectiveAiSuggest(wanted: true, premium: false), isFalse);
      expect(effectiveAiSuggest(wanted: false, premium: true), isFalse);
      expect(effectiveAiSuggest(wanted: false, premium: false), isFalse);
    });
  });
}
