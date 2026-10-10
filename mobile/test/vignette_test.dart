import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/vignette_info.dart';

Map<String, dynamic> _route(Map<String, dynamic> extra) => {
      'distance_km': 100.0,
      'free_flow_minutes': 60.0,
      'polyline': '',
      'toll_cost_eur': 50.0,
      'countries_crossed': <String>[],
      'geometry': <dynamic>[],
      ...extra,
    };

void main() {
  group('vignette lines', () {
    test('are parsed per country', () {
      final r = RouteInfo.fromJson(_route({
        'vignette_cost_eur': 52.8,
        'vignette_countries': ['AT', 'CH'],
        'vignettes': [
          {'country': 'AT', 'cost_eur': 12.8},
          {'country': 'CH', 'cost_eur': 40.0},
        ],
      }));
      expect(r.vignettes.map((v) => v.country), ['AT', 'CH']);
      expect(r.vignettes.last.costEur, 40.0);
    });

    test('an older server without the field still parses', () {
      final r = RouteInfo.fromJson(_route({
        'vignette_cost_eur': 12.8,
        'vignette_countries': ['AT'],
      }));
      expect(r.vignettes, isEmpty);
      expect(r.vignetteCountries, ['AT']);
    });

    test('verified tolls bring the lines with them', () {
      final core = RouteInfo.fromJson(_route({}));
      final enriched = RouteInfo.fromJson(_route({
        'toll_verified': true,
        'vignettes': [
          {'country': 'SK', 'cost_eur': 11.0},
        ],
      }));
      final merged = core.withVerifiedTolls(enriched);
      expect(merged.vignettes.single.country, 'SK');
    });
  });

  group('vignette info', () {
    test('every vignette country the server can send has an official seller', () {
      for (final c in ['AT', 'CH', 'CZ', 'SK', 'HU', 'SI', 'RO', 'BG']) {
        final info = vignetteInfoFor(c);
        expect(info, isNotNull, reason: c);
        expect(info!.officialUrl, startsWith('https://'), reason: c);
      }
    });

    test('only Switzerland is a sticker; lookup is case-insensitive', () {
      expect(vignetteInfoFor('ch')!.sticker, isTrue);
      expect(vignetteInfoFor('AT')!.sticker, isFalse);
    });

    test('an unknown country has no info', () {
      expect(vignetteInfoFor('FR'), isNull);
    });
  });
}
