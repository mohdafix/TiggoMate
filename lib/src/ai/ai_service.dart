import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Resolved configuration for live AI requests.
class ResolvedAiConfig {
  final String endpoint;
  final String model;
  final Map<String, String> headers;
  final String providerName;

  const ResolvedAiConfig({
    required this.endpoint,
    required this.model,
    required this.headers,
    required this.providerName,
  });
}

/// Helper to automatically detect and route AI requests to the right provider.
class AiConfigResolver {
  static ResolvedAiConfig resolve({
    required String apiKey,
    required String provider,
    required String modelInput,
    String customHost = '',
  }) {
    final key = apiKey.trim();
    String model = modelInput.trim().isEmpty ? 'gpt-4o-mini' : modelInput.trim();
    String endpoint;
    String providerName;
    final headers = <String, String>{
      'content-type': 'application/json; charset=utf-8',
    };

    final isExplicitOpenAi = provider == 'Direct OpenAI';
    final isExplicitOpenRouter = provider == 'OpenRouter';
    final isExplicitGroq = provider == 'Groq';
    final isExplicitGemini = provider == 'Google Gemini';

    // Auto-detect or explicit OpenAI
    if (isExplicitOpenAi ||
        (provider == 'Auto-Detect' &&
            (key.startsWith('sk-proj-') ||
                (key.startsWith('sk-') && !key.startsWith('sk-or-') && !key.startsWith('sk-ant-')))) ||
        (!isExplicitOpenRouter && key.startsWith('sk-proj-'))) {
      endpoint = 'https://api.openai.com/v1/chat/completions';
      providerName = 'OpenAI';
      headers['authorization'] = 'Bearer $key';
      if (model.startsWith('openai/')) {
        model = model.replaceFirst('openai/', '');
      }
    } else if (isExplicitGroq || (provider == 'Auto-Detect' && key.startsWith('gsk_'))) {
      endpoint = 'https://api.groq.com/openai/v1/chat/completions';
      providerName = 'Groq';
      headers['authorization'] = 'Bearer $key';
      if (model == 'gpt-4o-mini') model = 'llama-3.1-8b-instant';
    } else if (isExplicitGemini || (provider == 'Auto-Detect' && key.startsWith('AIzaSy'))) {
      endpoint = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
      providerName = 'Google Gemini';
      headers['authorization'] = 'Bearer $key';
      if (model == 'gpt-4o-mini') model = 'gemini-1.5-flash';
    } else if (provider == 'Custom Backend' ||
        (customHost.isNotEmpty && provider != 'OpenRouter' && provider != 'Auto-Detect')) {
      endpoint = customHost.endsWith('/chat/completions') || customHost.endsWith('/chat')
          ? customHost
          : '$customHost/v1/chat/completions';
      providerName = 'Custom Backend';
      if (key.isNotEmpty) headers['authorization'] = 'Bearer $key';
    } else {
      // Default to OpenRouter
      endpoint = 'https://openrouter.ai/api/v1/chat/completions';
      providerName = 'OpenRouter';
      headers['authorization'] = 'Bearer $key';
      headers['HTTP-Referer'] = 'https://tiggomate.app';
      headers['X-Title'] = 'TiggoMate';
    }

    return ResolvedAiConfig(
      endpoint: endpoint,
      model: model,
      headers: headers,
      providerName: providerName,
    );
  }

