import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Fuel fill-up log entry.
@immutable
class FuelEntry {
  final String id;
  final DateTime timestamp;
  final double odometerKm;
  final double liters;
  final double pricePerLiter;
  final double totalCostRm;
  final String fuelGrade; // e.g. 'RON95', 'RON97'
  final String station;
  final String notes;

  const FuelEntry({
    required this.id,
    required this.timestamp,
    required this.odometerKm,
    required this.liters,
    required this.pricePerLiter,
    required this.totalCostRm,
    this.fuelGrade = 'RON95',
    this.station = 'Petronas / Shell',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'odometerKm': odometerKm,
    'liters': liters,
    'pricePerLiter': pricePerLiter,
    'totalCostRm': totalCostRm,
    'fuelGrade': fuelGrade,
    'station': station,
    'notes': notes,
  };

  factory FuelEntry.fromMap(Map<String, dynamic> map) => FuelEntry(
    id: map['id'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
    odometerKm: (map['odometerKm'] as num).toDouble(),
    liters: (map['liters'] as num).toDouble(),
    pricePerLiter: (map['pricePerLiter'] as num).toDouble(),
    totalCostRm: (map['totalCostRm'] as num).toDouble(),
    fuelGrade: map['fuelGrade'] as String? ?? 'RON95',
    station: map['station'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
  );
}

/// EV charging session log entry.
@immutable
class ChargingSession {
  final String id;
  final DateTime timestamp;
  final double odometerKm;
  final double energyKwh;
  final double tariffPerKwh;
  final double totalCostRm;
  final String
  chargerType; // e.g., 'Home AC Wallbox (7kW)', 'Public AC (ChargEV/Gentari)'
  final int durationMinutes;
  final double startSoc;
  final double endSoc;
  final String notes;

  const ChargingSession({
    required this.id,
    required this.timestamp,
    required this.odometerKm,
    required this.energyKwh,
    required this.tariffPerKwh,
    required this.totalCostRm,
    this.chargerType = 'Home AC Wallbox (7kW)',
    this.durationMinutes = 180,
    this.startSoc = 20.0,
    this.endSoc = 100.0,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'odometerKm': odometerKm,
    'energyKwh': energyKwh,
    'tariffPerKwh': tariffPerKwh,
    'totalCostRm': totalCostRm,
    'chargerType': chargerType,
    'durationMinutes': durationMinutes,
    'startSoc': startSoc,
    'endSoc': endSoc,
    'notes': notes,
  };

  factory ChargingSession.fromMap(Map<String, dynamic> map) => ChargingSession(
    id: map['id'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
    odometerKm: (map['odometerKm'] as num).toDouble(),
    energyKwh: (map['energyKwh'] as num).toDouble(),
    tariffPerKwh: (map['tariffPerKwh'] as num).toDouble(),
    totalCostRm: (map['totalCostRm'] as num).toDouble(),
    chargerType: map['chargerType'] as String? ?? 'Home AC Wallbox (7kW)',
    durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 180,
    startSoc: (map['startSoc'] as num?)?.toDouble() ?? 20.0,
    endSoc: (map['endSoc'] as num?)?.toDouble() ?? 100.0,
    notes: map['notes'] as String? ?? '',
  );
}

/// Aggregated energy repository state.
@immutable
class EnergyState {
  final List<FuelEntry> fuelEntries;
  final List<ChargingSession> chargingSessions;
  final double defaultTariffPerKwh;
  final double defaultPetrolPricePerLiter;

  const EnergyState({
    this.fuelEntries = const [],
    this.chargingSessions = const [],
    this.defaultTariffPerKwh = 0.516,
    this.defaultPetrolPricePerLiter = 2.05,
  });

  double get totalFuelCostRm =>
      fuelEntries.fold(0.0, (sum, item) => sum + item.totalCostRm);

  double get totalChargingCostRm =>
      chargingSessions.fold(0.0, (sum, item) => sum + item.totalCostRm);

  double get totalEnergySpentRm => totalFuelCostRm + totalChargingCostRm;

  double get totalFuelLiters =>
      fuelEntries.fold(0.0, (sum, item) => sum + item.liters);

  double get totalChargedKwh =>
      chargingSessions.fold(0.0, (sum, item) => sum + item.energyKwh);

  Map<String, dynamic> toMap() => {
    'fuelEntries': fuelEntries.map((e) => e.toMap()).toList(),
    'chargingSessions': chargingSessions.map((e) => e.toMap()).toList(),
    'defaultTariffPerKwh': defaultTariffPerKwh,
    'defaultPetrolPricePerLiter': defaultPetrolPricePerLiter,
  };

  factory EnergyState.fromMap(Map<String, dynamic> map) => EnergyState(
    fuelEntries:
        (map['fuelEntries'] as List<dynamic>?)
            ?.map((e) => FuelEntry.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
    chargingSessions:
        (map['chargingSessions'] as List<dynamic>?)
            ?.map((e) => ChargingSession.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [],
    defaultTariffPerKwh:
        (map['defaultTariffPerKwh'] as num?)?.toDouble() ?? 0.516,
    defaultPetrolPricePerLiter:
        (map['defaultPetrolPricePerLiter'] as num?)?.toDouble() ?? 2.05,
  );

  String toJson() => json.encode(toMap());

  factory EnergyState.fromJson(String source) =>
      EnergyState.fromMap(json.decode(source) as Map<String, dynamic>);
}
