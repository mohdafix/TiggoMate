import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'carlinko_crypto.dart';

/// App-global key extracted from the CarLinko mobile APK (not a user secret).
/// Reference: https://github.com/thititongumpun/ha-carlinko
const String carLinkoSignKey = 'mYj3fzMpn77bir66';
const String carLinkoDefaultRegion = 'sea'; // South East Asia (Malaysia & Thailand)
const String carLinkoApiVersion = '1.14.0';
const String carLinkoUserAgent = 'Dart/3.10 (dart:io)';

/// Response codes meaning "the token is stale, log in again" — matches
/// ha-carlinko's STALE_TOKEN_CODES and Chery cloud session invalidation codes.
const Set<String> carLinkoStaleTokenCodes = {
  '9997',
  '40001',
  '40002',
  '40003',
  '401',
  '403',
  '1001',
  '1002',
  'A0200',
  'A0201',
  'A0202',
  'A1001',
};

/// Real remote-control opcodes (sent as the `data` field, hex strings), from
/// ha-carlinko's const.py — confirmed against the official app, unlike the
/// semantic command names ('door_lock', 'vehicle_locate', ...) this client
/// used before, which the real API rejected (parameter error).
class CarLinkoOpcodes {
  CarLinkoOpcodes._();

  static const String init0x23 = '2301'; // Handshake 0x23 from GodrezJr2/j5-ev-dashboard
  static const String init = '77'; // sent once before any other opcode, mirrors the app
  static const String lock = '740100';
  static const String unlock = '740200';
  static const String acOn = '741001';
  static const String acOff = '741000'; // Chery CAN-bus confirmed A/C off
  static const String acOffAlt = '741002'; // J5-EV alternative
  static const String stopCharging = '742701';
  static const String windowsClose = '740500';
  static const String windowsOpen = '740600';
  static const String windowsVent = '740E00';
  static const String findCar = '740400';
  static const String trunkOpen = '740300'; // Jump table decode: 740300 is Trunk Open (740500 was windows close)
  static const String trunkOpenAlt = '740500';
  static const String trunkClose = '740A00';
  static const String sunroofClose = '740F00';
  static const String sunroofOpen = '740F01';
  static const String sunroofTilt = '740F02';
  static const String defogOn = '741201';
  static const String defogOff = '741200';
  static const String quickCool = '742001';
  static const String quickCoolOff = '742000';
  static const String quickHeat = '741F01';
  static const String quickHeatOff = '741F00';
  static const String engineStart = '740700'; // Jump table decode (assembledSendData): Engine on
  static const String engineStop = '740800';  // Jump table decode (assembledSendData): Engine off
  static const String airPurifyOn = '742501';
  static const String airPurifyOff = '742500';
  static const String steeringHeatOn = '742401';
  static const String steeringHeatOff = '742400';

  /// T-Box permission / wake pre-command observed when car replies with status 0x44.
  static const String perm7801 = '7801';

  /// Dynamic cabin temperature setpoint: `7411` + hex(`0x80 + round(celsius * 2)`).
  /// Example: 17.5°C -> `7411A3`, 22.0°C -> `7411AC`.
  static String acTemperature(double celsius) {
    final clamped = celsius.clamp(16.0, 32.0);
    final byte = 0x80 + (clamped * 2).round();
    return '7411${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}';
  }

  // Front seats: 3-level heating (0x7415 / 0x7416)
  static const String driverSeatHeatOff = '741500';
  static const String driverSeatHeatL1 = '741501';
  static const String driverSeatHeatL2 = '741502';
  static const String driverSeatHeatL3 = '741503';
  static const String passengerSeatHeatOff = '741600';
  static const String passengerSeatHeatL1 = '741601';
  static const String passengerSeatHeatL2 = '741602';
  static const String passengerSeatHeatL3 = '741603';

  // Rear seats: 3-level heating (0x7417 / 0x7419)
  static const String rearLeftSeatHeatOff = '741700';
  static const String rearLeftSeatHeatL1 = '741701';
  static const String rearLeftSeatHeatL2 = '741702';
  static const String rearLeftSeatHeatL3 = '741703';
  static const String rearRightSeatHeatOff = '741900';
  static const String rearRightSeatHeatL1 = '741901';
  static const String rearRightSeatHeatL2 = '741902';
  static const String rearRightSeatHeatL3 = '741903';

  // Front seats: 3-level ventilation (0x741A / 0x741B)
  static const String driverSeatVentOff = '741A00';
  static const String driverSeatVentL1 = '741A01';
  static const String driverSeatVentL2 = '741A02';
  static const String driverSeatVentL3 = '741A03';
  static const String passengerSeatVentOff = '741B00';
  static const String passengerSeatVentL1 = '741B01';
  static const String passengerSeatVentL2 = '741B02';
  static const String passengerSeatVentL3 = '741B03';

  // Rear seats: 3-level ventilation (0x741C / 0x741E)
  static const String rearLeftSeatVentOff = '741C00';
  static const String rearLeftSeatVentL1 = '741C01';
  static const String rearLeftSeatVentL2 = '741C02';
  static const String rearLeftSeatVentL3 = '741C03';
  static const String rearRightSeatVentOff = '741E00';
  static const String rearRightSeatVentL1 = '741E01';
  static const String rearRightSeatVentL2 = '741E02';
  static const String rearRightSeatVentL3 = '741E03';

  // Dedicated rear window defogger (CAN opcode 0x74 subcommand 0x26)
  static const String rearDefogOff = '742600';
  static const String rearDefogOn = '742602';

  static String _levelOpcode(String prefix, int level) {
    final safe = level.clamp(0, 3);
    return '${prefix}0$safe';
  }

  // Helper selectors for level-based commands
  static String driverSeatVentOpcode(int level) => _levelOpcode('741A', level);
  static String passengerSeatVentOpcode(int level) => _levelOpcode('741B', level);
  static String rearLeftSeatVentOpcode(int level) => _levelOpcode('741C', level);
  static String rearRightSeatVentOpcode(int level) => _levelOpcode('741E', level);

