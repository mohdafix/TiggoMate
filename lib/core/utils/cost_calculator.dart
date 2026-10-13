import 'package:flutter/foundation.dart';

/// Calculation inputs for deterministic energy and trip cost calculations.
@immutable
class TripCostInputs {
  /// Distance travelled in kilometres (> 0)
  final double distanceKm;

  /// Measured charging energy consumed in kWh (>= 0)
  final double electricEnergyKwh;

  /// Petrol fuel consumed in litres (>= 0)
  final double fuelLiters;

  /// Electricity tariff in RM per kWh (> 0)
  final double electricityTariffPerKwh;

  /// Petrol price in RM per litre (> 0)
  final double petrolPricePerLiter;

  /// Fractional charging loss (e.g. 0.10 for 10% AC-DC OBC loss)
  final double chargingLossFraction;

  const TripCostInputs({
    required this.distanceKm,
    this.electricEnergyKwh = 0.0,
    this.fuelLiters = 0.0,
    required this.electricityTariffPerKwh,
    required this.petrolPricePerLiter,
    this.chargingLossFraction = 0.0,
  });
}

/// Detailed calculation result with full provenance of assumptions and units.
@immutable
class TripCostResult {
  final double distanceKm;
  final double effectiveEnergyKwhWithLoss;
  final double electricityCostRm;
  final double petrolCostRm;
  final double totalCostRm;
  final double costPerKmRm;
  final double costPer100KmRm;

  // Comparison metrics for Tiggo 7 PHEV
  /// Equivalent pure petrol cost for same distance (using Tiggo 7 PHEV average ~6.5L/100km ICE mode)
  final double equivalentPurePetrolCostRm;

  /// Cost saved versus driving purely on petrol
  final double savingsVersusPurePetrolRm;

  /// Human-readable explanation of assumptions
  final List<String> assumptions;

  const TripCostResult({
    required this.distanceKm,
    required this.effectiveEnergyKwhWithLoss,
    required this.electricityCostRm,
    required this.petrolCostRm,
    required this.totalCostRm,
    required this.costPerKmRm,
    required this.costPer100KmRm,
    required this.equivalentPurePetrolCostRm,
    required this.savingsVersusPurePetrolRm,
    required this.assumptions,
  });
}

/// Deterministic calculation functions for energy, fuel, and trip costs.
class CostCalculator {
  CostCalculator._();

  /// Calculates trip costs deterministically.
  /// Throws [ArgumentError] if distance <= 0 or prices <= 0.
  static TripCostResult calculateTripCost(TripCostInputs inputs) {
    if (inputs.distanceKm <= 0) {
      throw ArgumentError.value(
        inputs.distanceKm,
        'distanceKm',
        'Distance must be greater than 0 km',
      );
    }
    if (inputs.electricityTariffPerKwh <= 0) {
      throw ArgumentError.value(
        inputs.electricityTariffPerKwh,
        'electricityTariffPerKwh',
        'Electricity tariff must be greater than 0',
      );
    }
    if (inputs.petrolPricePerLiter <= 0) {
      throw ArgumentError.value(
        inputs.petrolPricePerLiter,
        'petrolPricePerLiter',
        'Petrol price must be greater than 0',
      );
    }
    if (inputs.electricEnergyKwh < 0) {
      throw ArgumentError.value(
        inputs.electricEnergyKwh,
        'electricEnergyKwh',
        'Electric energy cannot be negative',
      );
    }
    if (inputs.fuelLiters < 0) {
      throw ArgumentError.value(
        inputs.fuelLiters,
        'fuelLiters',
        'Fuel litres cannot be negative',
      );
    }

    final effectiveLoss = inputs.chargingLossFraction.clamp(0.0, 0.50);
    // Effective energy drawn from grid = measured / (1 - loss)
    final effectiveEnergyKwh = (1.0 + effectiveLoss) * inputs.electricEnergyKwh;
    final electricityCost = effectiveEnergyKwh * inputs.electricityTariffPerKwh;
    final petrolCost = inputs.fuelLiters * inputs.petrolPricePerLiter;
    final totalCost = electricityCost + petrolCost;

    final costPerKm = totalCost / inputs.distanceKm;
    final costPer100Km = costPerKm * 100.0;

    // Benchmark comparison: Tiggo 7 petrol-only mode typically consumes 6.5 L/100km
    final benchmarkPurePetrolLiters = (inputs.distanceKm / 100.0) * 6.5;
    final equivalentPurePetrolCost =
        benchmarkPurePetrolLiters * inputs.petrolPricePerLiter;
    final savings = equivalentPurePetrolCost - totalCost;

    final assumptions = <String>[
      'Distance: ${inputs.distanceKm.toStringAsFixed(1)} km',
      'Electricity Tariff: RM ${inputs.electricityTariffPerKwh.toStringAsFixed(3)} / kWh',
      'Petrol Price: RM ${inputs.petrolPricePerLiter.toStringAsFixed(2)} / L',
      if (effectiveLoss > 0)
        'Grid Charging Loss: ${(effectiveLoss * 100).toStringAsFixed(0)}% factored into electrical draw',
      'Benchmark ICE baseline: 6.5 L / 100 km for Malaysian Tiggo 7 hybrid in depleted-battery mode',
    ];

    return TripCostResult(
      distanceKm: inputs.distanceKm,
      effectiveEnergyKwhWithLoss: effectiveEnergyKwh,
      electricityCostRm: electricityCost,
      petrolCostRm: petrolCost,
      totalCostRm: totalCost,
      costPerKmRm: costPerKm,
      costPer100KmRm: costPer100Km,
      equivalentPurePetrolCostRm: equivalentPurePetrolCost,
      savingsVersusPurePetrolRm: savings,
      assumptions: assumptions,
    );
  }

  /// Calculates the cost for 100 km pure EV vs pure Petrol on Malaysian Tiggo 7 PHEV.
  /// Electric baseline: ~17.5 kWh / 100 km (typical real-world Tiggo 7 PHEV city/mixed EV consumption)
  /// Petrol baseline: ~6.5 L / 100 km (typical real-world Tiggo 7 HEV depleted engine consumption)
  static Map<String, dynamic> compareCostPer100Km({
    required double electricityTariffPerKwh,
    required double petrolPricePerLiter,
    double evKwhPer100Km = 17.5,
    double petrolLitersPer100Km = 6.5,
    double chargingLossFraction = 0.10,
  }) {
    final effectiveEvKwh = evKwhPer100Km * (1.0 + chargingLossFraction);
    final pureEvCost100Km = effectiveEvKwh * electricityTariffPerKwh;
    final purePetrolCost100Km = petrolLitersPer100Km * petrolPricePerLiter;
    final savingsPer100Km = purePetrolCost100Km - pureEvCost100Km;
    final savingsPercent = purePetrolCost100Km > 0
        ? (savingsPer100Km / purePetrolCost100Km) * 100
        : 0.0;

    return {
      'pureEvCost100KmRm': pureEvCost100Km,
      'purePetrolCost100KmRm': purePetrolCost100Km,
      'savingsPer100KmRm': savingsPer100Km,
      'savingsPercent': savingsPercent,
      'evConsumptionKwh100Km': evKwhPer100Km,
      'petrolConsumptionL100Km': petrolLitersPer100Km,
      'tariffRm': electricityTariffPerKwh,
      'petrolPriceRm': petrolPricePerLiter,
    };
  }
}
