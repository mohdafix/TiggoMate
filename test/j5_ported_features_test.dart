import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/carlinko/carlinko_api.dart';
import 'package:tiggomate_app/src/service/auto_trip_and_charge_service.dart';
import 'package:tiggomate_app/src/service/battery_health_service.dart';
import 'package:tiggomate_app/src/service/trip_planner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BatteryHealthService (Ported from j5-ev-dashboard)', () {
    test('12V voltage classification thresholds match automotive safety specs', () {
      final s = BatteryHealthService.instance;

      expect(s.getVolt12Status(12.6), Volt12HealthStatus.healthy);
      expect(s.getVolt12Status(12.4), Volt12HealthStatus.healthy);
      expect(s.getVolt12Status(12.2), Volt12HealthStatus.fair);
      expect(s.getVolt12Status(11.95), Volt12HealthStatus.low);
      expect(s.getVolt12Status(11.75), Volt12HealthStatus.critical);
    });

    test('LFP Cell Balance status reflects flat-curve BMS requirements', () {
      final s = BatteryHealthService.instance;

      // Default baseline
      expect(s.lfpStatus, LfpBalanceStatus.balanced);
      expect(s.daysSinceLast100, lessThanOrEqualTo(7));
    });

    test('7-day minimum 12V voltage correctly identifies lowest dip', () {
      final s = BatteryHealthService.instance;
      final minV = s.getMinVolt12Last7Days(12.55);
      expect(minV, closeTo(12.55, 0.05));
    });
  });

  group('AutoTripAndChargeService (Efficiency & Petrol Comparison)', () {
    test('chargeEfficiency implements non-linear taper and cell balancing curve', () {
      // <= 85% SoC: peak DC/AC efficiency (91%)
      expect(AutoTripAndChargeService.chargeEfficiency(80), closeTo(0.91, 0.001));
      expect(AutoTripAndChargeService.chargeEfficiency(85), closeTo(0.91, 0.001));

      // 85% to 95%: linear taper
      expect(AutoTripAndChargeService.chargeEfficiency(90), closeTo(0.8825, 0.001));

      // >= 95% SoC: cell balancing & current taper (85.5%)
      expect(AutoTripAndChargeService.chargeEfficiency(95), closeTo(0.855, 0.001));
      expect(AutoTripAndChargeService.chargeEfficiency(100), closeTo(0.855, 0.001));
    });
  });

  group('TripPlannerService (EV Highway Reachability & Charger Routing)', () {
    test('Calculates pure EV trip feasibility when within battery range', () async {
      final planner = TripPlannerService.instance;
      final origin = LatLng(3.1390, 101.6869); // KL
      final dest = LatLng(3.2000, 101.7000);  // ~10 km trip

      final res = await planner.planRoute(
        origin: origin,
        destination: dest,
        destinationName: 'Nearby Hub',
        currentSoc: 80,
        consumptionKwh100: 16.8,
      );

      expect(res.canReachPureEv, isTrue);
      expect(res.projectedArrivalSoc, greaterThan(60));
      expect(res.hybridShareKm, closeTo(0.0, 0.1));
    });

    test('Calculates hybrid powertrain split and suggests highway corridor charger for long trip', () async {
      final planner = TripPlannerService.instance;
      final origin = LatLng(3.1390, 101.6869); // KL
      final dest = LatLng(4.5975, 101.0772);  // Ipoh (~200 km trip)

      final res = await planner.planRoute(
        origin: origin,
        destination: dest,
        destinationName: 'Ipoh Old Town',
        currentSoc: 80, // ~87 km pure EV range
        consumptionKwh100: 16.8,
      );

      expect(res.canReachPureEv, isFalse);
      expect(res.distanceKm, greaterThan(150.0));
      expect(res.electricShareKm, lessThan(res.distanceKm));
      expect(res.hybridShareKm, greaterThan(50.0));
      // Interstate highway route should match a corridor charger
      expect(res.recommendedStop, isNotNull);
      expect(res.recommendedStop!.name.contains('PLUS'), isTrue);
    });
  });

  group('Extended CAN Remote Control Opcodes (j5-ev-dashboard parity)', () {
    test('Air purifier, seat ventilation, defog and quick cool opcodes match verified T-Box protocol', () {
      expect(CarLinkoOpcodes.airPurifyOn, equals('742501'));
      expect(CarLinkoOpcodes.airPurifyOff, equals('742500'));
      expect(CarLinkoOpcodes.defogOn, equals('741201'));
      expect(CarLinkoOpcodes.defogOff, equals('741200'));
      expect(CarLinkoOpcodes.quickCool, equals('742001'));
      expect(CarLinkoOpcodes.driverSeatVentL1, equals('741A01'));
      expect(CarLinkoOpcodes.driverSeatVentL2, equals('741A02'));
      expect(CarLinkoOpcodes.driverSeatVentL3, equals('741A03'));
      expect(CarLinkoOpcodes.driverSeatVentOff, equals('741A00'));
    });
  });
}
