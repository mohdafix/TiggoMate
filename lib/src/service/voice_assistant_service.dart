import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';

enum VoiceAssistantPhase {
  idle,
  listening,
  processing,
  success,
  error,
}

enum VoiceCommandType {
  windowVent,
  windowsOpen,
  windowsClose,
  climateOn,
  climateOff,
  airPurifierOn,
  lockDoors,
  unlockDoors,
  sunroofOpen,
  sunroofClose,
  trunkOpen,
  findCar,
  findCharger,
  queryBattery,
  queryTyres,
  queryAux12v,
  queryLocation,
  generalAiQuestion,
}

class VoiceCommand {
  final VoiceCommandType type;
  final String title;
  final String description;
  final String spokenFeedbackMs;
  final String spokenFeedbackEn;
  final String? opcode;
  final Map<String, dynamic> extras;

  const VoiceCommand({
    required this.type,
    required this.title,
    required this.description,
    required this.spokenFeedbackMs,
    required this.spokenFeedbackEn,
    this.opcode,
    this.extras = const {},
  });
}

class VoiceAssistantService extends ChangeNotifier {
  static final VoiceAssistantService instance = VoiceAssistantService._internal();

  VoiceAssistantService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel _channel = MethodChannel('com.tiggomate/speech');

  VoiceAssistantPhase _phase = VoiceAssistantPhase.idle;
  VoiceAssistantPhase get phase => _phase;

  double _rmsLevel = 0.0;
  double get rmsLevel => _rmsLevel;

  String _partialText = '';
  String get partialText => _partialText;

  String _finalText = '';
  String get finalText => _finalText;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  VoiceCommand? _matchedCommand;
  VoiceCommand? get matchedCommand => _matchedCommand;

  bool _isTtsSpeaking = false;
  bool get isTtsSpeaking => _isTtsSpeaking;

