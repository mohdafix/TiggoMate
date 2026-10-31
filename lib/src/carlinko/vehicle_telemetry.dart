enum VehicleConnectionStatus {
  disconnected,
  connecting,
  connected,
  authRequired,
  error,
}

/// Display unit for tyre pressure readouts.
enum TyrePressureUnit {
  kpa('kPa'),
  psi('psi'),
  bar('bar');

  final String label;
  const TyrePressureUnit(this.label);

  /// Next unit in the cycle (kPa -> psi -> bar -> kPa), for a tap-to-switch control.
  TyrePressureUnit get next => TyrePressureUnit.values[(index + 1) % TyrePressureUnit.values.length];

  /// Converts a kPa reading to this unit. Returns null unchanged (no reading).
  double? fromKpa(double? kpa) {
    if (kpa == null) return null;
    switch (this) {
      case TyrePressureUnit.kpa:
        return kpa;
      case TyrePressureUnit.psi:
        return VehicleTelemetry.kpaToPsi(kpa);
      case TyrePressureUnit.bar:
        return VehicleTelemetry.kpaToBar(kpa);
    }
  }
}

class VehicleTelemetry {
  final int batteryPct;
  final int electricRangeKm;
  final int fuelRangeKm;
  /// Fuel tank level, 0-100. 0 means unknown (no reading), same convention
  /// as [batteryPct]'s other telemetry fields.
  final int fuelCapacityPct;
  final int totalRangeKm;
  final int odometerKm;
  final double volt12;
  final double speedKmH;
  final bool isCharging;
  final double chargePowerKw;
  final int? chargeRemainMin;
  /// Average fuel consumption, L/100km. 0 means unknown.
  final double fuelConsumptionL100km;
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
  final bool isBound;
  final String dataSourceLabel;

  const VehicleTelemetry({
    this.batteryPct = 0,
    this.electricRangeKm = 0,
    this.fuelRangeKm = 0,
    this.fuelCapacityPct = 0,
    this.totalRangeKm = 0,
    this.odometerKm = 0,
    this.volt12 = 0.0,
    this.speedKmH = 0.0,
    this.isCharging = false,
    this.chargePowerKw = 0.0,
    this.chargeRemainMin,
    this.fuelConsumptionL100km = 0.0,
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
    this.airPurifier = false,
    this.fanGear = 0,
    this.seatHeatDriver = 0,
    this.seatVentDriver = 0,
    this.seatHeatPass = 0,
    this.seatVentPass = 0,
    this.steeringHeat = false,
    this.airDurationMin = 10,
    this.tyreFlPressureKpa = 0.0,
    this.tyreFrPressureKpa = 0.0,
    this.tyreRlPressureKpa = 0.0,
    this.tyreRrPressureKpa = 0.0,
    this.tyreFlTempC = 0.0,
    this.tyreFrTempC = 0.0,
    this.tyreRlTempC = 0.0,
    this.tyreRrTempC = 0.0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.headingDegrees = 0.0,
    this.locationName = 'Pending Car Bind',
    this.isParked = true,
    this.parkedDurationText = 'Awaiting CarLinko Bind',
    required this.lastUpdated,
    this.isSimulated = false,
    this.isBound = false,
    this.dataSourceLabel = 'Pending Car Bind',
  });

