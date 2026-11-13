import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../carlinko/vehicle_telemetry.dart';
import '../ui/app_notification.dart';
import 'smart_wrist_key_service.dart';

const String _kChannelId = 'tm_vehicle_alerts';
const String _kChannelName = 'Vehicle Alerts';
const String _kChannelDesc = 'Door and 12V battery alerts from your car';

const String _kLiveActivityChannelId = 'tm_live_activity';
const String _kLiveActivityChannelName = 'Live Activity & Charging';
const String _kLiveActivityChannelDesc = 'Persistent status during active charging and cabin climate pre-conditioning';

const String _kDoorOpenFlagKey = 'tm_alert_door_open_flag';
const String _kDoorLockedFlagKey = 'tm_alert_door_locked_flag';
const String _kIsChargingFlagKey = 'tm_alert_is_charging_flag';
const String _kLowVoltFlagKey = 'tm_alert_low_volt_flag';
const String _kWasDrivingFlagKey = 'tm_alert_was_driving_flag';

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
      final androidPlatform = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlatform?.createNotificationChannel(const AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        description: _kChannelDesc,
        importance: Importance.high,
      ));
      await androidPlatform?.createNotificationChannel(const AndroidNotificationChannel(
        _kLiveActivityChannelId,
        _kLiveActivityChannelName,
        description: _kLiveActivityChannelDesc,
        importance: Importance.low,
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
    SmartWristKeyService.updateWristKey(t);
    final prefs = await SharedPreferences.getInstance();

    final rawPlate = prefs.getString('tm_car_plate') ?? 'VRT 3342';
    final cleanPlate = rawPlate.replaceAll(' ', '');
    const carModel = 'TIGGO 7 CSH';

    // 1. Door Ajar Alert (when door opens while parked)
    final wasDoorOpen = prefs.getBool(_kDoorOpenFlagKey);
    if (wasDoorOpen != null && t.doorsOpen && !wasDoorOpen && t.isParked) {
      await _raiseAlert(
        id: 1001,
        title: 'TiggoMate.',
        message: '$cleanPlate door ajar, check in time',
        icon: Icons.sensor_door_outlined,
      );
    }
    if (t.doorsOpen != wasDoorOpen) {
      await prefs.setBool(_kDoorOpenFlagKey, t.doorsOpen);
    }

    // 2. Door Lock / Unlock Alerts (matching CarLinko)
    final wasDoorLocked = prefs.getBool(_kDoorLockedFlagKey);
    if (wasDoorLocked != null) {
      if (!t.doorsLocked && wasDoorLocked) {
        await _raiseAlert(
          id: 1005,
          title: 'TiggoMate.',
          message: '$cleanPlate door unlocked',
          icon: Icons.lock_open_rounded,
        );
      } else if (t.doorsLocked && !wasDoorLocked) {
        await _raiseAlert(
          id: 1006,
          title: 'TiggoMate.',
          message: '$cleanPlate door locked',
          icon: Icons.lock_outline_rounded,
        );
      }
    }
    if (t.doorsLocked != wasDoorLocked) {
      await prefs.setBool(_kDoorLockedFlagKey, t.doorsLocked);
    }

    // 3. EV Charging State Transitions (matching CarLinko)
    final wasCharging = prefs.getBool(_kIsChargingFlagKey);
    if (wasCharging != null) {
      if (t.isCharging && !wasCharging) {
        final batteryStr = t.batteryPct > 0 ? '${t.batteryPct}%' : '';
        await _raiseAlert(
          id: 1007,
          title: 'TiggoMate.',
          message: 'Your car $carModel $cleanPlate has started charging.${batteryStr.isNotEmpty ? ' Battery level: $batteryStr.' : ''}',
          icon: Icons.bolt_rounded,
        );
      } else if (!t.isCharging && wasCharging) {
        final batteryStr = t.batteryPct > 0 ? '${t.batteryPct}%' : '';
        final isFull = t.batteryPct >= 99;
        await _raiseAlert(
          id: 1008,
          title: 'TiggoMate.',
          message: isFull
              ? 'Your car $carModel $cleanPlate charging completed. Battery level: 100%.'
              : 'Your car $carModel $cleanPlate charging stopped.${batteryStr.isNotEmpty ? ' Battery level: $batteryStr.' : ''}',
          icon: Icons.battery_charging_full_rounded,
        );
      }
    }
    if (t.isCharging != wasCharging) {
      await prefs.setBool(_kIsChargingFlagKey, t.isCharging);
    }

    // 4. Post-Parking Security Check (doors unlocked or windows open when parked)
    final wasDriving = prefs.getBool(_kWasDrivingFlagKey) ?? false;
    final isDrivingNow = !t.isParked || t.speedKmH > 5;
    if (wasDriving && !isDrivingNow) {
      // Just parked: check if car is left unsecured
      if (!t.doorsLocked || t.windowsOpen) {
        final List<String> unsecuredParts = [];
        if (!t.doorsLocked) unsecuredParts.add('doors unlocked');
        if (t.windowsOpen) unsecuredParts.add('windows open');
        await _raiseAlert(
          id: 1010,
          title: '⚠️ Security Notice: $cleanPlate',
          message: 'Vehicle parked with ${unsecuredParts.join(" and ")}. Tap to review and secure.',
          icon: Icons.shield_outlined,
        );
      }
    }
    await prefs.setBool(_kWasDrivingFlagKey, isDrivingNow);

    // 5. 12V Aux Battery Monitor
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

    // 6. Persistent Live Activity Notifications (Charging & Climate Pre-cooling)
    await _handleLiveOngoingNotifications(t, cleanPlate: cleanPlate, carModel: carModel);

    // Local Smart Perimeter Guard monitoring
    final localFenceStr = prefs.getString('tm_local_geofence');
    if (localFenceStr != null && localFenceStr.isNotEmpty && t.hasLocation && t.latitude != 0.0 && t.longitude != 0.0) {
      try {
        final fence = json.decode(localFenceStr);
        if (fence is Map<String, dynamic> && (fence['status'] == 1 || fence['status'] == '1')) {
          final fenceLat = (fence['lat'] as num).toDouble();
          final fenceLng = (fence['lng'] as num).toDouble();
          final radius = (fence['radius'] as num).toDouble();
          final alarmType = (fence['alarmType'] as num?)?.toInt() ?? 2; // 2 = Exit, 1 = Entry
          final fenceName = fence['name']?.toString() ?? 'Perimeter';

          final dist = Geolocator.distanceBetween(t.latitude, t.longitude, fenceLat, fenceLng);
          final isOutside = dist > radius;
          final wasOutside = prefs.getBool('tm_fence_was_outside') ?? false;

          if (alarmType == 2) {
            // Exit perimeter alarm
            if (isOutside && !wasOutside) {
              await _raiseAlert(
                id: 1003,
                title: 'Perimeter Breach Detected',
                message: 'Vehicle has exited $fenceName (${dist.round()}m from center).',
                icon: Icons.security_update_warning_outlined,
              );
              await prefs.setBool('tm_fence_was_outside', true);
            } else if (!isOutside && wasOutside) {
              await prefs.setBool('tm_fence_was_outside', false);
            }
          } else if (alarmType == 1) {
            // Entry perimeter alarm
            if (!isOutside && wasOutside) {
              await _raiseAlert(
                id: 1004,
                title: 'Perimeter Entry Detected',
                message: 'Vehicle has entered $fenceName (${dist.round()}m from center).',
                icon: Icons.shield_outlined,
              );
              await prefs.setBool('tm_fence_was_outside', false);
            } else if (isOutside && !wasOutside) {
              await prefs.setBool('tm_fence_was_outside', true);
            }
          }
        }
      } catch (e) {
        debugPrint('VehicleAlertNotifier: local geofence check error: $e');
      }
    }
  }

  /// Public method to raise an immediate system status bar notification
  /// and record it in the in-app alert log. Callable from any isolate or background worker.
  static Future<void> raiseSystemNotification({
    required int id,
    required String title,
    required String message,
    required IconData icon,
    NotificationType type = NotificationType.warning,
  }) => _raiseAlert(id: id, title: title, message: message, icon: icon, type: type);

  static Future<void> _raiseAlert({
    required int id,
    required String title,
    required String message,
    required IconData icon,
    NotificationType type = NotificationType.warning,
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
            visibility: NotificationVisibility.public,
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

  static Future<void> _handleLiveOngoingNotifications(
    VehicleTelemetry t, {
    required String cleanPlate,
    required String carModel,
  }) async {
    await _ensurePlugin();

    // A. Active EV Charging Notification (Ongoing status card)
    if (t.isCharging) {
      final powerStr = t.chargePowerKw > 0 ? '${t.chargePowerKw.toStringAsFixed(1)} kW' : 'AC Charging';
      final remainStr = (t.chargeRemainMin != null && t.chargeRemainMin! > 0 && t.chargeRemainMin! < 1000)
          ? ' • ~${t.chargeRemainMin} mins to full'
          : '';
      final socStr = t.batteryPct > 0 ? '${t.batteryPct}%' : 'Charging';

      try {
        await _plugin.show(
          2001,
          '⚡ Charging $cleanPlate ($socStr)',
          '$powerStr$remainStr • Tiggo 7 PHEV connected',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _kLiveActivityChannelId,
              _kLiveActivityChannelName,
              channelDescription: _kLiveActivityChannelDesc,
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              showWhen: true,
            ),
          ),
        );
      } catch (e) {
        debugPrint('VehicleAlertNotifier: ongoing charging notification error: $e');
      }
    } else {
      try {
        await _plugin.cancel(2001);
      } catch (_) {}
    }

    // B. Active Climate Pre-Conditioning Notification (Ongoing status card)
    if (t.acOn) {
      final tempStr = t.acTemp > 0 ? '${t.acTemp}°C target' : 'Target: 22°C';
      try {
        await _plugin.show(
          2002,
          '❄️ Climate Pre-cooling Active • $cleanPlate',
          'A/C active ($tempStr) • Auto timer running',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _kLiveActivityChannelId,
              _kLiveActivityChannelName,
              channelDescription: _kLiveActivityChannelDesc,
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              showWhen: true,
            ),
          ),
        );
      } catch (e) {
        debugPrint('VehicleAlertNotifier: ongoing climate notification error: $e');
      }
    } else {
      try {
        await _plugin.cancel(2002);
      } catch (_) {}
    }
  }
}
