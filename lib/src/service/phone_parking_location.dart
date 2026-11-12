import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../carlinko/reverse_geocoder.dart';

const String _kStorageKey = 'tm_phone_parked_location_v1';

/// Where the phone was when the car was physically turned off and disconnected
/// from the phone's Bluetooth hands-free system.
class PhoneParkedLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;
  final bool isFromCarBluetooth;
  final String? carBluetoothName;

  const PhoneParkedLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
    this.isFromCarBluetooth = true,
    this.carBluetoothName,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestampMs': timestamp.millisecondsSinceEpoch,
        'address': address,
        'isFromCarBluetooth': isFromCarBluetooth,
        'carBluetoothName': carBluetoothName,
      };

  factory PhoneParkedLocation.fromJson(Map<String, dynamic> json) => PhoneParkedLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch((json['timestampMs'] as num).toInt()),
        address: json['address'] as String?,
        isFromCarBluetooth: json['isFromCarBluetooth'] as bool? ?? true,
        carBluetoothName: json['carBluetoothName'] as String?,
      );
}

/// Captures phone GPS position ONLY when the vehicle's Bluetooth disconnects
/// upon engine shutoff (confirming the user was physically in the vehicle).
class PhoneParkingLocationService {
  PhoneParkingLocationService._();

  /// Captures phone GPS on vehicle engine-off (car Bluetooth disconnect).
  static Future<void> captureOnBluetoothDisconnect({String? carName}) async {
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
            accuracy: LocationAccuracy.high,
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
        isFromCarBluetooth: true,
        carBluetoothName: carName,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKey, jsonEncode(record.toJson()));
      debugPrint('📍 Phone parking location saved from car Bluetooth disconnect: $address (${pos.latitude}, ${pos.longitude})');
    } catch (e) {
      debugPrint('PhoneParkingLocationService.captureOnBluetoothDisconnect failed: $e');
    }
  }

  /// Backward-compatible alias that logs a warning if called outside of car Bluetooth.
  static Future<void> captureNow({String? carName}) async {
    await captureOnBluetoothDisconnect(carName: carName);
  }

  /// Loads the last saved phone parking location.
  /// If [requireBluetoothVerification] is true, only returns location if it was
  /// genuinely stamped by a vehicle Bluetooth disconnection.
  static Future<PhoneParkedLocation?> loadLast({bool requireBluetoothVerification = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final record = PhoneParkedLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (requireBluetoothVerification && !record.isFromCarBluetooth) {
        return null;
      }
      return record;
    } catch (_) {
      return null;
    }
  }

  /// Clears stored phone parking location.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kStorageKey);
    } catch (_) {}
  }
}
