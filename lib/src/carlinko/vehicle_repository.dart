import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase/firebase_sync_service.dart';
import '../service/vehicle_alert_notifier.dart';
import 'carlinko_api.dart';
import 'reverse_geocoder.dart';
import 'vehicle_telemetry.dart';

const String _kCarLinkoTokenKey = 'tm_carlinko_token';
const String _kCarLinkoAccountKey = 'tm_carlinko_account';
const String _kCarLinkoRegionKey = 'tm_carlinko_region';
const String _kCarLinkoVehicleIdKey = 'tm_carlinko_vehicle_id';
const String _kCarLinkoDeviceSnKey = 'tm_carlinko_device_sn';

/// Pulls the vehicle's device serial number from a /user/vehicle row. Real
/// API responses use either key depending on the account (per ha-carlinko).
String? _extractDeviceSn(Map<String, dynamic> vehicle) =>
    vehicle['deviceId']?.toString() ?? vehicle['deviceSn']?.toString();

abstract class VehicleRepository {
  Stream<VehicleTelemetry> get telemetryStream;
  VehicleTelemetry get currentTelemetry;
  VehicleConnectionStatus get connectionStatus;
  bool get isCloudConnected;
  bool get isPreActivationMode;
  bool get isVehicleBound;
  String? get connectedAccount;
  String? get vehicleId;
  Future<void> refresh();
  Future<void> connect({required String account, required String password, String region = 'sea'});
  Future<void> disconnect();
  void toggleCharging(bool charging);
  Future<bool> sendRemoteCommand(String command, {Map<String, dynamic>? params});
  void dispose();
}

/// Simulated mock repository for automated unit testing.
class MockVehicleRepository implements VehicleRepository {
  final _controller = StreamController<VehicleTelemetry>.broadcast();
  VehicleTelemetry _current;
  VehicleConnectionStatus _status = VehicleConnectionStatus.disconnected;

  MockVehicleRepository({bool withSampleData = false})
      : _current = withSampleData
            ? VehicleTelemetry.sampleData()
            : VehicleTelemetry.unbound(label: 'Pending Car Bind'),
        _status = withSampleData
            ? VehicleConnectionStatus.connected
            : VehicleConnectionStatus.disconnected;

  @override
  Stream<VehicleTelemetry> get telemetryStream => _controller.stream;

  @override
  VehicleTelemetry get currentTelemetry => _current;

  @override
  VehicleConnectionStatus get connectionStatus => _status;

  @override
  bool get isCloudConnected => _current.isBound;

  @override
  bool get isPreActivationMode => false;

  @override
  bool get isVehicleBound => _current.isBound;

  @override
  String? get connectedAccount => null;

  @override
  String? get vehicleId => null;

  @override
  Future<void> refresh() async {
    _controller.add(_current);
  }

  @override
  void toggleCharging(bool charging) {
    _current = _current.copyWith(
      isCharging: charging,
      chargePowerKw: charging ? 6.6 : 0.0,
      chargeRemainMin: charging ? 38 : null,
      lastUpdated: DateTime.now(),
    );
    _controller.add(_current);
  }

  @override
  Future<void> connect({required String account, required String password, String region = 'sea'}) async {
    _status = VehicleConnectionStatus.connecting;
    await Future.delayed(const Duration(milliseconds: 100));
    _status = VehicleConnectionStatus.connected;
    _current = VehicleTelemetry.unbound(label: 'Pending Car Bind');
    _controller.add(_current);
  }

  @override
  Future<void> disconnect() async {
    _status = VehicleConnectionStatus.disconnected;
    _current = VehicleTelemetry.unbound(label: 'Pending Car Bind • Disconnected');
    _controller.add(_current);
  }

