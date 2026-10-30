import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mytnb_crypto.dart';

// ---------------- CONSTANTS ----------------
const String myTnbSitecoreLoginUrl = 'https://www.mytnb.com.my/api/sitecore/Account/Login';
const String myTnbSsoHandlerUrl = 'https://myaccount.mytnb.com.my/SSO/SSOHandler';
const String myTnbRestBaseUrl = 'https://api.mytnb.com.my';
// AWS API gateway: encrypted-payload account auto-discovery.
const String myTnbAwsApiBaseUrl = 'https://api.mytnb.com.my/core/api';
// Legacy ASMX backend: encrypted-payload usage/billing telemetry.
const String myTnbLegacyBaseUrl = 'https://mytnbapp.tnb.com.my/v7/mytnbws.asmx';
const String myTnbDefaultApiKey = 'gpUS5pe4aO2yMbId7bFa13dGfYYnBWbjn3vqn0d7';
// Static "SecureKey k1" the mobile app sends with every legacy ASMX request.
const String myTnbSecureKeyK1 = 'E6148656-205B-494C-BC95-CC241423E72F';
const String myTnbUserAgent = 'RestSharp/110.2.0.0';

// ---------------- EXCEPTIONS ----------------
class MyTnbException implements Exception {
  final String message;
  final String? code;
  const MyTnbException(this.message, [this.code]);

  @override
  String toString() => 'MyTnbException($code): $message';
}

class MyTnbAuthException extends MyTnbException {
  const MyTnbAuthException(super.message, [super.code]);
}

class MyTnbGeoBlockedException extends MyTnbException {
  const MyTnbGeoBlockedException()
      : super(
          'TNB Security WAF blocked the request. myTNB production endpoints enforce Malaysian IP restrictions. Use a Malaysian network/VPN or test using the Demo Smart Meter mode.',
          'GEO_BLOCKED_403',
        );
}

// ---------------- DATA MODELS ----------------

/// Authenticated myTNB session holding credentials and JWT tokens.
class MyTnbSession {
  final String email;
  final String userId;
  final String displayName;
  final String accessToken;
  final List<String> cookies;
  final bool isLoggedIn;
  final bool isDemo;
  final DateTime connectedAt;

  /// Login username as myTNB's SSO returned it (falls back to [email]).
  /// Sent as `eid`/`UserName` on every encrypted request.
  final String userName;

  /// Random per-session key sent as the `SecureKey` header on legacy ASMX
  /// calls (generated locally, like the mobile app does — not issued by TNB).
  final String secureKey;

  /// Random per-session device identifier sent as `deviceId`/`did`.
  final String deviceId;

