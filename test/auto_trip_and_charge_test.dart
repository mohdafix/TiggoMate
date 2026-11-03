import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_telemetry.dart';
import 'package:tiggomate_app/src/service/auto_trip_and_charge_service.dart';
import 'package:tiggomate_app/src/ui/trips_logbook_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AutoTripAndChargeService.instance.resetForTesting();
  });

  group('AutoTripAndChargeService Automated Trip & Charging Tests', () {
    test('Bridges short 60-second stop and finalizes trip after 3 minutes parked', () async {
      final service = AutoTripAndChargeService.instance;
      final startTime = DateTime(2026, 11, 3, 8, 0, 0);

      // Frame 1: Initial parked frame
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 5000,
          batteryPct: 80,
          speedKmH: 0.0,
          isBound: true,
          lastUpdated: startTime,
        ),
      );

      // Frame 2: Driving 5 km in 5 minutes (speed 60 km/h)
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 5005,
          batteryPct: 78,
          speedKmH: 60.0,
          isBound: true,
          lastUpdated: startTime.add(const Duration(minutes: 5)),
        ),
      );

      expect(service.isTripActive, isTrue);
      expect(service.activeTrip!.startOdo, 5000);
      expect(service.activeTrip!.lastOdo, 5005);

      // Frame 3: Stopped at red light for 60 seconds (odo unchanged)
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 5005,
          batteryPct: 78,
          speedKmH: 0.0,
          isBound: true,
          lastUpdated: startTime.add(const Duration(minutes: 6)),
        ),
      );

      // Trip should still be active because 60s < 180s (TRIP_GAP)
      expect(service.isTripActive, isTrue);

      // Frame 4: Resumed driving for another 5 km
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 5010,
          batteryPct: 75,
          speedKmH: 50.0,
          isBound: true,
          lastUpdated: startTime.add(const Duration(minutes: 12)),
        ),
      );

      expect(service.activeTrip!.lastOdo, 5010);

      // Frame 5: Parked at destination for 4 minutes (240s > 180s TRIP_GAP)
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 5010,
          batteryPct: 75,
          speedKmH: 0.0,
          isBound: true,
          lastUpdated: startTime.add(const Duration(minutes: 16)),
        ),
      );

      // Trip should now be closed and finalized
      expect(service.isTripActive, isFalse);

      // Verify trip was persisted in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tm_logged_trips_v2');
      expect(raw, isNotNull);
      final List<dynamic> list = jsonDecode(raw!);
      expect(list.isNotEmpty, isTrue);

      final saved = TripRecord.fromJson(list.first as Map<String, dynamic>);
      expect(saved.distanceKm, 10.0); // 5010 - 5000
      expect(saved.electricKwh, greaterThan(0.0));
    });

    test('Rejects cloud catch-up bursts from distorting live trips', () async {
      final service = AutoTripAndChargeService.instance;
      final t0 = DateTime(2026, 11, 3, 10, 0, 0);

      // Baseline frame
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 6000,
          batteryPct: 70,
          speedKmH: 0.0,
          isBound: true,
          lastUpdated: t0,
        ),
      );

      // Underground / deadzone catch-up burst: +50 km in 10 seconds
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 6050,
          batteryPct: 60,
          speedKmH: 40.0,
          isBound: true,
          lastUpdated: t0.add(const Duration(seconds: 10)),
        ),
      );

      // Should reject this burst rather than creating a 50 km trip in 10s (18,000 km/h)
      expect(service.isTripActive, isFalse);
    });

    test('Rejects downhill regenerative braking false-positives', () async {
      final service = AutoTripAndChargeService.instance;
      final t0 = DateTime(2026, 11, 3, 11, 0, 0);

      // Baseline parked
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 7000,
          batteryPct: 50,
          speedKmH: 0.0,
          isBound: true,
          lastUpdated: t0,
        ),
      );

      // 1% regen gain while stopped briefly for only 60 seconds
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 7000,
          batteryPct: 51,
          speedKmH: 0.0,
          isBound: true,
          lastUpdated: t0.add(const Duration(seconds: 60)),
        ),
      );

      // Vehicle drives off
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 7005,
          batteryPct: 50,
          speedKmH: 40.0,
          isBound: true,
          lastUpdated: t0.add(const Duration(minutes: 3)),
        ),
      );

      // Verify NO charge session was saved because it didn't meet >= 10 min or >= 2% gain
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tm_logged_expenses_v2');
      expect(raw, isNull);
    });

    test('Detects genuine AC charging session and logs expense record', () async {
      final service = AutoTripAndChargeService.instance;
      final t0 = DateTime(2026, 11, 3, 14, 0, 0);

      // Frame 1: Plugged in at 40%
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 8000,
          batteryPct: 40,
          speedKmH: 0.0,
          isCharging: true,
          chargePowerKw: 3.3,
          isBound: true,
          lastUpdated: t0,
        ),
      );

      expect(service.isChargeActive, isTrue);

      // Frame 2: Reached 60% after 60 minutes
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 8000,
          batteryPct: 60,
          speedKmH: 0.0,
          isCharging: true,
          chargePowerKw: 3.3,
          isBound: true,
          lastUpdated: t0.add(const Duration(minutes: 60)),
        ),
      );

      expect(service.activeCharge!.maxSoc, 60);

      // Frame 3: Finished charging and parked idle for 31 minutes
      service.processTelemetry(
        VehicleTelemetry(
          odometerKm: 8000,
          batteryPct: 60,
          speedKmH: 0.0,
          isCharging: false,
          chargePowerKw: 0.0,
          isBound: true,
          lastUpdated: t0.add(const Duration(minutes: 91)),
        ),
      );

      // Charge session finalized
      expect(service.isChargeActive, isFalse);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tm_logged_expenses_v2');
      expect(raw, isNotNull);

      final List<dynamic> list = jsonDecode(raw!);
      expect(list.isNotEmpty, isTrue);
      final expense = ExpenseRecord.fromJson(list.first as Map<String, dynamic>);
      expect(expense.type, 'home_ac');
      expect(expense.units, greaterThan(3.0)); // 20% of 18.3 kWh = 3.85 kWh
      expect(expense.amountRm, greaterThan(1.5));
    });
  });
}
