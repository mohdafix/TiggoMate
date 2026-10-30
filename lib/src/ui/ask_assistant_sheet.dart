import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/ai_service.dart';
import '../theme/app_tokens.dart';

/// Screen 6: Grounded Tiggo 7 PHEV AI Assistant Modal Sheet
class AskAssistantSheet extends StatefulWidget {
  final String carPlate;
  final String vehicleModel;
  final int batteryPct;
  final Function(String command)? onExecuteCommand;

  const AskAssistantSheet({
    super.key,
    this.carPlate = 'VRT 3342',
    this.vehicleModel = 'CHERY TIGGO 7 PHEV · CSH',
    this.batteryPct = 24,
    this.onExecuteCommand,
  });

  static Future<void> show(
    BuildContext context, {
    String carPlate = 'VRT 3342',
    String vehicleModel = 'CHERY TIGGO 7 PHEV · CSH',
    int batteryPct = 24,
    Function(String command)? onExecuteCommand,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0A0B0E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AskAssistantSheet(
        carPlate: carPlate,
        vehicleModel: vehicleModel,
        batteryPct: batteryPct,
        onExecuteCommand: onExecuteCommand,
      ),
    );
  }

  @override
  State<AskAssistantSheet> createState() => _AskAssistantSheetState();
}

class _AskAssistantSheetState extends State<AskAssistantSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _actionConfirmed = false;
  bool _isAiThinking = false;
  bool _isListening = false;

  String? _apiKey;
  String? _provider;
  String? _model;
  String? _host;

  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadAiConfig();
  }

  Future<void> _loadAiConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _apiKey = prefs.getString('tm_ai_api_key');
        _provider = prefs.getString('tm_ai_provider');
        _model = prefs.getString('tm_ai_model');
        _host = prefs.getString('tm_ai_host');
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _listenVoice() async {
    HapticFeedback.mediumImpact();
    setState(() => _isListening = true);

    try {
      final recognized = await VoiceRecognitionService.startListening();
      if (!mounted) return;
      setState(() => _isListening = false);

      if (recognized != null && recognized.trim().isNotEmpty) {
        _inputController.text = recognized;
        _sendMessage(recognized);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice Command: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Map<String, dynamic>? _matchActionFromPrompt(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('open') && (lower.contains('window') || lower.contains('tingkap'))) {
      return {
        'id': 'windows_open',
        'title': 'Open All Windows',
        'desc': 'Lowers all 4 power windows for cabin heat escape',
        'icon': Icons.window_outlined,
      };
    } else if (lower.contains('close') && (lower.contains('window') || lower.contains('tingkap'))) {
      return {
        'id': 'windows_close',
        'title': 'Close All Windows',
        'desc': 'Fully raises and secures all 4 power windows',
        'icon': Icons.window_outlined,
      };
    } else if (lower.contains('vent') && lower.contains('window')) {
      return {
        'id': 'windows_vent',
        'title': 'Vent Windows (20mm)',
        'desc': 'Crack opens windows 20mm for heat dissipation',
        'icon': Icons.air_rounded,
      };
    } else if ((lower.contains('open') || lower.contains('turn on') || lower.contains('start') || lower.contains('buka') || lower.contains('pasang')) &&
        (lower.contains('aircond') || lower.contains('ac') || lower.contains('climate') || lower.contains('hawa'))) {
      return {
        'id': 'climate_on',
        'title': 'Turn On Aircond (22°C)',
        'desc': 'Starts A/C compressor and dual-zone cabin pre-cooling',
        'icon': Icons.ac_unit_rounded,
      };
    } else if ((lower.contains('turn off') || lower.contains('stop') || lower.contains('close') || lower.contains('padam') || lower.contains('tutup')) &&
        (lower.contains('aircond') || lower.contains('ac') || lower.contains('climate'))) {
      return {
        'id': 'climate_off',
        'title': 'Turn Off Aircond',
        'desc': 'Shuts down A/C compressor and cabin blowers',
        'icon': Icons.power_settings_new_rounded,
      };
    } else if (lower.contains('sunroof') && (lower.contains('open') || lower.contains('buka'))) {
      return {
        'id': 'sunroof_open',
        'title': 'Open Panoramic Sunroof',
        'desc': 'Slides open glass sunroof for sky view',
        'icon': Icons.wb_sunny_outlined,
      };
    } else if (lower.contains('sunroof') && (lower.contains('close') || lower.contains('tutup'))) {
      return {
        'id': 'sunroof_close',
        'title': 'Close Panoramic Sunroof',
        'desc': 'Closes glass sunroof and sunshade curtain',
        'icon': Icons.close_fullscreen_rounded,
      };
    } else if (lower.contains('lock') || lower.contains('kunci')) {
      return {
        'id': 'door_lock',
        'title': 'Lock Vehicle Doors',
        'desc': 'Locks all 4 doors and arms vehicle alarm',
        'icon': Icons.lock_rounded,
      };
    } else if (lower.contains('unlock') || lower.contains('buka kunci')) {
      return {
        'id': 'door_unlock',
        'title': 'Unlock Vehicle Doors',
        'desc': 'Unlocks all vehicle doors',
        'icon': Icons.lock_open_rounded,
      };
    } else if (lower.contains('trunk') || lower.contains('tailgate') || lower.contains('boot')) {
      return {
        'id': 'trunk_open',
        'title': 'Open Power Tailgate',
        'desc': 'Unlatches power rear tailgate',
        'icon': Icons.car_rental_rounded,
      };
    } else if (lower.contains('charge') || lower.contains('charging') || lower.contains('caj')) {
      return {
        'id': 'schedule_charging',
        'title': 'Schedule Smart Charging (90% Target)',
        'desc': 'Arms charging optimizer during TNB off-peak (22:00)',
        'icon': Icons.ev_station_rounded,
      };
    } else if (lower.contains('tnb') || lower.contains('tariff') || lower.contains('rate') || lower.contains('kadar')) {
      return {
        'id': 'check_tnb',
        'title': 'Check TNB Smart Meter Rate',
        'desc': 'Reads live TNB Domestic Tariff A and off-peak schedule',
        'icon': Icons.bolt_rounded,
      };
    } else if (lower.contains('engine') || lower.contains('enjin')) {
      return {
        'id': 'engine_start',
        'title': 'Remote Start 1.5T Engine',
        'desc': 'Starts 1.5T engine for battery/cabin conditioning',
        'icon': Icons.speed_rounded,
      };
    } else if (lower.contains('locate') || lower.contains('find car') || lower.contains('cari')) {
      return {
        'id': 'locate',
        'title': 'Locate Vehicle (Radar & Horn)',
        'desc': 'Flashes hazard lights and sounds horn',
        'icon': Icons.radar_rounded,
      };
    }
    return null;
  }

  IconData _getIconForAction(String id) {
    switch (id) {
      case 'windows_open':
      case 'windows_close':
      case 'windows_vent':
        return Icons.window_outlined;
      case 'climate_on':
      case 'climate_off':
        return Icons.ac_unit_rounded;
      case 'sunroof_open':
      case 'sunroof_close':
        return Icons.wb_sunny_outlined;
      case 'door_lock':
        return Icons.lock_rounded;
      case 'door_unlock':
        return Icons.lock_open_rounded;
      case 'trunk_open':
        return Icons.car_rental_rounded;
      case 'schedule_charging':
        return Icons.ev_station_rounded;
      case 'check_tnb':
        return Icons.bolt_rounded;
      case 'engine_start':
      case 'engine_stop':
        return Icons.speed_rounded;
      case 'locate':
        return Icons.radar_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _inputController.clear();
      _isAiThinking = true;
    });
    _scrollToBottom();

    final hasApiKey = _apiKey != null && _apiKey!.trim().isNotEmpty;

    if (hasApiKey) {
      try {
        final history = <Map<String, String>>[];
        for (final m in _messages.reversed.take(6).toList().reversed) {
          if (m['role'] == 'user' && m['text'] != null) {
            history.add({'role': 'user', 'content': m['text'] as String});
          } else if (m['role'] == 'assistant' && m['text'] != null) {
            history.add({'role': 'assistant', 'content': m['text'] as String});
          }
        }
        if (history.isNotEmpty && history.last['content'] == text) {
          history.removeLast();
        }

        final aiReply = await AiConfigResolver.queryAi(
          prompt: text,
          apiKey: _apiKey!,
          provider: _provider ?? 'openrouter',
          modelInput: _model ?? '',
          customHost: _host ?? '',
          batteryPct: widget.batteryPct,
          carPlate: widget.carPlate,
          history: history,
        );

        if (!mounted) return;

        Map<String, dynamic>? action;
        String cleanText = aiReply;

        final actionRegex = RegExp(r'\[ACTION:\s*([a-zA-Z0-9_]+)\s*\|\s*([^|]+)\s*\|\s*([^\]]+)\]');
        final match = actionRegex.firstMatch(aiReply);
        if (match != null) {
          final actId = match.group(1)!.trim();
          action = {
            'id': actId,
            'title': match.group(2)!.trim(),
            'desc': match.group(3)!.trim(),
            'icon': _getIconForAction(actId),
          };
          cleanText = aiReply.replaceFirst(match.group(0)!, '').trim();
        } else {
          action = _matchActionFromPrompt(text);
        }

        setState(() {
          _isAiThinking = false;
          _messages.add({
            'role': 'assistant',
            'text': cleanText,
            'action': action,
            'citation': 'AI Copilot · ${(_provider ?? 'OpenRouter').toUpperCase()}',
            'soc': '${widget.batteryPct}%',
          });
        });
        _scrollToBottom();
        return;
      } catch (e) {
        debugPrint('Live AI call failed: $e, falling back to local automotive rules.');
      }
    }

    // Fallback: Intelligent onboard vehicle logic with full action integration
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final promptAction = _matchActionFromPrompt(text);
    String replyText;
    String citation;

    final lower = text.toLowerCase();
    if (promptAction != null) {
      if (promptAction['id'] == 'windows_open') {
        replyText =
            'Ready to lower all 4 power windows for cabin heat venting. Confirm below to transmit CAN-bus command via CarLinko T-Box.';
        citation = 'CarLinko Glazing Control';
      } else if (promptAction['id'] == 'windows_close') {
        replyText =
            'Ready to fully close and seal all 4 windows with anti-pinch protection. Confirm below to execute.';
        citation = 'CarLinko Glazing Control';
      } else if (promptAction['id'] == 'climate_on') {
        replyText =
            'Cabin pre-cooling requested for 22°C. The vehicle will use EV battery power to condition the cabin before your trip.';
        citation = 'Climate Comfort Telematics';
      } else if (promptAction['id'] == 'climate_off') {
        replyText = 'Ready to shut down the A/C compressor and ventilation blowers.';
        citation = 'Climate Comfort Telematics';
      } else if (promptAction['id'] == 'schedule_charging') {
        replyText =
            'Smart charging optimization ready. Recommended start: **22:00** during TNB Off-Peak rate (**RM 0.280/kWh**) to reach **90% SoC** by 01:45.';
        citation = 'Smart Charging Optimizer';
      } else if (promptAction['id'] == 'check_tnb') {
        replyText =
            'Your current electricity profile: **TNB Domestic Tariff A**.\n- Off-Peak window: **22:00 – 08:00 (RM 0.280/kWh)**\n- Normal daytime rate: **RM 0.516/kWh**\nTap below to inspect live smart meter telemetry and consumption.';
        citation = 'myTNB Smart Meter';
      } else {
        replyText = 'Action prepared for **${widget.vehicleModel}** (${widget.carPlate}). Tap confirm below to transmit to vehicle.';
        citation = 'T-Box Remote Dispatch';
      }
    } else if (lower.contains('cost') || lower.contains('last trip')) {
      replyText =
          'Last trip was **Home → Bangsar South (26 km)**. Driven 100% on EV using 5.1 kWh. Total electricity cost: **RM 1.43** (saved **RM 2.80** vs RON95 petrol).';
      citation = 'Trips Logbook';
    } else if (lower.contains('service') || lower.contains('1,000')) {
      replyText =
          'Your **1,000 km 1st Inspection** is complimentary (FOC labour & parts). Includes CarLinko telematics pairing, 3DHT & BMS scan, and HV harness torque inspection.';
      citation = 'Official Service Gazette';
    } else {
      final tip = hasApiKey
          ? ''
          : '\n\n💡 *Tip: Add your OpenRouter or Gemini API key in Settings & Profile for unrestricted real-time AI reasoning.*';
      replyText =
          'Command processed for **Chery Tiggo 7 PHEV CSH** with battery at **${widget.batteryPct}% SoC**.$tip';
      citation = 'Tiggo 7 Onboard Telematics';
    }

    setState(() {
      _isAiThinking = false;
      _messages.add({
        'role': 'assistant',
        'text': replyText,
        'action': promptAction,
        'citation': citation,
        'soc': '${widget.batteryPct}%',
      });
    });
    _scrollToBottom();
  }

  /// Custom rich markdown formatter to replace raw `**` with bold styled spans
  Widget _buildFormattedMarkdown(String text, TextStyle baseStyle, Color accentColor, bool isDark) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Headings (###)
      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            trimmed.substring(4).trim(),
            style: baseStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0A0B0E),
            ),
          ),
        ));
        continue;
      }

      // Numbered List (1. , 2. )
      final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (numMatch != null) {
        final numStr = numMatch.group(1) ?? '1';
        final content = numMatch.group(2) ?? '';
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$numStr.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: _parseInlineMarkdown(content, baseStyle, accentColor, isDark),
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      // Bullet List (- or * or •)
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('• ')) {
        final content = trimmed.substring(2).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 8, left: 2),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: _parseInlineMarkdown(content, baseStyle, accentColor, isDark),
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      // Regular Paragraph with Inline Bold Handling
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            children: _parseInlineMarkdown(trimmed, baseStyle, accentColor, isDark),
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  /// Parses inline bold syntax (`**text**`), italic (`*text*`), and code (` `code` `) into styled TextSpans with 0 raw asterisks
  List<InlineSpan> _parseInlineMarkdown(String text, TextStyle baseStyle, Color accentColor, bool isDark) {
    final spans = <InlineSpan>[];
    final boldStyle = baseStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : const Color(0xFF0A0B0E),
    );
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: (baseStyle.fontSize ?? 13) * 0.9,
      fontWeight: FontWeight.w600,
      color: accentColor,
      backgroundColor: isDark ? const Color(0xFF1E222B) : const Color(0xFFF1F5F9),
    );

    // Regex matches **bold**, `code`, or *italic*
    final tokenPattern = RegExp(r'(\*\*(.+?)\*\*|`([^`]+)`|\*([^*]+)\*)');
    int lastMatchEnd = 0;

    for (final match in tokenPattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final fullMatch = match.group(0)!;
      if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        final boldContent = match.group(2) ?? '';
        spans.add(TextSpan(text: boldContent, style: boldStyle));
      } else if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
        final codeContent = match.group(3) ?? '';
        spans.add(TextSpan(text: codeContent, style: codeStyle));
      } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
        final italicContent = match.group(4) ?? '';
        spans.add(TextSpan(text: italicContent, style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }

  Widget _buildInstructionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color limeAccent,
    required Color cardCol,
    required Color borderCol,
    required Color textColor,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: limeAccent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? const Color(0xFF0A0B0E) : Colors.white;
    final cardCol = isDark ? const Color(0xFF12141A) : const Color(0xFFF8FAFC);
    final borderCol = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);
    final limeAccent = context.tokens.accent;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasApiKey = _apiKey != null && _apiKey!.trim().isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: borderCol,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Top Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vehicleModel,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'ASK · GROUNDED ON TIGGO 7 MANUAL',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: hasApiKey ? limeAccent.withValues(alpha: 0.15) : borderCol,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              hasApiKey ? 'LIVE AI' : 'OFFLINE',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: hasApiKey ? limeAccent : textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Divider(color: borderCol, height: 16),

          // Chat Messages List
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (_messages.isEmpty) ...[
                  // Premium Greetings & Instructions Banner
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: limeAccent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.auto_awesome, color: limeAccent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tiggo AI Copilot Online',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Chery Tiggo 7 PHEV Intelligent Assistant',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'How can I assist your drive today? You can ask technical questions or instruct me to control your vehicle directly:',
                          style: TextStyle(
                            fontSize: 13,
                            color: textPrimary.withValues(alpha: 0.88),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Quick Action Guidance Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildInstructionChip(
                              icon: Icons.ac_unit_rounded,
                              label: 'Pre-cool cabin to 22°C',
                              onTap: () => _sendMessage('turn on aircond to 22°C'),
                              limeAccent: limeAccent,
                              cardCol: bgCol,
                              borderCol: borderCol,
                              textColor: textPrimary,
                            ),
                            _buildInstructionChip(
                              icon: Icons.window_outlined,
                              label: 'Open all windows',
                              onTap: () => _sendMessage('open all window'),
                              limeAccent: limeAccent,
                              cardCol: bgCol,
                              borderCol: borderCol,
                              textColor: textPrimary,
                            ),
                            _buildInstructionChip(
                              icon: Icons.ev_station_rounded,
                              label: 'Schedule 90% smart charge',
                              onTap: () => _sendMessage('schedule charging 90% tonight'),
                              limeAccent: limeAccent,
                              cardCol: bgCol,
                              borderCol: borderCol,
                              textColor: textPrimary,
                            ),
                            _buildInstructionChip(
                              icon: Icons.bolt_rounded,
                              label: 'Check TNB tariff & smart meter',
                              onTap: () => _sendMessage('check current tnb rate'),
                              limeAccent: limeAccent,
                              cardCol: bgCol,
                              borderCol: borderCol,
                              textColor: textPrimary,
                            ),
                            _buildInstructionChip(
                              icon: Icons.speed_rounded,
                              label: 'How does 3DHT hybrid mode work?',
                              onTap: () => _sendMessage('how does the 3DHT hybrid transmission work in Chery Tiggo 7 PHEV?'),
                              limeAccent: limeAccent,
                              cardCol: bgCol,
                              borderCol: borderCol,
                              textColor: textPrimary,
                            ),
                            _buildInstructionChip(
                              icon: Icons.lock_outline_rounded,
                              label: 'Lock vehicle doors',
                              onTap: () => _sendMessage('lock doors'),
                              limeAccent: limeAccent,
                              cardCol: bgCol,
                              borderCol: borderCol,
                              textColor: textPrimary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                ..._messages.map((m) {
                  final role = m['role'];
                  if (role == 'user') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('›  ', style: TextStyle(color: limeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              m['text'] ?? '',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (role == 'action_proposal') {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardCol,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                            child: Text(
                              'PROPOSED ACTION',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: textMuted,
                              ),
                            ),
                          ),
                          Divider(height: 1, color: borderCol),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['target'] ?? '22°C',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text('target', style: TextStyle(fontSize: 10, color: textMuted)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['start'] ?? '07:35',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text('start', style: TextStyle(fontSize: 10, color: textMuted)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['duration'] ?? '10 min',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(m['mode'] ?? 'EV only', style: TextStyle(fontSize: 10, color: textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: borderCol),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Target adjusted.')),
                                    );
                                  },
                                  child: Text('Adjust', style: TextStyle(color: textMuted, fontSize: 13)),
                                ),
                              ),
                              Container(width: 1, height: 36, color: borderCol),
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    HapticFeedback.heavyImpact();
                                    setState(() => _actionConfirmed = true);
                                    widget.onExecuteCommand?.call('climate_on');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Pre-cooling command transmitted to CarLinko T-Box ✓')),
                                    );
                                  },
                                  child: Text(
                                    _actionConfirmed ? 'Confirmed ✓' : 'Confirm',
                                    style: TextStyle(
                                      color: limeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  } else {
                    final actionData = m['action'] as Map<String, dynamic>?;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Formatted Markdown text (replacing raw ** with true bold text)
                          _buildFormattedMarkdown(
                            m['text'] ?? '',
                            TextStyle(
                              fontSize: 13.5,
                              color: textPrimary.withValues(alpha: 0.9),
                              height: 1.45,
                            ),
                            limeAccent,
                            isDark,
                          ),

                          // Interactive Action Execution Card
                          if (actionData != null)
                            _ActionExecutionCard(
                              actionId: actionData['id'] as String? ?? 'action',
                              title: actionData['title'] as String? ?? 'Action',
                              description: actionData['desc'] as String? ?? '',
                              icon: (actionData['icon'] as IconData?) ?? Icons.bolt_rounded,
                              onExecute: (id) => widget.onExecuteCommand?.call(id),
                              cardCol: cardCol,
                              borderCol: borderCol,
                              limeAccent: limeAccent,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                            ),

                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (m['citation'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: cardCol,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: borderCol),
                                  ),
                                  child: Text(
                                    m['citation'],
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 9.5,
                                      color: textMuted,
                                    ),
                                  ),
                                ),
                              if (m['soc'] != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: cardCol,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: borderCol),
                                  ),
                                  child: Text(
                                    'Your SoC · ${m['soc']}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 9.5,
                                      color: textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  }
                }),

                if (_isAiThinking)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(limeAccent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Copilot is reasoning...',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_messages.isNotEmpty) ...[
                  const SizedBox(height: 10),

                  // TRY Quick Slash Command Chips
                  Text(
                    'QUICK COMMANDS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  _SlashCommandChip(
                    text: '/open all window',
                    onTap: () => _sendMessage('open all window'),
                    textMuted: textMuted,
                  ),
                  _SlashCommandChip(
                    text: '/charge 90% tonight',
                    onTap: () => _sendMessage('/charge 90% tonight'),
                    textMuted: textMuted,
                  ),
                  _SlashCommandChip(
                    text: '/check current tnb rate',
                    onTap: () => _sendMessage('check current tnb rate'),
                    textMuted: textMuted,
                  ),
                  _SlashCommandChip(
                    text: '/turn on aircond to 22°',
                    onTap: () => _sendMessage('turn on aircond to 22°'),
                    textMuted: textMuted,
                  ),
                ],
              ],
            ),
          ),

          // Bottom Input Bar with Voice & Submit
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: BoxDecoration(
              color: cardCol,
              border: Border(top: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgCol,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isListening ? const Color(0xFFFF5252) : borderCol,
                        width: _isListening ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('›  ', style: TextStyle(color: limeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            style: TextStyle(fontSize: 13.5, color: textPrimary),
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: _isListening ? 'Listening... Speak command' : 'Ask or type / for commands',
                              hintStyle: TextStyle(
                                fontSize: 12.5,
                                color: _isListening ? const Color(0xFFFF5252) : textMuted,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Voice Mic Button
                InkWell(
                  onTap: _listenVoice,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isListening ? const Color(0xFFFF5252) : (isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isListening ? const Color(0xFFFF5252) : borderCol,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        size: 20,
                        color: _isListening ? Colors.white : limeAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Send Button
                GestureDetector(
                  onTap: () => _sendMessage(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: limeAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        '↑',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0A0B0E),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Action Execution Card inside the AI chat flow
class _ActionExecutionCard extends StatefulWidget {
  final String actionId;
  final String title;
  final String description;
  final IconData icon;
  final Function(String)? onExecute;
  final Color cardCol;
  final Color borderCol;
  final Color limeAccent;
  final Color textPrimary;
  final Color textMuted;

  const _ActionExecutionCard({
    required this.actionId,
    required this.title,
    required this.description,
    required this.icon,
    this.onExecute,
    required this.cardCol,
    required this.borderCol,
    required this.limeAccent,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  State<_ActionExecutionCard> createState() => _ActionExecutionCardState();
}

class _ActionExecutionCardState extends State<_ActionExecutionCard> {
  bool _executed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.cardCol,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _executed ? const Color(0xFF10B981) : widget.limeAccent.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (_executed ? const Color(0xFF10B981) : widget.limeAccent).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _executed ? Icons.check_circle_outline_rounded : widget.icon,
                  size: 18,
                  color: _executed ? const Color(0xFF10B981) : widget.limeAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: widget.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: TextStyle(fontSize: 11, color: widget.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _executed
                  ? null
                  : () {
                      HapticFeedback.heavyImpact();
                      widget.onExecute?.call(widget.actionId);
                      setState(() => _executed = true);
                    },
              icon: Icon(
                _executed ? Icons.check : Icons.send_rounded,
                size: 15,
                color: _executed ? Colors.white70 : const Color(0xFF0A0B0E),
              ),
              label: Text(
                _executed ? 'Executed ✓ (Transmitted to CarLinko T-Box)' : 'Confirm & Execute Action',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _executed ? Colors.white70 : const Color(0xFF0A0B0E),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _executed ? const Color(0xFF10B981) : widget.limeAccent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlashCommandChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color textMuted;

  const _SlashCommandChip({
    required this.text,
    required this.onTap,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