  /// Factory creating unbound/pending telemetry when vehicle is awaiting CarLinko pairing.
  factory VehicleTelemetry.unbound({
    String label = 'Pending Car Bind',
    DateTime? timestamp,
  }) {
    return VehicleTelemetry(
      batteryPct: 0,
      electricRangeKm: 0,
      fuelRangeKm: 0,
      totalRangeKm: 0,
      odometerKm: 0,
      volt12: 0.0,
      speedKmH: 0.0,
      isCharging: false,
      chargePowerKw: 0.0,
      chargeRemainMin: null,
      acOn: false,
      acTemp: 22,
      doorsOpen: false,
      trunkOpen: false,
      windowsOpen: false,
      sunroofOpen: false,
      engineOn: false,
      rapidCool: false,
      frontDefrost: false,
      rearDefrost: false,
      airPurifier: false,
      fanGear: 0,
      seatHeatDriver: 0,
      seatVentDriver: 0,
      seatHeatPass: 0,
      seatVentPass: 0,
      steeringHeat: false,
      airDurationMin: 10,
      tyreFlPressureKpa: 0.0,
      tyreFrPressureKpa: 0.0,
      tyreRlPressureKpa: 0.0,
      tyreRrPressureKpa: 0.0,
      tyreFlTempC: 0.0,
      tyreFrTempC: 0.0,
      tyreRlTempC: 0.0,
      tyreRrTempC: 0.0,
      latitude: 0.0,
      longitude: 0.0,
      headingDegrees: 0.0,
      locationName: 'Pending Car Bind',
      isParked: true,
      parkedDurationText: 'Awaiting CarLinko Bind',
      lastUpdated: timestamp ?? DateTime.now(),
      isSimulated: false,
      isBound: false,
      dataSourceLabel: label,
    );
  }

  /// Factory creating sample telemetry for automated tests.
  factory VehicleTelemetry.sampleData({DateTime? timestamp}) {
    return VehicleTelemetry(
      batteryPct: 78,
      electricRangeKm: 82,
      fuelRangeKm: 838,
      totalRangeKm: 920,
      odometerKm: 3420,
      volt12: 12.82,
      speedKmH: 0.0,
      isCharging: false,
      chargePowerKw: 0.0,
      chargeRemainMin: null,
      acOn: false,
      acTemp: 22,
      doorsOpen: false,
      trunkOpen: false,
      windowsOpen: false,
      sunroofOpen: false,
      engineOn: false,
      rapidCool: false,
      frontDefrost: false,
      rearDefrost: false,
      airPurifier: true,
      fanGear: 0,
      seatHeatDriver: 0,
      seatVentDriver: 0,
      seatHeatPass: 0,
      seatVentPass: 0,
      steeringHeat: false,
      airDurationMin: 10,
      tyreFlPressureKpa: 235.0,
      tyreFrPressureKpa: 234.0,
      tyreRlPressureKpa: 236.0,
      tyreRrPressureKpa: 235.0,
      tyreFlTempC: 32.0,
      tyreFrTempC: 33.0,
      tyreRlTempC: 31.0,
      tyreRrTempC: 31.0,
      latitude: 3.1189,
      longitude: 101.6672,
      headingDegrees: 38.0,
      locationName: 'The Sphere, Bangsar South, KL',
      isParked: true,
      parkedDurationText: 'Parked 42m ago',
      lastUpdated: timestamp ?? DateTime.now(),
      isSimulated: true,
      isBound: true,
      dataSourceLabel: 'Chery CarLinko Sample Data',
    );
  }

