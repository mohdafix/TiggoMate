import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// App-global key extracted from the CarLinko mobile APK (not a user secret).
/// Reference: https://github.com/thititongumpun/ha-carlinko
const String carLinkoSignKey = 'mYj3fzMpn77bir66';
const String carLinkoDefaultRegion = 'sea'; // South East Asia (Malaysia & Thailand)
const String carLinkoApiVersion = '1.12.0';
const String carLinkoUserAgent = 'Dart/3.10 (dart:io)';

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
    // Normalize values: null -> "", others -> toString()
    final normalized = <String, String>{};
    for (final entry in merged.entries) {
      normalized[entry.key] = entry.value == null ? '' : entry.value.toString();
    }

    // Sort keys alphabetically ascending
    final sortedKeys = normalized.keys.toList()..sort();
    final sortedMap = <String, String>{};
    for (final k in sortedKeys) {
      sortedMap[k] = normalized[k]!;
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
      'phoneBrand': 'Chery',
      'phoneModel': 'TiggoMate-Companion',
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
      throw CarLinkoException(
        'CarLinko server returned HTTP ${response.statusCode}',
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

  /// Retrieve decoded 73-byte telemetry state for a vehicle.
  Future<Map<String, dynamic>> getVehicleState(String vehicleId) async {
    final result = await _request('GET', '/user/vehicle/state/$vehicleId', signParams: {'id': vehicleId});
    final hexBlob = result?.toString() ?? '';
    final decoded = parseBlob(hexBlob);
    decoded['rawHex'] = hexBlob;
    return decoded;
  }

  /// Check whether vehicle telematics box is currently online.
  Future<bool> isVehicleOnline(String vehicleId) async {
    final result = await _request('GET', '/user/vehicle/isOnline/$vehicleId', signParams: {'id': vehicleId});
    return result == true;
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
  Future<bool> setTargetSoc(String vehicleId, int targetSoc) async {
    final body = {'vehicleId': vehicleId, 'targetSoc': targetSoc};
    await _request('POST', '/user/device/manage/targetSoc', body: body, signParams: body);
    return true;
  }

  /// Set smart cabin air conditioning pre-conditioning duration in minutes (e.g. 10 or 15 mins).
  Future<bool> setAirDuration(String vehicleId, int minutes) async {
    final body = {'vehicleId': vehicleId, 'airDuration': minutes};
    await _request('POST', '/user/device/manage/airDuration', body: body, signParams: body);
    return true;
  }

  /// Set smart scheduled AC charging timer.
  Future<bool> setBatterySchedule(String vehicleId, Map<String, dynamic> scheduleParams) async {
    final body = {'vehicleId': vehicleId, ...scheduleParams};
    await _request('POST', '/user/device/manage/batterySchedule', body: body, signParams: body);
    return true;
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

    final ts = _currentTimestamp();
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final signature = sign(signParams, ts);

    HttpClientResponse response;
    String bodyStr;
    try {
      final request = await _client.openUrl(method, uri).timeout(const Duration(seconds: 12));
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
        body['timestamp'] = ts;
        final utf8Body = utf8.encode(json.encode(body));
        request.headers.contentLength = utf8Body.length;
        request.add(utf8Body);
      }

      response = await request.close().timeout(const Duration(seconds: 12));
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
      throw CarLinkoException(
        'CarLinko server returned HTTP ${response.statusCode}',
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
      if (code == '1001' || code == '1002' || code == '401') {
        throw CarLinkoAuthException(payload['msg']?.toString() ?? 'Session expired', code);
      }
      throw CarLinkoException(payload['msg']?.toString() ?? 'API error', code);
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
    int? u32(int i) => (i + 3 < n) ? ((b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]) : null;

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
    out['ac_on'] = ac != null ? ac != 0 : null;
    out['ac_temp'] = u8(24);

    out['battery_pct'] = u8(28);
    out['range_km'] = u16(29);

    // GPS coordinates if available in telematics blob (scaled by 1e6)
    final rawLat = u32(32);
    final rawLon = u32(36);
    if (rawLat != null && rawLat != 0 && rawLon != null && rawLon != 0) {
      out['lat'] = rawLat / 1000000.0;
      out['lon'] = rawLon / 1000000.0;
    }

    out['wltc_range'] = u16(68);

    final cons = u8(55);
    out['consumption'] = cons != null ? (cons * 0.1) : null;

    out['charge_mode'] = u8(56);
    final chargeState = u8(57);
    out['charge_state'] = chargeState;

    final remainMin = u16(58);
    out['charge_remain_min'] = (remainMin == null || remainMin >= 0x3FE) ? null : remainMin;

    final rawPower = u16(62);
    out['charge_power_kw'] = (chargeState != null && chargeState > 0 && rawPower != null) ? (rawPower * 0.1) : null;

    // Direct TPMS (order: FL, FR, RL, RR)
    // Pressure: kPa = raw * 1.375 (0x00 or 0xFF = no reading)
    // Temperature: degC = raw * 0.5 - 25
    final positions = ['fl', 'fr', 'rl', 'rr'];
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final pRaw = u8(44 + i);
      out['tyre_${pos}_pressure'] = (pRaw == null || pRaw == 0 || pRaw == 0xFF) ? null : (pRaw * 1.375);

      final tRaw = u8(48 + i);
      out['tyre_${pos}_temp'] = (tRaw == null || tRaw == 0 || tRaw == 0xFF) ? null : (tRaw * 0.5 - 25.0);
    }

    return out;
  }
}
