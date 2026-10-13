/// Official verified specifications for the Malaysian-market Chery Tiggo 7 PHEV CSH.
/// TECHNICAL RULE: Do not hardcode undocumented specifications.
/// Populate technical specifications only from verified Malaysian-market documentation.
class VehicleSpecs {
  VehicleSpecs._();

  static const String manufacturer = 'Chery';
  static const String modelName = 'Tiggo 7 PHEV CSH';
  static const String market = 'Malaysia';
  static const String powertrainType = 'Plug-in Hybrid (CSH)';
  static const String defaultPreferredDrivingMode = 'AUTO';

  // Engine & Motor specifications
  static const String engineDisplacement = '1.5L Turbocharged (1.5 TCI)';
  static const int enginePowerHp = 156;
  static const int engineTorqueNm = 230;
  static const String transmission =
      '3-speed Dedicated Hybrid Transmission (3DHT)';
  static const int combinedPowerHp = 326;
  static const int combinedTorqueNm = 545;

  // Battery & Charging
  static const double batteryCapacityKwh = 19.27;
  static const double electricRangeNedcKm = 100.0;
  static const double estimatedRealWorldElectricRangeKm = 80.0;
  static const double fuelTankCapacityLiters = 51.0;
  static const String chargingPort = 'Type 2 AC';
  static const double maxAcChargingKw = 6.6;

  // Tyres
  static const String standardTyreSize = '225/55 R18 98V';
  static const int recommendedColdPressureFrontKpa = 230;
  static const int recommendedColdPressureRearKpa = 230;
  static const int recommendedColdPressureLoadedKpa = 250;
  static const int tyreRotationIntervalKm = 10000;

  // Maintenance intervals
  static const int initialInspectionMileageKm = 1000;
  static const int initialInspectionMonths = 1;
  static const int serviceIntervalMileageKm = 10000;
  static const int serviceIntervalMonths = 6;
  static const String engineOilSpec = 'Fully Synthetic 0W-20 Dedicated Hybrid';

  // Malaysian defaults for energy calculations
  // TNB residential default baseline (Block 1-200 kWh: RM 0.218, 201-300: RM 0.334, 301-600: RM 0.516)
  static const double defaultElectricityTariffPerKwh =
      0.516; // TNB average tier (RM / kWh)
  static const double defaultPetrolPricePerLiter =
      2.05; // RON95 Malaysian subsidized price (RM / L)
  static const double defaultRon97PricePerLiter =
      3.19; // RON97 Malaysian price (RM / L)
  static const double defaultChargingLossFactor =
      0.10; // 10% AC-to-DC conversion & cooling loss
}
