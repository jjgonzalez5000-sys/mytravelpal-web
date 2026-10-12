import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart' show LatLon;
import 'package:mytravelpal/design/stop_category_style.dart';
import 'package:mytravelpal/domain/my_place.dart';
import 'package:mytravelpal/domain/stop_suggestion.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/widgets/stop_ideas_view.dart';
import 'package:mytravelpal/widgets/stop_suggestions_sheet.dart'
    show suggestionKey, suggestionMapsUrl;

StopSuggestion _s(
  String id,
  String name, {
  String? kind,
  String category = 'x',
  bool picked = true,
  double lon = -3.0,
}) =>
    StopSuggestion.fromJson({
      'id': id,
      'name': name,
      'lat': 40.0,
      'lon': lon,
      'category': category,
      if (kind != null) 'kind': kind,
      'why': picked ? 'Because' : '',
      'visit_minutes': 30,
      'detour_minutes': 6,
      'distance_from_route_km': 1.0,
      'along_km': 10.0,
      'fits_window': true,
      'picked': picked,
    });

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

class _BlankTiles extends TileProvider {
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

void main() {
  setUpAll(() => StopIdeasView.debugTileProvider = _BlankTiles());
  tearDownAll(() => StopIdeasView.debugTileProvider = null);

  group('StopSuggestion kind', () {
    test('the server kind wins over the raw category', () {
      final s = _s('c1', 'A', kind: 'beach', category: 'natural.forest');
      expect(s.placeCategory, MyPlaceCategory.beach);
    });

    test('every server kind is a known category', () {
      for (final k in [
        'food', 'viewpoint', 'culture', 'history', 'nature', 'beach', 'kids',
        'shopping', 'other', //
      ]) {
        expect(_s('c1', 'A', kind: k).placeCategory.name, k);
      }
    });

    test('an unknown or missing kind falls back to the raw category', () {
      expect(_s('c1', 'A', kind: 'spaceport', category: 'catering.cafe')
          .placeCategory, MyPlaceCategory.food);
      expect(_s('c1', 'A', category: 'tourism.sights.castle').placeCategory,
          MyPlaceCategory.history);
      expect(_s('c1', 'A', category: 'beach.beach_resort').placeCategory,
          MyPlaceCategory.beach);
      expect(_s('c1', 'A', category: 'tourism.attraction.viewpoint')
          .placeCategory, MyPlaceCategory.viewpoint);
    });

    test('picked defaults to true and is read when present', () {
      expect(_s('c1', 'A').picked, isTrue);
      expect(_s('c1', 'A', picked: false).picked, isFalse);
    });

    test('a result survives a JSON round trip, kind and picked included', () {
      final res = StopSuggestionsResult(
        suggestions: [
          _s('c1', 'A', kind: 'history'),
          _s('c2', 'B', kind: 'food', picked: false),
        ],
        ai: true,
        windowMinutes: 120,
        usedMinutes: 40,
      );
      final back = StopSuggestionsResult.fromJson(
        jsonDecode(jsonEncode(res.toJson())) as Map<String, dynamic>,
      );
      expect(back.suggestions.map((s) => s.name), ['A', 'B']);
      expect(back.suggestions.map((s) => s.placeCategory),
          [MyPlaceCategory.history, MyPlaceCategory.food]);
      expect(back.suggestions.map((s) => s.picked), [true, false]);
      expect(back.ai, isTrue);
      expect(back.usedMinutes, 40);
    });

    test('a saved place with a new category name reads back', () {
      final p = MyPlace.fromJson({
        'id': '1',
        'name': 'n',
        'lat': 1.0,
        'lon': 2.0,
        'category': 'beach',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(p.category, MyPlaceCategory.beach);
    });
  });

  group('filters', () {
    final list = [
      _s('c1', 'Castle', kind: 'history'),
      _s('c2', 'Beach', kind: 'beach'),
      _s('c3', 'Pizza', kind: 'food'),
      _s('c4', 'Fort', kind: 'history', picked: false),
    ];

    test('counts and kinds follow the display order', () {
      expect(kindCounts(list)[MyPlaceCategory.history], 2);
      expect(kindsPresent(list), [
        MyPlaceCategory.food,
        MyPlaceCategory.history,
        MyPlaceCategory.beach,
      ]);
    });

    test('no kind chosen shows everything; several are a union', () {
      expect(filterByKinds(list, {}), list);
      expect(
        filterByKinds(list, {MyPlaceCategory.history}).map((s) => s.name),
        ['Castle', 'Fort'],
      );
      expect(
        filterByKinds(list, {MyPlaceCategory.history, MyPlaceCategory.food})
            .length,
        3,
      );
      expect(filterByKinds(list, {MyPlaceCategory.kids}), isEmpty);
    });

    test('a long route is thinned but keeps both ends', () {
      final line = [
        for (var i = 0; i < 5000; i++) LatLon(lat: 40.0, lon: -4.0 + i * 0.001),
      ];
      final out = thinPolyline(line, max: 300);
      expect(out.length, 300);
      expect(out.first.longitude, line.first.lon);
      expect(out.last.longitude, line.last.lon);
      expect(thinPolyline(line.take(10).toList()).length, 10);
    });
  });

  group('category style', () {
    test('every category has a distinct icon and colour', () {
      final icons = {
        for (final c in MyPlaceCategory.values) stopCategoryStyle(c).icon,
      };
      final colors = {
        for (final c in MyPlaceCategory.values) stopCategoryStyle(c).color,
      };
      expect(icons.length, MyPlaceCategory.values.length);
      expect(colors.length, MyPlaceCategory.values.length);
    });

    test('white on a pin and the tint on a surface stay readable', () {
      const lightSurface = Color(0xFFFAFAF7);
      const darkSurface = Color(0xFF16181B);
      for (final c in MyPlaceCategory.values) {
        final st = stopCategoryStyle(c);
        expect(_contrast(st.color, Colors.white), greaterThanOrEqualTo(4.5),
            reason: '$c pin');
        expect(
          _contrast(st.onSurface(Brightness.light), lightSurface),
          greaterThanOrEqualTo(4.5),
          reason: '$c on light',
        );
        expect(
          _contrast(st.onSurface(Brightness.dark), darkSurface),
          greaterThanOrEqualTo(4.5),
          reason: '$c on dark',
        );
      }
    });

    test('the nature pin is not the route green', () {
      expect(stopCategoryStyle(MyPlaceCategory.nature).color,
          isNot(const Color(0xFF2F5D50)));
    });
  });

  test('the maps link names the place and pins its coordinate', () {
    final uri = Uri.parse(suggestionMapsUrl(_s('c1', 'Bar  El Pino')));
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['query'], 'Bar El Pino 40.0,-3.0');
  });

  group('StopIdeasView', () {
    final suggestions = [
      _s('c1', 'Castle', kind: 'history', lon: -3.0),
      _s('c2', 'Playa Sur', kind: 'beach', lon: -2.9),
      _s('c3', 'Pizzeria', kind: 'food', lon: -2.8),
      _s('c4', 'Fort', kind: 'history', picked: false, lon: -2.7),
    ];
    final geometry = [
      for (var i = 0; i < 20; i++) LatLon(lat: 40.0, lon: -3.1 + i * 0.02),
    ];

    Future<List<StopSuggestion>> pump(
      WidgetTester tester, {
      Set<String> added = const {},
      Future<bool> Function(StopSuggestion)? onAdd,
      List<StopSuggestion>? items,
    }) async {
      final calls = <StopSuggestion>[];
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StopIdeasView(
              suggestions: items ?? suggestions,
              geometry: geometry,
              addedKeys: added,
              onAdd: onAdd ??
                  (s) async {
                    calls.add(s);
                    return true;
                  },
            ),
          ),
        ),
      ));
      await tester.pump();
      return calls;
    }

