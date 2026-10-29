import 'package:flutter_test/flutter_test.dart';
import 'package:tiggomate_app/src/carlinko/carlinko_api.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_repository.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_telemetry.dart';

void main() {
  const String sampleHexBlob =
      '77000000000200000000FF7F056800600000000372000101B80201003100F8B8'
      '000000000000000000000000FFFFFFFFFFFFFFFF00000071000003FF00000000'
      '000000FF00E000F802';

  group('CarLinko API HMAC Signing Tests (ha-carlinko compatibility)', () {
    test('sign normalizes null and empty string identically', () {
      const ts = '1700000000000';
      final s1 = CarLinkoClient.sign({'a': null}, ts);
      final s2 = CarLinkoClient.sign({'a': ''}, ts);
      expect(s1, equals(s2));
    });

    test('sign ignores parameter key insertion order', () {
      const ts = '1700000000000';
      final s1 = CarLinkoClient.sign({'a': 1, 'b': 2}, ts);
      final s2 = CarLinkoClient.sign({'b': 2, 'a': 1}, ts);
      expect(s1, equals(s2));
    });

    test('sign produces consistent base64 digest with CarLinko sign key', () {
      const ts = '1700000000000';
      final sig = CarLinkoClient.sign({'vehicleId': '12345'}, ts);
      expect(sig, isNotEmpty);
      expect(sig.length, greaterThan(20));
    });
  });

  group('CarLinko 73-Byte Telemetry Blob Parsing Tests', () {
    test('parseBlob parses valid telemetry sample matching reference', () {
      final parsed = CarLinkoClient.parseBlob(sampleHexBlob);

      expect(parsed['hv_state'], equals(2));
      expect(parsed['doors'], equals(0));
      expect(parsed['unlocked'], equals(0));
      expect(parsed['ac_on'], equals(true));
      expect(parsed['charge_remain_min'], isNull); // 0x3FF sentinel
      expect(parsed['charge_power_kw'], isNull);
      expect(parsed['tyre_fl_pressure'], isNull); // 0xFF = no reading
    });

    test('parseBlob handles short/malformed hex gracefully without throwing', () {
      final shortParsed = CarLinkoClient.parseBlob('7700');
      expect(shortParsed['battery_pct'], isNull);
      expect(shortParsed['range_km'], isNull);

      final invalidParsed = CarLinkoClient.parseBlob('not_a_hex_string');
      expect(invalidParsed, isEmpty);

      final emptyParsed = CarLinkoClient.parseBlob('');
      expect(emptyParsed, isEmpty);
    });

    test('VehicleTelemetry.fromBlobMap generates valid telemetry model', () {
      final parsed = CarLinkoClient.parseBlob(sampleHexBlob);
      final telemetry = VehicleTelemetry.fromBlobMap(parsed, isSimulated: false);

      expect(telemetry.isSimulated, isFalse);
      expect(telemetry.dataSourceLabel, contains('LIVE CARLINKO'));
      expect(telemetry.fuelRangeKm, equals(838));
      expect(telemetry.totalRangeKm, greaterThanOrEqualTo(838));
    });
  });

  group('VehicleRepository Mock and State Tests', () {
    test('MockVehicleRepository provides verified Malaysian Tiggo 7 PHEV sample state when requested', () {
      final repo = MockVehicleRepository(withSampleData: true);
      expect(repo.connectionStatus, equals(VehicleConnectionStatus.connected));

      final t = repo.currentTelemetry;
      expect(t.isBound, isTrue);
      expect(t.batteryPct, equals(78));
      expect(t.electricRangeKm, equals(82));
      expect(t.totalRangeKm, equals(920));
      expect(t.volt12, closeTo(12.82, 0.01));
      expect(t.tyreFlPressureKpa, equals(235.0));

      repo.dispose();
    });

    test('MockVehicleRepository default is pending car bind', () {
      final repo = MockVehicleRepository();
      expect(repo.isVehicleBound, isFalse);
      expect(repo.currentTelemetry.isBound, isFalse);
      expect(repo.currentTelemetry.batteryPct, equals(0));
      expect(repo.currentTelemetry.dataSourceLabel, equals('Pending Car Bind'));
      repo.dispose();
    });

    test('MockVehicleRepository toggleCharging updates telemetry reactively', () async {
      final repo = MockVehicleRepository(withSampleData: true);

      expect(repo.currentTelemetry.isCharging, isFalse);

      repo.toggleCharging(true);
      expect(repo.currentTelemetry.isCharging, isTrue);
      expect(repo.currentTelemetry.chargePowerKw, equals(6.6));
      expect(repo.currentTelemetry.chargeRemainMin, equals(38));

      repo.toggleCharging(false);
      expect(repo.currentTelemetry.isCharging, isFalse);
      expect(repo.currentTelemetry.chargePowerKw, equals(0.0));

      repo.dispose();
    });

    test('LiveCarLinkoRepository starts disconnected and handles disconnect', () async {
      final liveRepo = LiveCarLinkoRepository();
      expect(liveRepo.connectionStatus, equals(VehicleConnectionStatus.disconnected));

      await liveRepo.disconnect();
      expect(liveRepo.connectionStatus, equals(VehicleConnectionStatus.disconnected));
      liveRepo.dispose();
    });

    test('LiveCarLinkoRepository maintains connected status in pre-activation mode without vehicle bound', () {
      final liveRepo = LiveCarLinkoRepository();
      liveRepo.setPreActivationMode(account: 'linexsg@gmail.com');
      expect(liveRepo.connectionStatus, equals(VehicleConnectionStatus.connected));
      expect(liveRepo.isPreActivation, isTrue);
      expect(liveRepo.account, equals('linexsg@gmail.com'));
      expect(liveRepo.isVehicleBound, isFalse);
      expect(liveRepo.currentTelemetry.dataSourceLabel, contains('Pending Car Bind'));
      liveRepo.dispose();
    });

    test('AppVehicleRepository operates in real live mode and reflects pending car bind', () {
      final sharedRepo = AppVehicleRepository.instance;
      expect(sharedRepo.isLiveActive, isTrue);
      expect(sharedRepo.isVehicleBound, isFalse);

      sharedRepo.setPreActivationActive(account: 'linexsg@gmail.com');
      expect(sharedRepo.isLiveActive, isTrue);
      expect(sharedRepo.isPreActivation, isTrue);
      expect(sharedRepo.isPreActivationMode, isTrue);
      expect(sharedRepo.isVehicleBound, isFalse);
      expect(sharedRepo.connectionStatus, equals(VehicleConnectionStatus.connected));
      expect(sharedRepo.currentTelemetry.dataSourceLabel, contains('Pending Car Bind'));
    });
  });

  group('CarLinko Region & Parsing Improvements', () {
    test('CarLinkoClient region normalization and configuration', () {
      final client = CarLinkoClient();
      expect(client.region, equals('sea'));

      client.region = 'emea';
      expect(client.region, equals('me'));

      client.region = 'EU';
      expect(client.region, equals('me'));

      client.region = 'RU';
      expect(client.region, equals('ru'));

      client.region = 'AP';
      expect(client.region, equals('ap'));

      client.region = 'sea';
      expect(client.region, equals('sea'));
    });

    test('parseBlob handles odd-length hex strings gracefully', () {
      // 5 hex chars -> padded to 6 chars
      final parsed = CarLinkoClient.parseBlob('77000');
      expect(parsed, isNotNull);
    });
  });
}
