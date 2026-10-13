import 'package:flutter_test/flutter_test.dart';
import 'package:tiggomate/core/utils/cost_calculator.dart';

void main() {
  group('CostCalculator Unit Tests', () {
    test(
      'calculateTripCost computes deterministic costs correctly with charging loss',
      () {
        final inputs = TripCostInputs(
          distanceKm: 100.0,
          electricEnergyKwh: 15.0,
          fuelLiters: 2.0,
          electricityTariffPerKwh: 0.516, // RM 0.516/kWh
          petrolPricePerLiter: 2.05, // RM 2.05/L
          chargingLossFraction:
              0.10, // 10% loss -> 15 * 1.10 = 16.5 kWh effective
        );

        final result = CostCalculator.calculateTripCost(inputs);

        // 16.5 kWh * 0.516 = 8.514
        expect(result.electricityCostRm, closeTo(8.514, 0.001));
        // 2.0 L * 2.05 = 4.10
        expect(result.petrolCostRm, closeTo(4.10, 0.001));
        // Total = 8.514 + 4.10 = 12.614
        expect(result.totalCostRm, closeTo(12.614, 0.001));
        // Cost per km = 12.614 / 100 = 0.12614
        expect(result.costPerKmRm, closeTo(0.12614, 0.0001));
        // Cost per 100 km = 12.614
        expect(result.costPer100KmRm, closeTo(12.614, 0.001));

        // Pure petrol baseline: 100km * 6.5L/100km = 6.5L * 2.05 = RM 13.325
        expect(result.equivalentPurePetrolCostRm, closeTo(13.325, 0.001));
        // Savings = 13.325 - 12.614 = 0.711
        expect(result.savingsVersusPurePetrolRm, closeTo(0.711, 0.001));
      },
    );

    test('calculateTripCost throws ArgumentError for invalid distance', () {
      expect(
        () => CostCalculator.calculateTripCost(
          const TripCostInputs(
            distanceKm: 0.0,
            electricityTariffPerKwh: 0.516,
            petrolPricePerLiter: 2.05,
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => CostCalculator.calculateTripCost(
          const TripCostInputs(
            distanceKm: -10.0,
            electricityTariffPerKwh: 0.516,
            petrolPricePerLiter: 2.05,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('calculateTripCost throws ArgumentError for invalid tariffs', () {
      expect(
        () => CostCalculator.calculateTripCost(
          const TripCostInputs(
            distanceKm: 50.0,
            electricityTariffPerKwh: -0.1,
            petrolPricePerLiter: 2.05,
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => CostCalculator.calculateTripCost(
          const TripCostInputs(
            distanceKm: 50.0,
            electricityTariffPerKwh: 0.516,
            petrolPricePerLiter: 0.0,
          ),
        ),
        throwsArgumentError,
      );
    });

    test(
      'compareCostPer100Km calculates EV vs Petrol comparison correctly',
      () {
        final comparison = CostCalculator.compareCostPer100Km(
          electricityTariffPerKwh: 0.516,
          petrolPricePerLiter: 2.05,
          evKwhPer100Km: 17.5,
          petrolLitersPer100Km: 6.5,
          chargingLossFraction: 0.10,
        );

        // EV: 17.5 * 1.10 * 0.516 = 9.933
        expect(comparison['pureEvCost100KmRm'], closeTo(9.933, 0.01));
        // Petrol: 6.5 * 2.05 = 13.325
        expect(comparison['purePetrolCost100KmRm'], closeTo(13.325, 0.01));
        // Savings = 13.325 - 9.933 = 3.392
        expect(comparison['savingsPer100KmRm'], closeTo(3.392, 0.01));
        // Savings percent ~ 25.4%
        expect(comparison['savingsPercent'], closeTo(25.45, 0.2));
      },
    );
  });
}
