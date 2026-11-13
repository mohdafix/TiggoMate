import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ai/ai_service.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../service/voice_assistant_service.dart';
import 'settings_screen.dart';
import 'vehicle_radar_sheet.dart';

/// Interactive Floating Voice Assistant HUD Bottom Sheet
/// Inspired by DasHub's zero-latency bilingual in-car voice assistant with real-time feedback.
class VoiceAssistantHudSheet extends StatefulWidget {
  final VehicleRepository repository;
  final VoidCallback? onOpenRadar;

  const VoiceAssistantHudSheet({
    super.key,
    required this.repository,
    this.onOpenRadar,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleRepository repository,
    VoidCallback? onOpenRadar,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceAssistantHudSheet(
        repository: repository,
        onOpenRadar: onOpenRadar,
      ),
    );
  }

  @override
  State<VoiceAssistantHudSheet> createState() => _VoiceAssistantHudSheetState();
}

class _VoiceAssistantHudSheetState extends State<VoiceAssistantHudSheet> with SingleTickerProviderStateMixin {
  final VoiceAssistantService _voiceService = VoiceAssistantService.instance;
  late final AnimationController _pulseCtrl;
  String _selectedLang = 'ms-MY';
  bool _isExecutingAction = false;
  String? _executionResult;
  String? _aiResponseText;
  bool _isAiQuerying = false;
  Timer? _autoApplyTimer;
  int _countdownSecs = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _voiceService.addListener(_onVoiceServiceUpdate);

