import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../carlinko/vehicle_telemetry.dart';
import '../ui/app_notification.dart';

const String _kChannelId = 'tm_vehicle_alerts';
const String _kChannelName = 'Vehicle Alerts';
const String _kChannelDesc = 'Door and 12V battery alerts from your car';

const String _kDoorOpenFlagKey = 'tm_alert_door_open_flag';
const String _kLowVoltFlagKey = 'tm_alert_low_volt_flag';

const double _kLowVoltThreshold = 12.0;
// Hysteresis above the trigger threshold so a voltage hovering right at
// 12.0V doesn't re-fire the alert on every poll.
const double _kLowVoltRecoverThreshold = 12.2;

/// Detects door-ajar and low-12V-aux-battery conditions from live telemetry
/// and raises both a system notification (visible even with TiggoMate
/// closed, mirroring CarLinko's own "door ajar" vehicle alert) and an
/// in-app VehicleAlertsManager entry. Safe to call from the foreground
/// isolate or the background WorkManager isolate (LocationTrackerService).
class VehicleAlertNotifier {
  VehicleAlertNotifier._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _pluginReady = false;

  static Future<void> _ensurePlugin() async {
    if (_pluginReady) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    try {
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        description: _kChannelDesc,
        importance: Importance.high,
      ));
      _pluginReady = true;
    } catch (e) {
      debugPrint('VehicleAlertNotifier: plugin init failed: $e');
    }
  }

  /// Call once from the foreground app at startup to prompt for the
  /// Android 13+ POST_NOTIFICATIONS runtime permission.
  static Future<void> requestPermission() async {
    await _ensurePlugin();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('VehicleAlertNotifier: permission request failed: $e');
    }
  }

  /// Checks the latest telemetry for door-ajar / low-12V conditions and
  /// raises alerts on state transitions (not on every poll), with
  /// hysteresis on the voltage check so it doesn't flap at the threshold.
  static Future<void> checkAndNotify(VehicleTelemetry t) async {
    if (!t.isBound) return;
    final prefs = await SharedPreferences.getInstance();

    final wasDoorOpen = prefs.getBool(_kDoorOpenFlagKey) ?? false;
    if (t.doorsOpen && !wasDoorOpen && t.isParked) {
      await _raiseAlert(
        id: 1001,
        title: 'Door Ajar',
        message: 'A door is open while parked. Check if it needs closing.',
        icon: Icons.sensor_door_outlined,
      );
    }
    if (t.doorsOpen != wasDoorOpen) {
      await prefs.setBool(_kDoorOpenFlagKey, t.doorsOpen);
    }

    if (t.volt12 > 0) {
      final wasLow = prefs.getBool(_kLowVoltFlagKey) ?? false;
      if (!wasLow && t.volt12 < _kLowVoltThreshold) {
        await _raiseAlert(
          id: 1002,
          title: 'Low 12V Battery',
          message:
              '12V aux battery at ${t.volt12.toStringAsFixed(2)}V, below ${_kLowVoltThreshold.toStringAsFixed(1)}V. A short drive will recharge it.',
          icon: Icons.battery_alert_outlined,
        );
        await prefs.setBool(_kLowVoltFlagKey, true);
      } else if (wasLow && t.volt12 >= _kLowVoltRecoverThreshold) {
        await prefs.setBool(_kLowVoltFlagKey, false);
      }
    }
  }

  static Future<void> _raiseAlert({
    required int id,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    await _ensurePlugin();
    try {
      await _plugin.show(
        id,
        title,
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('VehicleAlertNotifier: show failed: $e');
    }

    try {
      // Background isolates get a fresh VehicleAlertsManager singleton, so
      // load its persisted history before appending, or addAlert's persist
      // would overwrite it with just this one entry.
      await VehicleAlertsManager.instance.init();
      await VehicleAlertsManager.instance.addAlert(
        VehicleAlertItem(
          id: '$id-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          message: message,
          timestamp: DateTime.now(),
          type: NotificationType.warning,
          icon: icon,
        ),
      );
    } catch (e) {
      debugPrint('VehicleAlertNotifier: in-app alert record failed: $e');
    }
  }
}