  @override
  Future<bool> sendRemoteCommand(String command, {Map<String, dynamic>? params}) async {
    return true;
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
  String? _deviceSn;
  String? _account;
  bool _isPreActivation = false;

  LiveCarLinkoRepository({String region = 'sea', CarLinkoClient? client})
      : _client = client ?? CarLinkoClient(region: region),
        _current = VehicleTelemetry.unbound(label: 'Pending Car Bind • Disconnected');

  CarLinkoClient get client => _client;
  @override
  String? get vehicleId => _vehicleId;
  String? get account => _account;
  bool get isPreActivation => _isPreActivation;

  @override
  Stream<VehicleTelemetry> get telemetryStream => _controller.stream;

  @override
  VehicleTelemetry get currentTelemetry => _current;

  @override
  VehicleConnectionStatus get connectionStatus => _status;

  @override
  bool get isCloudConnected => _status == VehicleConnectionStatus.connected;

  @override
  bool get isPreActivationMode => _isPreActivation;

  @override
  bool get isVehicleBound => _vehicleId != null && _status == VehicleConnectionStatus.connected && !_isPreActivation;

  @override
  String? get connectedAccount => _account;

  @override
  Future<void> connect({required String account, required String password, String region = 'sea'}) async {
    _status = VehicleConnectionStatus.connecting;
    _client.region = region;
    _account = account;
    try {
      await _client.login(account, password);

      List<Map<String, dynamic>> vehicles = [];
      try {
        vehicles = await _client.getVehicles();
      } catch (_) {
        vehicles = [];
      }

      if (vehicles.isEmpty) {
        // Authenticated with CarLinko cloud credentials,
        // but the Chery 3S/4S dealer has not yet bound/registered the VIN to the DMS.
        _vehicleId = null;
        _isPreActivation = true;
        _status = VehicleConnectionStatus.connected;
        _current = VehicleTelemetry.unbound(
          label: 'CarLinko Cloud Active • Pending Car Bind (Awaiting 3S/4S Pairing)',
        );
        _controller.add(_current);
      } else {
        _isPreActivation = false;
        _vehicleId = vehicles.first['vehicleId']?.toString();
        _deviceSn = _extractDeviceSn(vehicles.first);
        _status = VehicleConnectionStatus.connected;
        await refresh();
      }
      // Logged in successfully (whether or not a vehicle is bound yet) —
      // save the session so the app doesn't need a fresh login every cold
      // start. Only the bearer token is saved, never the password.
      await _persistSession();
    } catch (e) {
      if (e is CarLinkoAuthException) {
        _status = VehicleConnectionStatus.authRequired;
      } else {
        _status = VehicleConnectionStatus.error;
      }
      rethrow;
    }
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _client.token;
      if (token == null || _account == null) return;
      await prefs.setString(_kCarLinkoTokenKey, token);
      await prefs.setString(_kCarLinkoAccountKey, _account!);
      await prefs.setString(_kCarLinkoRegionKey, _client.region);
      if (_vehicleId != null) {
        await prefs.setString(_kCarLinkoVehicleIdKey, _vehicleId!);
      } else {
        await prefs.remove(_kCarLinkoVehicleIdKey);
      }
      if (_deviceSn != null) {
        await prefs.setString(_kCarLinkoDeviceSnKey, _deviceSn!);
      } else {
        await prefs.remove(_kCarLinkoDeviceSnKey);
      }
    } catch (_) {}
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCarLinkoTokenKey);
      await prefs.remove(_kCarLinkoRegionKey);
      await prefs.remove(_kCarLinkoVehicleIdKey);
      await prefs.remove(_kCarLinkoDeviceSnKey);
      // Keep the account name saved so the connect dialog can still
      // pre-fill it; only the token/session itself is invalidated.
    } catch (_) {}
  }

  /// Restore a previously-saved CarLinko session (if any) without asking
  /// the user to log in again. Returns true if a usable session (logged in
  /// to the cloud, whether or not a vehicle is bound yet) was restored.
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kCarLinkoTokenKey);
      final account = prefs.getString(_kCarLinkoAccountKey);
      if (token == null || token.isEmpty || account == null || account.isEmpty) {
        return false;
      }
      final region = prefs.getString(_kCarLinkoRegionKey) ?? 'sea';

      _status = VehicleConnectionStatus.connecting;
      _client.region = region;
      _client.token = token;
      _account = account;

      final savedVehicleId = prefs.getString(_kCarLinkoVehicleIdKey);
      final savedDeviceSn = prefs.getString(_kCarLinkoDeviceSnKey);
      List<Map<String, dynamic>> vehicles = [];
      try {
        vehicles = await _client.getVehicles();
      } catch (e) {
        if (e is CarLinkoAuthException) {
          // Saved token is no longer valid — clear it so the user gets a
          // normal login prompt instead of silently failing forever.
          _client.token = null;
          _status = VehicleConnectionStatus.disconnected;
          await _clearPersistedSession();
          return false;
        }
        // Network/transient error: keep the saved session, just couldn't
        // confirm it right now. Fall back to whatever we had saved.
        if (savedVehicleId != null) {
          _vehicleId = savedVehicleId;
          _deviceSn = savedDeviceSn;
          _isPreActivation = false;
        } else {
          _isPreActivation = true;
        }
        _status = VehicleConnectionStatus.connected;
        _current = VehicleTelemetry.unbound(
          label: 'CarLinko Cloud Active • Restoring session…',
        );
        _controller.add(_current);
        return true;
      }

      if (vehicles.isEmpty) {
        _vehicleId = null;
        _deviceSn = null;
        _isPreActivation = true;
        _status = VehicleConnectionStatus.connected;
        _current = VehicleTelemetry.unbound(
          label: 'CarLinko Cloud Active • Pending Car Bind (Awaiting 3S/4S Pairing)',
        );
        _controller.add(_current);
      } else {
        _isPreActivation = false;
        _vehicleId = vehicles.first['vehicleId']?.toString();
        _deviceSn = _extractDeviceSn(vehicles.first);
        _status = VehicleConnectionStatus.connected;
        await refresh();
      }
      await _persistSession();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Manually activate pre-activation mode (e.g. restoring saved active cloud state)
  void setPreActivationMode({String? account}) {
    _account = account ?? _account;
    _isPreActivation = true;
    _status = VehicleConnectionStatus.connected;
    _current = VehicleTelemetry.unbound(
      label: 'CarLinko Cloud Active • Pending Car Bind',
    );
    _controller.add(_current);
  }

  @override
  Future<void> refresh() async {
    if (_vehicleId == null) {
      // In pre-activation mode: check if dealer has freshly activated the vehicle on cloud
      if (_client.token != null) {
        try {
          final vehicles = await _client.getVehicles();
          if (vehicles.isNotEmpty) {
            _vehicleId = vehicles.first['vehicleId']?.toString();
            _deviceSn = _extractDeviceSn(vehicles.first);
            _isPreActivation = false;
            final state = await _client.getVehicleState(_vehicleId!);
            _logRawTelemetryBlob(state);
            _current = VehicleTelemetry.fromBlobMap(state, isSimulated: false);
            _status = VehicleConnectionStatus.connected;
            _controller.add(_current);
            _resolveLocation(_current);
            unawaited(VehicleAlertNotifier.checkAndNotify(_current));
            return;
          }
        } catch (e) {
          if (e is CarLinkoAuthException) {
            _status = VehicleConnectionStatus.authRequired;
            await _clearPersistedSession();
            rethrow;
          }
        }
      }
      _current = VehicleTelemetry.unbound(
        label: 'CarLinko Cloud Active • Pending Car Bind',
      );
      _status = VehicleConnectionStatus.connected;
      _controller.add(_current);
      return;
    }

    try {
      final state = await _client.getVehicleState(_vehicleId!);
      _logRawTelemetryBlob(state);
      _current = VehicleTelemetry.fromBlobMap(state, isSimulated: false);
      _status = VehicleConnectionStatus.connected;
      _controller.add(_current);
      _resolveLocation(_current);
      unawaited(VehicleAlertNotifier.checkAndNotify(_current));
    } catch (e) {
      if (e is CarLinkoAuthException) {
        _status = VehicleConnectionStatus.authRequired;
        await _clearPersistedSession();
      } else {
        _status = VehicleConnectionStatus.error;
      }
      rethrow;
    }
  }

  /// Fetches the car's real GPS position from CarLinko's own locate
  /// endpoint (the 73-byte telemetry blob never carries it — confirmed
  /// always zero on a real car) and backfills [telemetry] with it. Prefers
  /// CarLinko's own address when it provides one, falling back to
  /// OpenStreetMap only when it doesn't. Fire-and-forget, so a slow/failed
  /// lookup never blocks the dashboard from showing telemetry that already
  /// arrived.
  void _resolveLocation(VehicleTelemetry telemetry) {
    final deviceSn = _deviceSn;
    if (deviceSn == null) return;
    unawaited(() async {
      Map<String, dynamic> loc;
      try {
        loc = await _client.locateDevice(deviceSn);
      } catch (e) {
        debugPrint('CarLinko locateDevice failed: $e');
        return;
      }
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble() ?? (loc['lon'] as num?)?.toDouble();
      if (lat == null || lng == null || (lat == 0 && lng == 0)) return;

      var address = (loc['address'] as String?)?.trim();
      if (address == null || address.isEmpty) {
        address = await ReverseGeocoder.lookup(lat, lng);
      }

      // Only apply if nothing newer has arrived while this lookup was in
      // flight (a later refresh would already have its own location).
      if (!identical(_current, telemetry)) return;
      _current = _current.copyWith(
        latitude: lat,
        longitude: lng,
        locationName: address ?? _current.locationName,
      );
      _controller.add(_current);
    }());
  }

  /// Logs the raw 73-byte telemetry hex and every decoded field. The byte
  /// offsets in CarLinkoClient.parseBlob were ported from reverse-engineering
  /// a different Chery model; fields like 12V voltage, SOH or fuel level may
  /// be at the wrong offset (or simply not present) for this car. Compare
  /// this log against the car's own dash readouts to find/fix any that are
  /// wrong — grep logcat for "CarLinko raw blob".
  void _logRawTelemetryBlob(Map<String, dynamic> state) {
    debugPrint('CarLinko raw blob: ${state['rawHex']}');
    debugPrint('CarLinko decoded fields: $state');
  }

  @override
  void toggleCharging(bool charging) {
    if (_vehicleId != null) {
      _current = _current.copyWith(isCharging: charging);
      _controller.add(_current);
    }
  }

  @override
  Future<void> disconnect() async {
    _client.token = null;
    _vehicleId = null;
    _deviceSn = null;
    _account = null;
    _isPreActivation = false;
    _status = VehicleConnectionStatus.disconnected;
    _current = VehicleTelemetry.unbound(label: 'Pending Car Bind • Disconnected');
    _controller.add(_current);
    await _clearPersistedSession();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCarLinkoAccountKey);
    } catch (_) {}
  }

  /// [command] is a raw hex opcode from [CarLinkoOpcodes] (e.g.
  /// CarLinkoOpcodes.lock) — the real remoteControl API takes an opcode in
  /// its `data` field, not a semantic command name. [params] is unused; the
  /// real request body has no per-command extra fields.
  @override
  Future<bool> sendRemoteCommand(String command, {Map<String, dynamic>? params}) async {
    if (_vehicleId == null || _deviceSn == null) {
      debugPrint('CarLinko remoteControl "$command" skipped: no vehicle/deviceSn bound');
      return false;
    }
    try {
      // _client.sendRemoteControl() already throws unless CarLinko's cloud
      // reported top-level code "0000" (see CarLinkoClient._request), so
      // reaching here at all means the command was accepted. The returned
      // "data" payload isn't guaranteed to carry its own code/success
      // field, so re-checking one here was the actual bug: it silently
      // reported "failed" even on a real, accepted command.
      await _client.sendRemoteControl(
        vehicleId: _vehicleId!,
        deviceSn: _deviceSn!,
        opcode: command,
      );
      return true;
    } catch (e) {
      debugPrint('CarLinko remoteControl "$command" failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// Unified App-level repository managing the shared instance across the entire application.
class AppVehicleRepository implements VehicleRepository {
  static final AppVehicleRepository instance = AppVehicleRepository._internal();
  AppVehicleRepository._internal() {
    _isLiveActive = true;
    _current = _liveRepo.currentTelemetry;
    _liveSubscription = _liveRepo.telemetryStream.listen(_handleLiveTelemetry);
  }

  /// Shared by every place that (re)subscribes to the live telemetry
  /// stream: updates the unified stream and backs up a real reading to
  /// Firestore (fire-and-forget; sync failures never block the UI).
  void _handleLiveTelemetry(VehicleTelemetry data) {
    if (!_isLiveActive) return;
    _current = data;
    _controller.add(data);
    unawaited(FirebaseSyncService.instance.syncTelemetrySnapshot(data));
  }

  factory AppVehicleRepository() => instance;

  final MockVehicleRepository _mockRepo = MockVehicleRepository();
  final LiveCarLinkoRepository _liveRepo = LiveCarLinkoRepository();
  StreamSubscription<VehicleTelemetry>? _mockSubscription;
  StreamSubscription<VehicleTelemetry>? _liveSubscription;

  bool _isLiveActive = true;
  bool get isLiveActive => _isLiveActive;
  bool get isPreActivation => isPreActivationMode;

  @override
  bool get isCloudConnected => _isLiveActive ? _liveRepo.isCloudConnected : _mockRepo.isCloudConnected;

  @override
  bool get isPreActivationMode => _isLiveActive ? _liveRepo.isPreActivationMode : _mockRepo.isPreActivationMode;

  @override
  bool get isVehicleBound => _isLiveActive ? _liveRepo.isVehicleBound : _mockRepo.isVehicleBound;

  @override
  String? get vehicleId => _isLiveActive ? _liveRepo.vehicleId : _mockRepo.vehicleId;

  @override
  String? get connectedAccount => _isLiveActive ? _liveRepo.connectedAccount : null;

  LiveCarLinkoRepository get liveRepo => _liveRepo;

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

  @override
  Future<bool> sendRemoteCommand(String command, {Map<String, dynamic>? params}) async {
    if (_isLiveActive) {
      return _liveRepo.sendRemoteCommand(command, params: params);
    }
    return _mockRepo.sendRemoteCommand(command, params: params);
  }

  /// Restore a previously-saved CarLinko session (if any) so the app
  /// doesn't force a fresh login on every cold start. Returns true if a
  /// session was actually restored.
  Future<bool> restoreSession() async {
    final restored = await _liveRepo.restoreSession();
    if (restored) {
      _isLiveActive = true;
      _current = _liveRepo.currentTelemetry;
      _liveSubscription?.cancel();
      _liveSubscription = _liveRepo.telemetryStream.listen(_handleLiveTelemetry);
      _controller.add(_current);
    }
    return restored;
  }

  /// Explicitly reset to offline simulation mode (safe fallback before dealership activation).
  void useMockMode() {
    _isLiveActive = false;
    _current = _mockRepo.currentTelemetry;
    _controller.add(_current);
  }

  /// Manually activate pre-activation cloud state (e.g. restoring saved preferences)
  void setPreActivationActive({String? account}) {
    _isLiveActive = true;
    _liveRepo.setPreActivationMode(account: account);
    _current = _liveRepo.currentTelemetry;
    _liveSubscription?.cancel();
    _liveSubscription = _liveRepo.telemetryStream.listen(_handleLiveTelemetry);
    _controller.add(_current);
  }

  @override
  Future<void> connect({required String account, required String password, String region = 'sea'}) async {
    try {
      await _liveRepo.connect(account: account, password: password, region: region);
      _isLiveActive = true;
      _current = _liveRepo.currentTelemetry;
      _liveSubscription?.cancel();
      _liveSubscription = _liveRepo.telemetryStream.listen(_handleLiveTelemetry);
      _controller.add(_current);
    } catch (e) {
      _isLiveActive = true;
      _current = _liveRepo.currentTelemetry;
      _controller.add(_current);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _liveRepo.disconnect();
    _isLiveActive = true;
    _current = _liveRepo.currentTelemetry;
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
