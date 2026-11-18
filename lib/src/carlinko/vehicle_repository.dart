import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase/firebase_sync_service.dart';
import '../service/vehicle_alert_notifier.dart';
import '../service/auto_trip_and_charge_service.dart';
import 'carlinko_api.dart';
import 'carlinko_ble_controller.dart';
import 'reverse_geocoder.dart';
import 'vehicle_telemetry.dart';

const _secureStorage = FlutterSecureStorage();
const String _kCarLinkoSavedPasswordKey = 'tm_carlinko_saved_password';
const String _kCarLinkoSavedPasswordAccountKey = 'tm_carlinko_saved_password_account';

const String _kCarLinkoTokenKey = 'tm_carlinko_token';
const String _kCarLinkoAccountKey = 'tm_carlinko_account';
const String _kCarLinkoRegionKey = 'tm_carlinko_region';
const String _kCarLinkoVehicleIdKey = 'tm_carlinko_vehicle_id';
const String _kCarLinkoDeviceSnKey = 'tm_carlinko_device_sn';

/// Pulls the vehicle's device serial number from a /user/vehicle row. Real
/// API responses use either key depending on the account (per ha-carlinko).
/// Prioritizes deviceSn and sn over deviceId (which is an internal database row ID).
String? _extractDeviceSn(Map<String, dynamic> vehicle) =>
    vehicle['deviceSn']?.toString() ??
    vehicle['sn']?.toString() ??
    vehicle['deviceId']?.toString() ??
    vehicle['vin']?.toString() ??
    vehicle['vehicleId']?.toString();

/// Detailed outcome of a remote-control CAN opcode transmission.
class RemoteCommandResult {
  final bool success;
  final String opcode;
  final String? code;
  final String? ackStatus;
  final bool retriedWith7801;
  final String? message;
  final dynamic rawData;
  final int latencyMs;
  final DateTime timestamp;

