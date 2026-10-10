import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/domain/garage_vehicle.dart';
import 'package:mytravelpal/domain/trip_profile.dart';
import 'package:mytravelpal/domain/vehicle_kind.dart';
import 'package:mytravelpal/domain/vehicle_model.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/screens/add_vehicle_wizard.dart';
import 'package:mytravelpal/screens/vehicle_picker_screen.dart'
    show kCustomVehicleId;
import 'package:mytravelpal/services/garage_profile.dart';

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

GarageVehicle _custom(VehicleSpecs s, {int tank = 100}) => GarageVehicle(
      id: 'g', name: 'X', modelId: kCustomVehicleId,
      defaultTankPercent: tank, notes: s.toNotes(),
    );

void main() {
  group('applyGarageVehicle limits (the server answers 422 beyond them)', () {
    const base = TripProfile();

    test('a truck engine stays inside what /plan accepts', () {
      final p = applyGarageVehicle(
        base,
        _custom(const VehicleSpecs(
          kind: VehicleKind.truck, fuelType: FuelType.diesel,
          tankL: 5000, consumptionL100km: 400,
        )),
      );
      expect(p.vehicle.fuelTankL, kMaxTankL);
      expect(p.vehicle.consumptionLPer100km, kMaxConsumptionL100);
    });

    test('an electric range is capped, never above the server limit', () {
      final p = applyGarageVehicle(
        base,
        _custom(const VehicleSpecs(
          kind: VehicleKind.car, fuelType: FuelType.electric,
          tankL: 60, consumptionL100km: 0.5, // 12000 km on paper
        )),
      );
      expect(p.vehicle.evRangeKm, kMaxEvRangeKm);
    });

    test('a catalogue car brings its own tank and consumption', () {
      const model = VehicleModel(
        id: 'tesla_3', make: 'Tesla', model: '3', yearFrom: 2019, yearTo: null,
        fuelType: FuelType.electric, tankLiters: 75, consumptionL100km: 16.5,
      );
      final p = applyGarageVehicle(
        base,
        const GarageVehicle(
          id: 'c', name: 'T', modelId: 'tesla_3', defaultTankPercent: 80,
        ),
        catalogueModel: model,
      );
      expect(p.vehicle.fuelType, FuelType.electric);
      expect(p.vehicle.consumptionKwhPer100km, 16.5);
      expect(p.vehicle.evRangeKm, closeTo(75 / 16.5 * 100, 1e-6));
    });

    test('a catalogue petrol car sets litres, not kWh', () {
      const model = VehicleModel(
        id: 'golf', make: 'VW', model: 'Golf', yearFrom: 2019, yearTo: null,
        fuelType: FuelType.petrol, tankLiters: 50, consumptionL100km: 6.2,
      );
      final p = applyGarageVehicle(
        base,
        const GarageVehicle(
          id: 'c', name: 'G', modelId: 'golf', defaultTankPercent: 100,
        ),
        catalogueModel: model,
      );
      expect(p.vehicle.fuelTankL, 50);
      expect(p.vehicle.consumptionLPer100km, 6.2);
      expect(p.vehicle.fuelType, FuelType.petrol);
    });

    test("the garage entry's tank level fills the profile's only when empty", () {
      final empty = applyGarageVehicle(
        base,
        _custom(const VehicleSpecs(), tank: 25),
      );
      expect(empty.currentTankLevelPercent, 25);
      final set = applyGarageVehicle(
        base.copyWith(currentTankLevelPercent: 75),
        _custom(const VehicleSpecs(), tank: 25),
      );
      expect(set.currentTankLevelPercent, 75);
    });
  });

  group('wizard review fixes', () {
    testWidgets('going back and choosing another vehicle re-proposes the name',
        (tester) async {
      var n = 0;
      await tester.pumpWidget(_app(
        AddVehicleWizardScreen(defaultNameFor: (_) => 'Name ${++n}'),
      ));
      await tester.tap(find.byKey(const ValueKey('vehicle-kind-motorbike')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // fuel
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // name
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Name 1'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vehicle-kind-van')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // fuel
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // measures
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // name
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Name 1'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Name 2'), findsOneWidget);
    });

    testWidgets('a name the driver typed is kept', (tester) async {
      var n = 0;
      await tester.pumpWidget(_app(
        AddVehicleWizardScreen(defaultNameFor: (_) => 'Name ${++n}'),
      ));
      await tester.tap(find.byKey(const ValueKey('vehicle-kind-motorbike')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'My Vespa');
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'My Vespa'), findsOneWidget);
    });

    testWidgets('the name cannot exceed the 64 characters the server accepts',
        (tester) async {
      await tester.pumpWidget(_app(
        AddVehicleWizardScreen(defaultNameFor: (_) => 'x'),
      ));
      await tester.tap(find.byKey(const ValueKey('vehicle-kind-motorbike')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'a' * 90);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, 64);
    });

    testWidgets('choosing Electric swaps the combustion presets for EV ones',
        (tester) async {
      await tester.pumpWidget(_app(
        AddVehicleWizardScreen(defaultNameFor: (_) => 'x'),
      ));
      await tester.tap(find.byKey(const ValueKey('vehicle-kind-motorbike')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // fuel step
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '14'), findsOneWidget);

      await tester.tap(find.text('Electric'));
      await tester.pumpAndSettle();
      // 14 L / 5 L per 100 km would pass as a 14 kWh bike at 5 kWh/100 km.
      expect(find.widgetWithText(TextFormField, '8'), findsNWidgets(2));
      expect(find.text('kWh'), findsOneWidget);

      await tester.tap(find.text('Petrol'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '14'), findsOneWidget);
    });
  });
}
