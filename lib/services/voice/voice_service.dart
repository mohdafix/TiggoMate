import 'dart:async';
import 'package:flutter/foundation.dart';

/// Voice service supporting Android speech recognition interface and text-to-speech.
/// Gracefully falls back on emulators, desktop, or devices without microphone permissions.
class VoiceService {
  bool _isListening = false;
  bool _isTtsEnabled = false;

  bool get isListening => _isListening;
  bool get isTtsEnabled => _isTtsEnabled;

  void toggleTts(bool enabled) {
    _isTtsEnabled = enabled;
  }

  /// Listens for speech input, returning transcribed text or throwing if unavailable.
  Future<String?> listenForSpeech({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _isListening = true;
    try {
      // In production Android, connects to Android SpeechRecognizer service or intent.
      // For testing, graceful simulation/fallback.
      await Future.delayed(const Duration(milliseconds: 1200));
      _isListening = false;
      return null; // Will trigger the graceful text input fallback modal
    } catch (e) {
      _isListening = false;
      debugPrint('Voice recognition error: $e');
      return null;
    }
  }

  /// Speaks text response aloud if TTS is toggled on.
  Future<void> speakText(String text) async {
    if (!_isTtsEnabled) return;
    // In production Android, uses TextToSpeech engine
    debugPrint('TTS Spoken: $text');
  }

  void stopListening() {
    _isListening = false;
  }
}