  /// Factory creating validated telemetry from decoded CarLinko blob map.
  factory VehicleTelemetry.fromBlobMap(Map<String, dynamic> m, {required bool isSimulated}) {
    final int batt = (m['battery_pct'] as num?)?.toInt() ?? 0;
    final int evRange = (m['range_km'] as num?)?.toInt() ?? 0;
    final int odo = (m['odometer'] as num?)?.toInt() ?? 0;
    final double v12 = (m['volt12'] as num?)?.toDouble() ?? 0.0;
    final double spd = (m['speed'] as num?)?.toDouble() ?? 0.0;
    final bool charging = (m['charge_state'] as num?)?.toInt() == 1;
    final double pwr = (m['charge_power_kw'] as num?)?.toDouble() ?? 0.0;
    final int? remMin = (m['charge_remain_min'] as num?)?.toInt();
    final double fuelCons = (m['fuel_consumption_l100km'] as num?)?.toDouble() ?? 0.0;

    // TPMS: 0 means no reading, and the UI shows it as blank
    final double flP = (m['tyre_fl_pressure'] as num?)?.toDouble() ?? 0.0;
    final double frP = (m['tyre_fr_pressure'] as num?)?.toDouble() ?? 0.0;
    final double rlP = (m['tyre_rl_pressure'] as num?)?.toDouble() ?? 0.0;
    final double rrP = (m['tyre_rr_pressure'] as num?)?.toDouble() ?? 0.0;

    final double flT = (m['tyre_fl_temp'] as num?)?.toDouble() ?? 0.0;
    final double frT = (m['tyre_fr_temp'] as num?)?.toDouble() ?? 0.0;
    final double rlT = (m['tyre_rl_temp'] as num?)?.toDouble() ?? 0.0;
    final double rrT = (m['tyre_rr_temp'] as num?)?.toDouble() ?? 0.0;

    // 0 means unknown: the blob reports no fuel range unless it sends fuel_range_km
    final int estimatedFuelRange = (m['fuel_range_km'] as num?)?.toInt() ?? 0;
    final int fuelCap = (m['fuel_capacity_pct'] as num?)?.toInt() ?? 0;

    final double lat = (m['lat'] as num?)?.toDouble() ?? 0.0;
    final double lon = (m['lon'] as num?)?.toDouble() ?? 0.0;
    final bool parked = (m['is_parked'] as bool?) ?? spd <= 0;

    return VehicleTelemetry(
      batteryPct: batt.clamp(0, 100),
      electricRangeKm: evRange,
      fuelRangeKm: estimatedFuelRange,
      fuelCapacityPct: fuelCap.clamp(0, 100),
      totalRangeKm: evRange + estimatedFuelRange,
      odometerKm: odo,
      volt12: v12,
      speedKmH: spd,
      isCharging: charging,
      chargePowerKw: pwr,
      chargeRemainMin: remMin,
      fuelConsumptionL100km: fuelCons,
      acOn: m['ac_on'] == true,
      acTemp: (m['ac_temp'] as num?)?.toInt() ?? 23,
      doorsOpen: ((m['doors'] as num?)?.toInt() ?? 0) != 0,
      trunkOpen: ((m['trunk'] as num?)?.toInt() ?? 0) != 0,
      windowsOpen: ((m['windows'] as num?)?.toInt() ?? 0) != 0,
      sunroofOpen: ((m['sunroof'] as num?)?.toInt() ?? 0) != 0,
      engineOn: ((m['hv_state'] as num?)?.toInt() ?? 0) != 0,
      tyreFlPressureKpa: flP,
      tyreFrPressureKpa: frP,
      tyreRlPressureKpa: rlP,
      tyreRrPressureKpa: rrP,
      tyreFlTempC: flT,
      tyreFrTempC: frT,
      tyreRlTempC: rlT,
      tyreRrTempC: rrT,
      latitude: lat,
      longitude: lon,
      headingDegrees: (m['heading'] as num?)?.toDouble() ?? 0.0,
      locationName: (m['location_name'] as String?) ??
          (lat != 0.0 || lon != 0.0 ? 'Last reported position' : 'Location unavailable'),
      isParked: parked,
      parkedDurationText: (m['parked_duration'] as String?) ?? (parked ? 'Parked' : 'Moving'),
      lastUpdated: DateTime.now(),
      isSimulated: isSimulated,
      isBound: !isSimulated,
      dataSourceLabel: isSimulated ? 'Chery CarLinko Cloud • Simulated' : 'LIVE CARLINKO TELEMATICS',
    );
  }

  /// False when the car has not reported a position.
  bool get hasLocation => latitude != 0.0 || longitude != 0.0;

