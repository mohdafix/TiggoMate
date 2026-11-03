import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../carlinko/vehicle_repository.dart';
import '../ui/app_notification.dart';
import 'auto_trip_and_charge_service.dart';
import 'phone_parking_location.dart';

/// Service managing Bluetooth-triggered automatic drive tracking and parking location capture.
///
/// When the phone connects to the Chery Tiggo / CarLinko Bluetooth:
/// - Automatically engages the Android Foreground Service to prevent OS Doze mode
/// - Starts high-frequency CAN-bus telematics polling while driving
///
/// When the phone disconnects from the car Bluetooth (engine shut off):
/// - Instantly captures and saves the parking GPS location
/// - Immediately finalizes and saves the active trip in the Logbook
/// - Shuts down the background service to preserve phone battery
class BluetoothDrivingTrackerService extends ChangeNotifier {
  static final BluetoothDrivingTrackerService instance = BluetoothDrivingTrackerService._internal();

  BluetoothDrivingTrackerService._internal();

  static const MethodChannel _channel = MethodChannel('com.tiggomate/bluetooth_tracker');

  static const String _kEnabledKey = 'tm_enable_bluetooth_tracking';
  static const String _kCustomBtNameKey = 'tm_car_bluetooth_name';

  bool _isCarConnected = false;
  String? _connectedCarName;
  Timer? _drivingPollTimer;
  bool _initialized = false;
  bool _isEnabled = true;
  String? _customCarBtName;

  bool get isCarConnected => _isCarConnected;
  String? get connectedCarName => _connectedCarName;
  bool get isEnabled => _isEnabled;
  String? get customCarBtName => _customCarBtName;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_kEnabledKey) ?? true;
      _customCarBtName = prefs.getString(_kCustomBtNameKey);

      _channel.setMethodCallHandler(_handleNativeCall);
    } catch (e) {
      debugPrint('BluetoothDrivingTrackerService init error: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, enabled);
    if (!enabled && _isCarConnected) {
      await stopForegroundTracking();
    }
    notifyListeners();
  }

  Future<void> setCustomCarBtName(String? name) async {
    _customCarBtName = name?.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_customCarBtName != null && _customCarBtName!.isNotEmpty) {
      await prefs.setString(_kCustomBtNameKey, _customCarBtName!);
    } else {
      await prefs.remove(_kCustomBtNameKey);
    }
    notifyListeners();
  }

  Future<List<Map<String, String>>> getPairedDevices() async {
    try {
      final List<dynamic>? list = await _channel.invokeMethod('getPairedDevices');
      if (list == null) return [];
      return list.map((item) {
        final map = item as Map<dynamic, dynamic>;
        return {
          'name': map['name']?.toString() ?? 'Unknown Device',
          'address': map['address']?.toString() ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> startForegroundTracking({String vehicleName = 'Chery Tiggo'}) async {
    try {
      await _channel.invokeMethod('startForegroundService', {'vehicleName': vehicleName});
    } catch (e) {
      debugPrint('startForegroundTracking error: $e');
    }
  }

  Future<void> stopForegroundTracking() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (e) {
      debugPrint('stopForegroundTracking error: $e');
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (!_isEnabled) return;

    switch (call.method) {
      case 'onCarConnected':
        final args = call.arguments is Map ? call.arguments as Map<dynamic, dynamic> : null;
        final name = args?['name']?.toString() ?? 'Chery Tiggo';
        await _onConnected(name);
        break;

      case 'onCarDisconnected':
        final args = call.arguments is Map ? call.arguments as Map<dynamic, dynamic> : null;
        final name = args?['name']?.toString() ?? 'Chery Tiggo';
        await _onDisconnected(name);
        break;
    }
  }

  Future<void> _onConnected(String name) async {
    _isCarConnected = true;
    _connectedCarName = name;
    notifyListeners();

    debugPrint('🚗 Car Bluetooth Connected: $name -> Starting live driving telematics stream');

    // Post Alert Notification
    VehicleAlertsManager.instance.addAlert(
      VehicleAlertItem(
        id: 'bt_connect_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Vehicle Connected',
        message: 'Connected to $name • Live telematics and auto-trip tracking active',
        timestamp: DateTime.now(),
        type: NotificationType.info,
        icon: Icons.bluetooth_connected_rounded,
        isRead: false,
      ),
    );

    // Poll live telematics every 12 seconds while vehicle is running
    _drivingPollTimer?.cancel();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _drivingPollTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
        try {
          if (AppVehicleRepository.instance.isVehicleBound) {
            await AppVehicleRepository.instance.liveRepo.refresh();
          }
        } catch (e) {
          debugPrint('Driving poll error: $e');
        }
      });
    }
  }

  Future<void> _onDisconnected(String name) async {
    _isCarConnected = false;
    _drivingPollTimer?.cancel();
    _drivingPollTimer = null;
    notifyListeners();

    debugPrint('🅿️ Car Bluetooth Disconnected: $name -> Capturing parking location & finalizing trip');

    // 1. Immediately capture phone GPS and reverse-geocode address
    try {
      await PhoneParkingLocationService.captureNow();
    } catch (_) {}

    final phoneParked = await PhoneParkingLocationService.loadLast();
    final destinationAddress = phoneParked?.address;

    // 2. Immediately finalize in-flight trip without waiting for 3-minute idle timeout
    try {
      await AutoTripAndChargeService.instance.finalizeActiveTripNow(
        destinationAddress: destinationAddress,
      );
    } catch (e) {
      debugPrint('Error finalizing trip on disconnect: $e');
    }

    // 3. Post Parked Location Notification
    final now = DateTime.now();
    final addressText = destinationAddress != null && destinationAddress.isNotEmpty
        ? 'Parked at: $destinationAddress'
        : 'Car parked • Location saved';

    VehicleAlertsManager.instance.addAlert(
      VehicleAlertItem(
        id: 'bt_disconnect_${now.millisecondsSinceEpoch}',
        title: 'Vehicle Parked',
        message: '$addressText • Trip recorded in logbook',
        timestamp: now,
        type: NotificationType.success,
        icon: Icons.local_parking_rounded,
        isRead: false,
      ),
    );
  }

  @visibleForTesting
  void resetForTesting() {
    _drivingPollTimer?.cancel();
    _drivingPollTimer = null;
    _isCarConnected = false;
    _connectedCarName = null;
  }

  @visibleForTesting
  Future<void> simulateConnectForTesting(String name) async {
    await _onConnected(name);
  }

  @visibleForTesting
  Future<void> simulateDisconnectForTesting(String name) async {
    await _onDisconnected(name);
  }

  @override
  void dispose() {
    _drivingPollTimer?.cancel();
    super.dispose();
  }
}
