import 'package:flutter_test/flutter_test.dart';
import 'package:tiggomate_app/src/carlinko/carlinko_api.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_telemetry.dart';
import 'package:tiggomate_app/src/service/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testTelemetry = VehicleTelemetry(
    lastUpdated: DateTime(2026, 11, 13, 12, 0),
    batteryPct: 72,
    electricRangeKm: 65,
    fuelCapacityPct: 50,
    fuelRangeKm: 420,
    totalRangeKm: 485,
    volt12: 12.82,
    tyreFlPressureKpa: 231,
    tyreFrPressureKpa: 230,
    tyreRlPressureKpa: 229,
    tyreRrPressureKpa: 230,
    locationName: 'Subang Jaya, Selangor',
  );

  group('VoiceAssistantService Bilingual Command Parser Tests', () {
    test('Ventilation (20mm) matches opcode 740E00 and spoken feedback', () {
      final cmd1 = VoiceAssistantService.parseCommand('buka tingkap sikit mod ventilasi', testTelemetry);
      expect(cmd1.type, equals(VoiceCommandType.windowVent));
      expect(cmd1.opcode, equals(CarLinkoOpcodes.windowsVent));
      expect(cmd1.spokenFeedbackMs, contains('20mm'));

      final cmd2 = VoiceAssistantService.parseCommand('crack windows please', testTelemetry);
      expect(cmd2.type, equals(VoiceCommandType.windowVent));
      expect(cmd2.opcode, equals(CarLinkoOpcodes.windowsVent));
    });

    test('Windows Full Open matches opcode 740600', () {
      final cmd = VoiceAssistantService.parseCommand('buka semua tingkap kereta', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.windowsOpen));
      expect(cmd.opcode, equals(CarLinkoOpcodes.windowsOpen));
    });

    test('Windows Full Close matches opcode 740600', () {
      final cmd = VoiceAssistantService.parseCommand('tutup semua tingkap rapat', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.windowsClose));
      expect(cmd.opcode, equals(CarLinkoOpcodes.windowsClose));
    });

    test('A/C ON matches opcode 741001 with custom extracted temperature', () {
      final cmd = VoiceAssistantService.parseCommand('pasang aircond 20 darjah', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.climateOn));
      expect(cmd.opcode, equals(CarLinkoOpcodes.acOn));
      expect(cmd.extras['temperature'], equals(20));
      expect(cmd.spokenFeedbackMs, contains('20 darjah'));
    });

    test('A/C OFF matches opcode 741000', () {
      final cmd = VoiceAssistantService.parseCommand('matikan aircond', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.climateOff));
      expect(cmd.opcode, equals(CarLinkoOpcodes.acOff));
    });

    test('Air Purifier matches opcode 742501', () {
      final cmd = VoiceAssistantService.parseCommand('hidupkan pembersih udara', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.airPurifierOn));
      expect(cmd.opcode, equals(CarLinkoOpcodes.airPurifyOn));
    });

    test('Door Lock and Unlock match respective opcodes', () {
      final lockCmd = VoiceAssistantService.parseCommand('kunci kereta sekarang', testTelemetry);
      expect(lockCmd.type, equals(VoiceCommandType.lockDoors));
      expect(lockCmd.opcode, equals(CarLinkoOpcodes.lock));

      final unlockCmd = VoiceAssistantService.parseCommand('buka kunci pintu', testTelemetry);
      expect(unlockCmd.type, equals(VoiceCommandType.unlockDoors));
      expect(unlockCmd.opcode, equals(CarLinkoOpcodes.unlock));
    });

    test('Sunroof Open and Close match respective opcodes', () {
      final openCmd = VoiceAssistantService.parseCommand('buka sunroof', testTelemetry);
      expect(openCmd.type, equals(VoiceCommandType.sunroofOpen));
      expect(openCmd.opcode, equals(CarLinkoOpcodes.sunroofOpen));

      final closeCmd = VoiceAssistantService.parseCommand('tutup bumbung kaca', testTelemetry);
      expect(closeCmd.type, equals(VoiceCommandType.sunroofClose));
      expect(closeCmd.opcode, equals(CarLinkoOpcodes.sunroofClose));
    });

    test('Trunk / Boot matches opcode 741200', () {
      final cmd = VoiceAssistantService.parseCommand('buka bonet belakang', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.trunkOpen));
      expect(cmd.opcode, equals(CarLinkoOpcodes.trunkOpen));
    });

    test('Find Car (Horn/Flash) matches opcode 740400', () {
      final cmd = VoiceAssistantService.parseCommand('cari kereta bunyikan hon', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.findCar));
      expect(cmd.opcode, equals(CarLinkoOpcodes.findCar));
    });

    test('Find DC Charger matches charger radar trigger', () {
      final cmd = VoiceAssistantService.parseCommand('cari tempat cas berdekatan', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.findCharger));
      expect(cmd.spokenFeedbackMs, contains('radar pengecas'));
    });

    test('Zero-latency Battery Telemetry query responds with live SoC & range', () {
      final cmd = VoiceAssistantService.parseCommand('berapa baki bateri dan jarak', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.queryBattery));
      expect(cmd.spokenFeedbackMs, contains('72 peratus'));
      expect(cmd.spokenFeedbackMs, contains('65 kilometer'));
    });

    test('Zero-latency Tyre Pressure query responds with cold pressures', () {
      final cmd = VoiceAssistantService.parseCommand('bagaimana tekanan angin tayar', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.queryTyres));
      expect(cmd.spokenFeedbackMs, contains('231'));
      expect(cmd.spokenFeedbackMs, contains('230'));
    });

    test('Zero-latency 12V Aux Battery query responds with voltage and health', () {
      final cmd = VoiceAssistantService.parseCommand('cek bateri 12v kenderaan', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.queryAux12v));
      expect(cmd.spokenFeedbackMs, contains('12.8'));
      expect(cmd.spokenFeedbackMs, contains('sihat'));
    });

    test('Location query responds with current detected location', () {
      final cmd = VoiceAssistantService.parseCommand('kereta saya kat mana', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.queryLocation));
      expect(cmd.spokenFeedbackMs, contains('Subang Jaya'));
    });

    test('Unmatched queries default to General AI Question', () {
      final cmd = VoiceAssistantService.parseCommand('Berapa kos servis pertama Chery Tiggo?', testTelemetry);
      expect(cmd.type, equals(VoiceCommandType.generalAiQuestion));
    });
  });
}
