import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/widgets/trip_day_bars.dart';

void main() {
  final day = DayPlan(
    dayIndex: 1,
    startAt: DateTime(2026, 10, 11, 8),
    endAt: DateTime(2026, 10, 11, 20),
    fromKm: 0,
    toKm: 900,
    toName: 'Hjärnarp (Skåne County)',
    mealStops: [
      MealStopOpt(
        slot: 'lunch',
        at: DateTime(2026, 10, 11, 12, 12),
        distanceFromOriginKm: 400,
        restaurantName: 'Restaurang Carl Fredrik',
      ),
      MealStopOpt(
        slot: 'dinner',
        at: DateTime(2026, 10, 11, 19),
        distanceFromOriginKm: 850,
        cityHint: 'Ängelholm (Skåne County)',
      ),
    ],
    restStops: const [
      RestStop(
        distanceFromOriginKm: 200,
        cumulativeDrivingHours: 2,
        recommendedBreakMinutes: 45,
        coordinate: LatLon(lat: 55, lon: 13),
        name: 'Bei Ania',
      ),
    ],
  );

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripDayBars(
              days: [day],
              dayOverrides: const {},
              profileCapHours: 8,
              addedStopKeys: const {},
            ),
          ),
        ),
      ));

  testWidgets('lists the meals, service stops and end of day with place',
      (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('12:12'), findsOneWidget);
    expect(find.text('Restaurang Carl Fredrik · Lunch'), findsOneWidget);
    expect(find.text('Dinner · Ängelholm (Skåne County)'), findsOneWidget);
    expect(find.text('Bei Ania · 45 min'), findsOneWidget);
    expect(find.text('End of day · Hjärnarp (Skåne County)'), findsOneWidget);
  });

  testWidgets('explains the colours of the bar', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    for (final label in [
      'Driving',
      'Breakfast',
      'Lunch',
      'Dinner',
      'Rest stop added',
      'Suggested rest, not added',
      'Daily limit',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
