import 'package:flutter_test/flutter_test.dart';
import 'package:tiggomate_app/src/carlinko/carlinko_api.dart';
import 'package:tiggomate_app/src/carlinko/carlinko_crypto.dart';
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
      expect(parsed['energy_consumption_kwh100km'], isNotNull);
      expect(parsed['fuel_consumption_l100km'], isNotNull);
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

    test('parseBlob parses real Chery Tiggo 7 PHEV hex payload matching CarLinko exactly', () {
      const realHex =
          '77000000000000000000FF7F052900000000000BAF3F01002D02000032002C2D'
          '0000000000000000000000007972737365676464002E13E10101012D00000014'
          '00000000002C024702000000000000';

      final parsed = CarLinkoClient.parseBlob(realHex);
      final t = VehicleTelemetry.fromBlobMap(parsed, isSimulated: false);

      expect(t.volt12, equals(13.21));
      expect(t.odometerKm, equals(2991));
      expect(t.fuelConsumptionL100km, closeTo(4.6, 0.01));
      expect(t.energyConsumptionKwh100km, closeTo(-0.7, 0.01));
      expect(t.batteryPct, equals(50));
      expect(t.electricRangeKm, equals(44));
      expect(t.fuelRangeKm, equals(583));
      expect(t.tyreFlPressureKpa, closeTo(215.0, 1.0));
      expect(t.tyreFrPressureKpa, closeTo(203.0, 1.0));
      expect(t.tyreRlPressureKpa, closeTo(204.0, 1.0));
      expect(t.tyreRrPressureKpa, closeTo(204.0, 1.0));
    });

    test('VehicleTelemetry.fromBlobMap generates valid telemetry model', () {
      final parsed = CarLinkoClient.parseBlob(sampleHexBlob);
      final telemetry = VehicleTelemetry.fromBlobMap(parsed, isSimulated: false);

      expect(telemetry.isSimulated, isFalse);
      expect(telemetry.doorsLocked, isTrue);
      expect(telemetry.energyConsumptionKwh100km, isNotNull);
      expect(telemetry.dataSourceLabel, contains('LIVE CARLINKO'));
      // This fixture's tyre bytes are the 0xFF "no reading" sentinel, so
      // that field stays unknown rather than inventing a value.
      expect(telemetry.tyreFlPressureKpa, equals(0.0));
      // The fixture's fuel-range bytes (confirmed against a real car
      // reading) decode to a real, non-sentinel value here.
      expect(telemetry.fuelRangeKm, equals(248));
      expect(telemetry.totalRangeKm, equals(telemetry.electricRangeKm + 248));
    });

    test('VehicleTelemetry.fromBlobMap reports missing fields as unknown, not plausible values', () {
      final telemetry = VehicleTelemetry.fromBlobMap({}, isSimulated: false);

      expect(telemetry.hasLocation, isFalse);
      expect(telemetry.locationName, 'Location unavailable');
      expect(telemetry.headingDegrees, equals(0.0));
      expect(telemetry.parkedDurationText, 'Parked');
      expect(telemetry.volt12, equals(0.0));
      expect(telemetry.doorsOpen, isFalse);
      expect(telemetry.engineOn, isFalse);
    });

    test('VehicleTelemetry.fromBlobMap keeps reported coordinates and derives moving state from speed', () {
      final telemetry = VehicleTelemetry.fromBlobMap(
        {'lat': 3.2, 'lon': 101.7, 'speed': 40.0},
        isSimulated: false,
      );

      expect(telemetry.hasLocation, isTrue);
      expect(telemetry.locationName, 'Last reported position');
      expect(telemetry.isParked, isFalse);
      expect(telemetry.parkedDurationText, 'Moving');
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

  group('CarLinko v1.14.0 Opcode, Ack & Schedule Tests (j5-ev-dashboard parity)', () {
    test('acTemperature encodes dynamic half-degree setpoints into 7411xx', () {
      expect(CarLinkoOpcodes.acTemperature(17.5), equals('7411A3'));
      expect(CarLinkoOpcodes.acTemperature(22.0), equals('7411AC'));
      expect(CarLinkoOpcodes.acTemperature(16.0), equals('7411A0'));
      expect(CarLinkoOpcodes.acTemperature(32.0), equals('7411C0'));
    });

    test('seat ventilation and rear heating opcodes match verified T-Box mapping', () {
      expect(CarLinkoOpcodes.driverSeatHeatOpcode(2), equals('741502'));
      expect(CarLinkoOpcodes.passengerSeatHeatOpcode(3), equals('741603'));
      expect(CarLinkoOpcodes.rearLeftSeatHeatOpcode(1), equals('741701'));
      expect(CarLinkoOpcodes.rearRightSeatHeatOpcode(2), equals('741902'));
      expect(CarLinkoOpcodes.driverSeatVentOpcode(1), equals('741A01'));
      expect(CarLinkoOpcodes.passengerSeatVentOpcode(3), equals('741B03'));
      expect(CarLinkoOpcodes.rearLeftSeatVentOpcode(2), equals('741C02'));
      expect(CarLinkoOpcodes.rearRightSeatVentOpcode(1), equals('741E01'));
    });

    test('parseAckStatus extracts trailing status byte from <sn>__<opcode><status>', () {
      expect(CarLinkoClient.parseAckStatus('CQR8812__74020000', '740200'), equals('00'));
      expect(CarLinkoClient.parseAckStatus('CQR8812__74100144', '741001'), equals('44'));
      expect(
        CarLinkoClient.parseAckStatus({'data': 'SN01__74010000'}, '740100'),
        equals('00'),
      );
      expect(
        CarLinkoClient.parseAckStatus('SEA1257A68450667__7404', '740100'),
        equals('04'),
      );
      expect(CarLinkoClient.parseAckStatus('unexpected_format', '740200'), isNull);

      expect(CarLinkoClient.refusalReason('44'), contains('Car did not apply command'));
      expect(CarLinkoClient.refusalReason('04'), contains('T-Box auth fail'));
      expect(CarLinkoClient.refusalReason('96'), equals('Key detected inside the car'));
      expect(CarLinkoClient.refusalReason('2A'), equals('Vehicle in motion'));
    });

    test('normalizeBatterySchedulePayload builds exact CarLinko PUT body', () {
      final legacy = CarLinkoClient.normalizeBatterySchedulePayload('987654', {
        'startTime': '22:30',
        'durationMinutes': 360,
        'status': 1,
        'repeat': 'Monday to Friday',
      });
      expect(legacy['vehicleId'], equals(987654));
      expect(legacy['enabled'], isTrue);
      expect(legacy['hour'], equals(22));
      expect(legacy['minute'], equals(30));
      expect(legacy['duration'], equals(6));
      expect(legacy['week'], equals([false, true, true, true, true, true, false]));

      final native = CarLinkoClient.normalizeBatterySchedulePayload('987654', {
        'enabled': false,
        'hour': 1,
        'minute': 15,
        'duration': 4,
        'week': [true, false, false, false, false, false, true],
      });
      expect(native['enabled'], isFalse);
      expect(native['hour'], equals(1));
      expect(native['minute'], equals(15));
      expect(native['duration'], equals(4));
      // Ensure HMAC signer accepts list params cleanly without throwing
      expect(CarLinkoClient.sign(native, '1700000000000'), isNotEmpty);
    });

    test('VehicleCapabilities.fromVehicleMap parses vehicleImgConfig & vehicleControlConfig', () {
      final caps = VehicleCapabilities.fromVehicleMap({
        'plateNumber': 'VRT 3342',
        'airDuration': 15,
        'vehicleImgConfig': '{"Front":"https://cdn.example/front.png","Side":"https://cdn.example/side.png","Top":"https://cdn.example/top.png"}',
        'vehicleControlConfig': '{"minAcTemp":16,"maxAcTemp":31,"sunroof":true,"tailgate":false}',
      });
      expect(caps.plateNumber, equals('VRT 3342'));
      expect(caps.airDurationMin, equals(15));
      expect(caps.frontImageUrl, equals('https://cdn.example/front.png'));
      expect(caps.sideImageUrl, equals('https://cdn.example/side.png'));
      expect(caps.topImageUrl, equals('https://cdn.example/top.png'));
      expect(caps.minAcTemp, equals(16.0));
      expect(caps.maxAcTemp, equals(31.0));
      expect(caps.hasSunroof, isTrue);
      expect(caps.hasTailgate, isFalse);
    });

    test('CarLinkoCrypto matches FIPS-197 AES-128-ECB and captured v1.14.10 payloads', () {
      final tv = CarLinkoCrypto.encryptEcb(
        CarLinkoCrypto.hexToBytes('000102030405060708090a0b0c0d0e0f'),
        CarLinkoCrypto.hexToBytes('00112233445566778899aabbccddeeff'),
      );
      expect(CarLinkoCrypto.bytesToHex(tv), equals('69c4e0d86a7b0430d8cdb78070b4c55a'));

      const vin = 'MF7HD27B8TJ014064';
      const uid = '88504';
      expect(
        CarLinkoCrypto.buildControlPayload(
          '741001',
          vin,
          uid,
          randomBytes: CarLinkoCrypto.hexToBytes('5b860f36237770bc'),
        ),
        equals('665b860f36237770bc9e20d41399792a5cfd304f234dbd081a007dc9cef3b81634465e4e5d2e470785'),
      );
      expect(
        CarLinkoCrypto.buildControlPayload(
          '741000',
          vin,
          uid,
          randomBytes: CarLinkoCrypto.hexToBytes('d605e8d5dfef0987'),
        ),
        equals('66d605e8d5dfef0987565af8d5caf3d921d37a1d6be606fcb6400a930baa03acbf56180cf760cf2f26'),
      );
      expect(
        CarLinkoCrypto.buildControlPayload(
          '741001',
          vin,
          uid,
          randomBytes: CarLinkoCrypto.hexToBytes('26f9f0c671271a8c'),
        ),
        equals('6626f9f0c671271a8c956a30579874df39eb415e5cd42730010bb982060d174e1d89b690206231224e'),
      );
    });
  });
}
