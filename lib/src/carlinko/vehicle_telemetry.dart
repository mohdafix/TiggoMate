enum VehicleConnectionStatus {
  disconnected,
  connecting,
  connected,
  authRequired,
  error,
}

class VehicleTelemetry {
  final int batteryPct;
  final int electricRangeKm;
  final int fuelRangeKm;
  final int totalRangeKm;
  final int odometerKm;
  final double volt12;
  final double speedKmH;
  final bool isCharging;
  final double chargePowerKw;
  final int? chargeRemainMin;
  final bool acOn;
  final int acTemp;
  final bool doorsOpen;
  final bool trunkOpen;
  final bool windowsOpen;
  final bool sunroofOpen;
  final bool engineOn;
  final bool rapidCool;
  final bool frontDefrost;
  final bool rearDefrost;
  final bool airPurifier;
  final int fanGear; // 0 = Auto, 1..7
  final int seatHeatDriver; // 0..3
  final int seatVentDriver; // 0..3
  final int seatHeatPass; // 0..3
  final int seatVentPass; // 0..3
  final bool steeringHeat;
  final int airDurationMin;

  // Direct TPMS
  final double tyreFlPressureKpa;
  final double tyreFrPressureKpa;
  final double tyreRlPressureKpa;
  final double tyreRrPressureKpa;
  final double tyreFlTempC;
  final double tyreFrTempC;
  final double tyreRlTempC;
  final double tyreRrTempC;

  // GPS & Positioning (CarLinko Find My Car)
  final double latitude;
  final double longitude;
  final double headingDegrees;
  final String locationName;
  final bool isParked;
  final String parkedDurationText;

  final DateTime lastUpdated;
  final bool isSimulated;
  final String dataSourceLabel;

  const VehicleTelemetry({
    this.batteryPct = 78,
    this.electricRangeKm = 82,
    this.fuelRangeKm = 838,
    this.totalRangeKm = 920,
    this.odometerKm = 3420,
    this.volt12 = 12.82,
    this.speedKmH = 0.0,
    this.isCharging = false,
    this.chargePowerKw = 0.0,
    this.chargeRemainMin,
    this.acOn = false,
    this.acTemp = 22,
    this.doorsOpen = false,
    this.trunkOpen = false,
    this.windowsOpen = false,
    this.sunroofOpen = false,
    this.engineOn = false,
    this.rapidCool = false,
    this.frontDefrost = false,
    this.rearDefrost = false,
    this.airPurifier = true,
    this.fanGear = 0,
    this.seatHeatDriver = 0,
    this.seatVentDriver = 0,
    this.seatHeatPass = 0,
    this.seatVentPass = 0,
    this.steeringHeat = false,
    this.airDurationMin = 10,
    this.tyreFlPressureKpa = 235.0,
    this.tyreFrPressureKpa = 234.0,
    this.tyreRlPressureKpa = 236.0,
    this.tyreRrPressureKpa = 235.0,
    this.tyreFlTempC = 32.0,
    this.tyreFrTempC = 33.0,
    this.tyreRlTempC = 31.0,
    this.tyreRrTempC = 31.0,
    this.latitude = 3.1189,
    this.longitude = 101.6672,
    this.headingDegrees = 38.0,
    this.locationName = 'The Sphere, Bangsar South, KL',
    this.isParked = true,
    this.parkedDurationText = 'Parked 42m ago',
    required this.lastUpdated,
    this.isSimulated = true,
    this.dataSourceLabel = 'SIMULATED DATA (CarLinko Not Activated)',
  });