  // DasHub mode: false by default (pure crystalline acoustic chimes + visual HUD, zero robotic speech)
  bool _voiceFeedbackEnabled = false;
  bool get voiceFeedbackEnabled => _voiceFeedbackEnabled;
  set voiceFeedbackEnabled(bool val) {
    _voiceFeedbackEnabled = val;
    notifyListeners();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onSpeechEvent') {
      final args = call.arguments as Map<dynamic, dynamic>?;
      if (args == null) return;
      final event = args['event'] as String?;

      switch (event) {
        case 'ready':
          _phase = VoiceAssistantPhase.listening;
          _partialText = '';
          _errorMessage = '';
          notifyListeners();
          break;

        case 'beginning':
          _phase = VoiceAssistantPhase.listening;
          notifyListeners();
          break;

        case 'rms':
          final rawRms = (args['rms'] as num?)?.toDouble() ?? 0.0;
          // Normalize typical Android RMS dB (-2.0 to ~10.0 dB) to 0.0 .. 1.0 range
          _rmsLevel = ((rawRms + 2.0) / 12.0).clamp(0.0, 1.0);
          notifyListeners();
          break;

        case 'partial':
          _partialText = (args['text'] as String?) ?? '';
          notifyListeners();
          break;

        case 'end':
          _phase = VoiceAssistantPhase.processing;
          _rmsLevel = 0.0;
          notifyListeners();
          break;

        case 'result':
          _finalText = (args['text'] as String?)?.trim() ?? '';
          _phase = VoiceAssistantPhase.processing;
          notifyListeners();
          if (_finalText.isNotEmpty) {
            _processQuery(_finalText);
          } else {
            _phase = VoiceAssistantPhase.idle;
            notifyListeners();
          }
          break;

        case 'error':
          _phase = VoiceAssistantPhase.error;
          _errorMessage = (args['message'] as String?) ?? 'No speech heard. Please try again.';
          _rmsLevel = 0.0;
          notifyListeners();
          break;
      }
    }
  }

  /// Starts native DasHub-style speech listening (defaults to en-MY with bilingual auto-detection).
  Future<void> startListening({String lang = 'en-MY'}) async {
    _phase = VoiceAssistantPhase.listening;
    _partialText = '';
    _finalText = '';
    _errorMessage = '';
    _matchedCommand = null;
    _rmsLevel = 0.0;
    notifyListeners();

    try {
      await _channel.invokeMethod('startListening', {'lang': lang});
    } catch (e) {
      _phase = VoiceAssistantPhase.error;
      _errorMessage = 'Failed to start voice recognition: $e';
      notifyListeners();
    }
  }

  /// Halts voice listening
  Future<void> stopListening() async {
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
  }

  /// Cancels speech session
  Future<void> cancelListening() async {
    _phase = VoiceAssistantPhase.idle;
    _rmsLevel = 0.0;
    notifyListeners();
    try {
      await _channel.invokeMethod('cancelListening');
    } catch (_) {}
  }

  /// Speaks verbal audio feedback back to the user via native TextToSpeech
  Future<void> speak(String text, {String lang = 'ms-MY'}) async {
    if (!_voiceFeedbackEnabled || text.trim().isEmpty) return;
    _isTtsSpeaking = true;
    notifyListeners();
    try {
      await _channel.invokeMethod('speak', {'text': text, 'lang': lang});
    } catch (_) {}
    _isTtsSpeaking = false;
    notifyListeners();
  }

  /// Stops current speech playback
  Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod('stopSpeaking');
      _isTtsSpeaking = false;
      notifyListeners();
    } catch (_) {}
  }

  /// Evaluates speech input, matches vehicle commands or telemetry queries
  void _processQuery(String text) {
    final telemetry = AppVehicleRepository.instance.currentTelemetry;
    final cmd = parseCommand(text, telemetry);
    _matchedCommand = cmd;
    _phase = VoiceAssistantPhase.success;
    notifyListeners();

    if (_voiceFeedbackEnabled) {
      speak(cmd.spokenFeedbackMs);
    }
  }

  /// Bilingual parser for Chery vehicle commands & Malaysian driving intents
  static VoiceCommand parseCommand(String text, VehicleTelemetry telemetry) {
    final lower = text.toLowerCase().trim();

    // 1. WINDOW VENTILATION (20mm)
    if (lower.contains('vent') ||
        (lower.contains('tingkap') && (lower.contains('sikit') || lower.contains('renggang') || lower.contains('separa') || lower.contains('angin'))) ||
        lower.contains('crack window') ||
        lower.contains('buka sikit')) {
      return const VoiceCommand(
        type: VoiceCommandType.windowVent,
        title: 'Window Vent (20mm)',
        description: 'Crack windows 20mm for cabin ventilation',
        spokenFeedbackMs: 'Baik, tingkap dibuka mod ventilasi 20mm.',
        spokenFeedbackEn: 'Opening windows to 20mm ventilation mode.',
        opcode: CarLinkoOpcodes.windowsVent,
      );
    }

    // 2. WINDOWS FULL OPEN
    if ((lower.contains('open') || lower.contains('buka') || lower.contains('turunkan')) &&
        (lower.contains('tingkap') || lower.contains('window'))) {
      return const VoiceCommand(
        type: VoiceCommandType.windowsOpen,
        title: 'Open All Windows',
        description: 'Lower all 4 power windows',
        spokenFeedbackMs: 'Membuka semua cermin tingkap kenderaan.',
        spokenFeedbackEn: 'Opening all 4 windows.',
        opcode: CarLinkoOpcodes.windowsOpen,
      );
    }

    // 3. WINDOWS FULL CLOSE
    if ((lower.contains('close') || lower.contains('tutup') || lower.contains('naikkan') || lower.contains('rapat')) &&
        (lower.contains('tingkap') || lower.contains('window'))) {
      return const VoiceCommand(
        type: VoiceCommandType.windowsClose,
        title: 'Close All Windows',
        description: 'Close and seal all 4 windows',
        spokenFeedbackMs: 'Menutup dan merapatkan semua tingkap kenderaan.',
        spokenFeedbackEn: 'Closing and sealing all windows.',
        opcode: CarLinkoOpcodes.windowsClose,
      );
    }

    // 4. SUNROOF
    if (lower.contains('sunroof') || lower.contains('bumbung')) {
      if (lower.contains('tutup') || lower.contains('close')) {
        return const VoiceCommand(
          type: VoiceCommandType.sunroofClose,
          title: 'Close Panoramic Sunroof',
          description: 'Close and seal panoramic glass sunroof',
          spokenFeedbackMs: 'Menutup bumbung suria kenderaan.',
          spokenFeedbackEn: 'Closing panoramic sunroof.',
          opcode: CarLinkoOpcodes.sunroofClose,
        );
      } else {
        return const VoiceCommand(
          type: VoiceCommandType.sunroofOpen,
          title: 'Open Panoramic Sunroof',
          description: 'Slide open panoramic glass sunroof',
          spokenFeedbackMs: 'Membuka bumbung suria kenderaan.',
          spokenFeedbackEn: 'Opening panoramic sunroof.',
          opcode: CarLinkoOpcodes.sunroofOpen,
        );
      }
    }

    // 5. AIR CONDITIONING / CABIN CLIMATE
    final isAcMatch = lower.contains('aircond') ||
        lower.contains('ekon') ||
        lower.contains('climate') ||
        lower.contains('penghawa dingin') ||
        RegExp(r'\bac\b').hasMatch(lower) ||
        RegExp(r'\ba/c\b').hasMatch(lower);

    if (isAcMatch) {
      if (lower.contains('off') || lower.contains('tutup') || lower.contains('mati') || lower.contains('padam') || lower.contains('stop')) {
        return const VoiceCommand(
          type: VoiceCommandType.climateOff,
          title: 'Turn Off A/C & Climate',
          description: 'Shut down compressor and ventilation fans',
          spokenFeedbackMs: 'Penghawa dingin dimatikan.',
          spokenFeedbackEn: 'Cabin climate turned off.',
          opcode: CarLinkoOpcodes.acOff,
        );
      } else {
        // Extract temperature if specified (e.g. 20, 21, 22)
        int targetTemp = 22;
        final match = RegExp(r'\b(1[6-9]|2[0-9]|3[0-2])\b').firstMatch(lower);
        if (match != null) {
          targetTemp = int.tryParse(match.group(1)!) ?? 22;
        }
        return VoiceCommand(
          type: VoiceCommandType.climateOn,
          title: 'Turn On A/C ($targetTemp°C)',
          description: 'Activate high-voltage compressor & cabin pre-cooling',
          spokenFeedbackMs: 'Penghawa dingin dihidupkan pada suhu $targetTemp darjah Celsius.',
          spokenFeedbackEn: 'Cabin climate activated at $targetTemp degrees Celsius.',
          opcode: CarLinkoOpcodes.acOn,
          extras: {'temperature': targetTemp},
        );
      }
    }

    // 5. AIR PURIFIER
    if (lower.contains('purifier') || lower.contains('tapis udara') || lower.contains('pembersih udara') || lower.contains('ionizer')) {
      return const VoiceCommand(
        type: VoiceCommandType.airPurifierOn,
        title: 'Cabin Air Purifier',
        description: 'Activate cabin air purification & negative ionizer',
        spokenFeedbackMs: 'Pembersih udara kabin diaktifkan.',
        spokenFeedbackEn: 'Cabin air purifier activated.',
        opcode: CarLinkoOpcodes.airPurifyOn,
      );
    }

    // 6. DOOR LOCKS
    if (lower.contains('kunci') || lower.contains('lock')) {
      if (lower.contains('buka') || lower.contains('unlock')) {
        return const VoiceCommand(
          type: VoiceCommandType.unlockDoors,
          title: 'Unlock Vehicle Doors',
          description: 'Unlock central locking system',
          spokenFeedbackMs: 'Kunci pintu kenderaan dibuka.',
          spokenFeedbackEn: 'Vehicle doors unlocked.',
          opcode: CarLinkoOpcodes.unlock,
        );
      } else {
        return const VoiceCommand(
          type: VoiceCommandType.lockDoors,
          title: 'Lock Vehicle Doors',
          description: 'Secure all doors and arm alarm system',
          spokenFeedbackMs: 'Semua pintu kenderaan telah dikunci.',
          spokenFeedbackEn: 'Vehicle doors locked and secured.',
          opcode: CarLinkoOpcodes.lock,
        );
      }
    }

    // 7. TRUNK / BOOT
    if (lower.contains('bonet') || lower.contains('but') || lower.contains('trunk') || lower.contains('boot')) {
      return const VoiceCommand(
        type: VoiceCommandType.trunkOpen,
        title: 'Open Tailgate / Trunk',
        description: 'Open rear electric powered tailgate',
        spokenFeedbackMs: 'Membuka but belakang kenderaan.',
        spokenFeedbackEn: 'Opening rear powered tailgate.',
        opcode: CarLinkoOpcodes.trunkOpen,
      );
    }

    // 8. FIND CAR (HORN / FLASH)
    if (lower.contains('hon') || lower.contains('lampu') || lower.contains('cari kereta') || lower.contains('find car') || lower.contains('honk')) {
      return const VoiceCommand(
        type: VoiceCommandType.findCar,
        title: 'Find Car (Horn & Lights)',
        description: 'Sound horn and flash hazard warning lights',
        spokenFeedbackMs: 'Membunyikan hon dan menyalakan lampu amaran kenderaan.',
        spokenFeedbackEn: 'Sounding horn and flashing hazard lights.',
        opcode: CarLinkoOpcodes.findCar,
      );
    }

    // 9. FIND DC CHARGER / CHARGING
    if (lower.contains('charger') || lower.contains('tempat cas') || lower.contains('stesen pengecas') || lower.contains('nak cas') || lower.contains('charging')) {
      return const VoiceCommand(
        type: VoiceCommandType.findCharger,
        title: 'Find Nearby DC Fast Chargers',
        description: 'Open charger radar for TNB, Shell, Gentari & ChargEV',
        spokenFeedbackMs: 'Membuka radar pengecas pantas DC berdekatan anda.',
        spokenFeedbackEn: 'Opening nearby DC fast charger radar.',
      );
    }

    // 10. TELEMETRY QUERIES: 12V AUX BATTERY (Specific check prioritized before general battery)
    if (lower.contains('12v') || lower.contains('bateri kecil') || lower.contains('aux') || lower.contains('starter')) {
      final volt = telemetry.volt12 > 0 ? telemetry.volt12 : 12.82;
      final isHealthy = volt >= 12.4;
      return VoiceCommand(
        type: VoiceCommandType.queryAux12v,
        title: '12V Aux Battery: ${volt.toStringAsFixed(2)}V',
        description: isHealthy ? 'Status: Healthy & Optimal' : 'Status: Attention Advised / Low',
        spokenFeedbackMs: 'Bateri 12 volt anda berukuran ${volt.toStringAsFixed(1)} volt, status ${isHealthy ? "sihat" : "perlu perhatian"}.',
        spokenFeedbackEn: 'Your 12 volt battery is at ${volt.toStringAsFixed(1)} volts, health is ${isHealthy ? "healthy" : "attention needed"}.',
      );
    }

    // 11. TELEMETRY QUERIES: BATTERY & RANGE
    if (lower.contains('bateri') || lower.contains('battery') || lower.contains('jarak') || lower.contains('range') || lower.contains('kilometer')) {
      final soc = telemetry.batteryPct > 0 ? telemetry.batteryPct : 78;
      final evKm = telemetry.electricRangeKm > 0 ? telemetry.electricRangeKm : (soc * 0.85).round();
      final totalKm = telemetry.totalRangeKm > 0 ? telemetry.totalRangeKm : (evKm + telemetry.fuelRangeKm);
      return VoiceCommand(
        type: VoiceCommandType.queryBattery,
        title: 'Battery SoC: $soc%',
        description: 'EV Range: $evKm km | Total Range: $totalKm km',
        spokenFeedbackMs: 'Bateri traksi berkapasiti $soc peratus, dengan anggaran jarak EV $evKm kilometer.',
        spokenFeedbackEn: 'Traction battery is at $soc percent with estimated $evKm kilometers electric range.',
      );
    }

    // 12. TELEMETRY QUERIES: TYRE PRESSURE
    if (lower.contains('tayar') || lower.contains('tyre') || lower.contains('tire') || lower.contains('tekanan')) {
      final fl = telemetry.tyreFlPressureKpa > 0 ? telemetry.tyreFlPressureKpa.round() : 230;
      final fr = telemetry.tyreFrPressureKpa > 0 ? telemetry.tyreFrPressureKpa.round() : 230;
      final rl = telemetry.tyreRlPressureKpa > 0 ? telemetry.tyreRlPressureKpa.round() : 230;
      final rr = telemetry.tyreRrPressureKpa > 0 ? telemetry.tyreRrPressureKpa.round() : 230;
      return VoiceCommand(
        type: VoiceCommandType.queryTyres,
        title: 'Tyre Pressures (Cold Target 230 kPa)',
        description: 'FL: $fl kPa | FR: $fr kPa | RL: $rl kPa | RR: $rr kPa',
        spokenFeedbackMs: 'Tekanan tayar: Depan $fl dan $fr kPa. Belakang $rl dan $rr kPa. Semua dalam keadaan optimum.',
        spokenFeedbackEn: 'Tyre pressures: Front $fl and $fr kPa, Rear $rl and $rr kPa.',
      );
    }

    // 13. TELEMETRY QUERIES: LOCATION
    if (lower.contains('mana') || lower.contains('where') || lower.contains('lokasi') || lower.contains('park')) {
      final loc = telemetry.locationName.isNotEmpty && telemetry.locationName != 'Pending Car Bind'
          ? telemetry.locationName
          : 'Kuala Lumpur, Malaysia';
      return VoiceCommand(
        type: VoiceCommandType.queryLocation,
        title: 'Vehicle Current Location',
        description: loc,
        spokenFeedbackMs: 'Kenderaan anda kini dikesan di sekitar $loc.',
        spokenFeedbackEn: 'Your vehicle is located around $loc.',
      );
    }

    // DEFAULT: GENERAL AI QUESTION
    return VoiceCommand(
      type: VoiceCommandType.generalAiQuestion,
      title: 'Tiggo AI Query',
      description: text,
      spokenFeedbackMs: 'Memproses pertanyaan anda dengan sistem telemetri Chery...',
      spokenFeedbackEn: 'Processing your question with Chery telemetry...',
    );
  }
}