  static String driverSeatHeatOpcode(int level) => _levelOpcode('7415', level);
  static String passengerSeatHeatOpcode(int level) => _levelOpcode('7416', level);
  static String rearLeftSeatHeatOpcode(int level) => _levelOpcode('7417', level);
  static String rearRightSeatHeatOpcode(int level) => _levelOpcode('7419', level);
}

class CarLinkoException implements Exception {
  final String message;
  final String? code;
  CarLinkoException(this.message, [this.code]);

  @override
  String toString() => 'CarLinkoException($code): $message';
}

class CarLinkoAuthException extends CarLinkoException {
  CarLinkoAuthException(super.message, [super.code]);
}

/// Standalone CarLinko API client implementing direct cloud communication
/// with HMAC-SHA256 signature generation, region selection, and 73-byte telemetry blob decoding.
class CarLinkoClient {
  String _region;
  final HttpClient _client;
  int _skewMs = 0;
  bool _synced = false;
  String? token;

  CarLinkoClient({
    String region = carLinkoDefaultRegion,
    HttpClient? client,
    this.token,
  })  : _region = normalizeRegion(region),
        _client = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 12));

  String get region => _region;

  set region(String val) {
    final norm = normalizeRegion(val);
    if (_region != norm) {
      _region = norm;
      _synced = false; // Invalidate clock sync for the new endpoint
    }
  }

  /// Normalizes user-selected region strings to standard Chery cloud API subdomain identifiers.
  static String normalizeRegion(String r) {
    final clean = r.toLowerCase().trim();
    if (clean == 'emea' || clean == 'eu') return 'me';
    return clean.isEmpty ? carLinkoDefaultRegion : clean;
  }

  String get baseUrl => 'https://cqr-api-$_region.hzhjcl.com';

  /// Sign parameters matching the official mobile client algorithm byte-for-byte:
  /// base64(HMAC-SHA256(SIGN_KEY, jsonEncode(sortByKeyAsc({**params, timestamp}))))
  static String sign(Map<String, dynamic> params, String timestamp) {
    final merged = <String, dynamic>{...params, 'timestamp': timestamp};
    // Numbers (e.g. timeOut: 20) must be preserved as numeric values in jsonEncode,
    // not converted to strings, matching the official client and server verification.
    final sortedKeys = merged.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};
    for (final k in sortedKeys) {
      final v = merged[k];
      if (v == null) {
        sortedMap[k] = '';
      } else if (v is num || v is bool || v is List || v is Map) {
        sortedMap[k] = v;
      } else {
        sortedMap[k] = v.toString();
      }
    }

    final message = json.encode(sortedMap);
    final keyBytes = utf8.encode(carLinkoSignKey);
    final hmacSha256 = Hmac(sha256, keyBytes);
    final digest = hmacSha256.convert(utf8.encode(message));
    return base64.encode(digest.bytes);
  }

  String _currentTimestamp() {
    return (DateTime.now().millisecondsSinceEpoch + _skewMs).toString();
  }

  /// Sync device clock with CarLinko server clock to prevent signature rejection.
  Future<void> syncClock() async {
    try {
      final uri = Uri.parse('$baseUrl/pub/timestamp');
      final request = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
      request.headers.set('user-agent', carLinkoUserAgent);
      request.headers.set('language', 'en');
      request.headers.set('version', carLinkoApiVersion);

      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final bodyStr = await response.transform(utf8.decoder).join();
        final data = json.decode(bodyStr);
        if (data is Map<String, dynamic> && data['data'] != null) {
          final serverTs = int.tryParse(data['data'].toString()) ?? DateTime.now().millisecondsSinceEpoch;
          _skewMs = serverTs - DateTime.now().millisecondsSinceEpoch;
          _synced = true;
        }
      }
    } catch (_) {
      _skewMs = 0;
    }
  }

  /// Authenticate with CarLinko cloud using phone/account and password.
  /// Strictly safeguards credentials: raw password is never logged or stored.
  Future<String> login(String account, String password) async {
    if (!_synced) {
      await syncClock();
    }

    final ts = _currentTimestamp();
    final body = {
      'account': account,
      'password': password,
      'method': 'PASSWORD',
      'appType': 'APP',
      'osType': 'ANDROID',
      'appName': 'CarLinko',
      'appVersion': carLinkoApiVersion,
      'osVersion': '13',
      'language': 'en',
      'timeZone': 'Asia/Kuala_Lumpur',
      'phoneBrand': 'Xiaomi',
      'phoneModel': '25098pn5ac',
      'md5': '',
      'verifyCode': '',
      'dateTime': ts,
      'timestamp': ts,
    };

    final signature = sign(body, ts);
    final uri = Uri.parse('$baseUrl/user/login');

    HttpClientResponse response;
    String bodyStr;
    try {
      final request = await _client.postUrl(uri).timeout(const Duration(seconds: 12));
      request.headers.set('content-type', 'application/json');
      request.headers.set('timestamp', ts);
      request.headers.set('signature', signature);
      request.headers.set('user-agent', carLinkoUserAgent);
      request.headers.set('language', 'en');
      request.headers.set('version', carLinkoApiVersion);

      final utf8Body = utf8.encode(json.encode(body));
      request.headers.contentLength = utf8Body.length;
      request.add(utf8Body);
      response = await request.close().timeout(const Duration(seconds: 12));
      bodyStr = await response.transform(utf8.decoder).join();
    } on SocketException {
      throw CarLinkoException(
        'Unable to reach CarLinko cloud server ($baseUrl). Please check internet connection.',
        'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw CarLinkoException('CarLinko authentication timed out. Please try again.', 'TIMEOUT');
    } on HandshakeException catch (e) {
      throw CarLinkoException('Secure TLS connection to CarLinko failed: ${e.message}', 'SSL_ERROR');
    } catch (e) {
      if (e is CarLinkoException) rethrow;
      throw CarLinkoException('CarLinko connection failed: $e', 'CONNECTION_FAILED');
    }

    if (response.statusCode != 200) {
      String serverMsg = '';
      try {
        final decoded = json.decode(bodyStr);
        if (decoded is Map<String, dynamic>) {
          serverMsg = decoded['msg']?.toString() ??
              decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              '';
        }
      } catch (_) {}
      if (serverMsg.isEmpty && bodyStr.isNotEmpty) {
        serverMsg = bodyStr.length > 200 ? bodyStr.substring(0, 200) : bodyStr;
      }
      throw CarLinkoException(
        serverMsg.isNotEmpty
            ? 'CarLinko server error (${response.statusCode}): $serverMsg'
            : 'CarLinko server returned HTTP ${response.statusCode}',
        'HTTP_${response.statusCode}',
      );
    }

    Map<String, dynamic> payload;
    try {
      final decoded = json.decode(bodyStr);
      if (decoded is! Map<String, dynamic>) {
        throw CarLinkoException('Unexpected response format from CarLinko server', 'INVALID_FORMAT');
      }
      payload = decoded;
    } on FormatException {
      throw CarLinkoException(
        'Malformed response from CarLinko server (HTTP ${response.statusCode})',
        'INVALID_JSON',
      );
    }

    final code = payload['code']?.toString() ?? 'unknown';

    if (code != '0000') {
      throw CarLinkoAuthException(payload['msg']?.toString() ?? 'Login failed', code);
    }

    final data = payload['data'];
    final extractedToken = data is Map ? data['token']?.toString() : data?.toString();
    if (extractedToken == null || extractedToken.isEmpty) {
      throw CarLinkoAuthException('No token returned from server', code);
    }

    token = extractedToken;
    return extractedToken;
  }

  /// Discover user vehicles bound to this CarLinko account.
  Future<List<Map<String, dynamic>>> getVehicles() async {
    final result = await _request('GET', '/user/vehicle', signParams: {});
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Fetch digital key authority for Phone-as-a-Key / Bluetooth verification.
  Future<Map<String, dynamic>?> getKeyAuthority(String vehicleId) async {
    try {
      final q = {'vehicleId': vehicleId};
      final res = await _request('GET', '/user/keyAuthority', queryParams: q, signParams: q);
      if (res is Map<String, dynamic>) {
        debugPrint('CarLinko: Fetched digital key authority for vehicle $vehicleId');
        return res;
      }
    } catch (e) {
      debugPrint('CarLinko getKeyAuthority note: $e');
    }
    return null;
  }

  /// Retrieve decoded 73-byte telemetry state for a vehicle.
  Future<Map<String, dynamic>> getVehicleState(String vehicleId) async {
    final result = await _request('GET', '/user/vehicle/state/$vehicleId', signParams: {'id': vehicleId});
    final hexBlob = result?.toString() ?? '';
    final decoded = parseBlob(hexBlob);
    decoded['rawHex'] = hexBlob;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (hexBlob.isNotEmpty) {
        await prefs.setString('tm_last_raw_hex', hexBlob);
      }
    } catch (_) {}
    return decoded;
  }

  /// Check whether vehicle telematics box is currently online.
  Future<bool> isVehicleOnline(String vehicleId) async {
    final result = await _request('GET', '/user/vehicle/isOnline/$vehicleId', signParams: {'id': vehicleId});
    return result == true;
  }

  /// Fetch the car's live GPS position (and, when CarLinko has one, a
  /// pre-formatted address) via the real locate endpoint.
  /// Matches ha-carlinko reference client byte-for-byte:
  /// Payload: {"sn": deviceSn, "showAddress": 1, "timestamp": ts}
  Future<Map<String, dynamic>> locateDevice(String deviceSn, {String? vehicleId}) async {
    if (!_synced) {
      await syncClock();
    }
    final ts = _currentTimestamp();
    final cleanSn = deviceSn.trim();
    final attempts = [
      <String, dynamic>{
        'sn': cleanSn,
        'deviceId': cleanSn,
        if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        'showAddress': 1,
        'timestamp': ts,
      },
      <String, dynamic>{
        'sn': cleanSn,
        'showAddress': 1,
        'timestamp': ts,
      },
      <String, dynamic>{
        if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        'sn': cleanSn,
        'timestamp': ts,
      },
    ];

    for (final body in attempts) {
      try {
        final result = await _request('POST', '/maps/deviceLocate', body: body, signParams: body);
        debugPrint('locateDevice response: $result');
        if (result is Map<String, dynamic>) {
          final data = result['data'] is Map<String, dynamic> ? result['data'] as Map<String, dynamic> : result;
          if (data.containsKey('lat') || data.containsKey('latitude') || data.containsKey('point')) {
            return data;
          }
        }
      } catch (e) {
        debugPrint('locateDevice POST /maps/deviceLocate attempt failed: $e');
        if (e is CarLinkoException && e.code != null) {
          // If the endpoint explicitly rejected with an error, record it
          return {'errorCode': e.code, 'errorMessage': e.message};
        }
      }
    }
    return {};
  }

  /// Fetch official dealership service records.
  Future<List<Map<String, dynamic>>> getMaintenanceRecords(String vehicleId) async {
    final q = {'vehicleId': vehicleId, 'queryKey': '', 'page': '1', 'size': '20'};
    final result = await _request('GET', '/user/maintain/page', queryParams: q, signParams: q);
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Configure battery target state of charge (e.g. 80% or 100%).
  /// CarLinko v1.14.0 uses HTTP PUT with `{vehicleId, deviceSn?, targetSoc}`.
  Future<bool> setTargetSoc(String vehicleId, int targetSoc, {String? deviceSn}) async {
    final body = <String, dynamic>{
      'vehicleId': int.tryParse(vehicleId) ?? vehicleId,
      if (deviceSn != null && deviceSn.trim().isNotEmpty) 'deviceSn': deviceSn.trim(),
      'targetSoc': targetSoc,
    };
    await _request('PUT', '/user/device/manage/targetSoc', body: body, signParams: body);
    return true;
  }

  /// Set smart cabin air conditioning pre-conditioning duration in minutes (5, 10, or 15).
  /// CarLinko v1.14.0 uses HTTP PUT with `{duration, vehicleId}`.
  Future<bool> setAirDuration(String vehicleId, int minutes) async {
    final body = <String, dynamic>{
      'duration': minutes,
      'vehicleId': int.tryParse(vehicleId) ?? vehicleId,
    };
    await _request('PUT', '/user/device/manage/airDuration', body: body, signParams: body);
    return true;
  }

  /// Normalizes either native `{enabled, hour, minute, duration, week}` or
  /// legacy `{startTime, durationMinutes, status, repeat}` into CarLinko's
  /// `PUT /user/device/manage/batterySchedule` payload schema.
  static Map<String, dynamic> normalizeBatterySchedulePayload(
    String vehicleId,
    Map<String, dynamic> scheduleParams,
  ) {
    final vid = int.tryParse(vehicleId) ?? vehicleId;
    final enabled = scheduleParams.containsKey('enabled')
        ? scheduleParams['enabled'] == true
        : (scheduleParams['status'] == 1 || scheduleParams['status'] == true);

    var hour = (scheduleParams['hour'] as num?)?.toInt() ?? 0;
    var minute = (scheduleParams['minute'] as num?)?.toInt() ?? 0;
    final startTimeStr = scheduleParams['startTime']?.toString();
    if (!scheduleParams.containsKey('hour') && startTimeStr != null && startTimeStr.contains(':')) {
      final parts = startTimeStr.split(':');
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0].trim()) ?? hour;
        minute = int.tryParse(parts[1].trim()) ?? minute;
      }
    }

    final durationHours = (scheduleParams['duration'] as num?)?.toInt() ??
        ((((scheduleParams['durationMinutes'] as num?)?.toInt() ?? 120) / 60).round().clamp(1, 24));

    List<bool> week;
    final rawWeek = scheduleParams['week'];
    if (rawWeek is List && rawWeek.length == 7) {
      week = rawWeek.map((e) => e == true || e == 1).toList();
    } else {
      final repeat = (scheduleParams['repeat']?.toString() ?? '').toLowerCase();
      if (repeat.contains('every day') || repeat.contains('everyday') || repeat == 'daily') {
        week = List<bool>.filled(7, true);
      } else if (repeat.contains('weekday') || repeat.contains('monday') || repeat.contains('mon-fri')) {
        week = [false, true, true, true, true, true, false];
      } else if (repeat.contains('weekend') || repeat.contains('saturday') || repeat.contains('sat-sun')) {
        week = [true, false, false, false, false, false, true];
      } else {
        week = List<bool>.filled(7, false);
      }
    }

    return <String, dynamic>{
      'vehicleId': vid,
      'enabled': enabled,
      'hour': hour.clamp(0, 23),
      'minute': minute.clamp(0, 59),
      'duration': durationHours.clamp(1, 24),
      'week': week,
    };
  }

  /// Set smart scheduled AC charging timer via `PUT /user/device/manage/batterySchedule`.
  Future<bool> setBatterySchedule(String vehicleId, Map<String, dynamic> scheduleParams) async {
    final body = normalizeBatterySchedulePayload(vehicleId, scheduleParams);
    await _request('PUT', '/user/device/manage/batterySchedule', body: body, signParams: body);
    return true;
  }

  /// Fetch device/notification config: targetSoc, batterySchedule, startupAppointment,
  /// and cloud alert switches (`VEHICLE_ANOMALY`, `BATTERY_ANOMALY`).
  Future<Map<String, dynamic>> getTerminalNoticeConfig(String vehicleId) async {
    final res = await _request(
      'GET',
      '/user/device/manage/terminalNoticeConfig/$vehicleId',
      signParams: {'id': vehicleId},
    );
    if (res is! Map<String, dynamic>) return {};
    final out = Map<String, dynamic>.from(res);
    // Unpack nested JSON strings returned by CarLinko (`batterySchedule`, `extra`).
    for (final key in ['batterySchedule', 'extra']) {
      final raw = out[key];
      if (raw is String && raw.trim().isNotEmpty) {
        try {
          out['${key}Parsed'] = json.decode(raw);
        } catch (_) {}
      } else if (raw is Map<String, dynamic>) {
        out['${key}Parsed'] = raw;
      }
    }
    return out;
  }

  /// Generic writer for `PUT /user/device/manage/terminalNoticeConfig`.
  /// Supported [configName] values: `STARTUP_APPOINTMENT`, `VEHICLE_ANOMALY`, `BATTERY_ANOMALY`.
  Future<bool> setNoticeItem({
    required String vehicleId,
    required String configName,
    required bool configStatus,
    Map<String, dynamic>? configExtra,
  }) async {
    final body = <String, dynamic>{
      'configExtra': configExtra != null ? json.encode(configExtra) : '',
      'configName': configName,
      'configStatus': configStatus,
      'vehicleId': int.tryParse(vehicleId) ?? vehicleId,
    };
    await _request('PUT', '/user/device/manage/terminalNoticeConfig', body: body, signParams: body);
    return true;
  }

  /// Configure scheduled cabin departure pre-conditioning (`STARTUP_APPOINTMENT`).
  Future<bool> setScheduledTravel({
    required String vehicleId,
    required bool enabled,
    required int hour,
    required int minute,
    List<bool>? week,
  }) {
    final safeWeek = (week != null && week.length == 7) ? week : List<bool>.filled(7, false);
    return setNoticeItem(
      vehicleId: vehicleId,
      configName: 'STARTUP_APPOINTMENT',
      configStatus: enabled,
      configExtra: {
        'hour': hour.clamp(0, 23).toString().padLeft(2, '0'),
        'minute': minute.clamp(0, 59).toString().padLeft(2, '0'),
        'week': safeWeek,
      },
    );
  }

  /// Toggle cloud push alerts (`VEHICLE_ANOMALY`, `BATTERY_ANOMALY`).
  Future<bool> setAlertSwitch({
    required String vehicleId,
    required String configName,
    required bool enabled,
  }) {
    return setNoticeItem(
      vehicleId: vehicleId,
      configName: configName,
      configStatus: enabled,
    );
  }

  /// List configured electronic fences (geofences) for the vehicle.
  Future<List<Map<String, dynamic>>> getGeofences(String vehicleId, {int page = 1, int size = 50}) async {
    // Try with vehicleId, page, size first, then fall back to page only
    try {
      final q = {'vehicleId': vehicleId, 'page': page.toString(), 'size': size.toString()};
      final res = await _request('GET', '/user/electronicFence/list', queryParams: q, signParams: q);
      final list = _extractGeofenceList(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final q = {'page': page.toString(), 'size': size.toString()};
      final res = await _request('GET', '/user/electronicFence/list', queryParams: q, signParams: q);
      return _extractGeofenceList(res);
    } catch (e) {
      debugPrint('getGeofences error: $e');
    }
    return [];
  }

  static List<Map<String, dynamic>> _extractGeofenceList(dynamic res) {
    if (res is Map<String, dynamic>) {
      final list = res['list'] ?? res['data'] ?? res['records'];
      if (list is List) return list.cast<Map<String, dynamic>>();
    } else if (res is List) {
      return res.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Create a new electronic fence (geofence).
  /// Matches CarLinko AddGeofenceParams: [name], [lat], [lng], [radius], [alarmType], [fenceType], [status].
  /// [alarmType]: 1 = Enter (googleDriveIn), 2 = Exit (googleDriveOut). Default is 2 (Exit).
  /// [fenceType]: 1 = Circle, 2 = Square.
  Future<Map<String, dynamic>> addGeofence({
    required String vehicleId,
    required String fenceName,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int alarmType = 2,
    int fenceType = 1,
    int status = 1,
  }) async {
    final cleanLat = double.parse(latitude.toStringAsFixed(6));
    final cleanLng = double.parse(longitude.toStringAsFixed(6));
    final body = <String, dynamic>{
      'vehicleId': vehicleId,
      'name': fenceName,
      'lat': cleanLat,
      'lng': cleanLng,
      'radius': radiusMeters.round(),
      'alarmType': alarmType,
      'fenceType': fenceType,
      'status': status,
    };
    final res = await _request('POST', '/user/electronicFence/add', body: body, signParams: body);
    return res is Map<String, dynamic> ? res : {'status': 'ok'};
  }

  /// Update an existing electronic fence (geofence) by ID.
  /// Matches CarLinko UpdateGeofenceParams.
  Future<Map<String, dynamic>> updateGeofence({
    required String fenceId,
    required String vehicleId,
    required String fenceName,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int alarmType = 2,
    int fenceType = 1,
    int status = 1,
  }) async {
    final cleanLat = double.parse(latitude.toStringAsFixed(6));
    final cleanLng = double.parse(longitude.toStringAsFixed(6));
    final body = <String, dynamic>{
      'id': fenceId,
      'vehicleId': vehicleId,
      'name': fenceName,
      'lat': cleanLat,
      'lng': cleanLng,
      'radius': radiusMeters.round(),
      'alarmType': alarmType,
      'fenceType': fenceType,
      'status': status,
    };
    final res = await _request('POST', '/user/electronicFence/update', body: body, signParams: body);
    return res is Map<String, dynamic> ? res : {'status': 'ok'};
  }

  /// Toggle geofence active status (1 = enabled, 0 = disabled).
  Future<bool> updateGeofenceStatus({
    required String vehicleId,
    required String fenceId,
    required int status,
  }) async {
    final body = {
      'id': fenceId,
      'vehicleId': vehicleId,
      'status': status,
    };
    await _request('POST', '/user/electronicFence/updateStatus', body: body, signParams: body);
    return true;
  }

  /// Delete an electronic fence by ID.
  Future<bool> deleteGeofence(String fenceId, {String? vehicleId}) async {
    final body = {
      'id': fenceId,
      if (vehicleId != null) 'vehicleId': vehicleId,
    };
    try {
      await _request('POST', '/user/electronicFence/delete', body: body, signParams: body);
      return true;
    } catch (_) {
      try {
        await _request('DELETE', '/user/electronicFence/$fenceId', signParams: {'id': fenceId});
        return true;
      } catch (e) {
        debugPrint('deleteGeofence error: $e');
        return false;
      }
    }
  }

  /// Extracts a list of map items from standard CarLinko paginated responses.
  static List<Map<String, dynamic>> _extractPagedList(dynamic res) {
    if (res is Map<String, dynamic>) {
      final list = res['records'] ?? res['list'] ?? res['rows'] ?? res['data'];
      if (list is List) {
        return List<Map<String, dynamic>>.from(list.whereType<Map<String, dynamic>>());
      }
    } else if (res is List) {
      return List<Map<String, dynamic>>.from(res.whereType<Map<String, dynamic>>());
    }
    return [];
  }

  /// Fetches the vehicle operation / remote control history from `GET /user/operating/page`.
  /// Matches CarLinko v1.14.0's official "Vehicle control record" screen.
  Future<List<Map<String, dynamic>>> getOperatingRecord({
    String? vehicleId,
    String? vin,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      final q = <String, String>{
        if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        'page': pageNum.toString(),
        'size': pageSize.toString(),
      };
      final res = await _request('GET', '/user/operating/page', queryParams: q, signParams: q);
      final rows = _extractPagedList(res);
      if (rows.isNotEmpty || (vehicleId != null && vehicleId.isNotEmpty)) {
        return rows;
      }
    } catch (e) {
      debugPrint('getOperatingRecord GET /user/operating/page error: $e');
    }
    return [];
  }

  /// Fetch paginated cloud notifications (`GET /user/notice/page`).
  Future<List<Map<String, dynamic>>> getCloudNotifications(
    String vehicleId, {
    int page = 1,
    int size = 20,
  }) async {
    try {
      final q = {'vehicleId': vehicleId, 'page': page.toString(), 'size': size.toString()};
      final res = await _request('GET', '/user/notice/page', queryParams: q, signParams: q);
      return _extractPagedList(res);
    } catch (e) {
      debugPrint('getCloudNotifications error: $e');
      return [];
    }
  }

  /// Fetch unread cloud notice count (`GET /user/notice/unReadCount`).
  Future<int> getUnreadNoticeCount(String vehicleId) async {
    try {
      final q = {'vehicleId': vehicleId, 'clientType': 'C'};
      final res = await _request('GET', '/user/notice/unReadCount', queryParams: q, signParams: q);
      if (res is num) return res.toInt();
      if (res is Map<String, dynamic>) {
        return (res['count'] as num?)?.toInt() ?? (res['unReadCount'] as num?)?.toInt() ?? 0;
      }
      return int.tryParse(res?.toString() ?? '') ?? 0;
    } catch (e) {
      debugPrint('getUnreadNoticeCount error: $e');
      return 0;
    }
  }

  /// Chery T-Box CAN refusal code mapping (reversed from libapp.so & verified in j5-ev-dashboard).
  static const Map<String, String> refusalReasons = {
    '2A': 'Vehicle in motion',
    '93': 'Vehicle not in remote mode',
    '23': 'Vehicle is started',
    '94': 'High-voltage fault',
    '95': 'Battery too low',
    '96': 'Key detected inside the car',
    '22': 'A door is unlocked',
    '99': 'T-Box authentication failed',
    '9A': 'Not in P',
    '9B': 'Hazard lights are on',
    '04': 'T-Box auth fail (plain opcode rejected by firmware >= 2.3.1)',
    '44': 'Car did not apply command (CAN sleeping / not in remote mode or BCM refused)',
  };

  /// Translate an acknowledgment status code into a readable description.
  static String? refusalReason(String? ackCode) {
    if (ackCode == null) return null;
    return refusalReasons[ackCode.toUpperCase()];
  }

  /// Parse CarLinko's `<sn>__<OPCODE><STATUS_BYTE>` echo string.
  /// Returns `'00'` (applied), `'44'` (not applied by T-Box), etc., or `null`
  /// when the response does not contain a recognizable trailing status byte.
  static String? parseAckStatus(dynamic rawResponse, String sentOpcode) {
    final op = sentOpcode.trim().toUpperCase();
    if (op.isEmpty) return null;
    String raw = '';
    if (rawResponse is Map) {
      raw = (rawResponse['data'] ?? rawResponse['echo'] ?? '').toString();
    } else if (rawResponse != null) {
      raw = rawResponse.toString();
    }
    if (raw.isEmpty) return null;
    final echo = raw.split('__').last.trim().toUpperCase();
    if (echo.startsWith(op) && echo.length == op.length + 2) {
      return echo.substring(op.length);
    }
    // Some T-Box firmwares (e.g. 2.3.1_050F01R) reply with a shortened
    // `<family><STATUS>` error such as `7404` when rejecting a `74xx` command.
    if (op.length >= 4 && echo.length == 4 && echo.startsWith(op.substring(0, 2))) {
      return echo.substring(2);
    }
    return null;
  }

  /// Fetch current CarLinko account profile (`GET /user/info`) for account ID.
  /// Rethrows [CarLinkoAuthException] (and stale-token [CarLinkoException]) so
  /// callers can trigger auto-reauth rather than silently losing `userId`.
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final res = await _request('GET', '/user/info', signParams: const {});
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
    } on CarLinkoAuthException {
      rethrow;
    } on CarLinkoException catch (e) {
      if (e.code != null && carLinkoStaleTokenCodes.contains(e.code)) rethrow;
      debugPrint('getUserInfo error: $e');
    } catch (e) {
      debugPrint('getUserInfo error: $e');
    }
    return null;
  }

  /// Send a remote-control opcode to the Chery T-Box via
  /// /user/vehicle/remoteControl. [opcode] is a raw hex string from
  /// [CarLinkoOpcodes] (e.g. CarLinkoOpcodes.lock = '740100').
  ///
  /// When [vin] and [userId] are provided, `74xx` actuation commands are
  /// AES-128-ECB encrypted (`"66" + randomHex + ciphertextHex`) as required
  /// by CarLinko v1.14.10+ / T-Box >= 2.3.1_050F01R. Init commands (`77`,
  /// `2301`, `24`) remain plain.
  ///
  /// Automatically parses the `<sn>__<opcode><STATUS>` echo byte (`00` = applied,
  /// `44`/non-`00` = rejected by T-Box).
  ///
  /// Following GodrezJr2/j5-ev-dashboard and official CarLinko app flow:
  /// - Sends `77` init wake when [sendWakeupHandshake] or [sendWakeupInit] is true
  ///   with a 600ms delay to bring CAN bus out of sleep mode.
  /// - Legacy `2301` is only sent if explicitly requested ([send0x23Init]).
  /// - `7801` retry is completely dropped (7801 is rejected on modern firmware).
  Future<Map<String, dynamic>> sendRemoteControl({
    required String vehicleId,
    required String deviceSn,
    required String opcode,
    String? vin,
    String? userId,
    bool sendWakeupHandshake = true,
    bool sendWakeupInit = false,
    bool send0x23Init = false,
  }) async {
    bool isEncrypted = false;
    Future<dynamic> postOp(String op, {int timeOut = 20}) {
      var payloadData = op;
      if (op.toUpperCase().startsWith('74') &&
          vin != null &&
          vin.isNotEmpty &&
          userId != null &&
          userId.isNotEmpty) {
        payloadData = CarLinkoCrypto.buildControlPayload(op, vin, userId);
        isEncrypted = true;
      }
      final b = <String, dynamic>{
        'vehicleId': vehicleId,
        'deviceSn': deviceSn,
        'data': payloadData,
        'timeOut': timeOut,
      };
      return _request('POST', '/user/vehicle/remoteControl', body: b, signParams: b);
    }

    // Official CarLinko / j5-ev-dashboard wakeup flow: init '77' then 600ms delay
    if (sendWakeupHandshake || sendWakeupInit) {
      try {
        debugPrint('CarLinko Cloud: Dispatching official Stage 1 wake (opcode 77)...');
        await postOp('77', timeOut: 15);
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (e) {
        debugPrint('CarLinko Cloud: Stage 1 wakeup note: $e');
      }
    }

    // Optional legacy 0x23 init (only if explicitly enabled)
    if (send0x23Init) {
      try {
        debugPrint('CarLinko Cloud: Dispatching legacy 0x23 init (opcode 2301)...');
        await postOp('2301', timeOut: 10);
        await Future.delayed(const Duration(milliseconds: 250));
      } catch (e) {
        debugPrint('CarLinko Cloud: Legacy 0x23 note: $e');
      }
    }

    try {
      final res = await postOp(opcode, timeOut: 20);
      final ackStatus = parseAckStatus(res, opcode);
      final applied = ackStatus == null || ackStatus == '00';
      final rawEcho = res is Map ? (res['data'] ?? res['echo'] ?? res).toString() : (res?.toString() ?? '<null>');

      if (res is Map<String, dynamic>) {
        return {
          ...res,
          'status': applied ? (res['status'] ?? 'success') : 'rejected',
          'applied': applied,
          if (ackStatus != null) 'ackStatus': ackStatus,
          'echo': rawEcho,
          'encrypted': isEncrypted,
          'refusalReason': refusalReason(ackStatus),
        };
      }
      return {
        'status': applied ? 'success' : 'rejected',
        'applied': applied,
        if (ackStatus != null) 'ackStatus': ackStatus,
        'echo': rawEcho,
        'encrypted': isEncrypted,
        'refusalReason': refusalReason(ackStatus),
        'data': res,
      };
    } on CarLinkoException catch (e) {
      if (e.code == '50043' || e.code == 'A50043' || e.message.contains('设备网络不佳')) {
        throw CarLinkoException(
          'Vehicle cellular modem is asleep (code 50043).',
          '50043',
        );
      }
      rethrow;
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    required Map<String, dynamic> signParams,
  }) async {
    if (!_synced) {
      await syncClock();
    }

    // If body already has timestamp (e.g. locateDevice, login), use it so body and headers match byte-for-byte.
    final ts = (body != null && body['timestamp'] != null && body['timestamp'].toString().isNotEmpty)
        ? body['timestamp'].toString()
        : _currentTimestamp();
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final signature = sign(signParams, ts);

    HttpClientResponse response;
    String bodyStr;
    final isRemoteControl = path.contains('remoteControl');
    final timeoutDuration = Duration(seconds: isRemoteControl ? 35 : 15);
    try {
      final request = await _client.openUrl(method, uri).timeout(timeoutDuration);
      request.headers.set('content-type', 'application/json');
      request.headers.set('timestamp', ts);
      request.headers.set('signature', signature);
      request.headers.set('user-agent', carLinkoUserAgent);
      request.headers.set('language', 'en');
      request.headers.set('version', carLinkoApiVersion);
      if (token != null) {
        request.headers.set('token', token!);
      }

      if (body != null) {
        // Do NOT mutate body by adding body['timestamp'] = ts.
        // CarLinko expects timestamp in headers, not in the JSON body.
        final utf8Body = utf8.encode(json.encode(body));
        request.headers.contentLength = utf8Body.length;
        request.add(utf8Body);
      }

      response = await request.close().timeout(timeoutDuration);
      bodyStr = await response.transform(utf8.decoder).join();
    } on SocketException {
      throw CarLinkoException(
        'Unable to reach CarLinko cloud server ($baseUrl). Please check internet connection.',
        'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw CarLinkoException('CarLinko request timed out. Please try again.', 'TIMEOUT');
    } on HandshakeException catch (e) {
      throw CarLinkoException('Secure TLS connection to CarLinko failed: ${e.message}', 'SSL_ERROR');
    } catch (e) {
      if (e is CarLinkoException) rethrow;
      throw CarLinkoException('CarLinko request failed: $e', 'CONNECTION_FAILED');
    }

    if (response.statusCode != 200) {
      String serverMsg = '';
      try {
        final decoded = json.decode(bodyStr);
        if (decoded is Map<String, dynamic>) {
          serverMsg = decoded['msg']?.toString() ??
              decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              '';
        }
      } catch (_) {}
      if (serverMsg.isEmpty && bodyStr.isNotEmpty) {
        serverMsg = bodyStr.length > 200 ? bodyStr.substring(0, 200) : bodyStr;
      }
      throw CarLinkoException(
        serverMsg.isNotEmpty
            ? 'CarLinko server error (${response.statusCode}): $serverMsg'
            : 'CarLinko server returned HTTP ${response.statusCode}',
        'HTTP_${response.statusCode}',
      );
    }

    Map<String, dynamic> payload;
    try {
      final decoded = json.decode(bodyStr);
      if (decoded is! Map<String, dynamic>) {
        throw CarLinkoException('Unexpected response format from CarLinko server', 'INVALID_FORMAT');
      }
      payload = decoded;
    } on FormatException {
      throw CarLinkoException(
        'Malformed response from CarLinko server (HTTP ${response.statusCode})',
        'INVALID_JSON',
      );
    }

    final code = payload['code']?.toString() ?? 'unknown';
    final msg = payload['msg']?.toString() ?? payload['message']?.toString() ?? '';
    if (code != '0000' && code != 'A0000' && code != '0' && code != '200') {
      final lowerMsg = msg.toLowerCase();
      final isAuthError = carLinkoStaleTokenCodes.contains(code) ||
          lowerMsg.contains('token') ||
          lowerMsg.contains('login') ||
          lowerMsg.contains('session') ||
          lowerMsg.contains('unauthorized') ||
          lowerMsg.contains('auth fail');
      if (isAuthError) {
        throw CarLinkoAuthException(msg.isNotEmpty ? msg : 'Session expired', code);
      }
      throw CarLinkoException(msg.isNotEmpty ? msg : 'API error', code);
    }

    return payload['data'];
  }

  /// Decode the 73-byte Chery CarLinko telemetry hex blob.
  /// Grounded in verified ha-carlinko decoder logic.
  static Map<String, dynamic> parseBlob(String hexStr) {
    Uint8List b;
    try {
      var clean = hexStr.replaceAll(' ', '').replaceAll('0x', '').replaceAll('0X', '').trim();
      if (clean.isEmpty) return <String, dynamic>{};
      // Pad odd length hex strings safely to prevent RangeError
      if (clean.length % 2 != 0) {
        clean = '0$clean';
      }
      final list = <int>[];
      for (int i = 0; i < clean.length; i += 2) {
        list.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
      b = Uint8List.fromList(list);
    } catch (_) {
      return <String, dynamic>{};
    }

    final n = b.length;
    int? u8(int i) => i < n ? b[i] : null;
    int? u16(int i) => (i + 1 < n) ? ((b[i] << 8) | b[i + 1]) : null;
    int? u24(int i) => (i + 2 < n) ? ((b[i] << 16) | (b[i + 1] << 8) | b[i + 2]) : null;

    final out = <String, dynamic>{};
    out['doors'] = u8(2);
    out['unlocked'] = u8(3);
    out['trunk'] = u8(4);
    out['hv_state'] = u8(5);
    out['windows'] = u8(8);
    out['sunroof'] = u8(9);

    final rawVolt = u16(12);
    out['volt12'] = rawVolt != null ? (rawVolt * 0.01) : null;

    final rawSpeed = u16(14);
    out['speed'] = rawSpeed != null ? (rawSpeed / 16.0) : null;

    out['odometer'] = u24(18);

    final ac = u8(23);
    final rawAcTemp = u8(24);
    int? decodedAcTemp;
    if (rawAcTemp != null && rawAcTemp > 0) {
      if (rawAcTemp >= 100) {
        // Bit 7 (0x80 = 128) is the AC status / active flag.
        // Bits 0-6 (0x7F) represent the target temperature in 0.5°C steps.
        // e.g. 172 (0xAC) -> 172 & 0x7F = 44 -> 44 * 0.5 = 22.0°C!
        final halfDeg = rawAcTemp & 0x7F;
        decodedAcTemp = (halfDeg > 0) ? (halfDeg * 0.5).round() : null;
      } else if (rawAcTemp >= 32 && rawAcTemp <= 70) {
        // Unmasked half-degrees (e.g. 44 -> 22°C).
        decodedAcTemp = (rawAcTemp * 0.5).round();
      } else if (rawAcTemp >= 15 && rawAcTemp <= 35) {
        // Direct integer Celsius (e.g. 22).
        decodedAcTemp = rawAcTemp;
      }
    }

    out['ac_on'] = ac != null ? ac != 0 : ((rawAcTemp != null && (rawAcTemp & 0x80) != 0) ? true : null);
    out['ac_temp'] = decodedAcTemp;

    out['battery_pct'] = u8(28);
    out['range_km'] = u16(29);

    // No GPS here: bytes 32-39 (where a u32 lat/lon pair would plausibly
    // live) are confirmed always zero on a real car, and ha-carlinko's own
    // reference decoder doesn't attempt this blob for location either — see
    // CarLinkoClient.locateDevice() for the real /maps/deviceLocate source.

    out['wltc_range'] = u16(68);

    // Confirmed against a real Tiggo 7 PHEV reading (2026-11-01): this byte
    // position holds the fuel range directly, matching the car's own
    // "395 km" fuel-range display exactly. Previously never decoded, so
    // VehicleTelemetry.fromBlobMap's fuel_range_km always defaulted to 0.
    final rawFuelRange = u16(70);
    out['fuel_range_km'] = (rawFuelRange == null || rawFuelRange >= 0x3FE) ? null : rawFuelRange;

    // Confirmed against the same reading: fuel tank level, matching the
    // car's own "46% Fuel capacity" gauge exactly.
    final rawFuelCap = u8(21);
    out['fuel_capacity_pct'] = (rawFuelCap == null || rawFuelCap > 100) ? null : rawFuelCap;

    // Confirmed against real CarLinko telematics & live CAN-bus hex (2026-11-08):
    // 12-bit signed EV energy consumption packed across Byte 54 (low 4 bits) and Byte 55,
    // with standard automotive CAN offset -1000 and 0.1 factor:
    // (raw_12bit - 1000) * 0.1 kWh/100km.
    // e.g. Byte 54 = 0x13, Byte 55 = 0xE1 -> raw = ((0x13 & 0x0F) << 8) | 0xE1 = 993
    //      (993 - 1000) * 0.1 = -0.70 kWh/100km, matching CarLinko exactly.
    final b54 = u8(54);
    final b55 = u8(55);
    double? parsedConsumption;
    if (b54 != null && b55 != null && !(b54 == 0xFF && b55 == 0xFF)) {
      final rawCons = ((b54 & 0x0F) << 8) | b55;
      parsedConsumption = (rawCons - 1000) * 0.1;
    } else if (b55 != null && b55 != 0xFF) {
      parsedConsumption = (b55 - 1000) * 0.1;
    }
    out['consumption'] = parsedConsumption;
    out['energy_consumption_kwh100km'] = parsedConsumption;

    // Confirmed against real CarLinko telematics (Tiggo 7 PHEV): byte 53 * 0.1
    // = fuel consumption (e.g. 11 * 0.1 = 1.10 L/100km). Byte 55 * 0.1
    // = energy consumption (e.g. 94 * 0.1 = 9.40 kWh/100km).
    final fuelCons = u8(53);
    final double? parsedFuelCons = (fuelCons == null || fuelCons == 0xFF) ? null : (fuelCons * 0.1);
    out['fuel_consumption_l100km'] = parsedFuelCons;

    out['charge_mode'] = u8(56);
    final chargeState = u8(57);
    out['charge_state'] = chargeState;

    final remainMin = u16(58);
    out['charge_remain_min'] = (remainMin == null || remainMin >= 0x3FE) ? null : remainMin;

    final rawPower = u16(62);
    out['charge_power_kw'] = (chargeState != null && chargeState > 0 && rawPower != null) ? (rawPower * 0.1) : null;

    // Direct TPMS (order: FL, FR, RL, RR)
    // Pressure: kPa = raw * 1.75 + 3 (0x00 or 0xFF = no reading)
    // Temperature: degC = raw * 0.6 - 34.2
    // Both formulas were re-derived and confirmed against a real Tiggo 7
    // PHEV reading (2026-11-01) — the previously-used ha-carlinko formulas
    // (raw*1.375 / raw*0.5-25) were ported from a different Chery model and
    // read consistently low: pressure by ~29%, temperature by ~3-4°C.
    // Pressure now matches the car's own display exactly; temperature is
    // within 0.4°C (one reading's worth of data — refine further if a
    // second real-car comparison shows drift).
    final positions = ['fl', 'fr', 'rl', 'rr'];
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final pRaw = u8(44 + i);
      out['tyre_${pos}_pressure'] = (pRaw == null || pRaw == 0 || pRaw == 0xFF) ? null : (pRaw * 1.75 + 3.0);

      final tRaw = u8(48 + i);
      out['tyre_${pos}_temp'] = (tRaw == null || tRaw == 0 || tRaw == 0xFF) ? null : (tRaw * 0.6 - 34.2);
    }

    return out;
  }
}
