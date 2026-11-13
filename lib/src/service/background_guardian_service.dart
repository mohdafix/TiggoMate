import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing Android background execution permissions,
/// battery optimization exemptions, and OEM Autostart settings (especially HyperOS / MIUI).
class BackgroundGuardianService {
  BackgroundGuardianService._();
  static final BackgroundGuardianService instance = BackgroundGuardianService._();

  static const MethodChannel _channel = MethodChannel('com.tiggomate/battery_optimization');
  static const String _kGuardianPrefKey = 'tm_guardian_service_enabled';

  /// Whether the app is currently whitelisted from Android battery optimizations.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the Android OS system dialog to allow TiggoMate to run in background.
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the OEM-specific Autostart / Background App management screen
  /// (e.g. Xiaomi Security Center, Samsung Device Care, Huawei, Oppo, Vivo).
  Future<bool> openAutostartSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openAutostartSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves device manufacturer info (e.g. Xiaomi, POCO, Samsung).
  Future<Map<String, String>> getDeviceInfo() async {
    if (!Platform.isAndroid) return {};
    try {
      final res = await _channel.invokeMethod<Map>('getManufacturer');
      if (res == null) return {};
      return res.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Checks if device is a Xiaomi / Redmi / POCO phone running MIUI or HyperOS.
  Future<bool> isXiaomiDevice() async {
    final info = await getDeviceInfo();
    final m = (info['manufacturer'] ?? '').toLowerCase();
    final b = (info['brand'] ?? '').toLowerCase();
    return m.contains('xiaomi') || m.contains('redmi') || m.contains('poco') ||
           b.contains('xiaomi') || b.contains('redmi') || b.contains('poco');
  }

  /// Whether 24/7 background guardian monitoring is enabled in settings.
  Future<bool> isGuardianEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kGuardianPrefKey) ?? true;
  }

  /// Toggles 24/7 background guardian monitoring.
  Future<void> setGuardianEnabled(bool enabled, {String vehicleName = 'Chery Tiggo 7 PHEV'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuardianPrefKey, enabled);
    if (!Platform.isAndroid) return;
    try {
      if (enabled) {
        await _channel.invokeMethod('startGuardianService', {'vehicleName': vehicleName});
      } else {
        await _channel.invokeMethod('stopGuardianService');
      }
    } catch (_) {}
  }

  /// Checks if the native Guardian foreground service is running.
  Future<bool> isGuardianRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      return (await _channel.invokeMethod<bool>('isGuardianRunning')) ?? false;
    } catch (_) {
      return false;
    }
  }
}