  /// Serializes every field for backup/sync (e.g. the last-known-telemetry
  /// snapshot kept in Firestore). [isSimulated]/[isBound] round-trip too, so
  /// a restored snapshot can't be mistaken for live data.
  Map<String, dynamic> toJson() => {
        'batteryPct': batteryPct,
        'electricRangeKm': electricRangeKm,
        'fuelRangeKm': fuelRangeKm,
        'fuelCapacityPct': fuelCapacityPct,
        'totalRangeKm': totalRangeKm,
        'odometerKm': odometerKm,
        'volt12': volt12,
        'speedKmH': speedKmH,
        'isCharging': isCharging,
        'chargePowerKw': chargePowerKw,
        'chargeRemainMin': chargeRemainMin,
        'fuelConsumptionL100km': fuelConsumptionL100km,
        'acOn': acOn,
        'acTemp': acTemp,
        'doorsOpen': doorsOpen,
        'trunkOpen': trunkOpen,
        'windowsOpen': windowsOpen,
        'sunroofOpen': sunroofOpen,
        'engineOn': engineOn,
        'rapidCool': rapidCool,
        'frontDefrost': frontDefrost,
        'rearDefrost': rearDefrost,
        'airPurifier': airPurifier,
        'fanGear': fanGear,
        'seatHeatDriver': seatHeatDriver,
        'seatVentDriver': seatVentDriver,
        'seatHeatPass': seatHeatPass,
        'seatVentPass': seatVentPass,
        'steeringHeat': steeringHeat,
        'airDurationMin': airDurationMin,
        'tyreFlPressureKpa': tyreFlPressureKpa,
        'tyreFrPressureKpa': tyreFrPressureKpa,
        'tyreRlPressureKpa': tyreRlPressureKpa,
        'tyreRrPressureKpa': tyreRrPressureKpa,
        'tyreFlTempC': tyreFlTempC,
        'tyreFrTempC': tyreFrTempC,
        'tyreRlTempC': tyreRlTempC,
        'tyreRrTempC': tyreRrTempC,
        'latitude': latitude,
        'longitude': longitude,
        'headingDegrees': headingDegrees,
        'locationName': locationName,
        'isParked': isParked,
        'parkedDurationText': parkedDurationText,
        'lastUpdated': lastUpdated.toIso8601String(),
        'isSimulated': isSimulated,
        'isBound': isBound,
        'dataSourceLabel': dataSourceLabel,
      };

  factory VehicleTelemetry.fromJson(Map<String, dynamic> json) => VehicleTelemetry(
        batteryPct: (json['batteryPct'] as num?)?.toInt() ?? 0,
        electricRangeKm: (json['electricRangeKm'] as num?)?.toInt() ?? 0,
        fuelRangeKm: (json['fuelRangeKm'] as num?)?.toInt() ?? 0,
        fuelCapacityPct: (json['fuelCapacityPct'] as num?)?.toInt() ?? 0,
        totalRangeKm: (json['totalRangeKm'] as num?)?.toInt() ?? 0,
        odometerKm: (json['odometerKm'] as num?)?.toInt() ?? 0,
        volt12: (json['volt12'] as num?)?.toDouble() ?? 0.0,
        speedKmH: (json['speedKmH'] as num?)?.toDouble() ?? 0.0,
        isCharging: json['isCharging'] as bool? ?? false,
        chargePowerKw: (json['chargePowerKw'] as num?)?.toDouble() ?? 0.0,
        chargeRemainMin: (json['chargeRemainMin'] as num?)?.toInt(),
        fuelConsumptionL100km: (json['fuelConsumptionL100km'] as num?)?.toDouble() ?? 0.0,
        acOn: json['acOn'] as bool? ?? false,
        acTemp: (json['acTemp'] as num?)?.toInt() ?? 22,
        doorsOpen: json['doorsOpen'] as bool? ?? false,
        trunkOpen: json['trunkOpen'] as bool? ?? false,
        windowsOpen: json['windowsOpen'] as bool? ?? false,
        sunroofOpen: json['sunroofOpen'] as bool? ?? false,
        engineOn: json['engineOn'] as bool? ?? false,
        rapidCool: json['rapidCool'] as bool? ?? false,
        frontDefrost: json['frontDefrost'] as bool? ?? false,
        rearDefrost: json['rearDefrost'] as bool? ?? false,
        airPurifier: json['airPurifier'] as bool? ?? false,
        fanGear: (json['fanGear'] as num?)?.toInt() ?? 0,
        seatHeatDriver: (json['seatHeatDriver'] as num?)?.toInt() ?? 0,
        seatVentDriver: (json['seatVentDriver'] as num?)?.toInt() ?? 0,
        seatHeatPass: (json['seatHeatPass'] as num?)?.toInt() ?? 0,
        seatVentPass: (json['seatVentPass'] as num?)?.toInt() ?? 0,
        steeringHeat: json['steeringHeat'] as bool? ?? false,
        airDurationMin: (json['airDurationMin'] as num?)?.toInt() ?? 10,
        tyreFlPressureKpa: (json['tyreFlPressureKpa'] as num?)?.toDouble() ?? 0.0,
        tyreFrPressureKpa: (json['tyreFrPressureKpa'] as num?)?.toDouble() ?? 0.0,
        tyreRlPressureKpa: (json['tyreRlPressureKpa'] as num?)?.toDouble() ?? 0.0,
        tyreRrPressureKpa: (json['tyreRrPressureKpa'] as num?)?.toDouble() ?? 0.0,
        tyreFlTempC: (json['tyreFlTempC'] as num?)?.toDouble() ?? 0.0,
        tyreFrTempC: (json['tyreFrTempC'] as num?)?.toDouble() ?? 0.0,
        tyreRlTempC: (json['tyreRlTempC'] as num?)?.toDouble() ?? 0.0,
        tyreRrTempC: (json['tyreRrTempC'] as num?)?.toDouble() ?? 0.0,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        headingDegrees: (json['headingDegrees'] as num?)?.toDouble() ?? 0.0,
        locationName: json['locationName'] as String? ?? 'Pending Car Bind',
        isParked: json['isParked'] as bool? ?? true,
        parkedDurationText: json['parkedDurationText'] as String? ?? 'Awaiting CarLinko Bind',
        lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ?? DateTime.now(),
        isSimulated: json['isSimulated'] as bool? ?? false,
        isBound: json['isBound'] as bool? ?? false,
        dataSourceLabel: json['dataSourceLabel'] as String? ?? 'Pending Car Bind',
      );

