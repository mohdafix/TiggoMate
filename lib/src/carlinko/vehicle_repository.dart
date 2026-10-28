import 'dart:async';
import 'carlinko_api.dart';
import 'vehicle_telemetry.dart';

abstract class VehicleRepository {
  Stream<VehicleTelemetry> get telemetryStream;
  VehicleTelemetry get currentTelemetry;
  VehicleConnectionStatus get connectionStatus;
  Future<void> refresh();
  Future<void> connect({required String account, required String password, String region = 'sea'});
  Future<void> disconnect();
  void toggleCharging(bool charging);
  void dispose();
}

/// Simulated mock repository for the Malaysian Chery Tiggo 7 PHEV CSH.
/// Active before the vehicle's CarLinko account is activated at the 1,000 km dealership service.
class MockVehicleRepository implements VehicleRepository {
  final _controller = StreamController<VehicleTelemetry>.broadcast();
  VehicleTelemetry _current;
  VehicleConnectionStatus _status = VehicleConnectionStatus.connected;

  MockVehicleRepository()
      : _current = VehicleTelemetry(
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
          tyreFlPressureKpa: 235.0,
          tyreFrPressureKpa: 234.0,
          tyreRlPressureKpa: 236.0,
          tyreRrPressureKpa: 235.0,
          tyreFlTempC: 32.0,
          tyreFrTempC: 33.0,
          tyreRlTempC: 31.0,
          tyreRrTempC: 31.0,
          lastUpdated: DateTime.now(),
          isSimulated: true,
          dataSourceLabel: 'SIMULATED DATA (CarLinko Not Activated)',
        );

  @override
  Stream<VehicleTelemetry> get telemetryStream => _controller.stream;

  @override
  VehicleTelemetry get currentTelemetry => _current;

  @override
  VehicleConnectionStatus get connectionStatus => _status;

  @override
  Future<void> refresh() async {
    final now = DateTime.now();
    _current = VehicleTelemetry(
      batteryPct: _current.batteryPct,
      electricRangeKm: _current.electricRangeKm,
      fuelRangeKm: _current.fuelRangeKm,
      totalRangeKm: _current.totalRangeKm,
      odometerKm: _current.odometerKm,
      volt12: 12.82,
      speedKmH: _current.speedKmH,
      isCharging: _current.isCharging,
      chargePowerKw: _current.isCharging ? 6.6 : 0.0,
      chargeRemainMin: _current.isCharging ? 38 : null,
      acOn: _current.acOn,
      acTemp: _current.acTemp,
      doorsOpen: _current.doorsOpen,
      trunkOpen: _current.trunkOpen,
      windowsOpen: _current.windowsOpen,
      tyreFlPressureKpa: 235.0,
      tyreFrPressureKpa: 234.0,
      tyreRlPressureKpa: 236.0,
      tyreRrPressureKpa: 235.0,
      tyreFlTempC: 32.0,
      tyreFrTempC: 33.0,
      tyreRlTempC: 31.0,
      tyreRrTempC: 31.0,
      lastUpdated: now,
      isSimulated: true,
      dataSourceLabel: 'SIMULATED DATA (CarLinko Not Activated)',
    );
    _controller.add(_current);
  }

  @override
  void toggleCharging(bool charging) {
    _current = VehicleTelemetry(
      batteryPct: _current.batteryPct,
      electricRangeKm: _current.electricRangeKm,
      fuelRangeKm: _current.fuelRangeKm,
      totalRangeKm: _current.totalRangeKm,
      odometerKm: _current.odometerKm,
      volt12: _current.volt12,
      speedKmH: 0.0,
      isCharging: charging,
      chargePowerKw: charging ? 6.6 : 0.0,
      chargeRemainMin: charging ? 38 : null,
      acOn: _current.acOn,
      acTemp: _current.acTemp,
      doorsOpen: _current.doorsOpen,
      trunkOpen: _current.trunkOpen,
      windowsOpen: _current.windowsOpen,
      tyreFlPressureKpa: _current.tyreFlPressureKpa,
      tyreFrPressureKpa: _current.tyreFrPressureKpa,
      tyreRlPressureKpa: _current.tyreRlPressureKpa,
      tyreRrPressureKpa: _current.tyreRrPressureKpa,
      tyreFlTempC: _current.tyreFlTempC,
      tyreFrTempC: _current.tyreFrTempC,
      tyreRlTempC: _current.tyreRlTempC,
      tyreRrTempC: _current.tyreRrTempC,
      lastUpdated: DateTime.now(),
      isSimulated: true,
      dataSourceLabel: 'SIMULATED DATA (CarLinko Not Activated)',
    );
    _controller.add(_current);
  }

  @override
  Future<void> connect({required String account, required String password, String region = 'sea'}) async {
    _status = VehicleConnectionStatus.connecting;
    await Future.delayed(const Duration(milliseconds: 400));
    _status = VehicleConnectionStatus.connected;
    await refresh();
  }