  /// Factory creating validated telemetry from decoded CarLinko blob map.
  factory VehicleTelemetry.fromBlobMap(Map<String, dynamic> m, {required bool isSimulated}) {
    final int batt = (m['battery_pct'] as num?)?.toInt() ?? 0;
    final int evRange = (m['range_km'] as num?)?.toInt() ?? 0;
    final int odo = (m['odometer'] as num?)?.toInt() ?? 0;
    final double v12 = (m['volt12'] as num?)?.toDouble() ?? 12.6;
    final double spd = (m['speed'] as num?)?.toDouble() ?? 0.0;
    final bool charging = (m['charge_state'] as num?)?.toInt() == 1;
    final double pwr = (m['charge_power_kw'] as num?)?.toDouble() ?? 0.0;
    final int? remMin = (m['charge_remain_min'] as num?)?.toInt();

    // TPMS
    final double flP = (m['tyre_fl_pressure'] as num?)?.toDouble() ?? 230.0;
    final double frP = (m['tyre_fr_pressure'] as num?)?.toDouble() ?? 230.0;
    final double rlP = (m['tyre_rl_pressure'] as num?)?.toDouble() ?? 230.0;
    final double rrP = (m['tyre_rr_pressure'] as num?)?.toDouble() ?? 230.0;

    final double flT = (m['tyre_fl_temp'] as num?)?.toDouble() ?? 30.0;
    final double frT = (m['tyre_fr_temp'] as num?)?.toDouble() ?? 30.0;
    final double rlT = (m['tyre_rl_temp'] as num?)?.toDouble() ?? 30.0;
    final double rrT = (m['tyre_rr_temp'] as num?)?.toDouble() ?? 30.0;

    // Fuel Range calculation based on Chery Tiggo 7 PHEV 51L fuel tank
    const int estimatedFuelRange = 838;

    return VehicleTelemetry(
      batteryPct: batt.clamp(0, 100),
      electricRangeKm: evRange,
      fuelRangeKm: estimatedFuelRange,
      totalRangeKm: evRange + estimatedFuelRange,
      odometerKm: odo,
      volt12: v12,
      speedKmH: spd,
      isCharging: charging,
      chargePowerKw: pwr,
      chargeRemainMin: remMin,
      acOn: m['ac_on'] == true,
      acTemp: (m['ac_temp'] as num?)?.toInt() ?? 23,
      doorsOpen: (m['doors'] as num?)?.toInt() != 0,
      trunkOpen: (m['trunk'] as num?)?.toInt() != 0,
      windowsOpen: (m['windows'] as num?)?.toInt() != 0,
      sunroofOpen: (m['sunroof'] as num?)?.toInt() != 0,
      engineOn: (m['hv_state'] as num?)?.toInt() != 0,
      tyreFlPressureKpa: flP,
      tyreFrPressureKpa: frP,
      tyreRlPressureKpa: rlP,
      tyreRrPressureKpa: rrP,
      tyreFlTempC: flT,
      tyreFrTempC: frT,
      tyreRlTempC: rlT,
      tyreRrTempC: rrT,
      latitude: (m['lat'] as num?)?.toDouble() ?? 3.1189,
      longitude: (m['lon'] as num?)?.toDouble() ?? 101.6672,
      headingDegrees: (m['heading'] as num?)?.toDouble() ?? 38.0,
      locationName: (m['location_name'] as String?) ?? 'The Sphere, Bangsar South, KL',
      isParked: (m['is_parked'] as bool?) ?? true,
      parkedDurationText: (m['parked_duration'] as String?) ?? 'Parked 42m ago',
      lastUpdated: DateTime.now(),
      isSimulated: isSimulated,
      dataSourceLabel: isSimulated ? 'SIMULATED DATA (CarLinko Not Activated)' : 'LIVE CARLINKO TELEMATICS',
    );
  }

  /// Convert kPa to PSI for dual automotive readouts.
  static double kpaToPsi(double kpa) => kpa * 0.145038;

