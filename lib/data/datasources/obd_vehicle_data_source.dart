import 'dart:async';
import '../models/telemetry.dart';
import 'vehicle_data_source.dart';

/// Future independent diagnostic module for standard OBD-II / BLE scanners.
///
/// SAFETY & DESIGN RULES:
/// - Strictly read-only operations.
/// - Never attempt ECU writing, DTC clearing, immobilizer access, or drive-mode tampering.
/// - Generic OBD-II does NOT reliably expose traction-battery SOC, hybrid mode, or cell voltages
///   without proprietary Chery PHEV PID definitions.
/// - Returns disconnected state until a physical Bluetooth/Wi-Fi OBD dongle is paired and verified.
class ObdVehicleDataSource implements VehicleDataSource {
  final String? deviceMacAddress;

  ObdVehicleDataSource({this.deviceMacAddress});

  @override
  Future<VehicleConnectionStatus> getConnectionStatus() async {
    return VehicleConnectionStatus(
      state: ConnectionStateEnum.disconnected,
      providerName: 'OBD-II Diagnostic Interface',
      statusDescription:
          'OBD-II scanner not configured. Dongle pairing required for standard diagnostic telemetry.',
      lastChecked: DateTime.now(),
      isSimulated: false,
      endpointInfo: deviceMacAddress ?? 'bluetooth://unconfigured',
    );
  }

  @override
  Stream<VehicleTelemetry> watchTelemetry() {
    return Stream.value(
      VehicleTelemetry.disconnected(
        statusMessage: 'OBD-II scanner disconnected',
      ),
    );
  }

  @override
  Future<VehicleCapabilities> getCapabilities() async {
    return const VehicleCapabilities(
      canReadSoc: false, // Standard OBD cannot read PHEV high-voltage SOC
      canReadOdometer: false, // Standard Mode $01 does not mandate odometer PID
      canReadFuel: false,
      canReadTyrePressures: false,
      canRemoteControlClimate: false,
      canRemoteLockUnlock: false,
      documentationSource: 'Standard SAE J1979 OBD-II Diagnostic Specification',
    );
  }
}