  @override
  Future<void> disconnect() async {
    _status = VehicleConnectionStatus.disconnected;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// Live implementation communicating directly with the Chery CarLinko cloud REST API.
class LiveCarLinkoRepository implements VehicleRepository {
  final _controller = StreamController<VehicleTelemetry>.broadcast();
  final CarLinkoClient _client;
  VehicleTelemetry _current;
  VehicleConnectionStatus _status = VehicleConnectionStatus.disconnected;
  String? _vehicleId;

  LiveCarLinkoRepository({String region = 'sea'})
      : _client = CarLinkoClient(region: region),
        _current = VehicleTelemetry(
          lastUpdated: DateTime.now(),
          isSimulated: false,
          dataSourceLabel: 'CARLINKO DISCONNECTED',
        );

  @override
  Stream<VehicleTelemetry> get telemetryStream => _controller.stream;

  @override
  VehicleTelemetry get currentTelemetry => _current;

  @override
  VehicleConnectionStatus get connectionStatus => _status;

  @override
  Future<void> connect({required String account, required String password, String region = 'sea'}) async {
    _status = VehicleConnectionStatus.connecting;
    _client.region = region;
    try {
      await _client.login(account, password);
      final vehicles = await _client.getVehicles();
      if (vehicles.isEmpty) {
        _status = VehicleConnectionStatus.error;
        throw CarLinkoException('No vehicles found on this CarLinko account', 'NO_VEHICLES');
      }
      _vehicleId = vehicles.first['vehicleId']?.toString();
      _status = VehicleConnectionStatus.connected;
      await refresh();
    } catch (e) {
      if (e is CarLinkoAuthException) {
        _status = VehicleConnectionStatus.authRequired;
      } else {
        _status = VehicleConnectionStatus.error;
      }
      rethrow;
    }
  }

  @override
  Future<void> refresh() async {
    if (_vehicleId == null) return;
    try {
      final state = await _client.getVehicleState(_vehicleId!);
      _current = VehicleTelemetry.fromBlobMap(state, isSimulated: false);
      _status = VehicleConnectionStatus.connected;
      _controller.add(_current);
    } catch (e) {
      if (e is CarLinkoAuthException) {
        _status = VehicleConnectionStatus.authRequired;
      } else {
        _status = VehicleConnectionStatus.error;
      }
      rethrow;
    }
  }

  @override
  void toggleCharging(bool charging) {
    // Before live CAN-bus command activation, no-op safely
  }

  @override
  Future<void> disconnect() async {
    _client.token = null;
    _status = VehicleConnectionStatus.disconnected;
    _current = VehicleTelemetry(
      lastUpdated: DateTime.now(),
      isSimulated: false,
      dataSourceLabel: 'CARLINKO DISCONNECTED',
    );
    _controller.add(_current);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// Unified App-level repository managing the shared instance across the entire application.
/// Defaults to verified Mock/Simulation mode for pre-activation vehicles.
class AppVehicleRepository implements VehicleRepository {
  static final AppVehicleRepository instance = AppVehicleRepository._internal();
  AppVehicleRepository._internal() {
    _current = _mockRepo.currentTelemetry;
    _mockSubscription = _mockRepo.telemetryStream.listen((data) {
      if (!_isLiveActive) {
        _current = data;
        _controller.add(data);
      }
    });
  }

  factory AppVehicleRepository() => instance;

  final MockVehicleRepository _mockRepo = MockVehicleRepository();
  final LiveCarLinkoRepository _liveRepo = LiveCarLinkoRepository();
  StreamSubscription<VehicleTelemetry>? _mockSubscription;
  StreamSubscription<VehicleTelemetry>? _liveSubscription;

  bool _isLiveActive = false;
  bool get isLiveActive => _isLiveActive;
  bool get isPreActivationMode => !_isLiveActive;

  final _controller = StreamController<VehicleTelemetry>.broadcast();
  late VehicleTelemetry _current;

  @override
  Stream<VehicleTelemetry> get telemetryStream => _controller.stream;

  @override
  VehicleTelemetry get currentTelemetry => _isLiveActive ? _liveRepo.currentTelemetry : _mockRepo.currentTelemetry;

  @override
  VehicleConnectionStatus get connectionStatus =>
      _isLiveActive ? _liveRepo.connectionStatus : _mockRepo.connectionStatus;

  @override
  Future<void> refresh() async {
    if (_isLiveActive) {
      await _liveRepo.refresh();
    } else {
      await _mockRepo.refresh();
    }
  }

  @override
  void toggleCharging(bool charging) {
    if (_isLiveActive) {
      _liveRepo.toggleCharging(charging);
    } else {
      _mockRepo.toggleCharging(charging);
    }
  }

  /// Explicitly reset to offline simulation mode (safe fallback before dealership activation).
  void useMockMode() {
    _isLiveActive = false;
    _current = _mockRepo.currentTelemetry;
    _controller.add(_current);
  }

  @override
  Future<void> connect({required String account, required String password, String region = 'sea'}) async {
    try {
      await _liveRepo.connect(account: account, password: password, region: region);
      _isLiveActive = true;
      _current = _liveRepo.currentTelemetry;
      _liveSubscription?.cancel();
      _liveSubscription = _liveRepo.telemetryStream.listen((data) {
        if (_isLiveActive) {
          _current = data;
          _controller.add(data);
        }
      });
      _controller.add(_current);
    } catch (e) {
      // Keep verified simulated mode safe on activation failure
      _isLiveActive = false;
      _current = _mockRepo.currentTelemetry;
      _controller.add(_current);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _liveRepo.disconnect();
    _isLiveActive = false;
    _current = _mockRepo.currentTelemetry;
    _controller.add(_current);
  }

  @override
  void dispose() {
    _mockSubscription?.cancel();
    _liveSubscription?.cancel();
    _mockRepo.dispose();
    _liveRepo.dispose();
    _controller.close();
  }
}
