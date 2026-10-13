import 'dart:async';
import '../datasources/local_storage_datasource.dart';
import '../datasources/mock_vehicle_data_source.dart';
import '../datasources/vehicle_data_source.dart';
import '../models/telemetry.dart';
import '../models/vehicle_profile.dart';

class VehicleRepository {
  final LocalStorageDataSource storage;
  final MockVehicleDataSource mockDataSource;

  late VehicleProfile _currentProfile;
  late bool _isSimulatedMode;

  VehicleRepository({required this.storage, required this.mockDataSource}) {
    _currentProfile = storage.loadVehicleProfile();
    _isSimulatedMode = storage.getSimulationMode();
    mockDataSource.setSimulationMode(
      _isSimulatedMode,
      userOdo: _currentProfile.currentOdometerKm,
    );
  }

  VehicleProfile get currentProfile => _currentProfile;
  bool get isSimulatedMode => _isSimulatedMode;

  Future<void> updateProfile(VehicleProfile updated) async {
    _currentProfile = updated;
    await storage.saveVehicleProfile(updated);
    if (_isSimulatedMode) {
      mockDataSource.setSimulationMode(
        true,
        userOdo: updated.currentOdometerKm,
      );
    }
  }

  Future<void> updateOdometer(double newOdometerKm) async {
    _currentProfile = _currentProfile.copyWith(
      currentOdometerKm: newOdometerKm,
    );
    await storage.saveVehicleProfile(_currentProfile);
    mockDataSource.setSimulationMode(_isSimulatedMode, userOdo: newOdometerKm);
  }

  Future<void> setSimulatedDataMode(bool enabled) async {
    _isSimulatedMode = enabled;
    await storage.setSimulationMode(enabled);
    mockDataSource.setSimulationMode(
      enabled,
      userOdo: _currentProfile.currentOdometerKm,
    );
  }

  Stream<VehicleTelemetry> watchTelemetry() {
    return mockDataSource.watchTelemetry();
  }

  Future<VehicleConnectionStatus> getConnectionStatus() {
    return mockDataSource.getConnectionStatus();
  }

  Future<VehicleCapabilities> getCapabilities() {
    return mockDataSource.getCapabilities();
  }
}