    testWidgets('shows chips with counts and one row per stop', (tester) async {
      await pump(tester);
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('History (2)'), findsOneWidget);
      expect(find.text('Beach (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('ideas-map')), findsOneWidget);
      for (final s in suggestions) {
        expect(find.byKey(ValueKey('ideas-row-${suggestionKey(s)}')),
            findsOneWidget);
      }
      expect(find.text('More places nearby'), findsOneWidget);
    });

    testWidgets('a kind chip filters the list and the pins', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('ideas-chip-history')));
      await tester.pump();
      expect(find.byKey(ValueKey('ideas-row-${suggestionKey(suggestions[0])}')),
          findsOneWidget);
      expect(find.byKey(ValueKey('ideas-row-${suggestionKey(suggestions[1])}')),
          findsNothing);
      expect(find.byKey(ValueKey('ideas-pin-${suggestionKey(suggestions[1])}')),
          findsNothing);
      // The counts keep describing the whole answer.
      expect(find.text('Beach (1)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ideas-chip-all')));
      await tester.pump();
      expect(find.byKey(ValueKey('ideas-row-${suggestionKey(suggestions[1])}')),
          findsOneWidget);
    });

    testWidgets('selecting a row shows its card with an Add button',
        (tester) async {
      final calls = await pump(tester);
      expect(find.text('Add'), findsNothing);
      await tester.tap(
        find.byKey(ValueKey('ideas-row-${suggestionKey(suggestions[1])}')),
      );
      await tester.pump();
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Details and map'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(calls.single.name, 'Playa Sur');
    });

    testWidgets('tapping a pin selects the stop and shows its type',
        (tester) async {
      await pump(tester);
      final pin = find.byKey(
        ValueKey('ideas-pin-${suggestionKey(suggestions[2])}'),
      );
      expect(pin, findsOneWidget);
      await tester.tap(pin);
      await tester.pump();
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Picked by AI'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
    });

    testWidgets('an added stop shows as added', (tester) async {
      await pump(tester, added: {suggestionKey(suggestions[0])});
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(
        find.byKey(ValueKey('ideas-add-${suggestionKey(suggestions[0])}')),
        findsNothing,
      );
    });

    testWidgets('a single kind needs no chips', (tester) async {
      await pump(tester, items: [_s('c1', 'Castle', kind: 'history')]);
      expect(find.byKey(const ValueKey('ideas-chip-all')), findsNothing);
    });

    testWidgets('many extras are collapsed behind Show more', (tester) async {
      final many = [
        _s('c0', 'Picked', kind: 'history'),
        for (var i = 1; i <= 9; i++)
          _s('c$i', 'Extra $i', kind: 'food', picked: false, lon: -3 + i * 0.01),
      ];
      await pump(tester, items: many);
      expect(find.text('Show 4 more'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ideas-show-more')));
      await tester.pump();
      expect(find.text('Show 4 more'), findsNothing);
      expect(find.text('Extra 9'), findsOneWidget);
    });

    testWidgets('the full screen map opens and closes', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Full screen map'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ideas-map')), findsOneWidget);
      expect(find.byTooltip('Close map'), findsOneWidget);
      await tester.tap(find.byTooltip('Close map'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close map'), findsNothing);
    });
  });
}
