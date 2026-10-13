import 'package:flutter/foundation.dart';

/// Provenance source category for vehicle data.
/// The assistant and application must strictly distinguish these 5 categories.
enum ReadingSource {
  /// Category 1: Live reading directly from a verified connected vehicle telematics stream
  liveConnected,

  /// Category 2: A cached/previously retrieved reading from a past session
  previouslyRetrieved,

  /// Category 3: A value entered manually by the owner
  userEntered,

  /// Category 4: Explicitly simulated development data
  simulated,

  /// Category 5: Value is unavailable / no reading exists
  unavailable,
}

/// Provenance metadata attached to individual data points.
@immutable
class ReadingProvenance<T> {
  final T? value;
  final String unit;
  final ReadingSource source;
  final DateTime timestamp;
  final String connectionStatusLabel;
  final double confidence; // 0.0 to 1.0

  const ReadingProvenance({
    required this.value,
    required this.unit,
    required this.source,
    required this.timestamp,
    required this.connectionStatusLabel,
    this.confidence = 1.0,
  });

  bool get isAvailable => value != null && source != ReadingSource.unavailable;
  bool get isLive => source == ReadingSource.liveConnected;
  bool get isSimulated => source == ReadingSource.simulated;
  bool get isUserEntered => source == ReadingSource.userEntered;
  bool get isStale =>
      isAvailable &&
      (source == ReadingSource.previouslyRetrieved ||
          DateTime.now().difference(timestamp).inMinutes > 60);

  String get categoryLabel {
    switch (source) {
      case ReadingSource.liveConnected:
        return 'LIVE VERIFIED';
      case ReadingSource.previouslyRetrieved:
        return 'CACHED (STALE)';
      case ReadingSource.userEntered:
        return 'MANUAL ENTRY';
      case ReadingSource.simulated:
        return 'SIMULATED DATA (DEV)';
      case ReadingSource.unavailable:
        return 'UNAVAILABLE';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'unit': unit,
      'source': source.name,
      'timestamp': timestamp.toIso8601String(),
      'connectionStatusLabel': connectionStatusLabel,
      'confidence': confidence,
    };
  }
}

/// Comprehensive vehicle telemetry state.
@immutable
class VehicleTelemetry {
  final ReadingProvenance<double> batteryPercentage;
  final ReadingProvenance<double> fuelPercentage;
  final ReadingProvenance<double> odometerKm;
  final ReadingProvenance<double> estimatedElectricRangeKm;
  final ReadingProvenance<double> estimatedTotalRangeKm;
  final ReadingProvenance<bool> isCharging;
  final ReadingProvenance<String> drivingMode;
  final bool isSimulatedModeActive;
  final String connectionStatusText;

  const VehicleTelemetry({
    required this.batteryPercentage,
    required this.fuelPercentage,
    required this.odometerKm,
    required this.estimatedElectricRangeKm,
    required this.estimatedTotalRangeKm,
    required this.isCharging,
    required this.drivingMode,
    required this.isSimulatedModeActive,
    required this.connectionStatusText,
  });

  /// Honest empty/disconnected telemetry when CarLinko is not active and simulation is off.
  factory VehicleTelemetry.disconnected({
    double? lastKnownOdo,
    String statusMessage = 'CarLinko Not Activated',
  }) {
    final now = DateTime.now();
    return VehicleTelemetry(
      batteryPercentage: ReadingProvenance<double>(
        value: null,
        unit: '%',
        source: ReadingSource.unavailable,
        timestamp: now,
        connectionStatusLabel: statusMessage,
      ),
      fuelPercentage: ReadingProvenance<double>(
        value: null,
        unit: '%',
        source: ReadingSource.unavailable,
        timestamp: now,
        connectionStatusLabel: statusMessage,
      ),
      odometerKm: ReadingProvenance<double>(
        value: lastKnownOdo,
        unit: 'km',
        source: lastKnownOdo != null
            ? ReadingSource.userEntered
            : ReadingSource.unavailable,
        timestamp: now,
        connectionStatusLabel: statusMessage,
      ),
      estimatedElectricRangeKm: ReadingProvenance<double>(
        value: null,
        unit: 'km',
        source: ReadingSource.unavailable,
        timestamp: now,
        connectionStatusLabel: statusMessage,
      ),
      estimatedTotalRangeKm: ReadingProvenance<double>(
        value: null,
        unit: 'km',
        source: ReadingSource.unavailable,
        timestamp: now,
        connectionStatusLabel: statusMessage,
      ),
      isCharging: ReadingProvenance<bool>(
        value: null,
        unit: '',
        source: ReadingSource.unavailable,
        timestamp: now,
        connectionStatusLabel: statusMessage,
      ),
      drivingMode: ReadingProvenance<String>(
        value: null,
        unit: '',
        source: ReadingSource.unavailable,
        timestamp: now,
        connectionStatusLabel: statusMessage,
      ),
      isSimulatedModeActive: false,
      connectionStatusText: statusMessage,
    );
  }

  /// Explicitly simulated telemetry for testing and development.
  factory VehicleTelemetry.simulated({
    double batteryPercent = 78.0,
    double fuelPercent = 85.0,
    double odo = 850.0,
    double evRange = 68.0,
    double totalRange = 820.0,
    bool charging = false,
    String mode = 'AUTO',
  }) {
    final now = DateTime.now();
    const label = 'Simulated Development Stream';
    return VehicleTelemetry(
      batteryPercentage: ReadingProvenance<double>(
        value: batteryPercent,
        unit: '%',
        source: ReadingSource.simulated,
        timestamp: now,
        connectionStatusLabel: label,
      ),
      fuelPercentage: ReadingProvenance<double>(
        value: fuelPercent,
        unit: '%',
        source: ReadingSource.simulated,
        timestamp: now,
        connectionStatusLabel: label,
      ),
      odometerKm: ReadingProvenance<double>(
        value: odo,
        unit: 'km',
        source: ReadingSource.simulated,
        timestamp: now,
        connectionStatusLabel: label,
      ),
      estimatedElectricRangeKm: ReadingProvenance<double>(
        value: evRange,
        unit: 'km',
        source: ReadingSource.simulated,
        timestamp: now,
        connectionStatusLabel: label,
      ),
      estimatedTotalRangeKm: ReadingProvenance<double>(
        value: totalRange,
        unit: 'km',
        source: ReadingSource.simulated,
        timestamp: now,
        connectionStatusLabel: label,
      ),
      isCharging: ReadingProvenance<bool>(
        value: charging,
        unit: '',
        source: ReadingSource.simulated,
        timestamp: now,
        connectionStatusLabel: label,
      ),
      drivingMode: ReadingProvenance<String>(
        value: mode,
        unit: '',
        source: ReadingSource.simulated,
        timestamp: now,
        connectionStatusLabel: label,
      ),
      isSimulatedModeActive: true,
      connectionStatusText: 'SIMULATED (DEV MODE)',
    );
  }
}
