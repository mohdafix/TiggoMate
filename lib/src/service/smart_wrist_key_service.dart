import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';

const String kWristKeyChannelId = 'tm_wrist_key';
const String kWristKeyChannelName = 'Smartwatch & Wrist Quick Key';
const String kWristKeyChannelDesc = 'Interactive vehicle controls (Unlock, Lock, Climate, Trunk) for Huawei, Wear OS, and smartwatch notification trays';

const int kWristKeyNotificationId = 3001;
const int kWristKeyFeedbackNotificationId = 3002;
const String kWristKeyEnabledPrefKey = 'tm_smartwatch_key_enabled';

@pragma('vm:entry-point')
void wristKeyBackgroundNotificationHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  final actionId = response.actionId;
  if (actionId != null && actionId.startsWith('wrist_')) {
    await SmartWristKeyService.handleWristAction(actionId);
  }
}

/// Provides persistent, zero-latency interactive vehicle action cards
/// directly mirrored to Huawei Watch Fit / GT, Wear OS, and Android notification trays.
class SmartWristKeyService {
  SmartWristKeyService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _enabled = true;
  static VehicleTelemetry? _lastTelemetry;

  static bool get isEnabled => _enabled;

  /// Initializes notification channels and action tap handlers
  static Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(kWristKeyEnabledPrefKey) ?? true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          final actionId = response.actionId;
          if (actionId != null && actionId.startsWith('wrist_')) {
            await handleWristAction(actionId);
          }
        },
        onDidReceiveBackgroundNotificationResponse: wristKeyBackgroundNotificationHandler,
      );

      final androidPlatform = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlatform?.createNotificationChannel(
        const AndroidNotificationChannel(
          kWristKeyChannelId,
          kWristKeyChannelName,
          description: kWristKeyChannelDesc,
          importance: Importance.low,
          enableVibration: false,
          showBadge: false,
        ),
      );

      await androidPlatform?.createNotificationChannel(
        const AndroidNotificationChannel(
          'tm_wrist_feedback',
          'Wrist Key Feedback',
          description: 'Haptic confirmation buzz when an action executes from your watch',
          importance: Importance.high,
          enableVibration: true,
          showBadge: true,
        ),
      );

      _initialized = true;
    } catch (e) {
      debugPrint('SmartWristKeyService: init error: $e');
    }
  }

  /// Toggles whether the persistent wrist key is displayed
  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kWristKeyEnabledPrefKey, enabled);

    if (enabled) {
      if (_lastTelemetry != null) {
        await updateWristKey(_lastTelemetry!);
      }
    } else {
      await cancelWristKey();
    }
  }

  /// Updates the watch notification card with latest battery %, lock state, and action buttons
  static Future<void> updateWristKey(VehicleTelemetry telemetry) async {
    _lastTelemetry = telemetry;
    if (!_enabled) return;
    await init();

    final prefs = await SharedPreferences.getInstance();
    final carPlate = prefs.getString('tm_car_plate') ?? 'VRT 3342';
    final cleanPlate = carPlate.replaceAll(' ', '');

    final soc = telemetry.batteryPct > 0 ? telemetry.batteryPct : 78;
    final evKm = telemetry.electricRangeKm > 0 ? telemetry.electricRangeKm : (soc * 0.85).round();
    final totalKm = telemetry.totalRangeKm > 0 ? telemetry.totalRangeKm : (evKm + telemetry.fuelRangeKm);

    final statusText = telemetry.doorsOpen
        ? '⚠️ DOORS AJAR'
        : (telemetry.isParked ? 'Secured & Parked' : 'Vehicle in Motion');

    final bodyText = '⚡ $soc% ($evKm km EV / $totalKm km total) • 12V: ${telemetry.volt12 > 0 ? telemetry.volt12.toStringAsFixed(1) : "12.8"}V';

    try {
      await _plugin.show(
        kWristKeyNotificationId,
        '🚗 $cleanPlate • $statusText',
        bodyText,
        NotificationDetails(
          android: AndroidNotificationDetails(
            kWristKeyChannelId,
            kWristKeyChannelName,
            channelDescription: kWristKeyChannelDesc,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
            category: AndroidNotificationCategory.status,
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'wrist_unlock',
                '🔓 Unlock',
                showsUserInterface: false,
                cancelNotification: false,
              ),
              AndroidNotificationAction(
                'wrist_lock',
                '🔒 Lock',
                showsUserInterface: false,
                cancelNotification: false,
              ),
              AndroidNotificationAction(
                'wrist_ac',
                '❄️ A/C 22°',
                showsUserInterface: false,
                cancelNotification: false,
              ),
              AndroidNotificationAction(
                'wrist_trunk',
                '🚗 Trunk',
                showsUserInterface: false,
                cancelNotification: false,
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('SmartWristKeyService: failed to display wrist key: $e');
    }
  }

  /// Cancels the persistent wrist card
  static Future<void> cancelWristKey() async {
    try {
      await _plugin.cancel(kWristKeyNotificationId);
    } catch (_) {}
  }

  /// Executes remote opcode when a button is tapped on Huawei Watch Fit / notification
  static Future<void> handleWristAction(String actionId) async {
    HapticFeedback.heavyImpact();

    String opcode;
    String actionName;
    switch (actionId) {
      case 'wrist_unlock':
        opcode = CarLinkoOpcodes.unlock;
        actionName = 'Unlock Doors';
        break;
      case 'wrist_lock':
        opcode = CarLinkoOpcodes.lock;
        actionName = 'Lock Doors';
        break;
      case 'wrist_ac':
        opcode = CarLinkoOpcodes.acOn;
        actionName = 'Pre-cool Cabin (22°C)';
        break;
      case 'wrist_trunk':
        opcode = CarLinkoOpcodes.trunkOpen;
        actionName = 'Open Trunk';
        break;
      default:
        return;
    }

    // Try to ensure session is available
    if (!AppVehicleRepository.instance.isVehicleBound) {
      await AppVehicleRepository.instance.restoreSession();
    }

    // Execute remote command
    final result = await AppVehicleRepository.instance.sendRemoteCommandWithResult(opcode);

    // Play native acoustic chime
    try {
      const MethodChannel('com.tiggomate/speech').invokeMethod('playChime', {
        'type': result.success ? 'success' : 'error',
      });
    } catch (_) {}

    // Send instant haptic feedback notification to the watch
    try {
      await _plugin.show(
        kWristKeyFeedbackNotificationId,
        result.success ? '✓ $actionName' : '⚠️ $actionName Failed',
        result.success
            ? 'Command sent to Chery T-Box. Vehicle executing.'
            : (result.message != null && result.message!.isNotEmpty ? result.message! : 'Please check vehicle connection.'),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tm_wrist_feedback',
            'Wrist Key Feedback',
            channelDescription: 'Haptic confirmation buzz when an action executes from your watch',
            importance: Importance.high,
            priority: Priority.high,
            autoCancel: true,
            timeoutAfter: 4000,
          ),
        ),
      );
    } catch (e) {
      debugPrint('SmartWristKeyService: feedback notification error: $e');
    }

    // Refresh wrist key notification
    if (_lastTelemetry != null) {
      await updateWristKey(_lastTelemetry!);
    }
  }
}
