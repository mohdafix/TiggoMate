import 'dart:convert';

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
  final double energyConsumptionKwh100km;
  final bool acOn;
  final int acTemp;
  final bool doorsOpen;
  final bool doorsLocked;
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
  final String? rawBlobHex;

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
    this.energyConsumptionKwh100km = 0.0,
    this.acOn = false,
    this.acTemp = 22,
    this.doorsOpen = false,
    this.doorsLocked = true,
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
    this.rawBlobHex,
  });

  /// Full live status as a readable block, for handing to the AI assistant
  /// so it can answer questions about any current vehicle state instead of
  /// just the few fields explicitly threaded through as separate params.
  String get aiStatusSummary {
    final lines = <String>[
      'Odometer: $odometerKm km',
      'Battery: $batteryPct% (EV range ~$electricRangeKm km)${isCharging ? ', Charging: yes (${chargePowerKw.toStringAsFixed(1)} kW${chargeRemainMin != null ? ', ~$chargeRemainMin min remaining' : ''})' : ', Charging: no'}',
      'Fuel: $fuelCapacityPct% (range ~$fuelRangeKm km)${fuelConsumptionL100km > 0 ? ', consumption ${fuelConsumptionL100km.toStringAsFixed(1)} L/100km' : ''}${energyConsumptionKwh100km > 0 ? ', energy ${energyConsumptionKwh100km.toStringAsFixed(2)} kWh/100km' : ''}',
      'Total combined range: ~$totalRangeKm km',
      '12V aux battery: ${volt12 > 0 ? '${volt12.toStringAsFixed(2)} V' : 'unknown'}',
      'Speed: ${speedKmH.toStringAsFixed(0)} km/h',
      'Engine: ${engineOn ? 'running' : 'off'}',
      'Doors: ${doorsOpen ? 'open/ajar' : (doorsLocked ? 'locked' : 'unlocked')}',
      'Trunk: ${trunkOpen ? 'open' : 'closed'}',
      'Windows: ${windowsOpen ? 'open/vented' : 'closed'}',
      'Sunroof: ${sunroofOpen ? 'open' : 'closed'}',
      'Climate: ${acOn ? 'on, target $acTemp°C, fan gear ${fanGear == 0 ? 'auto' : fanGear}' : 'off'}',
      if (rapidCool) 'Rapid cool: active',
      if (frontDefrost) 'Front defrost: active',
      if (rearDefrost) 'Rear defrost: active',
      if (airPurifier) 'Air purifier: active',
      if (seatHeatDriver > 0) 'Driver seat heat: level $seatHeatDriver',
      if (seatVentDriver > 0) 'Driver seat vent: level $seatVentDriver',
      if (seatHeatPass > 0) 'Passenger seat heat: level $seatHeatPass',
      if (seatVentPass > 0) 'Passenger seat vent: level $seatVentPass',
      if (steeringHeat) 'Steering wheel heat: on',
      'Tyre pressure (kPa): FL ${tyreFlPressureKpa.toStringAsFixed(0)}, FR ${tyreFrPressureKpa.toStringAsFixed(0)}, RL ${tyreRlPressureKpa.toStringAsFixed(0)}, RR ${tyreRrPressureKpa.toStringAsFixed(0)}',
      'Tyre temperature (°C): FL ${tyreFlTempC.toStringAsFixed(0)}, FR ${tyreFrTempC.toStringAsFixed(0)}, RL ${tyreRlTempC.toStringAsFixed(0)}, RR ${tyreRrTempC.toStringAsFixed(0)}',
      'Location: ${isParked ? 'Parked ($parkedDurationText)' : 'Moving'}${locationName.isNotEmpty ? ', near $locationName' : ''}',
      'Data as of: $lastUpdated${isSimulated ? ' (simulated/demo data)' : ''}',
    ];
    return lines.join('\n- ');
  }

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
      fuelConsumptionL100km: 0.0,
      energyConsumptionKwh100km: 0.0,
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
      fuelConsumptionL100km: 1.10,
      energyConsumptionKwh100km: 9.40,
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
  /// Normalizes CAN-bus HVAC raw temperature values to standard Celsius (16-32°C).
  /// Handles Chery T-Box 0.5°C step encoding and Bit-7 active status flags
  /// (e.g. 172 [0xAC] -> 172 & 0x7F = 44 -> 44 * 0.5 = 22°C).
  static int sanitizeAcTemp(num? raw) {
    if (raw == null) return 22;
    final val = raw.toInt();
    if (val >= 100) {
      final deg = ((val & 0x7F) * 0.5).round();
      return (deg >= 16 && deg <= 32) ? deg : 22;
    }
    if (val >= 32 && val <= 70) {
      final deg = (val * 0.5).round();
      return (deg >= 16 && deg <= 32) ? deg : 22;
    }
    if (val >= 16 && val <= 32) {
      return val;
    }
    return 22;
  }

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
    final double energyCons = (m['energy_consumption_kwh100km'] as num?)?.toDouble() ??
        (m['consumption'] as num?)?.toDouble() ??
        0.0;
    final int? rawUnlocked = (m['unlocked'] as num?)?.toInt();
    final bool isDoorAjar = ((m['doors'] as num?)?.toInt() ?? 0) != 0;
    final bool isDoorLocked = rawUnlocked != null ? (rawUnlocked == 0) : !isDoorAjar;

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
      energyConsumptionKwh100km: energyCons,
      acOn: m['ac_on'] == true,
      acTemp: sanitizeAcTemp(m['ac_temp'] as num?),
      doorsOpen: isDoorAjar,
      doorsLocked: isDoorLocked,
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
      rawBlobHex: m['rawHex'] as String?,
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
        'energyConsumptionKwh100km': energyConsumptionKwh100km,
        'acOn': acOn,
        'acTemp': acTemp,
        'doorsOpen': doorsOpen,
        'doorsLocked': doorsLocked,
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
        'rawBlobHex': rawBlobHex,
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
        energyConsumptionKwh100km: (json['energyConsumptionKwh100km'] as num?)?.toDouble() ?? 0.0,
        acOn: json['acOn'] as bool? ?? false,
        acTemp: sanitizeAcTemp(json['acTemp'] as num?),
        doorsOpen: json['doorsOpen'] as bool? ?? false,
        doorsLocked: json['doorsLocked'] as bool? ?? true,
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
        rawBlobHex: json['rawBlobHex'] as String?,
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
    double? energyConsumptionKwh100km,
    bool? acOn,
    int? acTemp,
    bool? doorsOpen,
    bool? doorsLocked,
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
    String? rawBlobHex,
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
      energyConsumptionKwh100km: energyConsumptionKwh100km ?? this.energyConsumptionKwh100km,
      acOn: acOn ?? this.acOn,
      acTemp: acTemp ?? this.acTemp,
      doorsOpen: doorsOpen ?? this.doorsOpen,
      doorsLocked: doorsLocked ?? this.doorsLocked,
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
      rawBlobHex: rawBlobHex ?? this.rawBlobHex,
    );
  }
}

