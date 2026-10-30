import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../carlinko/vehicle_telemetry.dart';

/// Numbers shown on the home screen widget. [unknown] means there is no reading,
/// and both the sheet preview and the native widget render it as "--".
class HomeWidgetValues {
  static const int unknown = -1;

  final int batterySoc;
  final int batteryRange;
  final int fuelLevel;
  final int fuelRange;
  final int totalRange;

  const HomeWidgetValues({
    required this.batterySoc,
    required this.batteryRange,
    required this.fuelLevel,
    required this.fuelRange,
    required this.totalRange,
  });

  factory HomeWidgetValues.fromTelemetry(VehicleTelemetry telemetry, {required bool isBound}) {
    final hasFuelRange = isBound && telemetry.fuelRangeKm > 0;
    return HomeWidgetValues(
      batterySoc: isBound ? telemetry.batteryPct : unknown,
      batteryRange: isBound ? telemetry.electricRangeKm : unknown,
      fuelLevel: hasFuelRange ? ((telemetry.fuelRangeKm / 838.0) * 100).round().clamp(0, 100) : unknown,
      fuelRange: hasFuelRange ? telemetry.fuelRangeKm : unknown,
      totalRange: hasFuelRange ? telemetry.totalRangeKm : unknown,
    );
  }

  static String format(int value) => value < 0 ? '--' : '$value';
}

/// Service coordinating Android Native Home Screen Widgets & App Shortcuts
/// via MethodChannel 'com.tiggomate/quick_actions'.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const MethodChannel _channel = MethodChannel('com.tiggomate/quick_actions');

  final StreamController<String> _actionController = StreamController<String>.broadcast();

  /// Stream of incoming quick action URIs triggered from native shortcuts or widget buttons.
  Stream<String> get onQuickAction => _actionController.stream;

  bool _initialized = false;

  /// Initializes listening for native quick action callbacks.
  void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickAction') {
        final uri = call.arguments as String?;
        if (uri != null && uri.isNotEmpty) {
          _actionController.add(uri);
        }
      }
    });

    // Check if app was started with an initial action
    getInitialAction().then((uri) {
      if (uri != null && uri.isNotEmpty) {
        _actionController.add(uri);
      }
    }).catchError((dynamic e) {
      debugPrint('[HomeWidgetService] Failed to get initial action: $e');
    });
  }

  /// Gets any pending action URI if app was launched via shortcut or widget click.
  Future<String?> getInitialAction() async {
    try {
      final action = await _channel.invokeMethod<String>('getInitialAction');
      return action;
    } on PlatformException catch (e) {
      debugPrint('[HomeWidgetService] PlatformException in getInitialAction: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Pushes updated Chery Tiggo 7 PHEV telemetry into Android Native SharedPreferences
  /// and triggers RemoteViews update for all installed home screen widgets.
  Future<bool> syncWidgetTelemetry({
    String vehicleName = 'Tiggo 7 PHEV',
    bool isBound = false,
    int batterySoc = HomeWidgetValues.unknown,
    int batteryRange = HomeWidgetValues.unknown,
    int fuelLevel = HomeWidgetValues.unknown,
    int fuelRange = HomeWidgetValues.unknown,
    int totalRange = HomeWidgetValues.unknown,
    bool isLocked = true,
    bool isCharging = false,
    bool isClimateOn = false,
  }) async {
    try {
      final success = await _channel.invokeMethod<bool>('updateWidgetData', {
        'vehicle_name': vehicleName,
        'is_bound': isBound,
        'battery_soc': batterySoc,
        'battery_range': batteryRange,
        'fuel_level': fuelLevel,
        'fuel_range': fuelRange,
        'total_range': totalRange,
        'is_locked': isLocked,
        'is_charging': isCharging,
        'is_climate_on': isClimateOn,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[HomeWidgetService] Error syncing widget data: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  void dispose() {
    _actionController.close();
  }
}
