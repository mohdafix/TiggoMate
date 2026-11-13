import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_telemetry.dart';
import 'package:tiggomate_app/src/service/smart_wrist_key_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      kWristKeyEnabledPrefKey: true,
      'tm_car_plate': 'VRT 3342',
    });
  });

  group('SmartWristKeyService Tests', () {
    test('Initialization loads enabled preference correctly', () async {
      await SmartWristKeyService.init();
      expect(SmartWristKeyService.isEnabled, isTrue);

      await SmartWristKeyService.setEnabled(false);
      expect(SmartWristKeyService.isEnabled, isFalse);

      await SmartWristKeyService.setEnabled(true);
      expect(SmartWristKeyService.isEnabled, isTrue);
    });

    test('updateWristKey accepts live vehicle telemetry without errors', () async {
      final telemetry = VehicleTelemetry(
        lastUpdated: DateTime.now(),
        batteryPct: 85,
        electricRangeKm: 80,
        fuelCapacityPct: 60,
        fuelRangeKm: 480,
        totalRangeKm: 560,
        doorsOpen: false,
        isParked: true,
        volt12: 12.85,
      );

      // Should run cleanly without throwing
      await expectLater(
        SmartWristKeyService.updateWristKey(telemetry),
        completes,
      );
    });
  });
}