/// Dynamic vehicle capability flags and official CarLinko CDN render URLs
/// decoded from `/user/vehicle` (`vehicleImgConfig`, `vehicleControlConfig`,
/// and `airDuration`).
class VehicleCapabilities {
  final String? plateNumber;
  final String? vin;
  final String? seriesName;
  final String? modelName;
  final String? frontImageUrl;
  final String? sideImageUrl;
  final String? topImageUrl;
  final int airDurationMin;
  final double minAcTemp;
  final double maxAcTemp;
  final double tempStep;
  final bool hasSeatHeat;
  final bool hasSeatVent;
  final bool hasSunroof;
  final bool hasTailgate;
  final bool hasScheduledCharge;
  final bool hasScheduledTravel;

  const VehicleCapabilities({
    this.plateNumber,
    this.vin,
    this.seriesName,
    this.modelName,
    this.frontImageUrl,
    this.sideImageUrl,
    this.topImageUrl,
    this.airDurationMin = 10,
    this.minAcTemp = 16.0,
    this.maxAcTemp = 32.0,
    this.tempStep = 0.5,
    this.hasSeatHeat = true,
    this.hasSeatVent = true,
    this.hasSunroof = true,
    this.hasTailgate = true,
    this.hasScheduledCharge = true,
    this.hasScheduledTravel = true,
  });

  factory VehicleCapabilities.defaults() => const VehicleCapabilities();

  static Map<String, dynamic> _decodeJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return {};
  }

  static bool _flag(Map<String, dynamic> ctrl, List<String> keys, {bool fallback = true}) {
    for (final k in keys) {
      if (ctrl.containsKey(k)) {
        final v = ctrl[k];
        if (v is bool) return v;
        if (v is num) return v > 0;
        if (v is String) {
          final lower = v.toLowerCase().trim();
          if (lower == 'true' || lower == '1' || lower == 'yes') return true;
          if (lower == 'false' || lower == '0' || lower == 'no') return false;
        }
        if (v is Map) {
          return v['enable'] == true || v['enabled'] == true || v['support'] == true;
        }
      }
    }
    return fallback;
  }

  factory VehicleCapabilities.fromVehicleMap(Map<String, dynamic> row) {
    final imgs = _decodeJsonMap(row['vehicleImgConfig']);
    final ctrl = _decodeJsonMap(row['vehicleControlConfig']);
    final acCfg = _decodeJsonMap(ctrl['airConditioner'] ?? ctrl['ac'] ?? ctrl['climate']);

    final rawMin = (acCfg['minTemp'] ?? ctrl['minAcTemp'] ?? ctrl['tempMin']) as num?;
    final rawMax = (acCfg['maxTemp'] ?? ctrl['maxAcTemp'] ?? ctrl['tempMax']) as num?;
    final rawStep = (acCfg['step'] ?? ctrl['tempStep']) as num?;

    return VehicleCapabilities(
      plateNumber: row['plateNumber']?.toString() ?? row['licensePlate']?.toString(),
      vin: row['vin']?.toString(),
      seriesName: row['seriesName']?.toString() ?? row['brandName']?.toString(),
      modelName: row['modelName']?.toString() ?? row['vehicleModelName']?.toString(),
      frontImageUrl: imgs['Front']?.toString() ?? imgs['front']?.toString(),
      sideImageUrl: imgs['Side']?.toString() ?? imgs['side']?.toString(),
      topImageUrl: imgs['Top']?.toString() ?? imgs['top']?.toString(),
      airDurationMin: (row['airDuration'] as num?)?.toInt() ?? 10,
      minAcTemp: rawMin?.toDouble() ?? 16.0,
      maxAcTemp: rawMax?.toDouble() ?? 32.0,
      tempStep: rawStep?.toDouble() ?? 0.5,
      hasSeatHeat: _flag(ctrl, ['seatHeat', 'seatHeating', 'frontSeatHeat']),
      hasSeatVent: _flag(ctrl, ['seatVent', 'seatVentilation', 'frontSeatVent']),
      hasSunroof: _flag(ctrl, ['sunroof', 'skylight']),
      hasTailgate: _flag(ctrl, ['tailgate', 'trunk', 'powerTailgate']),
      hasScheduledCharge: _flag(ctrl, ['batterySchedule', 'scheduledCharge']),
      hasScheduledTravel: _flag(ctrl, ['startupAppointment', 'scheduledTravel']),
    );
  }
}
