import '../models/telemetry.dart';

enum ConnectionStateEnum {
  notActivated, // e.g. CarLinko awaiting dealer activation at 1,000 km
  disconnected,
  connecting,
  connected,
  simulatedMode,
}

class VehicleConnectionStatus {
  final ConnectionStateEnum state;
  final String providerName; // e.g. 'CarLinko', 'OBD-II', 'Mock Provider'
  final String statusDescription;
  final DateTime lastChecked;
  final bool isSimulated;
  final String? endpointInfo;

  const VehicleConnectionStatus({
    required this.state,
    required this.providerName,
    required this.statusDescription,
    required this.lastChecked,
    this.isSimulated = false,
    this.endpointInfo,
  });

  bool get isConnected => state == ConnectionStateEnum.connected;
  bool get isNotActivated => state == ConnectionStateEnum.notActivated;
}

class VehicleCapabilities {
  final bool canReadSoc;
  final bool canReadOdometer;
  final bool canReadFuel;
  final bool canReadTyrePressures;
  final bool canRemoteControlClimate;
  final bool canRemoteLockUnlock;
  final String documentationSource;

  const VehicleCapabilities({
    required this.canReadSoc,
    required this.canReadOdometer,
    required this.canReadFuel,
    required this.canReadTyrePressures,
    required this.canRemoteControlClimate,
    required this.canRemoteLockUnlock,
    required this.documentationSource,
  });

  factory VehicleCapabilities.notActivated() {
    return const VehicleCapabilities(
      canReadSoc: false,
      canReadOdometer: false,
      canReadFuel: false,
      canReadTyrePressures: false,
      canRemoteControlClimate: false,
      canRemoteLockUnlock: false,
      documentationSource: 'CarLinko pending activation at 1,000 km service',
    );
  }

  factory VehicleCapabilities.simulated() {
    return const VehicleCapabilities(
      canReadSoc: true,
      canReadOdometer: true,
      canReadFuel: true,
      canReadTyrePressures: true,
      canRemoteControlClimate: true,
      canRemoteLockUnlock: true,
      documentationSource: 'MockVehicleDataSource (Simulated Dev Profile)',
    );
  }
}

/// Abstract contract for all vehicle telematics and diagnostic data sources.
abstract class VehicleDataSource {
  Future<VehicleConnectionStatus> getConnectionStatus();
  Stream<VehicleTelemetry> watchTelemetry();
  Future<VehicleCapabilities> getCapabilities();
}
