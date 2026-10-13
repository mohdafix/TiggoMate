import 'dart:async';
import '../models/telemetry.dart';
import 'vehicle_data_source.dart';

/// Mock vehicle data source with explicitly labelled simulated telemetry.
/// TECHNICAL RULE:
/// - Mock telemetry is visibly labelled as simulated.
/// - Disabling mock telemetry produces honest disconnected states.
/// - Never invent vehicle readings or claim a real connection has been established.
class MockVehicleDataSource implements VehicleDataSource {
  bool _isSimulationActive = false;
  final StreamController<VehicleTelemetry> _telemetryController =
      StreamController<VehicleTelemetry>.broadcast();

  MockVehicleDataSource({bool initialSimulationActive = false}) {
    _isSimulationActive = initialSimulationActive;
  }

  bool get isSimulationActive => _isSimulationActive;

  void setSimulationMode(bool enabled, {double? userOdo}) {
    _isSimulationActive = enabled;
    _emitCurrentState(userOdo: userOdo);
  }

  void _emitCurrentState({double? userOdo}) {
    if (_isSimulationActive) {
      _telemetryController.add(
        VehicleTelemetry.simulated(
          batteryPercent: 78.0,
          fuelPercent: 85.0,
          odo: userOdo ?? 850.0,
          evRange: 68.0,
          totalRange: 820.0,
          charging: false,
          mode: 'AUTO',
        ),
      );
    } else {
      _telemetryController.add(
        VehicleTelemetry.disconnected(
          lastKnownOdo: userOdo,
          statusMessage:
              'CarLinko Not Activated (Real Car Pending 1,000 km Service)',
        ),
      );
    }
  }

  @override
  Future<VehicleConnectionStatus> getConnectionStatus() async {
    if (_isSimulationActive) {
      return VehicleConnectionStatus(
        state: ConnectionStateEnum.simulatedMode,
        providerName: 'Mock Vehicle Telemetry Engine',
        statusDescription: 'Simulated Data Active (Testing & Demo Mode)',
        lastChecked: DateTime.now(),
        isSimulated: true,
        endpointInfo: 'internal://mock-telemetry-engine',
      );
    } else {
      return VehicleConnectionStatus(
        state: ConnectionStateEnum.notActivated,
        providerName: 'CarLinko Malaysia Telematics',
        statusDescription:
            'Vehicle connection not activated. Awaiting CarLinko onboarding at 1,000 km dealer inspection.',
        lastChecked: DateTime.now(),
        isSimulated: false,
        endpointInfo: 'carlinko://chery-malaysia/pending-activation',
      );
    }
  }

  @override
  Stream<VehicleTelemetry> watchTelemetry() {
    // Schedule initial emission
    Future.microtask(() => _emitCurrentState());
    return _telemetryController.stream;
  }

  @override
  Future<VehicleCapabilities> getCapabilities() async {
    if (_isSimulationActive) {
      return VehicleCapabilities.simulated();
    }
    return VehicleCapabilities.notActivated();
  }

  void dispose() {
    _telemetryController.close();
  }
}