  VehicleTelemetry copyWith({
    int? batteryPct,
    int? electricRangeKm,
    int? fuelRangeKm,
    int? totalRangeKm,
    int? odometerKm,
    double? volt12,
    double? speedKmH,
    bool? isCharging,
    double? chargePowerKw,
    int? chargeRemainMin,
    bool? acOn,
    int? acTemp,
    bool? doorsOpen,
    bool? trunkOpen,
    bool? windowsOpen,
    bool? sunroofOpen,
    bool? engineOn,
    bool? rapidCool,
    bool? frontDefrost,
    bool? rearDefrost,
    bool? airPurifier,
    int? fanGear,
    int? seatHeatDriver,
    int? seatVentDriver,
    int? seatHeatPass,
    int? seatVentPass,
    bool? steeringHeat,
    int? airDurationMin,
    double? tyreFlPressureKpa,
    double? tyreFrPressureKpa,
    double? tyreRlPressureKpa,
    double? tyreRrPressureKpa,
    double? tyreFlTempC,
    double? tyreFrTempC,
    double? tyreRlTempC,
    double? tyreRrTempC,
    double? latitude,
    double? longitude,
    double? headingDegrees,
    String? locationName,
    bool? isParked,
    String? parkedDurationText,
    DateTime? lastUpdated,
    bool? isSimulated,
    String? dataSourceLabel,
  }) {
    return VehicleTelemetry(
      batteryPct: batteryPct ?? this.batteryPct,
      electricRangeKm: electricRangeKm ?? this.electricRangeKm,
      fuelRangeKm: fuelRangeKm ?? this.fuelRangeKm,
      totalRangeKm: totalRangeKm ?? this.totalRangeKm,
      odometerKm: odometerKm ?? this.odometerKm,
      volt12: volt12 ?? this.volt12,
      speedKmH: speedKmH ?? this.speedKmH,
      isCharging: isCharging ?? this.isCharging,
      chargePowerKw: chargePowerKw ?? this.chargePowerKw,
      chargeRemainMin: chargeRemainMin ?? this.chargeRemainMin,
      acOn: acOn ?? this.acOn,
      acTemp: acTemp ?? this.acTemp,
      doorsOpen: doorsOpen ?? this.doorsOpen,
      trunkOpen: trunkOpen ?? this.trunkOpen,
      windowsOpen: windowsOpen ?? this.windowsOpen,
      sunroofOpen: sunroofOpen ?? this.sunroofOpen,
      engineOn: engineOn ?? this.engineOn,
      rapidCool: rapidCool ?? this.rapidCool,
      frontDefrost: frontDefrost ?? this.frontDefrost,
      rearDefrost: rearDefrost ?? this.rearDefrost,
      airPurifier: airPurifier ?? this.airPurifier,
      fanGear: fanGear ?? this.fanGear,
      seatHeatDriver: seatHeatDriver ?? this.seatHeatDriver,
      seatVentDriver: seatVentDriver ?? this.seatVentDriver,
      seatHeatPass: seatHeatPass ?? this.seatHeatPass,
      seatVentPass: seatVentPass ?? this.seatVentPass,
      steeringHeat: steeringHeat ?? this.steeringHeat,
      airDurationMin: airDurationMin ?? this.airDurationMin,
      tyreFlPressureKpa: tyreFlPressureKpa ?? this.tyreFlPressureKpa,
      tyreFrPressureKpa: tyreFrPressureKpa ?? this.tyreFrPressureKpa,
      tyreRlPressureKpa: tyreRlPressureKpa ?? this.tyreRlPressureKpa,
      tyreRrPressureKpa: tyreRrPressureKpa ?? this.tyreRrPressureKpa,
      tyreFlTempC: tyreFlTempC ?? this.tyreFlTempC,
      tyreFrTempC: tyreFrTempC ?? this.tyreFrTempC,
      tyreRlTempC: tyreRlTempC ?? this.tyreRlTempC,
      tyreRrTempC: tyreRrTempC ?? this.tyreRrTempC,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      locationName: locationName ?? this.locationName,
      isParked: isParked ?? this.isParked,
      parkedDurationText: parkedDurationText ?? this.parkedDurationText,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isSimulated: isSimulated ?? this.isSimulated,
      dataSourceLabel: dataSourceLabel ?? this.dataSourceLabel,
    );
  }
}