  /// Convert kPa to PSI for dual automotive readouts.
  static double kpaToPsi(double kpa) => kpa * 0.145038;

  /// Convert kPa to bar for dual automotive readouts.
  static double kpaToBar(double kpa) => kpa * 0.01;

  /// Convert PSI to kPa (inverse of [kpaToPsi]).
  static double psiToKpa(double psi) => psi / 0.145038;

  /// Convert bar to kPa (inverse of [kpaToBar]).
  static double barToKpa(double bar) => bar * 100.0;

  VehicleTelemetry copyWith({
    int? batteryPct,
    int? electricRangeKm,
    int? fuelRangeKm,
    int? fuelCapacityPct,
    int? totalRangeKm,
    int? odometerKm,
    double? volt12,
    double? speedKmH,
    bool? isCharging,
    double? chargePowerKw,
    int? chargeRemainMin,
    double? fuelConsumptionL100km,
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
    bool? isBound,
    String? dataSourceLabel,
  }) {
    return VehicleTelemetry(
      batteryPct: batteryPct ?? this.batteryPct,
      electricRangeKm: electricRangeKm ?? this.electricRangeKm,
      fuelRangeKm: fuelRangeKm ?? this.fuelRangeKm,
      fuelCapacityPct: fuelCapacityPct ?? this.fuelCapacityPct,
      totalRangeKm: totalRangeKm ?? this.totalRangeKm,
      odometerKm: odometerKm ?? this.odometerKm,
      volt12: volt12 ?? this.volt12,
      speedKmH: speedKmH ?? this.speedKmH,
      isCharging: isCharging ?? this.isCharging,
      chargePowerKw: chargePowerKw ?? this.chargePowerKw,
      chargeRemainMin: chargeRemainMin ?? this.chargeRemainMin,
      fuelConsumptionL100km: fuelConsumptionL100km ?? this.fuelConsumptionL100km,
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
      isBound: isBound ?? this.isBound,
      dataSourceLabel: dataSourceLabel ?? this.dataSourceLabel,
    );
  }
}