  /// Ping the resolved AI service to test credentials and latency.
  static Future<({bool ok, String message, int latencyMs})> testConnection({
    required String apiKey,
    required String provider,
    required String modelInput,
    String customHost = '',
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return (ok: false, message: 'Please enter an API key first.', latencyMs: 0);
    }

    final config = resolve(
      apiKey: key,
      provider: provider,
      modelInput: modelInput,
      customHost: customHost,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final request = await client.postUrl(Uri.parse(config.endpoint));
      config.headers.forEach((k, v) => request.headers.set(k, v));

      final payload = jsonEncode({
        "model": config.model,
        "messages": [
          {"role": "user", "content": "ping"}
        ],
        "max_tokens": 5,
      });

      final utf8Payload = utf8.encode(payload);
      request.headers.contentLength = utf8Payload.length;
      request.add(utf8Payload);
      final res = await request.close();
      stopwatch.stop();

      final body = await res.transform(utf8.decoder).join();

      if (res.statusCode == 200) {
        return (
          ok: true,
          message: 'Connected to ${config.providerName}! Model ${config.model} responded.',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        String errorMsg = 'HTTP ${res.statusCode}';
        try {
          final data = jsonDecode(body);
          if (data is Map && data.containsKey('error')) {
            final e = data['error'];
            if (e is Map && e.containsKey('message')) {
              errorMsg = e['message'].toString();
            } else {
              errorMsg = e.toString();
            }
          }
        } catch (_) {}

        return (
          ok: false,
          message: errorMsg,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return (
        ok: false,
        message: 'Network error connecting to ${config.providerName}: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Send live prompt to the user's configured AI model with Tiggo 7 PHEV grounding.
  static Future<String> queryAi({
    required String prompt,
    required String apiKey,
    required String provider,
    required String modelInput,
    String customHost = '',
    int batteryPct = 24,
    String carPlate = 'VRT 3342',
    List<Map<String, String>> history = const [],
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception('NO_API_KEY');
    }

    final config = resolve(
      apiKey: key,
      provider: provider,
      modelInput: modelInput,
      customHost: customHost,
    );

    final systemPrompt = '''
You are the onboard AI Copilot for Chery Tiggo 7 PHEV CSH (Chery Super Hybrid) in Malaysia.
Vehicle Telematics & Specs:
- License Plate: $carPlate
- Powertrain: 1.5T Dedicated Hybrid Engine (156 PS) + Dual Electric Motors + 3DHT (Total: 326 PS / 545 Nm)
- Battery: 19.27 kWh LFP (CATL cells), 350V
- Current Battery SoC: $batteryPct%
- EV Range: ~82 km (NEDC ~100 km)
- Fuel Tank: 60L RON95 Petrol
- Total Hybrid Range: ~920 km
- AC Charging: Type 2 (6.6 kW, ~3 hours 0-100%)
- DC Fast Charging: CCS2 (supports ~30 mins 30-80%)
- Tariff: TNB Domestic Tariff A (Off-peak: 22:00-08:00 @ RM 0.280/kWh, Normal: RM 0.516/kWh)
- Connected CAN-bus Telematics: Chery CarLinko T-Box

IMPORTANT INSTRUCTIONS:
1. VEHICLE CONTROL ACTION TRIGGER:
If the user's intent is to control the car or trigger an app feature (such as opening/closing windows, turning on aircond/climate, scheduling charging, checking TNB rate, locking/unlocking doors, opening trunk/tailgate, opening sunroof, remote engine start), you MUST output an action tag on its very own first line:
[ACTION: <action_id> | <Action Title> | <Short Description>]
Supported action IDs:
- [ACTION: windows_open | Open All Windows | Lowers all 4 power windows for cabin heat escape]
- [ACTION: windows_close | Close All Windows | Fully raises and secures all 4 power windows]
- [ACTION: windows_vent | Vent Windows (20mm) | Crack opens windows 20mm for ventilation]
- [ACTION: climate_on | Turn On Aircond (22°C) | Starts A/C compressor and dual-zone cabin pre-cooling]
- [ACTION: climate_off | Turn Off Aircond | Shuts down A/C compressor and cabin blowers]
- [ACTION: sunroof_open | Open Panoramic Sunroof | Slides open glass sunroof for sky view]
- [ACTION: sunroof_close | Close Panoramic Sunroof | Closes glass sunroof and sunshade curtain]
- [ACTION: door_lock | Lock Doors | Locks all 4 doors and arms vehicle alarm]
- [ACTION: door_unlock | Unlock Doors | Unlocks all vehicle doors]
- [ACTION: trunk_open | Open Tailgate | Unlatches power rear tailgate]
- [ACTION: schedule_charging | Schedule Smart Charging | Sets 90% charge target during TNB off-peak (22:00)]
- [ACTION: check_tnb | Check TNB Tariff | Retrieves live smart meter tariff and bill details]
- [ACTION: engine_start | Remote Engine Start | Starts 1.5T engine for battery/cabin conditioning]
- [ACTION: locate | Find Vehicle | Flashes hazard lights and sounds horn]

2. TEXT FORMATTING:
Keep responses concise (1 to 2 short paragraphs or lists), direct, and automotive-accurate. Use standard markdown (**bold** for key terms, numbered lists 1., 2. or bullet points -).
Answer in the user's language (English or Bahasa Melayu).
''';

    final messages = <Map<String, String>>[
      {"role": "system", "content": systemPrompt},
      ...history,
      {"role": "user", "content": prompt},
    ];

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);
    final request = await client.postUrl(Uri.parse(config.endpoint));
    config.headers.forEach((k, v) => request.headers.set(k, v));

    final payload = jsonEncode({
      "model": config.model,
      "messages": messages,
      "max_tokens": 450,
      "temperature": 0.6,
    });

    final utf8Payload = utf8.encode(payload);
    request.headers.contentLength = utf8Payload.length;
    request.add(utf8Payload);
    final res = await request.close();

    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final first = choices[0] as Map<String, dynamic>;
        final message = first['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          return content.trim();
        }
      }
      return 'No response generated from ${config.providerName}.';
    } else {
      String err = 'HTTP ${res.statusCode}';
      try {
        final data = jsonDecode(body);
        if (data is Map && data.containsKey('error')) {
          final e = data['error'];
          if (e is Map && e.containsKey('message')) {
            err = e['message'].toString();
          } else {
            err = e.toString();
          }
        }
      } catch (_) {}
      throw Exception('$err (${config.providerName})');
    }
  }
}

/// Native Voice Command Recognition Bridge via Android SpeechRecognizer / iOS Speech
class VoiceRecognitionService {
  static const _channel = MethodChannel('com.tiggomate/speech');

  /// Trigger native speech input popup and return transcribed text.
  static Future<String?> startListening() async {
    try {
      final res = await _channel.invokeMethod<String>('startListening');
      return res?.trim();
    } catch (e) {
      return null;
    }
  }
}
