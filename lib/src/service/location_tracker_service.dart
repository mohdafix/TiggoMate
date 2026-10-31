import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../carlinko/carlinko_api.dart';
import '../carlinko/reverse_geocoder.dart';

const String _kTaskName = 'tm_location_tracker_task';
const String _kHistoryKey = 'tm_location_history';
const int _kMaxHistoryEntries = 50;

const String _kCarLinkoTokenKey = 'tm_carlinko_token';
const String _kCarLinkoRegionKey = 'tm_carlinko_region';
const String _kCarLinkoDeviceSnKey = 'tm_carlinko_device_sn';

/// One GPS fix captured by the background tracker.
class LocationHistoryEntry {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? address;

  const LocationHistoryEntry({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'timestampMs': timestamp.millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      };

  factory LocationHistoryEntry.fromJson(Map<String, dynamic> json) => LocationHistoryEntry(
        timestamp: DateTime.fromMillisecondsSinceEpoch((json['timestampMs'] as num?)?.toInt() ?? 0),
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        address: json['address'] as String?,
      );
}

/// Periodic (every ~15 min — Android's WorkManager floor for periodic work)
/// background GPS logger, independent of the app being open. Mirrors what
/// ha-carlinko describes CarLinko's own "Find My Car" doing: it polls the
/// account API directly for the vehicle's last reported position, not
/// anything from the CarLinko app's own UI.
class LocationTrackerService {
  LocationTrackerService._();

  /// Call once at app startup. Safe to call every launch — Workmanager
  /// no-ops a periodic task that's already registered under the same name.
  static Future<void> initializeAndSchedule() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _kTaskName,
        _kTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('LocationTrackerService: failed to schedule background task: $e');
    }
  }

  static Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(_kTaskName);
    } catch (_) {}
  }

  static Future<List<LocationHistoryEntry>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => LocationHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kHistoryKey);
    } catch (_) {}
  }

  /// Fetches the car's current position once and appends it to history.
  /// Used by both the background task and (optionally) a manual "track now"
  /// trigger from the UI.
  static Future<void> captureOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kCarLinkoTokenKey);
      final deviceSn = prefs.getString(_kCarLinkoDeviceSnKey);
      final region = prefs.getString(_kCarLinkoRegionKey) ?? carLinkoDefaultRegion;
      if (token == null || token.isEmpty || deviceSn == null || deviceSn.isEmpty) {
        // Not bound / no saved session — nothing to track yet.
        return;
      }

      final client = CarLinkoClient(region: region, token: token);
      // The 73-byte telemetry blob never carries GPS — use the real locate
      // endpoint (same one the dashboard uses) instead of parsing the blob.
      final loc = await client.locateDevice(deviceSn);
      final lat = (loc['lat'] as num?)?.toDouble();
      final lon = (loc['lng'] as num?)?.toDouble() ?? (loc['lon'] as num?)?.toDouble();
      if (lat == null || lon == null || (lat == 0 && lon == 0)) return;

      var address = (loc['address'] as String?)?.trim();
      if (address == null || address.isEmpty) {
        address = await ReverseGeocoder.lookup(lat, lon);
      }

      final history = await loadHistory();
      history.insert(
        0,
        LocationHistoryEntry(timestamp: DateTime.now(), latitude: lat, longitude: lon, address: address),
      );
      final trimmed = history.take(_kMaxHistoryEntries).toList();
      await prefs.setString(_kHistoryKey, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('LocationTrackerService.captureOnce failed: $e');
    }
  }
}

/// Entry point WorkManager calls in a separate background isolate — must
/// stay a top-level/static function annotated like this so the Android
/// plugin can find it after the app process has been killed.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await LocationTrackerService.captureOnce();
    return true;
  });
}
