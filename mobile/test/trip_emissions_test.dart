import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart' show FuelCost;
import 'package:mytravelpal/domain/trip_emissions.dart';
import 'package:mytravelpal/domain/trip_profile.dart' show FuelType;

FuelCost _cost(FuelType type, double units) => FuelCost(
      totalCostEur: 0,
      averageUnitPriceEur: 0,
      fuelType: type,
      fuelUnits: units,
      unitLabel: type == FuelType.electric ? 'kWh' : 'L',
      rangeOk: true,
      notes: const [],
    );

void main() {
  group('tripEmissions', () {
    test('petrol uses 2.31 kg per litre', () {
      final e = tripEmissions(fuelCost: _cost(FuelType.petrol, 40), travellers: 1)!;
      expect(e.totalKg, closeTo(92.4, 0.01));
      expect(e.electric, isFalse);
    });

    test('diesel burns more CO2 per litre than petrol', () {
      final d = tripEmissions(fuelCost: _cost(FuelType.diesel, 40), travellers: 1)!;
      final p = tripEmissions(fuelCost: _cost(FuelType.petrol, 40), travellers: 1)!;
      expect(d.totalKg, greaterThan(p.totalKg));
    });

    test('LPG and E85 are lower than petrol per litre', () {
      final p = tripEmissions(fuelCost: _cost(FuelType.petrol, 10), travellers: 1)!;
      for (final t in [FuelType.lpg, FuelType.e85]) {
        final e = tripEmissions(fuelCost: _cost(t, 10), travellers: 1)!;
        expect(e.totalKg, lessThan(p.totalKg));
      }
    });

    test('the total is split between travellers', () {
      final e = tripEmissions(fuelCost: _cost(FuelType.petrol, 40), travellers: 4)!;
      expect(e.perPassengerKg, closeTo(e.totalKg / 4, 1e-9));
    });

    test('zero travellers never divides by zero', () {
      final e = tripEmissions(fuelCost: _cost(FuelType.petrol, 40), travellers: 0)!;
      expect(e.perPassengerKg, e.totalKg);
    });

    test('electric uses the grid factor and is flagged', () {
      final e = tripEmissions(fuelCost: _cost(FuelType.electric, 60), travellers: 1)!;
      expect(e.totalKg, closeTo(60 * kGridKgCo2PerKwh, 1e-9));
      expect(e.electric, isTrue);
    });

    test('no fuel used gives no figure', () {
      expect(tripEmissions(fuelCost: _cost(FuelType.petrol, 0), travellers: 1), isNull);
    });
  });
}
