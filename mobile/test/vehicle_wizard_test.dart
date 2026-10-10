import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/domain/garage_vehicle.dart';
import 'package:mytravelpal/domain/trip_profile.dart';
import 'package:mytravelpal/domain/vehicle_kind.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/screens/add_vehicle_wizard.dart';
import 'package:mytravelpal/screens/vehicle_picker_screen.dart'
    show kCustomVehicleId;
import 'package:mytravelpal/services/garage_profile.dart';

GarageVehicle _gv(String modelId, VehicleSpecs s, {int tank = 100}) =>
    GarageVehicle(
      id: 'g1', name: 'X', modelId: modelId,
      defaultTankPercent: tank, notes: s.toNotes(),
    );

void main() {
  group('VehicleSpecs notes', () {
    test('round trip keeps every field', () {
      const s = VehicleSpecs(
        kind: VehicleKind.truck, fuelType: FuelType.diesel,
        tankL: 400, consumptionL100km: 30.5,
        heightM: 3.8, lengthM: 12, weightT: 18, axles: 3,
      );
      final back = VehicleSpecs.fromNotes(s.toNotes());
      expect(back.kind, VehicleKind.truck);
      expect(back.fuelType, FuelType.diesel);
      expect(back.tankL, 400);
      expect(back.consumptionL100km, 30.5);
      expect(back.heightM, 3.8);
      expect(back.lengthM, 12);
      expect(back.weightT, 18);
      expect(back.axles, 3);
    });

    test('the largest vehicle still fits the server limit of 280 chars', () {
      const s = VehicleSpecs(
        kind: VehicleKind.truck, fuelType: FuelType.hybrid,
        tankL: 1000, consumptionL100km: 80,
        heightM: 4.5, lengthM: 25, weightT: 44, axles: 6,
      );
      expect(s.toNotes().length, lessThan(280));
    });

    test('entries saved before the wizard still read (t, c, f only)', () {
      final s = VehicleSpecs.fromNotes(
        jsonEncode({'t': 55.0, 'c': 7.5, 'f': 'petrol'}),
      );
      expect(s.kind, VehicleKind.car);
      expect(s.tankL, 55);
      expect(s.fuelType, FuelType.petrol);
      expect(s.hasEngineSpecs, isTrue);
    });

    test('null, blank, free text and unknown fuel never throw', () {
      for (final n in [null, '', '   ', 'my old car', '[1,2]', '{"f":"plasma"}']) {
        final s = VehicleSpecs.fromNotes(n);
        expect(s.kind, VehicleKind.car);
      }
      expect(VehicleSpecs.fromNotes('{"f":"plasma"}').fuelType, isNull);
    });

    test('a garage entry exposes its kind', () {
      expect(_gv('x', const VehicleSpecs(kind: VehicleKind.camper)).kind,
          VehicleKind.camper);
      expect(
        const GarageVehicle(
          id: 'a', name: 'old', modelId: 'm', defaultTankPercent: 50,
        ).kind,
        VehicleKind.car,
      );
    });
  });

  group('VehicleKind', () {
    test('a truck is planned as a van; the others as themselves', () {
      expect(VehicleKind.truck.planningType, VehicleType.van);
      expect(VehicleKind.car.planningType, VehicleType.car);
      expect(VehicleKind.motorbike.planningType, VehicleType.motorbike);
      expect(VehicleKind.camper.planningType, VehicleType.camper);
      expect(VehicleKind.van.planningType, VehicleType.van);
    });

    test('only vans, campers and trucks need measures; only cars have a catalogue', () {
      expect(VehicleKind.values.where((k) => k.needsDimensions),
          [VehicleKind.van, VehicleKind.camper, VehicleKind.truck]);
      expect(VehicleKind.values.where((k) => k.hasCatalogue), [VehicleKind.car]);
    });
  });

  group('applyGarageVehicle', () {
    const base = TripProfile();

    test('a typed-in camper sets type, fuel, tank and consumption', () {
      final p = applyGarageVehicle(
        base,
        _gv(
          kCustomVehicleId,
          const VehicleSpecs(
            kind: VehicleKind.camper, fuelType: FuelType.diesel,
            tankL: 90, consumptionL100km: 12,
          ),
        ),
      );
      expect(p.vehicle.type, VehicleType.camper);
      expect(p.vehicle.fuelType, FuelType.diesel);
      expect(p.vehicle.fuelTankL, 90);
      expect(p.vehicle.consumptionLPer100km, 12);
    });

    test('a truck goes to the server as a van', () {
      final p = applyGarageVehicle(
        base,
        _gv(
          kCustomVehicleId,
          const VehicleSpecs(
            kind: VehicleKind.truck, fuelType: FuelType.diesel,
            tankL: 400, consumptionL100km: 30,
          ),
        ),
      );
      expect(p.vehicle.type, VehicleType.van);
      expect(p.vehicle.fuelTankL, 400);
    });

    test('an electric vehicle derives its range from battery and consumption', () {
      final p = applyGarageVehicle(
        base,
        _gv(
          kCustomVehicleId,
          const VehicleSpecs(
            kind: VehicleKind.car, fuelType: FuelType.electric,
            tankL: 60, consumptionL100km: 15,
          ),
        ),
      );
      expect(p.vehicle.fuelType, FuelType.electric);
      expect(p.vehicle.consumptionKwhPer100km, 15);
      expect(p.vehicle.evRangeKm, closeTo(400, 1e-9));
    });

    test('a catalogue car keeps the profile engine figures', () {
      final p = applyGarageVehicle(
        base.copyWith(vehicle: const Vehicle(fuelTankL: 61, consumptionLPer100km: 6.1)),
        _gv('seat_leon', const VehicleSpecs(kind: VehicleKind.car)),
      );
      expect(p.vehicle.fuelTankL, 61);
      expect(p.vehicle.consumptionLPer100km, 6.1);
      expect(p.vehicleModelId, 'seat_leon');
    });

    test('an old entry without specs changes nothing but the model id', () {
      final p = applyGarageVehicle(
        base,
        const GarageVehicle(
          id: 'o', name: 'old', modelId: kCustomVehicleId, defaultTankPercent: 100,
        ),
      );
      expect(p.vehicle.fuelTankL, base.vehicle.fuelTankL);
      expect(p.vehicle.type, VehicleType.car);
    });
  });

  group('AddVehicleWizardScreen', () {
    Future<NewVehicleDraft?> run(WidgetTester tester, Future<void> Function() drive) async {
      NewVehicleDraft? result;
      var done = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await Navigator.of(ctx).push<NewVehicleDraft>(
                        MaterialPageRoute(
                          builder: (_) => AddVehicleWizardScreen(
                            defaultNameFor: (_) => 'My vehicle',
                          ),
                        ),
                      );
                      done = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await drive();
      expect(done, isTrue);
      return result;
    }

    testWidgets('nothing can be saved before a type is chosen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddVehicleWizardScreen(defaultNameFor: (_) => 'x'),
        ),
      );
      final next = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(next.onPressed, isNull);
      expect(find.text('Step 1 of 1'), findsOneWidget);
    });

    testWidgets('a truck goes through type, fuel, measures and name', (tester) async {
      final draft = await run(tester, () async {
        await tester.tap(find.byKey(const ValueKey('vehicle-kind-truck')));
        await tester.pumpAndSettle();
        expect(find.text('Step 1 of 4'), findsOneWidget);

        await tester.tap(find.text('Next')); // -> fuel and consumption
        await tester.pumpAndSettle();
        expect(find.text('Fuel and consumption'), findsOneWidget);

        await tester.tap(find.text('Next')); // -> measures (defaults are valid)
        await tester.pumpAndSettle();
        expect(find.text('Size and weight'), findsOneWidget);
        expect(find.text('Axles'), findsOneWidget);

        await tester.tap(find.text('4')); // axles
        await tester.pump();
        await tester.tap(find.text('Next')); // -> name
        await tester.pumpAndSettle();
        expect(find.text('Name and starting level'), findsOneWidget);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      });
      expect(draft, isNotNull);
      expect(draft!.name, 'My vehicle');
      expect(draft.modelId, kCustomVehicleId);
      final specs = VehicleSpecs.fromNotes(draft.notes);
      expect(specs.kind, VehicleKind.truck);
      expect(specs.axles, 4);
      expect(specs.heightM, 3.8);
      expect(specs.fuelType, FuelType.diesel);
    });

    testWidgets('a motorbike skips measures and goes straight to its fuel', (tester) async {
      final draft = await run(tester, () async {
        await tester.tap(find.byKey(const ValueKey('vehicle-kind-motorbike')));
        await tester.pumpAndSettle();
        expect(find.text('Step 1 of 3'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Size and weight'), findsNothing);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      });
      final specs = VehicleSpecs.fromNotes(draft!.notes);
      expect(specs.kind, VehicleKind.motorbike);
      expect(specs.heightM, isNull);
      expect(specs.tankL, 14);
    });

    testWidgets('a car offers the catalogue step', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddVehicleWizardScreen(defaultNameFor: (_) => 'x'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('vehicle-kind-car')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Find my model'), findsOneWidget);
    });

    testWidgets('an out-of-range figure blocks the step with a message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddVehicleWizardScreen(defaultNameFor: (_) => 'x'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('vehicle-kind-camper')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // fuel step
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next')); // measures
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '9'); // height
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Between 1.5 and 4.5'), findsOneWidget);
      expect(find.text('Size and weight'), findsOneWidget);
    });
  });
}
