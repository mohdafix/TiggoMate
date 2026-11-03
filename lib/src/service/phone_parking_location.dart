import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../carlinko/reverse_geocoder.dart';

const String _kStorageKey = 'tm_phone_parked_location_v1';

/// Where the phone was, the moment the car was last seen transitioning to
/// parked. A fallback for when CarLinko's own GPS fetch fails (the
/// recurring "query location failed" server error) -- captured from the
/// phone itself instead, with no extra background-location permission.
class PhoneParkedLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;

  const PhoneParkedLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestampMs': timestamp.millisecondsSinceEpoch,
        'address': address,
      };

  factory PhoneParkedLocation.fromJson(Map<String, dynamic> json) => PhoneParkedLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch((json['timestampMs'] as num).toInt()),
        address: json['address'] as String?,
      );
}

/// Captures the phone's own GPS position the moment the car's telemetry
/// shows it just transitioned to parked, as a fallback location source.
/// Foreground-only by design: reading location from a WorkManager
/// background isolate needs the separate, heavier
/// ACCESS_BACKGROUND_LOCATION permission, and would often fire minutes
/// after the user has already walked away (15-min poll interval, further
/// deferred by MIUI) -- less accurate than capturing it on the spot while
/// the app is open and the user is still near the car.
class PhoneParkingLocationService {
  PhoneParkingLocationService._();

  static Future<void> captureNow() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return;
      final address = await ReverseGeocoder.lookup(pos.latitude, pos.longitude);

      final record = PhoneParkedLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        address: address,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKey, jsonEncode(record.toJson()));
    } catch (e) {
      debugPrint('PhoneParkingLocationService.captureNow failed: $e');
    }
  }

  static Future<PhoneParkedLocation?> loadLast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw == null || raw.isEmpty) return null;
      return PhoneParkedLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