    // Auto-start listening on sheet open with haptic bump
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.mediumImpact();
      _startVoiceSession();
    });
  }

  @override
  void dispose() {
    _autoApplyTimer?.cancel();
    _pulseCtrl.dispose();
    _voiceService.removeListener(_onVoiceServiceUpdate);
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    super.dispose();
  }

  void _onVoiceServiceUpdate() {
    if (!mounted) return;
    setState(() {});

    final cmd = _voiceService.matchedCommand;
    // Auto-apply hands-free countdown for vehicle remote commands
    if (_voiceService.phase == VoiceAssistantPhase.success &&
        cmd != null &&
        cmd.opcode != null &&
        !_isExecutingAction &&
        _executionResult == null &&
        _autoApplyTimer == null &&
        _countdownSecs == 0) {
      _startAutoApplyCountdown(cmd.opcode!, cmd.title);
    }

    // If an action was recognized and needs external AI resolution
    if (_voiceService.phase == VoiceAssistantPhase.success &&
        cmd != null &&
        cmd.type == VoiceCommandType.generalAiQuestion &&
        !_isAiQuerying &&
        _aiResponseText == null) {
      _resolveAiQuestion(cmd.description);
    }
  }

  void _startAutoApplyCountdown(String opcode, String label) {
    _autoApplyTimer?.cancel();
    setState(() => _countdownSecs = 3);
    _autoApplyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSecs <= 1) {
        timer.cancel();
        _autoApplyTimer = null;
        setState(() => _countdownSecs = 0);
        _executeOpcode(opcode, label);
      } else {
        setState(() => _countdownSecs--);
      }
    });
  }

  void _cancelAutoApply() {
    _autoApplyTimer?.cancel();
    _autoApplyTimer = null;
    setState(() => _countdownSecs = 0);
  }

  void _startVoiceSession() {
    _cancelAutoApply();
    _aiResponseText = null;
    _executionResult = null;
    _isExecutingAction = false;
    _isAiQuerying = false;
    _voiceService.startListening(lang: _selectedLang);
  }

  Future<void> _executeOpcode(String opcode, String label) async {
    setState(() {
      _isExecutingAction = true;
      _executionResult = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final res = await widget.repository.sendRemoteCommandWithResult(opcode);
      if (!mounted) return;
      setState(() {
        _isExecutingAction = false;
        if (res.success) {
          _executionResult = 'Berjaya! Arahan "$label" diterima T-Box.';
          HapticFeedback.lightImpact();
        } else {
          _executionResult = 'Gagal: ${res.message}';
          HapticFeedback.heavyImpact();
        }
      });
      if (res.success) {
        _voiceService.speak('Selesai. $label telah dilaksanakan.');
      } else {
        _voiceService.speak('Maaf, arahan gagal dilaksanakan.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExecutingAction = false;
        _executionResult = 'Ralat sambungan: $e';
      });
    }
  }

  Future<void> _resolveAiQuestion(String prompt) async {
    setState(() => _isAiQuerying = true);
    final telemetry = widget.repository.currentTelemetry;

    try {
      final settings = await SettingsService.load();
      if (settings.aiApiKey.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _isAiQuerying = false;
          _aiResponseText = 'Sila tetapkan Kunci AI API dalam skrin Tetapan.';
        });
        _voiceService.speak('Sila tetapkan kunci AI API dalam Tetapan.');
        return;
      }

      final res = await AiConfigResolver.queryAi(
        prompt: prompt,
        apiKey: settings.aiApiKey,
        provider: settings.aiProvider,
        modelInput: settings.aiModel,
        customHost: settings.aiHost,
        batteryPct: telemetry.batteryPct,
        odometerKm: telemetry.odometerKm,
      );
      if (!mounted) return;
      setState(() {
        _isAiQuerying = false;
        _aiResponseText = res;
      });
      _voiceService.speak(res);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiQuerying = false;
        _aiResponseText = 'Maaf, tidak dapat memproses maklumat AI buat masa ini.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phase = _voiceService.phase;
    final rms = _voiceService.rmsLevel;
    final matchedCmd = _voiceService.matchedCommand;

    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? const Color(0xFF263244) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 36,
            spreadRadius: 4,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header bar: Title, Language Selector, Spoken Mute Toggle
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.graphic_eq_rounded, color: Color(0xFF06B6D4), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'TiggoMate Voice',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF06B6D4),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Language selector
                  PopupMenuButton<String>(
                    tooltip: 'Tukar Bahasa',
                    initialValue: _selectedLang,
                    onSelected: (val) {
                      setState(() => _selectedLang = val);
                      _startVoiceSession();
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language_rounded, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                          const SizedBox(width: 5),
                          Text(
                            _selectedLang == 'ms-MY' ? 'BM / EN' : 'English',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'ms-MY',
                        child: Text('Bahasa Melayu & English (Auto)'),
                      ),
                      const PopupMenuItem(
                        value: 'en-MY',
                        child: Text('English (Malaysian)'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // TTS Voice Feedback toggle
                  IconButton(
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    icon: Icon(
                      _voiceService.voiceFeedbackEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: _voiceService.voiceFeedbackEnabled
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    tooltip: _voiceService.voiceFeedbackEnabled ? 'Voice Feedback ON' : 'Muted',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _voiceService.voiceFeedbackEnabled = !_voiceService.voiceFeedbackEnabled;
                        if (!_voiceService.voiceFeedbackEnabled) {
                          _voiceService.stopSpeaking();
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Real-Time Animated Waveform & Mic Core (DasHub Style)
              _buildVoiceWaveformCenter(isDark, phase, rms),
              const SizedBox(height: 16),

              // Status Banner & Live Transcript
              _buildTranscriptionBox(isDark, phase),
              const SizedBox(height: 16),

              // Matched Command Card / Execution Button
              if (matchedCmd != null) _buildCommandCard(context, isDark, matchedCmd),

              // AI Thinking / Answer Card
              if (_isAiQuerying || _aiResponseText != null) _buildAiResponseCard(isDark),

              // Quick Suggestion Chips (when idle or listening)
              if (matchedCmd == null && !_isAiQuerying) ...[
                const SizedBox(height: 12),
                _buildQuickChips(isDark),
              ],

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceWaveformCenter(bool isDark, VoiceAssistantPhase phase, double rms) {
    final isListening = phase == VoiceAssistantPhase.listening;
    final isProcessing = phase == VoiceAssistantPhase.processing;
    final isError = phase == VoiceAssistantPhase.error;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isListening) {
          _voiceService.stopListening();
        } else {
          _startVoiceSession();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              if (isListening) ...[
                const Color(0xFF06B6D4).withValues(alpha: 0.28 + (rms * 0.35)),
                Colors.transparent,
              ] else if (isProcessing) ...[
                const Color(0xFFD2F835).withValues(alpha: 0.25),
                Colors.transparent,
              ] else if (isError) ...[
                Colors.redAccent.withValues(alpha: 0.25),
                Colors.transparent,
              ] else ...[
                (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                Colors.transparent,
              ],
            ],
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Waveform Bars (7 vertical lines that bounce with speech RMS)
              if (isListening)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(7, (i) {
                    final factor = 1.0 - ((i - 3).abs() * 0.22);
                    final barHeight = (12.0 + (rms * 54.0 * factor)).clamp(8.0, 68.0);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 65),
                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                      width: 5,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: i % 2 == 0 ? const Color(0xFF06B6D4) : const Color(0xFFD2F835),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }),
                )
              else
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isError
                        ? Colors.redAccent.withValues(alpha: 0.2)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    border: Border.all(
                      color: isError
                          ? Colors.redAccent
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isProcessing
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.8,
                              color: Color(0xFF06B6D4),
                            ),
                          )
                        : Icon(
                            isError ? Icons.mic_off_rounded : Icons.mic_rounded,
                            size: 30,
                            color: isError
                                ? Colors.redAccent
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptionBox(bool isDark, VoiceAssistantPhase phase) {
    String headline = 'Sebut arahan kereta atau soalan...';
    Color headlineColor = isDark ? Colors.white54 : Colors.black54;

    if (phase == VoiceAssistantPhase.listening) {
      headline = 'Mendengar... (Sebut apa sahaja)';
      headlineColor = const Color(0xFF06B6D4);
    } else if (phase == VoiceAssistantPhase.processing) {
      headline = 'Memproses ucapan...';
      headlineColor = const Color(0xFFD2F835);
    } else if (phase == VoiceAssistantPhase.error) {
      headline = _voiceService.errorMessage;
      headlineColor = Colors.redAccent;
    }

    final displayText = _voiceService.partialText.isNotEmpty
        ? _voiceService.partialText
        : _voiceService.finalText;

    return Column(
      children: [
        Text(
          headline,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: headlineColor,
          ),
        ),
        if (displayText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              '"$displayText"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommandCard(BuildContext context, bool isDark, VoiceCommand cmd) {
    final hasOpcode = cmd.opcode != null;
    final isCharger = cmd.type == VoiceCommandType.findCharger;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.45),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cmd.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cmd.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_executionResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _executionResult!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (hasOpcode) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isExecutingAction
                          ? null
                          : () {
                              _cancelAutoApply();
                              _executeOpcode(cmd.opcode!, cmd.title);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: _isExecutingAction
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isExecutingAction
                            ? 'Menghantar ke T-Box...'
                            : (_countdownSecs > 0
                                ? 'Auto-Laksana ($_countdownSecs s)'
                                : 'Laksanakan Sekarang'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                if (_countdownSecs > 0) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _cancelAutoApply,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (isCharger) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (widget.onOpenRadar != null) {
                    widget.onOpenRadar!();
                  } else {
                    VehicleRadarSheet.show(
                      context,
                      telemetry: widget.repository.currentTelemetry,
                      onHornFlash: () => widget.repository.sendRemoteCommandWithResult(CarLinkoOpcodes.findCar),
                      repository: widget.repository,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.ev_station_rounded, size: 18),
                label: const Text(
                  'Buka Radar Pengecas DC',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiResponseCard(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF06B6D4), size: 16),
              const SizedBox(width: 8),
              Text(
                'Jawapan Pembantu Tiggo',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const Spacer(),
              if (_isAiQuerying)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isAiQuerying
                ? 'Sedang menganalisis telemetri kenderaan...'
                : (_aiResponseText ?? ''),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips(bool isDark) {
    final chips = [
      {'label': '🪟 Vent 20mm', 'text': 'buka tingkap sikit mod ventilasi'},
      {'label': '🔒 Kunci Kereta', 'text': 'kunci kereta'},
      {'label': '❄️ Pasang A/C', 'text': 'pasang aircond 22'},
      {'label': '🔋 Baki Bateri', 'text': 'berapa baki bateri dan jarak'},
      {'label': '⚡ Cari DC Charger', 'text': 'cari tempat cas'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: chips.map((c) {
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            final telemetry = widget.repository.currentTelemetry;
            final cmd = VoiceAssistantService.parseCommand(c['text']!, telemetry);
            setState(() {
              _voiceService.stopListening();
              _voiceService.startListening();
            });
            // Simulate command match
            Future.delayed(const Duration(milliseconds: 150), () {
              if (!mounted) return;
              setState(() {
                _voiceService.stopListening();
                // Speak and show command
                if (_voiceService.voiceFeedbackEnabled) {
                  _voiceService.speak(cmd.spokenFeedbackMs);
                }
              });
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              c['label']!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