  const MyTnbSession({
    required this.email,
    required this.userId,
    required this.displayName,
    required this.accessToken,
    this.cookies = const [],
    this.isLoggedIn = true,
    this.isDemo = false,
    required this.connectedAt,
    this.userName = '',
    this.secureKey = '',
    this.deviceId = '',
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'userId': userId,
        'displayName': displayName,
        'accessToken': accessToken,
        'cookies': cookies,
        'isLoggedIn': isLoggedIn,
        'isDemo': isDemo,
        'connectedAt': connectedAt.toIso8601String(),
        'userName': userName,
        'secureKey': secureKey,
        'deviceId': deviceId,
      };

  factory MyTnbSession.fromJson(Map<String, dynamic> json) => MyTnbSession(
        email: json['email'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        accessToken: json['accessToken'] as String? ?? '',
        cookies: (json['cookies'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        isLoggedIn: json['isLoggedIn'] as bool? ?? false,
        isDemo: json['isDemo'] as bool? ?? false,
        connectedAt: json['connectedAt'] != null
            ? DateTime.tryParse(json['connectedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        userName: json['userName'] as String? ?? '',
        secureKey: json['secureKey'] as String? ?? '',
        deviceId: json['deviceId'] as String? ?? '',
      );
}

/// A TNB contract account with smart meter telemetry and billing stats.
class MyTnbAccount {
  final String accountNumber;
  final String accountDesc;
  final String address;
  final String ownerName;
  final bool isSmartMeter;
  final double currentCharges;
  final double currentUsageKwh;
  final double projectedCostRm;
  final String lastReadingTime;
  final double effectiveTariff;
  final bool isDemo;

  const MyTnbAccount({
    required this.accountNumber,
    required this.accountDesc,
    required this.address,
    required this.ownerName,
    required this.isSmartMeter,
    required this.currentCharges,
    required this.currentUsageKwh,
    required this.projectedCostRm,
    required this.lastReadingTime,
    required this.effectiveTariff,
    this.isDemo = false,
  });

  Map<String, dynamic> toJson() => {
        'accountNumber': accountNumber,
        'accountDesc': accountDesc,
        'address': address,
        'ownerName': ownerName,
        'isSmartMeter': isSmartMeter,
        'currentCharges': currentCharges,
        'currentUsageKwh': currentUsageKwh,
        'projectedCostRm': projectedCostRm,
        'lastReadingTime': lastReadingTime,
        'effectiveTariff': effectiveTariff,
        'isDemo': isDemo,
      };

  factory MyTnbAccount.fromJson(Map<String, dynamic> json) => MyTnbAccount(
        accountNumber: json['accountNumber'] as String? ?? '',
        accountDesc: json['accountDesc'] as String? ?? '',
        address: json['address'] as String? ?? '',
        ownerName: json['ownerName'] as String? ?? '',
        isSmartMeter: json['isSmartMeter'] as bool? ?? true,
        currentCharges: (json['currentCharges'] as num?)?.toDouble() ?? 0.0,
        currentUsageKwh: (json['currentUsageKwh'] as num?)?.toDouble() ?? 0.0,
        projectedCostRm: (json['projectedCostRm'] as num?)?.toDouble() ?? 0.0,
        lastReadingTime: json['lastReadingTime'] as String? ?? 'Today',
        effectiveTariff: (json['effectiveTariff'] as num?)?.toDouble() ?? 0.57,
        isDemo: json['isDemo'] as bool? ?? false,
      );
}

// ---------------- TNB DOMESTIC TARIFF CALCULATOR ----------------
/// Official Malaysian TNB Tariff A (Domestic / Kediaman) calculator.
/// Rates verified from Tenaga Nasional Berhad official tariff schedule.
class TnbTariffCalculator {
  // Block 1: 1 - 200 kWh @ RM 0.218 / kWh
  static const double block1Limit = 200.0;
  static const double block1Rate = 0.218;

  // Block 2: 201 - 300 kWh @ RM 0.334 / kWh
  static const double block2Limit = 100.0; // 300 - 200
  static const double block2Rate = 0.334;

  // Block 3: 301 - 600 kWh @ RM 0.516 / kWh
  static const double block3Limit = 300.0; // 600 - 300
  static const double block3Rate = 0.516;

  // Block 4: 601 - 900 kWh @ RM 0.546 / kWh
  static const double block4Limit = 300.0; // 900 - 600
  static const double block4Rate = 0.546;

  // Block 5: > 900 kWh @ RM 0.571 / kWh
  static const double block5Rate = 0.571;

  // Off-Peak rate (TNB EV Time-of-Use / Solar off-peak 10:00 PM – 08:00 AM)
  static const double offPeakRate = 0.280;

  /// Calculate total domestic bill (in RM) from total kWh consumption.
  static double calculateDomesticBill(double totalKwh) {
    if (totalKwh <= 0) return 0.0;

    double bill = 0.0;
    double remaining = totalKwh;

    // Block 1
    final b1 = remaining > block1Limit ? block1Limit : remaining;
    bill += b1 * block1Rate;
    remaining -= b1;
    if (remaining <= 0) return bill;

    // Block 2
    final b2 = remaining > block2Limit ? block2Limit : remaining;
    bill += b2 * block2Rate;
    remaining -= b2;
    if (remaining <= 0) return bill;

    // Block 3
    final b3 = remaining > block3Limit ? block3Limit : remaining;
    bill += b3 * block3Rate;
    remaining -= b3;
    if (remaining <= 0) return bill;

    // Block 4
    final b4 = remaining > block4Limit ? block4Limit : remaining;
    bill += b4 * block4Rate;
    remaining -= b4;
    if (remaining <= 0) return bill;

    // Block 5
    bill += remaining * block5Rate;
    return bill;
  }

  /// Calculate effective blended tariff rate (RM per kWh) for the given consumption.
  static double calculateEffectiveTariff(double totalKwh) {
    if (totalKwh <= 0) return block1Rate;
    final totalBill = calculateDomesticBill(totalKwh);
    return double.parse((totalBill / totalKwh).toStringAsFixed(4));
  }

  /// Calculate marginal PHEV home charging cost.
  /// If [currentHouseholdKwh] is known from smart meter, the PHEV kWh is added
  /// on top of household consumption into the actual higher tariff tier!
  static double calculatePhevChargeCost({
    required double phevKwh,
    double currentHouseholdKwh = 0.0,
    bool isOffPeak = false,
  }) {
    if (phevKwh <= 0) return 0.0;
    if (isOffPeak) return phevKwh * offPeakRate;

    if (currentHouseholdKwh <= 0) {
      // Default to highest domestic tier (RM 0.57) if no smart meter data
      return phevKwh * 0.57;
    }

    // Marginal calculation: Bill(household + phev) - Bill(household)
    final billBefore = calculateDomesticBill(currentHouseholdKwh);
    final billAfter = calculateDomesticBill(currentHouseholdKwh + phevKwh);
    return billAfter - billBefore;
  }
}

// ---------------- MYTNB API CLIENT ----------------
/// Direct reverse-engineered client for TNB authentication and smart meter sync.
class MyTnbClient {
  final HttpClient _client;

  MyTnbClient({HttpClient? client}) : _client = client ?? HttpClient();

  /// Authenticate with myTNB credentials or return a demo session if in test mode.
  Future<MyTnbSession> login({
    required String email,
    required String password,
    bool isDemo = false,
  }) async {
    // 1. Check for explicit demo mode or demo credentials
    if (isDemo || email.trim().toLowerCase() == 'demo' || email.trim().toLowerCase() == 'demo@mytnb.com.my') {
      return MyTnbSession(
        email: 'chery.owner@mytnb.com.my',
        userId: 'MYTNB-USR-8829104',
        displayName: 'Ahmad Chery (Smart Meter)',
        accessToken: 'demo_live_jwt_access_token_mytnb',
        isLoggedIn: true,
        isDemo: true,
        connectedAt: DateTime.now(),
      );
    }

    try {
      // Step 1: Pre-flight GET to establish Sitecore session cookie
      final homeReq = await _client.getUrl(Uri.parse('https://www.mytnb.com.my/'));
      homeReq.headers.set('User-Agent', myTnbUserAgent);
      final homeResp = await homeReq.close();
      final sessionCookies = <String>[];
      homeResp.headers.forEach((name, values) {
        if (name.toLowerCase() == 'set-cookie') {
          sessionCookies.addAll(values);
        }
      });
      await homeResp.drain<void>();

      // Step 2: Post plaintext credentials to Sitecore web login
      final loginReq = await _client.postUrl(Uri.parse(myTnbSitecoreLoginUrl));
      loginReq.headers.set('User-Agent', myTnbUserAgent);
      loginReq.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      loginReq.headers.set('Origin', 'https://www.mytnb.com.my');
      loginReq.headers.set('Referer', 'https://www.mytnb.com.my/');
      if (sessionCookies.isNotEmpty) {
        loginReq.headers.set('Cookie', sessionCookies.join('; '));
      }

      final formPayload = 'Email=${Uri.encodeQueryComponent(email.trim())}&Password=${Uri.encodeQueryComponent(password)}';
      loginReq.write(formPayload);
      final loginResp = await loginReq.close();

      if (loginResp.statusCode == 403) {
        throw const MyTnbGeoBlockedException();
      }

      final loginHtml = await utf8.decodeStream(loginResp);

      if (loginResp.statusCode != 200) {
        throw MyTnbAuthException('myTNB login failed with HTTP ${loginResp.statusCode}');
      }

      // Step 3: Extract hidden form inputs from HTML for SSO Handshake
      final ssoFields = <String, String>{};
      final regex = RegExp(r'name="([^"]+)"\s+value="([^"]*)"');
      for (final match in regex.allMatches(loginHtml)) {
        final k = match.group(1);
        final v = match.group(2);
        if (k != null && v != null) {
          ssoFields[k] = v;
        }
      }

      if (!ssoFields.containsKey('USERNAME') && !loginHtml.contains('SSOHandler')) {
        throw const MyTnbAuthException('Invalid myTNB email or password. Please verify your credentials.');
      }

      // Step 4: Submit SSO form with redirect capture (.AspNet.ApplicationCookie)
      final ssoReq = await _client.postUrl(Uri.parse(myTnbSsoHandlerUrl));
      ssoReq.followRedirects = false; // Capture all session cookies before browser redirect
      ssoReq.headers.set('User-Agent', myTnbUserAgent);
      ssoReq.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      ssoReq.headers.set('Origin', 'https://www.mytnb.com.my');
      ssoReq.headers.set('Referer', 'https://www.mytnb.com.my/');
      if (sessionCookies.isNotEmpty) {
        ssoReq.headers.set('Cookie', sessionCookies.join('; '));
      }

      final ssoBody = ssoFields.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      ssoReq.write(ssoBody);

      final ssoResp = await ssoReq.close();
      String? jwtToken;

      final allCookies = <String>[...sessionCookies];
      ssoResp.headers.forEach((name, values) {
        if (name.toLowerCase() == 'set-cookie') {
          allCookies.addAll(values);
          for (final c in values) {
            final match = RegExp(r'=(eyJ[^;]+)').firstMatch(c);
            if (match != null) {
              jwtToken = match.group(1);
              break;
            }
          }
        }
      });

      // Follow SSO redirect location to finalize myaccount.mytnb.com.my session
      final redirectLocation = ssoResp.headers.value(HttpHeaders.locationHeader);
      await ssoResp.drain<void>();

      if (redirectLocation != null && redirectLocation.isNotEmpty) {
        try {
          final redirectUri = Uri.parse(redirectLocation.startsWith('http')
              ? redirectLocation
              : 'https://myaccount.mytnb.com.my$redirectLocation');
          final redReq = await _client.getUrl(redirectUri);
          redReq.headers.set('User-Agent', myTnbUserAgent);
          if (allCookies.isNotEmpty) {
            redReq.headers.set('Cookie', allCookies.join('; '));
          }
          final redResp = await redReq.close();
          redResp.headers.forEach((name, values) {
            if (name.toLowerCase() == 'set-cookie') {
              allCookies.addAll(values);
            }
          });
          await redResp.drain<void>();
        } catch (_) {}
      }

      String userId = 'MYTNB-USER';
      String displayName = email.split('@').first;
      String userName = email.trim();

      if (jwtToken != null) {
        try {
          final parts = jwtToken!.split('.');
          if (parts.length >= 2) {
            String norm = parts[1];
            while (norm.length % 4 != 0) {
              norm += '=';
            }
            final decodedPayload = utf8.decode(base64Decode(norm));
            final jwtData = jsonDecode(decodedPayload) as Map<String, dynamic>;
            if (jwtData.containsKey('UserInfo')) {
              final ui = jsonDecode(jwtData['UserInfo'] as String) as Map<String, dynamic>;
              userId = ui['UserId']?.toString() ?? userId;
              displayName = ui['DisplayName']?.toString() ?? ui['UserName']?.toString() ?? displayName;
              userName = ui['UserName']?.toString() ?? userName;
            }
          }
        } catch (e) {
          debugPrint('Error parsing SSO JWT: $e');
        }
      }

      // Step 5: Generate mobile access token
      final tokenUri = Uri.parse('$myTnbRestBaseUrl/Identity/api/v1/Identity/GenerateAccessToken?environment=Prod');
      final tokenReq = await _client.postUrl(tokenUri);
      tokenReq.headers.set('Content-Type', 'application/json');
      tokenReq.headers.set('Accept', 'application/json');
      tokenReq.headers.set('x-api-key', myTnbDefaultApiKey);
      tokenReq.headers.set('User-Agent', myTnbUserAgent);

      tokenReq.write(jsonEncode({
        'channel': 'myTNB_API_Mobile',
        'userId': userId,
      }));

      final tokenResp = await tokenReq.close();
      final tokenBody = await utf8.decodeStream(tokenResp);
      String accessToken = 'tnb_token_${DateTime.now().millisecondsSinceEpoch}';

      if (tokenResp.statusCode == 200) {
        try {
          final tokenJson = jsonDecode(tokenBody) as Map<String, dynamic>;
          final content = tokenJson['content'] as Map<String, dynamic>?;
          if (content != null && content.containsKey('accessToken')) {
            accessToken = content['accessToken'] as String;
          }
        } catch (_) {}
      }

      return MyTnbSession(
        email: email.trim(),
        userId: userId,
        displayName: displayName,
        accessToken: accessToken,
        cookies: allCookies,
        isLoggedIn: true,
        isDemo: false,
        connectedAt: DateTime.now(),
        userName: userName,
        secureKey: MyTnbCrypto.generateUuidV4(),
        deviceId: MyTnbCrypto.generateUuidV4(),
      );
    } catch (e) {
      if (e is MyTnbException) rethrow;
      // Network/socket error or connection refused
      throw MyTnbException('Failed to connect to myTNB servers: $e', 'NETWORK_ERR');
    }
  }

  /// Discover all linked customer accounts and their smart meter telemetry.
  Future<List<MyTnbAccount>> getCustomerAccounts(MyTnbSession session) async {
    // If in demo mode or if remote endpoints are offline, provide realistic Malaysian Smart Meter data
    if (session.isDemo) {
      final double demoKwh = 482.6;
      final double effectiveRate = TnbTariffCalculator.calculateEffectiveTariff(demoKwh);
      final double billAmount = TnbTariffCalculator.calculateDomesticBill(demoKwh);

      return [
        MyTnbAccount(
          accountNumber: '220384918204',
          accountDesc: 'Kediaman Bangi (Smart Meter)',
          address: 'No. 18, Jalan 13/2, Seksyen 13, 43650 Bandar Baru Bangi, Selangor',
          ownerName: session.displayName.isNotEmpty ? session.displayName : 'Ahmad Chery',
          isSmartMeter: true,
          currentCharges: double.parse(billAmount.toStringAsFixed(2)),
          currentUsageKwh: demoKwh,
          projectedCostRm: 185.20,
          lastReadingTime: 'Today 08:30 AM (Half-Hourly Sync)',
          effectiveTariff: effectiveRate,
          isDemo: true,
        ),
        MyTnbAccount(
          accountNumber: '210948271039',
          accountDesc: 'Rumah Kampung (Standard Meter)',
          address: 'Lot 24, Jalan Sungai Ramal Luar, 43000 Kajang, Selangor',
          ownerName: session.displayName.isNotEmpty ? session.displayName : 'Ahmad Chery',
          isSmartMeter: false,
          currentCharges: 62.40,
          currentUsageKwh: 245.0,
          projectedCostRm: 85.00,
          lastReadingTime: 'Monthly Meter Cycle',
          effectiveTariff: 0.265,
          isDemo: true,
        ),
      ];
    }

    // For a live session: discover linked accounts, then pull each one's
    // real bill/usage telemetry, from myTNB's actual encrypted API (ported
    // from the open-source python-mytnb client) — not a guess.
    return _fetchLiveAccounts(session);
  }

  Map<String, dynamic> _baseUserInfo(MyTnbSession session) => {
        'eid': session.userName.isNotEmpty ? session.userName : session.email,
        'sspuid': session.userId,
        'did': session.deviceId,
        'ft': '',
        'lang': 'EN',
        'sec_auth_k1': myTnbSecureKeyK1,
        'sec_auth_k2': '',
        'ses_param1': '',
        'ses_param2': '',
      };

  Map<String, dynamic> _baseDeviceInfo(MyTnbSession session) => {
        'deviceId': session.deviceId,
        'appVersion': '4.0.2',
        'osType': '1', // 1 = Android (this app's native platform)
        'osVersion': '14',
        'deviceDesc': 'EN',
        'versionCode': '1425',
      };

  bool _parseFlag(dynamic value) {
    if (value is bool) return value;
    final s = value?.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  /// POST an AES-256-CBC + RSA-OAEP encrypted body to the legacy ASMX API
  /// and unwrap the `{"d": {...}}` envelope, surfacing any TNB-reported
  /// error instead of papering over it.
  Future<Map<String, dynamic>> _postLegacyEncrypted({
    required MyTnbSession session,
    required String endpoint,
    required Map<String, dynamic> data,
  }) async {
    final payload = MyTnbCrypto.encryptRequest(data);
    final req = await _client.postUrl(Uri.parse('$myTnbLegacyBaseUrl/$endpoint'));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set(
      'Accept',
      'application/json,text/json,text/x-json,text/javascript,application/xml,text/xml',
    );
    req.headers.set('Lang', 'EN');
    req.headers.set('UserInfo', jsonEncode({
      'RoleId': '16',
      'UserId': session.userId,
      'UserName': session.userName.isNotEmpty ? session.userName : session.email,
      'Lang': 'EN',
    }));
    req.headers.set('SecureKey', session.secureKey);
    req.headers.set('User-Agent', myTnbUserAgent);
    req.write(jsonEncode({'dt': payload.toJson()}));

    final resp = await req.close();
    if (resp.statusCode == 403) {
      throw const MyTnbGeoBlockedException();
    }
    if (resp.statusCode != 200) {
      throw MyTnbException('myTNB $endpoint failed with HTTP ${resp.statusCode}', 'HTTP_${resp.statusCode}');
    }

    final text = await utf8.decodeStream(resp);
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    final d = (parsed['d'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    // 7200/7204 are TNB's own "success" codes; anything else is a real error.
    final errorCode = d['ErrorCode']?.toString();
    if (errorCode != null && errorCode != '7200' && errorCode != '7204') {
      final message = d['DisplayMessage'] ?? d['displayMessage'] ?? d['Message'] ?? d['message'];
      throw MyTnbException((message ?? 'myTNB $endpoint returned error $errorCode').toString(), errorCode);
    }
    return d;
  }

  Future<List<MyTnbAccount>> _fetchLiveAccounts(MyTnbSession session) async {
    // 1. Discover every account linked to this login via the AWS gateway.
    final discoveryData = {
      'usrInf': {..._baseUserInfo(session), 'IsWhiteList': false},
      'deviceInf': _baseDeviceInfo(session),
      'featureInfo': <dynamic>[],
    };
    final discoveryPayload = MyTnbCrypto.encryptRequest(discoveryData);

    final discoveryReq = await _client.postUrl(Uri.parse('$myTnbAwsApiBaseUrl/v3/account/GetAccount'));
    discoveryReq.headers.set('Content-Type', 'application/json');
    discoveryReq.headers.set(
      'Accept',
      'application/json,text/json,text/x-json,text/javascript,application/xml,text/xml',
    );
    discoveryReq.headers.set('User-Agent', myTnbUserAgent);
    discoveryReq.write(jsonEncode({'dt': discoveryPayload.toJson()}));

    final discoveryResp = await discoveryReq.close();
    if (discoveryResp.statusCode == 403) {
      throw const MyTnbGeoBlockedException();
    }
    if (discoveryResp.statusCode != 200) {
      throw MyTnbException(
        'myTNB account discovery failed with HTTP ${discoveryResp.statusCode}',
        'DISCOVER_HTTP_${discoveryResp.statusCode}',
      );
    }

    final discoveryText = await utf8.decodeStream(discoveryResp);
    final discoveryJson = jsonDecode(discoveryText) as Map<String, dynamic>;
    final rawAccounts = (discoveryJson['data'] as List?) ?? const [];
    if (rawAccounts.isEmpty) {
      throw const MyTnbException('No myTNB accounts are linked to this login.', 'NO_ACCOUNTS');
    }

    final accounts = <MyTnbAccount>[];
    for (final raw in rawAccounts) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final caNo = (map['accNum'] ?? '').toString();
      if (caNo.isEmpty) continue;

      final smartMeterCode = (map['smartMeterCode'] ?? map['SmartMeterCode'] ?? '').toString();
      final isSmart = smartMeterCode.isNotEmpty;
      final isOwned = _parseFlag(map['isOwned']);

      double currentCharges = 0.0;
      double currentUsageKwh = 0.0;
      String lastReadingTime = 'Pending Sync';

      // 2. Current outstanding bill. Best-effort: a failure here shouldn't
      // hide an account that *was* discovered — it just stays unknown ("--").
      try {
        final due = await _postLegacyEncrypted(
          session: session,
          endpoint: 'GetAccountDueAmount',
          data: {
            'contractAccount': caNo,
            'isOwnedAccount': isOwned ? 'true' : 'false',
            'usrInf': _baseUserInfo(session),
          },
        );
        final dueData = due['data'];
        final dueMap = dueData is Map ? (dueData['AccountAmountDue'] ?? dueData) : null;
        if (dueMap is Map) {
          currentCharges = double.tryParse('${dueMap['amountDue'] ?? ''}') ?? 0.0;
        }
      } catch (e) {
        debugPrint('myTNB GetAccountDueAmount failed for $caNo: $e');
      }

      // 3. Current-cycle usage in kWh.
      try {
        final usage = await _postLegacyEncrypted(
          session: session,
          endpoint: 'GetAccountUsageSmart',
          data: {
            'contractAccount': caNo,
            'isOwner': isOwned ? 'true' : 'false',
            'metercode': '',
            'usrInf': _baseUserInfo(session),
          },
        );
        final usageData = usage['data'];
        final byMonth = usageData is Map ? usageData['ByMonth'] : null;
        final months = (byMonth is Map ? byMonth['Months'] : null);
        if (months is List) {
          final monthMaps = months.whereType<Map>().toList();
          if (monthMaps.isNotEmpty) {
            final current = monthMaps.firstWhere(
              (m) => m['IsUnbilled'] == true,
              orElse: () => monthMaps.last,
            );
            currentUsageKwh = double.tryParse('${current['UsageTotal'] ?? ''}') ?? 0.0;
            final month = current['Month']?.toString() ?? '';
            final year = current['Year']?.toString() ?? '';
            lastReadingTime = (month.isNotEmpty || year.isNotEmpty)
                ? 'Smart Meter: $month $year'
                : 'Live Smart Meter Sync';
          }
        }
      } catch (e) {
        debugPrint('myTNB GetAccountUsageSmart failed for $caNo: $e');
      }

      final effectiveTariff =
          currentUsageKwh > 0 ? TnbTariffCalculator.calculateEffectiveTariff(currentUsageKwh) : 0.0;
      final accDesc = (map['accDesc'] ?? '').toString();
      final ownerName = (map['ownerName'] ?? '').toString();

      accounts.add(
        MyTnbAccount(
          accountNumber: caNo,
          accountDesc: accDesc.isNotEmpty ? accDesc : (isSmart ? 'Home (Smart Meter)' : 'Home (Standard Meter)'),
          address: (map['accountStAddress'] ?? '').toString(),
          ownerName: ownerName.isNotEmpty
              ? ownerName
              : (session.displayName.isNotEmpty ? session.displayName : 'TNB Customer'),
          isSmartMeter: isSmart,
          currentCharges: double.parse(currentCharges.toStringAsFixed(2)),
          currentUsageKwh: currentUsageKwh,
          // The real "projected" bill isn't fetched; showing the same real
          // due amount twice beats inventing a markup guess.
          projectedCostRm: double.parse(currentCharges.toStringAsFixed(2)),
          lastReadingTime: lastReadingTime,
          effectiveTariff: effectiveTariff,
          isDemo: false,
        ),
      );
    }

    if (accounts.isEmpty) {
      throw const MyTnbException('myTNB returned accounts with no valid account number.', 'NO_VALID_ACCOUNTS');
    }
    return accounts;
  }
}

// ---------------- REPOSITORY & SERVICE ----------------
/// Manages myTNB session storage, current smart meter telemetry, and listeners.
class MyTnbRepository {
  static const String _kSessionKey = 'mytnb_saved_session';
  static const String _kAccountKey = 'mytnb_saved_account';
  static const String _kAccountsListKey = 'mytnb_saved_accounts_list';

  final MyTnbClient client;
  final ValueNotifier<MyTnbSession?> sessionNotifier = ValueNotifier<MyTnbSession?>(null);
  final ValueNotifier<MyTnbAccount?> selectedAccountNotifier = ValueNotifier<MyTnbAccount?>(null);
  final ValueNotifier<List<MyTnbAccount>> allAccountsNotifier = ValueNotifier<List<MyTnbAccount>>([]);

  MyTnbRepository({MyTnbClient? client}) : client = client ?? MyTnbClient();

  /// Initialize and restore any persisted myTNB session from SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString(_kSessionKey);
    if (rawSession != null) {
      try {
        final sessionMap = jsonDecode(rawSession) as Map<String, dynamic>;
        sessionNotifier.value = MyTnbSession.fromJson(sessionMap);
      } catch (e) {
        debugPrint('Failed to load saved myTNB session: $e');
      }
    }

    final rawAccount = prefs.getString(_kAccountKey);
    if (rawAccount != null) {
      try {
        final accountMap = jsonDecode(rawAccount) as Map<String, dynamic>;
        selectedAccountNotifier.value = MyTnbAccount.fromJson(accountMap);
      } catch (e) {
        debugPrint('Failed to load saved myTNB account: $e');
      }
    }

    final rawList = prefs.getString(_kAccountsListKey);
    if (rawList != null) {
      try {
        final list = (jsonDecode(rawList) as List)
            .map((item) => MyTnbAccount.fromJson(item as Map<String, dynamic>))
            .toList();
        allAccountsNotifier.value = list;
      } catch (e) {
        debugPrint('Failed to load saved myTNB accounts list: $e');
      }
    }
  }

  /// Sign in with myTNB credentials and automatically select primary Smart Meter account.
  Future<MyTnbAccount?> login({
    required String email,
    required String password,
    bool isDemo = false,
  }) async {
    final session = await client.login(email: email, password: password, isDemo: isDemo);
    sessionNotifier.value = session;

    // Persist session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, jsonEncode(session.toJson()));

    // Fetch accounts
    final accounts = await client.getCustomerAccounts(session);
    allAccountsNotifier.value = accounts;
    await prefs.setString(
      _kAccountsListKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );

    if (accounts.isNotEmpty) {
      // Prioritize smart meter account
      final primary = accounts.firstWhere(
        (a) => a.isSmartMeter,
        orElse: () => accounts.first,
      );
      selectedAccountNotifier.value = primary;
      await prefs.setString(_kAccountKey, jsonEncode(primary.toJson()));
      return primary;
    }
    return null;
  }

  /// Select a specific contract account
  Future<void> selectAccount(MyTnbAccount account) async {
    selectedAccountNotifier.value = account;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccountKey, jsonEncode(account.toJson()));
  }

  /// Refresh smart meter reading
  Future<MyTnbAccount?> refreshReading() async {
    final session = sessionNotifier.value;
    if (session == null) return null;
    final accounts = await client.getCustomerAccounts(session);
    allAccountsNotifier.value = accounts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kAccountsListKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );

    if (accounts.isNotEmpty) {
      final currentAccNum = selectedAccountNotifier.value?.accountNumber;
      final match = accounts.firstWhere(
        (a) => a.accountNumber == currentAccNum,
        orElse: () => accounts.first,
      );
      selectedAccountNotifier.value = match;
      await prefs.setString(_kAccountKey, jsonEncode(match.toJson()));
      return match;
    }
    return null;
  }

  /// Log out and clear saved credentials
  Future<void> logout() async {
    sessionNotifier.value = null;
    selectedAccountNotifier.value = null;
    allAccountsNotifier.value = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
    await prefs.remove(_kAccountKey);
    await prefs.remove(_kAccountsListKey);
  }
}