  RemoteCommandResult({
    required this.success,
    required this.opcode,
    this.code,
    this.ackStatus,
    this.retriedWith7801 = false,
    this.message,
    this.rawData,
    this.latencyMs = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'RemoteCommandResult(success: $success, opcode: $opcode, code: $code, ackStatus: $ackStatus, retried7801: $retriedWith7801, message: $message, latency: ${latencyMs}ms)';
}

abstract class VehicleRepository {
  Stream<VehicleTelemetry> get telemetryStream;
  VehicleTelemetry get currentTelemetry;
  VehicleCapabilities get vehicleCapabilities;
  VehicleConnectionStatus get connectionStatus;
  bool get isCloudConnected;
  bool get isPreActivationMode;
  bool get isVehicleBound;
  String? get connectedAccount;
  String? get vehicleId;
  String? get vin;
  String? get userId;
  String? get deviceSn;
  String? get lastLocateStatus;
  Future<List<Map<String, dynamic>>> getOperatingRecord();
  Future<void> refresh();
  Future<void> connect({required String account, required String password, String region = 'sea'});
  Future<void> disconnect();
  void toggleCharging(bool charging);
  Future<bool> sendRemoteCommand(String command, {Map<String, dynamic>? params});
  Future<RemoteCommandResult> sendRemoteCommandWithResult(
    String command, {
    bool sendWakeupHandshake = true,
    bool send0x23Init = false,
  });
  Future<bool> setTargetSoc(int targetSoc);
  Future<bool> setAirDuration(int minutes);
  Future<bool> setBatterySchedule(Map<String, dynamic> params);
  Future<Map<String, dynamic>> getTerminalNoticeConfig();
  Future<bool> setScheduledTravel({
    required bool enabled,
    required int hour,
    required int minute,
    List<bool>? week,
  });
  Future<bool> setAlertSwitch({required String configName, required bool enabled});
  Future<List<Map<String, dynamic>>> getCloudNotifications({int page = 1, int size = 20});
  Future<int> getUnreadNoticeCount();
  Future<List<Map<String, dynamic>>> getGeofences();
  Future<bool> addGeofence({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  });
  Future<RemoteCommandResult> addGeofenceWithResult({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  });
  Future<bool> updateGeofence({
    required String fenceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  });
  Future<RemoteCommandResult> updateGeofenceWithResult({
    required String fenceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  });
  Future<bool> updateGeofenceStatus(String id, int status);
  Future<bool> deleteGeofence(String id);
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
  VehicleCapabilities get vehicleCapabilities => VehicleCapabilities.defaults();

  @override
  String? get lastLocateStatus => 'GPS locked (Demo)';

  @override
  String? get connectedAccount => null;

  @override
  String? get vehicleId => null;

  @override
  String? get vin => null;

  @override
  String? get userId => '88504';

  @override
  String? get deviceSn => 'SEA1257A68450667';

  @override
  Future<List<Map<String, dynamic>>> getOperatingRecord() async => [];

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
  Future<RemoteCommandResult> sendRemoteCommandWithResult(
    String command, {
    bool sendWakeupHandshake = false,
    bool send0x23Init = false,
  }) async {
    return RemoteCommandResult(
      success: true,
      opcode: command,
      code: '0000',
      message: 'Mock command executed successfully',
      latencyMs: 12,
    );
  }

  @override
  Future<bool> setTargetSoc(int targetSoc) async => true;

  @override
  Future<bool> setAirDuration(int minutes) async => true;

  @override
  Future<bool> setBatterySchedule(Map<String, dynamic> params) async => true;

  @override
  Future<Map<String, dynamic>> getTerminalNoticeConfig() async => {};

  @override
  Future<bool> setScheduledTravel({
    required bool enabled,
    required int hour,
    required int minute,
    List<bool>? week,
  }) async =>
      true;

  @override
  Future<bool> setAlertSwitch({required String configName, required bool enabled}) async => true;

  @override
  Future<List<Map<String, dynamic>>> getCloudNotifications({int page = 1, int size = 20}) async => [];

  @override
  Future<int> getUnreadNoticeCount() async => 0;

  final List<Map<String, dynamic>> _mockGeofences = [];

  @override
  Future<List<Map<String, dynamic>>> getGeofences() async => List.from(_mockGeofences);

  @override
  Future<bool> addGeofence({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) async {
    final res = await addGeofenceWithResult(name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType);
    return res.success;
  }

  @override
  Future<RemoteCommandResult> addGeofenceWithResult({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) async {
    _mockGeofences.add({
      'id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius.round(),
      'alarmType': alarmType,
      'status': 1,
    });
    return RemoteCommandResult(
      success: true,
      opcode: 'GEOFENCE',
      code: '0000',
      message: 'Geofence active',
    );
  }

  @override
  Future<bool> updateGeofence({
    required String fenceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) async {
    final res = await updateGeofenceWithResult(
      fenceId: fenceId,
      name: name,
      lat: lat,
      lng: lng,
      radius: radius,
      alarmType: alarmType,
    );
    return res.success;
  }

  @override
  Future<RemoteCommandResult> updateGeofenceWithResult({
    required String fenceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) async {
    final idx = _mockGeofences.indexWhere((f) => f['id'] == fenceId);
    if (idx != -1) {
      _mockGeofences[idx] = {
        'id': fenceId,
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius': radius.round(),
        'alarmType': alarmType,
        'status': _mockGeofences[idx]['status'] ?? 1,
      };
    }
    return RemoteCommandResult(
      success: true,
      opcode: 'GEOFENCE',
      code: '0000',
      message: 'Geofence updated',
    );
  }

  @override
  Future<bool> updateGeofenceStatus(String id, int status) async {
    final idx = _mockGeofences.indexWhere((f) => f['id'] == id);
    if (idx != -1) {
      _mockGeofences[idx]['status'] = status;
    }
    return true;
  }

  @override
  Future<bool> deleteGeofence(String id) async {
    _mockGeofences.removeWhere((f) => f['id'] == id);
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
  String? _vin;
  String? _userId;
  String? _account;
  bool _isPreActivation = false;
  String? _lastLocateStatus;
  VehicleCapabilities _capabilities = VehicleCapabilities.defaults();

  LiveCarLinkoRepository({String region = 'sea', CarLinkoClient? client})
      : _client = client ?? CarLinkoClient(region: region),
        _current = VehicleTelemetry.unbound(label: 'Pending Car Bind • Disconnected');

  CarLinkoClient get client => _client;
  @override
  VehicleCapabilities get vehicleCapabilities => _capabilities;
  @override
  String? get vehicleId => _vehicleId;
  @override
  String? get vin => _vin;
  @override
  String? get userId => _userId;
  @override
  String? get deviceSn => _deviceSn;
  String? get account => _account;
  bool get isPreActivation => _isPreActivation;

  @override
  String? get lastLocateStatus => _lastLocateStatus;

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
  bool get isVehicleBound =>
      _vehicleId != null &&
      _status != VehicleConnectionStatus.disconnected &&
      _status != VehicleConnectionStatus.authRequired &&
      !_isPreActivation;

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
        _bindVehicleRow(vehicles.first);
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

  void _bindVehicleRow(Map<String, dynamic> row) {
    _vehicleId = row['vehicleId']?.toString();
    _deviceSn = _extractDeviceSn(row);
    _vin = row['vin']?.toString() ?? row['carVin']?.toString() ?? row['vinNo']?.toString();
    if (row['userId'] != null) {
      _userId ??= row['userId']?.toString();
    }
    _capabilities = VehicleCapabilities.fromVehicleMap(row);
    _isPreActivation = false;
    unawaited(_ensureUserId());
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
      if (_vin != null) {
        await prefs.setString('tm_carlinko_vin', _vin!);
      } else {
        await prefs.remove('tm_carlinko_vin');
      }
      if (_userId != null) {
        await prefs.setString('tm_carlinko_user_id', _userId!);
      } else {
        await prefs.remove('tm_carlinko_user_id');
      }
    } catch (_) {}
  }

  Future<String?> _ensureUserId() async {
    if (_userId != null && _userId!.isNotEmpty) return _userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('tm_carlinko_user_id');
      if (cached != null && cached.isNotEmpty) {
        _userId = cached;
        return _userId;
      }
    } catch (_) {}
    Map<String, dynamic>? info;
    try {
      info = await _client.getUserInfo();
    } on CarLinkoAuthException {
      if (await _tryAutoReauth()) {
        try {
          info = await _client.getUserInfo();
        } catch (_) {}
      }
    } on CarLinkoException catch (e) {
      if (e.code != null && carLinkoStaleTokenCodes.contains(e.code) && await _tryAutoReauth()) {
        try {
          info = await _client.getUserInfo();
        } catch (_) {}
      }
    } catch (_) {}
    final id = info?['id']?.toString();
    if (id != null && id.isNotEmpty) {
      _userId = id;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tm_carlinko_user_id', id);
      } catch (_) {}
    }
    return _userId;
  }

  Future<bool> _tryAutoReauth() async {
    try {
      final savedAccount = await _secureStorage.read(key: _kCarLinkoSavedPasswordAccountKey);
      final savedPassword = await _secureStorage.read(key: _kCarLinkoSavedPasswordKey);
      final accountToUse = (_account != null && _account!.isNotEmpty) ? _account! : savedAccount;
      if (accountToUse != null && savedPassword != null && accountToUse.isNotEmpty && savedPassword.isNotEmpty) {
        debugPrint('Auto-reauthenticating CarLinko session for account $accountToUse...');
        await connect(account: accountToUse, password: savedPassword, region: _client.region);
        return true;
      }
    } catch (e) {
      debugPrint('Auto-reauth failed: $e');
    }
    return false;
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCarLinkoTokenKey);
      await prefs.remove(_kCarLinkoRegionKey);
      await prefs.remove(_kCarLinkoVehicleIdKey);
      await prefs.remove(_kCarLinkoDeviceSnKey);
      await prefs.remove('tm_carlinko_user_id');
      _userId = null;
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
      _vin ??= prefs.getString('tm_carlinko_vin');
      _userId ??= prefs.getString('tm_carlinko_user_id');
      List<Map<String, dynamic>> vehicles = [];
      try {
        vehicles = await _client.getVehicles();
      } catch (e) {
        if (e is CarLinkoAuthException) {
          final reauthed = await _tryAutoReauth();
          if (reauthed) {
            return true;
          }
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
        _bindVehicleRow(vehicles.first);
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
            _bindVehicleRow(vehicles.first);
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
        final reauthed = await _tryAutoReauth();
        if (reauthed) {
          return;
        }
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
    unawaited(() async {
      double? lat;
      double? lng;
      String? address;

      final deviceSn = _deviceSn;
      if (deviceSn != null) {
        try {
          final loc = await _client.locateDevice(deviceSn, vehicleId: _vehicleId);
          if (loc['errorCode'] != null) {
            _lastLocateStatus = 'Chery Cloud [${loc['errorCode']}]: ${loc['errorMessage'] ?? 'Locate query failed'}';
          }
          double? parseCoord(dynamic val) {
            if (val == null) return null;
            if (val is num) return val.toDouble();
            if (val is String) return double.tryParse(val.trim());
            return null;
          }

          lat = parseCoord(loc['lat']) ??
              parseCoord(loc['latitude']) ??
              parseCoord(loc['gpsLat']) ??
              parseCoord(loc['pointLat']) ??
              (loc['point'] is Map ? parseCoord(loc['point']['lat']) : null);
          lng = parseCoord(loc['lng']) ??
              parseCoord(loc['lon']) ??
              parseCoord(loc['longitude']) ??
              parseCoord(loc['gpsLng']) ??
              parseCoord(loc['pointLng']) ??
              (loc['point'] is Map ? parseCoord(loc['point']['lng']) : null);
          address = (loc['address'] as String?)?.trim() ?? (loc['locationName'] as String?)?.trim();

          // Ported CarLinko telemetry cellular signal strength parsing
          int? parseSignalBars(dynamic val) {
            if (val == null) return null;
            final numVal = (val is num) ? val.toInt() : int.tryParse(val.toString().trim());
            if (numVal == null) return null;
            if (numVal >= 0 && numVal <= 4) return numVal;
            if (numVal >= 5 && numVal <= 31) {
              if (numVal >= 20) return 4;
              if (numVal >= 15) return 3;
              if (numVal >= 10) return 2;
              return 1;
            }
            if (numVal < 0) {
              if (numVal >= -75) return 4;
              if (numVal >= -85) return 3;
              if (numVal >= -100) return 2;
              return 1;
            }
            return null;
          }

          final rawSig = loc['signal'] ?? loc['gsmSignal'] ?? loc['csq'] ?? loc['netSignal'] ?? loc['signalLevel'] ?? loc['networkSignal'];
          final parsedBars = parseSignalBars(rawSig);
          final parsedCsq = (rawSig is num) ? rawSig.toInt() : int.tryParse(rawSig?.toString() ?? '');

          if (parsedBars != null || parsedCsq != null) {
            _current = _current.copyWith(
              cellularSignalBars: parsedBars ?? _current.cellularSignalBars,
              cellularCsq: parsedCsq ?? _current.cellularCsq,
            );
          }
        } catch (e) {
          debugPrint('CarLinko locateDevice failed: $e');
          _lastLocateStatus = 'Locate error: $e';
        }
      }

      if (lat != null && lng != null && (lat != 0 && lng != 0)) {
        if (address == null || address.isEmpty) {
          address = await ReverseGeocoder.lookup(lat, lng);
        }
        _lastLocateStatus = 'Vehicle GPS locked (${address ?? "$lat, $lng"})';
        _current = _current.copyWith(
          latitude: lat,
          longitude: lng,
          locationName: address ?? _current.locationName,
        );
        _controller.add(_current);
        return;
      }

      // CRITICAL: NEVER overwrite vehicle telemetry with phone parking coordinates!
      // The vehicle's telemetry must strictly represent the car's state.
      // If Chery T-Box has not reported GPS coordinates (e.g. offline, asleep, or underground),
      // we maintain the telemetry's honesty and mark status accordingly.
      if (_current.latitude == 0.0 && (_current.locationName.isEmpty || _current.locationName == 'Pending Car Bind')) {
        _current = _current.copyWith(
          locationName: 'Vehicle GPS Signal Pending',
        );
        _controller.add(_current);
      }
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
    final raw = state['rawHex']?.toString();
    if (raw != null && raw.isNotEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('tm_last_raw_hex', raw);
      }).catchError((_) {});
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOperatingRecord() async {
    return _client.getOperatingRecord(vehicleId: _vehicleId, vin: _vin);
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
    final res = await sendRemoteCommandWithResult(command);
    return res.success;
  }

  @override
  Future<RemoteCommandResult> sendRemoteCommandWithResult(
    String command, {
    bool sendWakeupHandshake = true,
    bool send0x23Init = false,
  }) async {
    final ble = CarLinkoBleController();
    bool bleDispatched = false;

    // Optional proximity actuation if BLE is active
    if (ble.isConnected) {
      final bleOpcode = CarLinkoBleOpcodes.fromCloudOpcode(command);
      if (bleOpcode != null) {
        debugPrint('Dual-Link BLE: Dispatching proximity opcode $bleOpcode over Nordic UART');
        bleDispatched = await ble.sendCommand(bleOpcode);
      }
    }

    if (_vehicleId == null || _deviceSn == null) {
      debugPrint('CarLinko remoteControl "$command" skipped: no vehicle/deviceSn bound');
      return RemoteCommandResult(
        success: bleDispatched,
        opcode: command,
        code: bleDispatched ? 'BLE_OK' : 'NO_BIND',
        message: bleDispatched
            ? 'Command executed via Direct BLE (<50ms proximity)'
            : 'No vehicle or device serial number bound',
      );
    }
    RemoteCommandResult buildCloudResult(
      String usedOpcode,
      Map<String, dynamic> res, {
      required int latencyMs,
      String? note,
    }) {
      final ackStatus = res['ackStatus']?.toString();
      final applied = res['applied'] != false;

      if (applied) {
        // Schedule a background telemetry refresh ~1.8s after T-Box confirmation so UI reflects hardware state.
        unawaited(
          Future.delayed(const Duration(milliseconds: 1800), () async {
            try {
              await refresh();
            } catch (_) {}
          }),
        );
      }

      final success = applied || bleDispatched;
      final code = applied ? (ackStatus != null ? 'ACK_$ackStatus' : '0000') : 'ACK_${ackStatus ?? 'REJECTED'}';
      final rawEcho = res['echo']?.toString() ?? '<null>';
      final refusalDesc = CarLinkoClient.refusalReason(ackStatus);
      final rawTag = ' (raw: $rawEcho)';
      final ackTag = ackStatus != null ? ' (ack $ackStatus)$rawTag' : rawTag;
      final msg = applied
          ? (bleDispatched
              ? 'Executed via Direct BLE & Applied on T-Box$ackTag'
              : '${note ?? 'Command applied by T-Box via 4G'}$ackTag')
          : (bleDispatched
              ? 'Executed via Direct BLE (<50ms proximity) • 4G T-Box returned $ackStatus$rawTag'
              : 'T-Box returned status $ackStatus${refusalDesc != null ? ' ($refusalDesc)' : ' (car did not apply command)'}$rawTag');

      return RemoteCommandResult(
        success: success,
        opcode: usedOpcode,
        code: code,
        ackStatus: ackStatus,
        retriedWith7801: false,
        message: msg,
        rawData: res,
        latencyMs: latencyMs,
      );
    }

    final uid = command.toUpperCase().startsWith('74') ? await _ensureUserId() : _userId;
    final sw = Stopwatch()..start();
    try {
      final res = await _client.sendRemoteControl(
        vehicleId: _vehicleId!,
        deviceSn: _deviceSn!,
        opcode: command,
        vin: _vin,
        userId: uid,
        sendWakeupHandshake: sendWakeupHandshake,
        send0x23Init: send0x23Init,
      );
      sw.stop();
      return buildCloudResult(command, res, latencyMs: sw.elapsedMilliseconds);
    } on CarLinkoException catch (e) {
      sw.stop();
      debugPrint('CarLinko remoteControl "$command" failed: ${e.code} - ${e.message}');

      // If cellular asleep (50043) but BLE succeeded, return success via BLE
      if (e.code == '50043' && bleDispatched) {
        return RemoteCommandResult(
          success: true,
          opcode: command,
          code: 'BLE_OK',
          message: 'Executed via Direct BLE (<50ms proximity) • (Vehicle 4G modem asleep)',
          latencyMs: sw.elapsedMilliseconds,
        );
      }

      // If cellular asleep (50043), trigger background BLE auto-discovery & retry with 0x77 wakeup frame
      if (e.code == '50043') {
        unawaited(ble.startScan(timeoutSeconds: 8));
        if (!sendWakeupHandshake && _vehicleId != null && _deviceSn != null) {
          debugPrint('Modem asleep (50043). Retrying with official 0x77 wakeup handshake...');
          try {
            final resRetry = await _client.sendRemoteControl(
              vehicleId: _vehicleId!,
              deviceSn: _deviceSn!,
              opcode: command,
              vin: _vin,
              userId: uid,
              sendWakeupHandshake: true,
              send0x23Init: false,
            );
            return buildCloudResult(
              command,
              resRetry,
              latencyMs: sw.elapsedMilliseconds,
              note: 'Command succeeded via 4G after official 77 wakeup handshake',
            );
          } catch (retryErr) {
            debugPrint('Wakeup handshake retry also failed: $retryErr');
          }
        }
      }

      // 1. If auth/token issue, attempt auto-reauth once and retry command
      if (e is CarLinkoAuthException || (e.code != null && carLinkoStaleTokenCodes.contains(e.code))) {
        debugPrint('Detected stale token during command execution. Attempting auto-reauth...');
        final reauthed = await _tryAutoReauth();
        if (reauthed && _vehicleId != null && _deviceSn != null) {
          try {
            final resRetry = await _client.sendRemoteControl(
              vehicleId: _vehicleId!,
              deviceSn: _deviceSn!,
              opcode: command,
              vin: _vin,
              userId: await _ensureUserId(),
              sendWakeupHandshake: sendWakeupHandshake,
              send0x23Init: send0x23Init,
            );
            return buildCloudResult(
              command,
              resRetry,
              latencyMs: sw.elapsedMilliseconds,
              note: 'Command succeeded after auto-relogin',
            );
          } catch (retryErr) {
            debugPrint('Command retry after auto-reauth failed: $retryErr');
          }
        }
      }

      // 2. Alternative opcode for A/C off (if primary opcode rejected)
      if (command == CarLinkoOpcodes.acOff) {
        try {
          final resAlt = await _client.sendRemoteControl(
            vehicleId: _vehicleId!,
            deviceSn: _deviceSn!,
            opcode: CarLinkoOpcodes.acOffAlt,
            vin: _vin,
            userId: uid,
            sendWakeupHandshake: false,
            send0x23Init: false,
          );
          return buildCloudResult(
            CarLinkoOpcodes.acOffAlt,
            resAlt,
            latencyMs: sw.elapsedMilliseconds,
            note: 'A/C off executed with alternative opcode',
          );
        } catch (_) {}
      }

      // 3. Alternative opcode for Trunk open (if primary opcode rejected)
      if (command == CarLinkoOpcodes.trunkOpen) {
        try {
          final resAlt = await _client.sendRemoteControl(
            vehicleId: _vehicleId!,
            deviceSn: _deviceSn!,
            opcode: CarLinkoOpcodes.trunkOpenAlt,
            vin: _vin,
            userId: uid,
            sendWakeupHandshake: false,
            send0x23Init: false,
          );
          return buildCloudResult(
            CarLinkoOpcodes.trunkOpenAlt,
            resAlt,
            latencyMs: sw.elapsedMilliseconds,
            note: 'Trunk open executed with alternative opcode',
          );
        } catch (_) {}
      }

      return RemoteCommandResult(
        success: bleDispatched,
        opcode: command,
        code: bleDispatched ? 'BLE_OK' : e.code,
        message: bleDispatched ? 'Executed via Direct BLE (<50ms proximity)' : e.message,
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      debugPrint('CarLinko remoteControl "$command" error: $e');
      return RemoteCommandResult(
        success: bleDispatched,
        opcode: command,
        code: bleDispatched ? 'BLE_OK' : 'ERROR',
        message: bleDispatched ? 'Executed via Direct BLE (<50ms proximity)' : e.toString(),
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  }

  @override
  Future<bool> setTargetSoc(int targetSoc) async {
    if (_vehicleId == null) return false;
    try {
      return await _client.setTargetSoc(_vehicleId!, targetSoc, deviceSn: _deviceSn);
    } catch (e) {
      debugPrint('LiveCarLinkoRepository setTargetSoc error: $e');
      return false;
    }
  }

  @override
  Future<bool> setAirDuration(int minutes) async {
    if (_vehicleId == null) return false;
    try {
      return await _client.setAirDuration(_vehicleId!, minutes);
    } catch (e) {
      debugPrint('LiveCarLinkoRepository setAirDuration error: $e');
      return false;
    }
  }

  @override
  Future<bool> setBatterySchedule(Map<String, dynamic> params) async {
    if (_vehicleId == null) return false;
    try {
      return await _client.setBatterySchedule(_vehicleId!, params);
    } catch (e) {
      debugPrint('LiveCarLinkoRepository setBatterySchedule error: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getTerminalNoticeConfig() async {
    if (_vehicleId == null) return {};
    try {
      return await _client.getTerminalNoticeConfig(_vehicleId!);
    } catch (e) {
      debugPrint('LiveCarLinkoRepository getTerminalNoticeConfig error: $e');
      return {};
    }
  }

  @override
  Future<bool> setScheduledTravel({
    required bool enabled,
    required int hour,
    required int minute,
    List<bool>? week,
  }) async {
    if (_vehicleId == null) return false;
    try {
      return await _client.setScheduledTravel(
        vehicleId: _vehicleId!,
        enabled: enabled,
        hour: hour,
        minute: minute,
        week: week,
      );
    } catch (e) {
      debugPrint('LiveCarLinkoRepository setScheduledTravel error: $e');
      return false;
    }
  }

  @override
  Future<bool> setAlertSwitch({required String configName, required bool enabled}) async {
    if (_vehicleId == null) return false;
    try {
      return await _client.setAlertSwitch(
        vehicleId: _vehicleId!,
        configName: configName,
        enabled: enabled,
      );
    } catch (e) {
      debugPrint('LiveCarLinkoRepository setAlertSwitch error: $e');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCloudNotifications({int page = 1, int size = 20}) async {
    if (_vehicleId == null) return [];
    return _client.getCloudNotifications(_vehicleId!, page: page, size: size);
  }

  @override
  Future<int> getUnreadNoticeCount() async {
    if (_vehicleId == null) return 0;
    return _client.getUnreadNoticeCount(_vehicleId!);
  }

  @override
  Future<List<Map<String, dynamic>>> getGeofences() async {
    final list = <Map<String, dynamic>>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('tm_local_geofence');
      if (localJson != null && localJson.isNotEmpty) {
        final decoded = json.decode(localJson);
        if (decoded is Map<String, dynamic>) {
          list.add(decoded);
        }
      }
    } catch (e) {
      debugPrint('Error reading local geofence: $e');
    }

    if (_vehicleId != null) {
      try {
        final cloudFences = await _client.getGeofences(_vehicleId!);
        list.addAll(cloudFences);
      } catch (e) {
        debugPrint('LiveCarLinkoRepository getGeofences error: $e');
      }
    }
    return list;
  }

  @override
  Future<bool> addGeofence({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) async {
    final res = await addGeofenceWithResult(name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType);
    return res.success;
  }

  @override
  Future<RemoteCommandResult> addGeofenceWithResult({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) async {
    if (_vehicleId == null) {
      return RemoteCommandResult(
        success: false,
        opcode: 'GEOFENCE',
        code: 'NO_BIND',
        message: 'No vehicle bound',
      );
    }

    try {
      final res = await _client.addGeofence(
        vehicleId: _vehicleId!,
        fenceName: name,
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
        alarmType: alarmType,
      );
      return RemoteCommandResult(
        success: true,
        opcode: 'GEOFENCE',
        code: '0000',
        message: 'Geofence active on T-Box',
        rawData: res,
      );
    } on CarLinkoException catch (e) {
      debugPrint('LiveCarLinkoRepository addGeofence error: ${e.code} - ${e.message}');
      return RemoteCommandResult(
        success: false,
        opcode: 'GEOFENCE',
        code: e.code,
        message: e.message,
      );
    } catch (e) {
      debugPrint('LiveCarLinkoRepository addGeofence error: $e');
      return RemoteCommandResult(
        success: false,
        opcode: 'GEOFENCE',
        code: 'ERROR',
        message: e.toString(),
      );
    }
  }

  @override
  Future<bool> updateGeofence({
    required String fenceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) async {
    final res = await updateGeofenceWithResult(
      fenceId: fenceId,
      name: name,
      lat: lat,
      lng: lng,
      radius: radius,
      alarmType: alarmType,
    );
    return res.success;
  }

  @override
  Future<RemoteCommandResult> updateGeofenceWithResult({
    required String fenceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) async {
    if (_vehicleId == null) {
      return RemoteCommandResult(
        success: false,
        opcode: 'GEOFENCE',
        code: 'NO_BIND',
        message: 'No vehicle bound',
      );
    }

    try {
      final res = await _client.updateGeofence(
        fenceId: fenceId,
        vehicleId: _vehicleId!,
        fenceName: name,
        latitude: lat,
        longitude: lng,
        radiusMeters: radius,
        alarmType: alarmType,
      );
      return RemoteCommandResult(
        success: true,
        opcode: 'GEOFENCE',
        code: '0000',
        message: 'Geofence updated on T-Box',
        rawData: res,
      );
    } on CarLinkoException catch (e) {
      debugPrint('LiveCarLinkoRepository updateGeofence error: ${e.code} - ${e.message}');
      return RemoteCommandResult(
        success: false,
        opcode: 'GEOFENCE',
        code: e.code,
        message: e.message,
      );
    } catch (e) {
      debugPrint('LiveCarLinkoRepository updateGeofence error: $e');
      return RemoteCommandResult(
        success: false,
        opcode: 'GEOFENCE',
        code: 'ERROR',
        message: e.toString(),
      );
    }
  }

  @override
  Future<bool> updateGeofenceStatus(String id, int status) async {
    if (id == 'local_guard' || id.startsWith('local_')) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final localJson = prefs.getString('tm_local_geofence');
        if (localJson != null && localJson.isNotEmpty) {
          final decoded = json.decode(localJson) as Map<String, dynamic>;
          decoded['status'] = status;
          await prefs.setString('tm_local_geofence', json.encode(decoded));
          return true;
        }
      } catch (e) {
        debugPrint('Error updating local geofence status: $e');
      }
      return false;
    }

    if (_vehicleId == null) return false;
    try {
      return await _client.updateGeofenceStatus(
        vehicleId: _vehicleId!,
        fenceId: id,
        status: status,
      );
    } catch (e) {
      debugPrint('LiveCarLinkoRepository updateGeofenceStatus error: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteGeofence(String id) async {
    if (id == 'local_guard' || id.startsWith('local_')) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tm_local_geofence');
        await prefs.remove('tm_fence_was_outside');
        return true;
      } catch (e) {
        debugPrint('Error deleting local geofence: $e');
        return false;
      }
    }

    try {
      return await _client.deleteGeofence(id, vehicleId: _vehicleId);
    } catch (e) {
      debugPrint('LiveCarLinkoRepository deleteGeofence error: $e');
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
    try {
      AutoTripAndChargeService.instance.processTelemetry(data);
    } catch (_) {}
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
  String? get lastLocateStatus => _isLiveActive ? _liveRepo.lastLocateStatus : _mockRepo.lastLocateStatus;

  @override
  VehicleTelemetry get currentTelemetry => _isLiveActive ? _liveRepo.currentTelemetry : _mockRepo.currentTelemetry;

  @override
  VehicleCapabilities get vehicleCapabilities =>
      _isLiveActive ? _liveRepo.vehicleCapabilities : _mockRepo.vehicleCapabilities;

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
  String? get vin => _isLiveActive ? _liveRepo.vin : _mockRepo.vin;

  @override
  String? get userId => _isLiveActive ? _liveRepo.userId : _mockRepo.userId;

  @override
  String? get deviceSn => _isLiveActive ? _liveRepo.deviceSn : _mockRepo.deviceSn;

  @override
  Future<List<Map<String, dynamic>>> getOperatingRecord() =>
      _isLiveActive ? _liveRepo.getOperatingRecord() : _mockRepo.getOperatingRecord();

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

  @override
  Future<RemoteCommandResult> sendRemoteCommandWithResult(
    String command, {
    bool sendWakeupHandshake = true,
    bool send0x23Init = false,
  }) async {
    if (_isLiveActive) {
      return _liveRepo.sendRemoteCommandWithResult(
        command,
        sendWakeupHandshake: sendWakeupHandshake,
        send0x23Init: send0x23Init,
      );
    }
    return _mockRepo.sendRemoteCommandWithResult(
      command,
      sendWakeupHandshake: sendWakeupHandshake,
      send0x23Init: send0x23Init,
    );
  }

  @override
  Future<bool> setTargetSoc(int targetSoc) =>
      _isLiveActive ? _liveRepo.setTargetSoc(targetSoc) : _mockRepo.setTargetSoc(targetSoc);

  @override
  Future<bool> setAirDuration(int minutes) =>
      _isLiveActive ? _liveRepo.setAirDuration(minutes) : _mockRepo.setAirDuration(minutes);

  @override
  Future<bool> setBatterySchedule(Map<String, dynamic> params) =>
      _isLiveActive ? _liveRepo.setBatterySchedule(params) : _mockRepo.setBatterySchedule(params);

  @override
  Future<Map<String, dynamic>> getTerminalNoticeConfig() =>
      _isLiveActive ? _liveRepo.getTerminalNoticeConfig() : _mockRepo.getTerminalNoticeConfig();

  @override
  Future<bool> setScheduledTravel({
    required bool enabled,
    required int hour,
    required int minute,
    List<bool>? week,
  }) =>
      _isLiveActive
          ? _liveRepo.setScheduledTravel(enabled: enabled, hour: hour, minute: minute, week: week)
          : _mockRepo.setScheduledTravel(enabled: enabled, hour: hour, minute: minute, week: week);

  @override
  Future<bool> setAlertSwitch({required String configName, required bool enabled}) =>
      _isLiveActive
          ? _liveRepo.setAlertSwitch(configName: configName, enabled: enabled)
          : _mockRepo.setAlertSwitch(configName: configName, enabled: enabled);

  @override
  Future<List<Map<String, dynamic>>> getCloudNotifications({int page = 1, int size = 20}) =>
      _isLiveActive
          ? _liveRepo.getCloudNotifications(page: page, size: size)
          : _mockRepo.getCloudNotifications(page: page, size: size);

  @override
  Future<int> getUnreadNoticeCount() =>
      _isLiveActive ? _liveRepo.getUnreadNoticeCount() : _mockRepo.getUnreadNoticeCount();

  @override
  Future<List<Map<String, dynamic>>> getGeofences() =>
      _isLiveActive ? _liveRepo.getGeofences() : _mockRepo.getGeofences();

  @override
  Future<bool> addGeofence({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) => _isLiveActive
      ? _liveRepo.addGeofence(name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType)
      : _mockRepo.addGeofence(name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType);

  @override
  Future<RemoteCommandResult> addGeofenceWithResult({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) => _isLiveActive
      ? _liveRepo.addGeofenceWithResult(name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType)
      : _mockRepo.addGeofenceWithResult(name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType);

  @override
  Future<bool> updateGeofence({
    required String fenceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) => _isLiveActive
      ? _liveRepo.updateGeofence(fenceId: fenceId, name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType)
      : _mockRepo.updateGeofence(fenceId: fenceId, name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType);

  @override
  Future<RemoteCommandResult> updateGeofenceWithResult({
    required String fenceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
    int alarmType = 2,
  }) => _isLiveActive
      ? _liveRepo.updateGeofenceWithResult(fenceId: fenceId, name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType)
      : _mockRepo.updateGeofenceWithResult(fenceId: fenceId, name: name, lat: lat, lng: lng, radius: radius, alarmType: alarmType);

  @override
  Future<bool> updateGeofenceStatus(String id, int status) =>
      _isLiveActive ? _liveRepo.updateGeofenceStatus(id, status) : _mockRepo.updateGeofenceStatus(id, status);

  @override
  Future<bool> deleteGeofence(String id) =>
      _isLiveActive ? _liveRepo.deleteGeofence(id) : _mockRepo.deleteGeofence(id);

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

  /// Fills the dashboard with the last real telemetry reading backed up
  /// to Firestore, for the gap between app launch and the first live
  /// CarLinko poll (or permanently, if there's no live session at all).
  /// Never overwrites telemetry that's already live/bound.
  Future<void> restoreLastKnownTelemetryFromCloud() async {
    if (_current.isBound) return;
    try {
      final snapshot = await FirebaseSyncService.instance.fetchLastTelemetrySnapshot();
      if (snapshot != null && !_current.isBound) {
        _current = snapshot;
        _controller.add(_current);
      }
    } catch (e) {
      debugPrint('[AppVehicleRepository] Cloud telemetry restore note: $e');
    }
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
