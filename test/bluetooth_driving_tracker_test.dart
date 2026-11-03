import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_telemetry.dart';
import 'package:tiggomate_app/src/service/auto_trip_and_charge_service.dart';
import 'package:tiggomate_app/src/service/bluetooth_driving_tracker_service.dart';
import 'package:tiggomate_app/src/service/phone_parking_location.dart';
import 'package:tiggomate_app/src/ui/trips_logbook_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AutoTripAndChargeService.instance.resetForTesting();
    BluetoothDrivingTrackerService.instance.resetForTesting();
  });

  group('BluetoothDrivingTrackerService Tests', () {
    test('Initializes with default configuration', () async {
      final service = BluetoothDrivingTrackerService.instance;
      await service.init();

      expect(service.isEnabled, isTrue);
      expect(service.isCarConnected, isFalse);
      expect(service.connectedCarName, isNull);
      expect(service.customCarBtName, isNull);
    });

    test('Can enable/disable and persist setting', () async {
      final service = BluetoothDrivingTrackerService.instance;
      await service.init();

      await service.setEnabled(false);
      expect(service.isEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tm_enable_bluetooth_tracking'), isFalse);

      await service.setEnabled(true);
      expect(service.isEnabled, isTrue);
      expect(prefs.getBool('tm_enable_bluetooth_tracking'), isTrue);
    });

    test('Can set and clear custom car Bluetooth name', () async {
      final service = BluetoothDrivingTrackerService.instance;
      await service.init();

      await service.setCustomCarBtName('CHERY_TIGGO7_BT');
      expect(service.customCarBtName, 'CHERY_TIGGO7_BT');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tm_car_bluetooth_name'), 'CHERY_TIGGO7_BT');

      await service.setCustomCarBtName(null);
      expect(service.customCarBtName, isNull);
      expect(prefs.containsKey('tm_car_bluetooth_name'), isFalse);
    });

    test('Car connection updates state and notifications', () async {
      final service = BluetoothDrivingTrackerService.instance;
      await service.init();

      await service.simulateConnectForTesting('Chery Tiggo 7 Pro');
      expect(service.isCarConnected, isTrue);
      expect(service.connectedCarName, 'Chery Tiggo 7 Pro');
    });

    test('Car disconnect immediately finalizes in-flight trip and captures parking', () async {
      final btService = BluetoothDrivingTrackerService.instance;
      final tripService = AutoTripAndChargeService.instance;
      await btService.init();

      // Simulate a trip in progress
      final startTime = DateTime(2026, 11, 4, 10, 0, 0);
      tripService.processTelemetry(
        VehicleTelemetry(
          odometerKm: 6000,
          batteryPct: 85,
          speedKmH: 0.0,
          isBound: true,
          lastUpdated: startTime,
        ),
      );
      tripService.processTelemetry(
        VehicleTelemetry(
          odometerKm: 6010,
          batteryPct: 80,
          speedKmH: 50.0,
          isBound: true,
          lastUpdated: startTime.add(const Duration(minutes: 10)),
        ),
      );

      expect(tripService.isTripActive, isTrue);

      // Pre-save a mock parking location to simulate GPS capture
      final parked = PhoneParkedLocation(
        latitude: 3.1390,
        longitude: 101.6869,
        timestamp: DateTime.now(),
        address: 'Mid Valley Megamall, Kuala Lumpur',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tm_phone_parked_location_v1', jsonEncode(parked.toJson()));

      // Vehicle engine turns off -> Bluetooth disconnects
      await btService.simulateDisconnectForTesting('Chery Tiggo 7 Pro');

      expect(btService.isCarConnected, isFalse);
      expect(tripService.isTripActive, isFalse);

      final rawTrips = prefs.getString('tm_logged_trips_v2');
      expect(rawTrips, isNotNull);
      final List<dynamic> list = jsonDecode(rawTrips!);
      expect(list.isNotEmpty, isTrue);

      final saved = TripRecord.fromJson(list.first as Map<String, dynamic>);
      expect(saved.distanceKm, 10.0);
      expect(saved.title, contains('Mid Valley Megamall, Kuala Lumpur'));
    });
  });
}
