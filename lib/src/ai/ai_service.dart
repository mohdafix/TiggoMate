import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'chery_club_knowledge.dart';

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
      'accept': 'application/json',
    };

    final isExplicitOpenAi = provider == 'Direct OpenAI';
    final isExplicitOpenRouter = provider == 'OpenRouter';
    final isExplicitGroq = provider == 'Groq';
    final isExplicitGemini = provider == 'Google Gemini';
    final isExplicitCustom = provider == 'Custom Backend';

    final trimmedHost = customHost.trim().replaceAll(RegExp(r'/+$'), '');
    final hasCustomHost = trimmedHost.isNotEmpty &&
        trimmedHost != 'http://10.0.2.2:8088' &&
        !trimmedHost.contains('openrouter.ai');

    String normalizeCustomEndpoint(String host) {
      if (host.endsWith('/chat/completions') || host.endsWith('/chat')) {
        return host;
      }
      if (host.endsWith('/v1')) {
        return '$host/chat/completions';
      }
      return '$host/v1/chat/completions';
    }

    // Custom Backend or explicit custom host provided with OpenRouter / Auto-Detect
    if (isExplicitCustom || (hasCustomHost && (isExplicitOpenRouter || provider == 'Auto-Detect'))) {
      final hostToUse = trimmedHost.isNotEmpty ? trimmedHost : 'http://10.0.2.2:8088';
      endpoint = normalizeCustomEndpoint(hostToUse);
      providerName = isExplicitOpenRouter ? 'OpenRouter Relay' : 'Custom Backend';
      if (key.isNotEmpty) headers['authorization'] = 'Bearer $key';
      headers['HTTP-Referer'] = 'https://tiggomate.app';
      headers['X-Title'] = 'TiggoMate';
      if (model.startsWith('openai/')) {
        model = model.replaceFirst('openai/', '');
      }
    } else if (isExplicitOpenAi ||
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
      final modelLower = config.model.toLowerCase();
      final isReasoningOrGpt5 = modelLower.startsWith('o1') ||
          modelLower.startsWith('o3') ||
          modelLower.startsWith('gpt-5') ||
          modelLower.contains('r1') ||
          modelLower.contains('qwq') ||
          modelLower.contains('reasoning');
      final isOpenAi = config.providerName.toLowerCase().contains('openai');

      final payloadMap = <String, dynamic>{
        "model": config.model,
        "messages": [
          {"role": isReasoningOrGpt5 ? "developer" : "user", "content": "ping"}
        ],
        "stream": false,
      };

      if (isReasoningOrGpt5) {
        payloadMap["max_completion_tokens"] = 150;
        payloadMap["reasoning_effort"] = "low";
      } else if (isOpenAi) {
        payloadMap["max_completion_tokens"] = 50;
      } else {
        payloadMap["max_tokens"] = 15;
      }

      Future<(int, String)> postJson(Map<String, dynamic> data) async {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
        final request = await client.postUrl(Uri.parse(config.endpoint));
        config.headers.forEach((k, v) => request.headers.set(k, v));
        final utf8Payload = utf8.encode(jsonEncode(data));
        request.headers.contentLength = utf8Payload.length;
        request.add(utf8Payload);
        final res = await request.close();
        final b = await res.transform(utf8.decoder).join();
        return (res.statusCode, b);
      }

      var (statusCode, body) = await postJson(payloadMap);

      // Self-healing parameter fallback for modern / legacy proxies
      if (statusCode == 400) {
        bool needRetry = false;
        if (body.contains('reasoning_effort') && payloadMap.containsKey('reasoning_effort')) {
          payloadMap.remove('reasoning_effort');
          needRetry = true;
        }
        if ((body.contains('developer') || body.contains('role')) && isReasoningOrGpt5) {
          payloadMap["messages"] = [
            {"role": "user", "content": "ping"}
          ];
          needRetry = true;
        }
        if (body.contains('max_tokens') && body.contains('max_completion_tokens')) {
          payloadMap.remove('max_tokens');
          payloadMap['max_completion_tokens'] = isReasoningOrGpt5 ? 150 : 50;
          needRetry = true;
        } else if (body.contains('max_completion_tokens') && !payloadMap.containsKey('max_tokens')) {
          payloadMap.remove('max_completion_tokens');
          payloadMap.remove('reasoning_effort');
          payloadMap['max_tokens'] = 15;
          needRetry = true;
        }
        if (body.contains('temperature') && payloadMap.containsKey('temperature')) {
          payloadMap.remove('temperature');
          needRetry = true;
        }
        if (needRetry) {
          final retry = await postJson(payloadMap);
          statusCode = retry.$1;
          body = retry.$2;
        }
      }
      stopwatch.stop();

      if (statusCode == 200) {
        return (
          ok: true,
          message: 'Connected to ${config.providerName}! Model ${config.model} responded.',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        String errorMsg = 'HTTP $statusCode';
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
    int odometerKm = 0,
    String? nextServiceInfo,
    String? lastServiceInfo,
    String? tripInfo,
    String? liveStatusBlock,
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
- Battery: 18.3 kWh LFP (CATL cells), 350V
- Current Battery SoC: $batteryPct%
- Current Odometer: $odometerKm km${lastServiceInfo != null && lastServiceInfo.isNotEmpty ? '\n- Service History & Records:\n  $lastServiceInfo' : ''}${nextServiceInfo != null ? '\n- $nextServiceInfo' : ''}${tripInfo != null && tripInfo.isNotEmpty ? '\n- Trip History & Driving Records:\n  $tripInfo' : ''}
- Factory Battery Specs: 18.3 kWh LFP (CATL cells), 350V (NEDC ~100 km EV, WLTP ~82 km EV when fully charged)
- Factory Fuel Tank: 60L RON95 Petrol
${liveStatusBlock != null ? '\nLive Vehicle Status (real-time from vehicle CAN telematics):\n- $liveStatusBlock\n' : ''}
- AC Charging: Type 2 (6.6 kW, ~3 hours 0-100%)
- DC Fast Charging: CCS2 (supports ~30 mins 30-80%)
- Tariff: TNB Domestic Tariff A (Off-peak: 22:00-08:00 @ RM 0.280/kWh, Normal: RM 0.516/kWh)
- Connected CAN-bus Telematics: Vehicle T-Box

IMPORTANT INSTRUCTIONS:
0. REAL-TIME RANGE & TELEMETRICS GROUNDING:
- When discussing or calculating vehicle range, fuel distance, battery autonomy, or travel capabilities, ALWAYS rely strictly on the real-time values provided in 'Live Vehicle Status' above (Live Total Combined Range, EV Range, Petrol Range).
- NEVER invent or use a static 920 km range. The vehicle's ECU dynamically calculates the real combined range based on active fuel level, battery state-of-charge, and actual consumption.
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

3. Use the Current Odometer, Service History & Records (last service date, completed services, upcoming appointments), Trip History & Driving Records (latest completed trip, distances, EV percentage, energy consumed, costs, active drive, etc.), and the Live Vehicle Status block above directly whenever relevant (last trip, recent drives, service history, mileage, tyre pressure, doors, climate, battery, fuel, GPS/parked state, etc.) -- never say you don't have access to trip history, driving logs, last service date, or vehicle details when provided above. When the user asks about their last trip or driving log, state the exact details from the Trip History above (route/title, distance in km, EV ratio %, and cost in RM). If no trips are recorded yet in the logbook, state that no trips have been logged yet and guide them to record a drive or tap "+ Add Trip" in the LOG tab.

4. MALAYSIA CHERY TIGGO 7 PHEV CLUB KNOWLEDGE & DIRECTORY:
${CheryClubKnowledge.knowledgePromptBlock}
''';

    final modelLower = config.model.toLowerCase();
    final isReasoningOrGpt5 = modelLower.startsWith('o1') ||
        modelLower.startsWith('o3') ||
        modelLower.startsWith('gpt-5') ||
        modelLower.contains('r1') ||
        modelLower.contains('qwq') ||
        modelLower.contains('reasoning');
    final isOpenAi = config.providerName.toLowerCase().contains('openai');

    final roleName = isReasoningOrGpt5 ? 'developer' : 'system';
    final messages = <Map<String, String>>[
      {"role": roleName, "content": systemPrompt},
      ...history,
      {"role": "user", "content": prompt},
    ];

    final payloadMap = <String, dynamic>{
      "model": config.model,
      "messages": messages,
      "stream": false,
    };

    if (isReasoningOrGpt5) {
      // Reasoning models (gpt-5-nano, o1, o3) use completion tokens for internal thought
      // tokens + visible answer. Budget ample tokens (3500) and set reasoning_effort to low.
      payloadMap["max_completion_tokens"] = 3500;
      payloadMap["reasoning_effort"] = "low";
    } else if (isOpenAi) {
      payloadMap["max_completion_tokens"] = 1200;
    } else {
      payloadMap["max_tokens"] = 600;
    }

    if (!isReasoningOrGpt5) {
      payloadMap["temperature"] = 0.6;
    }

    Future<(int, String)> postJson(Map<String, dynamic> data) async {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);
      final request = await client.postUrl(Uri.parse(config.endpoint));
      config.headers.forEach((k, v) => request.headers.set(k, v));
      final utf8Payload = utf8.encode(jsonEncode(data));
      request.headers.contentLength = utf8Payload.length;
      request.add(utf8Payload);
      final res = await request.close();
      final b = await res.transform(utf8.decoder).join();
      return (res.statusCode, b);
    }

    var (statusCode, body) = await postJson(payloadMap);

    // Self-healing parameter fallback for modern / legacy models
    if (statusCode == 400) {
      bool needRetry = false;
      if (body.contains('reasoning_effort') && payloadMap.containsKey('reasoning_effort')) {
        payloadMap.remove('reasoning_effort');
        needRetry = true;
      }
      if ((body.contains('developer') || body.contains('role')) && isReasoningOrGpt5) {
        messages[0] = {"role": "system", "content": systemPrompt};
        payloadMap["messages"] = messages;
        needRetry = true;
      }
      if (body.contains('max_tokens') && body.contains('max_completion_tokens')) {
        payloadMap.remove('max_tokens');
        payloadMap['max_completion_tokens'] = isReasoningOrGpt5 ? 3500 : 1200;
        needRetry = true;
      } else if (body.contains('max_completion_tokens') && !payloadMap.containsKey('max_tokens')) {
        payloadMap.remove('max_completion_tokens');
        payloadMap.remove('reasoning_effort');
        payloadMap['max_tokens'] = 600;
        needRetry = true;
      }
      if (body.contains('temperature') && payloadMap.containsKey('temperature')) {
        payloadMap.remove('temperature');
        needRetry = true;
      }
      if (needRetry) {
        final retry = await postJson(payloadMap);
        statusCode = retry.$1;
        body = retry.$2;
      }
    }

    if (statusCode == 200) {
      final trimmedBody = body.trim();
      // Handle SSE stream fallback if the proxy streams despite stream:false
      if (trimmedBody.startsWith('data:')) {
        final buffer = StringBuffer();
        for (final line in const LineSplitter().convert(trimmedBody)) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          final jsonStr = trimmed.substring(5).trim();
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
          try {
            final chunk = jsonDecode(jsonStr);
            if (chunk is Map && chunk.containsKey('choices')) {
              final choices = chunk['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'] as Map?;
                final content = delta?['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  buffer.write(content);
                } else {
                  final reasoning = delta?['reasoning_content'] as String?;
                  if (reasoning != null && reasoning.isNotEmpty && buffer.isEmpty) {
                    buffer.write(reasoning);
                  }
                }
              }
            }
          } catch (_) {}
        }
        final result = buffer.toString().trim();
        if (result.isNotEmpty) return result;
      }

      try {
        final data = jsonDecode(body);
        final extracted = _safeExtractText(data);
        if (extracted != null && extracted.isNotEmpty) {
          return extracted;
        }

        if (data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
          final first = (data['choices'] as List).first;
          if (first is Map && first['finish_reason'] == 'length') {
            return 'Model hit token limit during internal reasoning. Please ask a shorter question or use a standard conversational model like gpt-4o-mini.';
          }
        }
      } catch (err) {
        // Safe fallback
      }
      return 'No response generated from ${config.providerName}.';
    } else {
      String err = 'HTTP $statusCode';
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

  static String? _safeExtractText(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      final s = data.trim();
      return s.isNotEmpty ? s : null;
    }
    if (data is List) {
      final buf = StringBuffer();
      for (final item in data) {
        final t = _safeExtractText(item);
        if (t != null && t.isNotEmpty) buf.write(t);
      }
      final res = buf.toString().trim();
      return res.isNotEmpty ? res : null;
    }
    if (data is Map) {
      // 1. Direct content or text fields
      for (final key in ['content', 'text', 'response', 'output']) {
        if (data.containsKey(key)) {
          final t = _safeExtractText(data[key]);
          if (t != null && t.isNotEmpty) return t;
        }
      }
      // 2. Choices list
      if (data['choices'] is List && (data['choices'] as List).isNotEmpty) {
        for (final item in (data['choices'] as List)) {
          final t = _safeExtractText(item);
          if (t != null && t.isNotEmpty) return t;
        }
      }
      // 3. Nested message or delta
      for (final key in ['message', 'delta']) {
        if (data.containsKey(key)) {
          final t = _safeExtractText(data[key]);
          if (t != null && t.isNotEmpty) return t;
        }
      }
      // 4. Reasoning / thought fields
      for (final key in ['reasoning_content', 'reasoning', 'thought']) {
        if (data.containsKey(key)) {
          final t = _safeExtractText(data[key]);
          if (t != null && t.isNotEmpty) return t;
        }
      }
      // 5. Refusal
      if (data['refusal'] != null) {
        final r = _safeExtractText(data['refusal']);
        if (r != null && r.isNotEmpty) return 'AI Refusal: $r';
      }
    }
    return null;
  }
}

/// Fully offline, on-device voice command recognition using a bundled
/// sherpa-onnx streaming Zipformer model. No popup, no dependency on the
/// phone having a system speech recognition service registered -- the
/// model (~74MB) is downloaded once on first use and cached locally.
/// Falls back to the Android system speech popup only if the model can't
/// be loaded (e.g. first-run download failed with no internet) or the mic
/// can't be opened.
class VoiceRecognitionService {
  static const _modelBaseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/main';
  static const _encoderFile = 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx';
  static const _decoderFile = 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx';
  static const _joinerFile = 'joiner-epoch-99-avg-1-chunk-16-left-128.onnx';
  static const _tokensFile = 'tokens.txt';
  static const _modelFiles = [_encoderFile, _decoderFile, _joinerFile, _tokensFile];

  static sherpa_onnx.OnlineRecognizer? _recognizer;
  static bool _sherpaInitCalled = false;
  static final AudioRecorder _audioRecorder = AudioRecorder();
  static const _fallbackChannel = MethodChannel('com.tiggomate/speech');

  static Future<String?> startListening() async {
    // 1. Try native platform speech first (Zero external downloads, instant, multi-language)
    final nativeResult = await _tryFallbackPopup();
    if (nativeResult != null && nativeResult.trim().isNotEmpty) {
      return nativeResult.trim();
    }
    // 2. Fall back to local neural engine if available
    final local = await _tryLocalEngine();
    if (local != null && local.trim().isNotEmpty) return local.trim();
    return null;
  }

  /// Streams microphone audio into the local sherpa-onnx recognizer and
  /// returns the transcript once an endpoint (pause) is detected.
  static Future<String?> _tryLocalEngine() async {
    StreamSubscription<Uint8List>? sub;
    sherpa_onnx.OnlineStream? stream;
    try {
      final recognizer = await _ensureRecognizer();
      if (recognizer == null) return null;
      if (!await _audioRecorder.hasPermission()) return null;

      stream = recognizer.createStream();
      final completer = Completer<String?>();
      String lastText = '';

      final audioStream = await _audioRecorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
      );

      sub = audioStream.listen((chunk) {
        stream!.acceptWaveform(samples: _bytesToFloat32(chunk), sampleRate: 16000);
        while (recognizer.isReady(stream)) {
          recognizer.decode(stream);
        }
        final text = recognizer.getResult(stream).text.trim();
        if (text.isNotEmpty) lastText = text;

        if (recognizer.isEndpoint(stream) && !completer.isCompleted) {
          completer.complete(lastText.isNotEmpty ? lastText : null);
        }
      });

      final text = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => lastText.isNotEmpty ? lastText : null,
      );
      return (text != null && text.isNotEmpty) ? text : null;
    } catch (e) {
      return null;
    } finally {
      await sub?.cancel();
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      stream?.free();
    }
  }

  static Future<sherpa_onnx.OnlineRecognizer?> _ensureRecognizer() async {
    if (_recognizer != null) return _recognizer;
    try {
      if (!_sherpaInitCalled) {
        sherpa_onnx.initBindings();
        _sherpaInitCalled = true;
      }

      final dir = await getApplicationSupportDirectory();
      final modelDir = Directory(p.join(dir.path, 'voice_model'));
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      for (final name in _modelFiles) {
        final file = File(p.join(modelDir.path, name));
        if (!await file.exists() || await file.length() == 0) {
          final res = await http.get(Uri.parse('$_modelBaseUrl/$name'));
          if (res.statusCode != 200) return null;
          await file.writeAsBytes(res.bodyBytes);
        }
      }

      final modelConfig = sherpa_onnx.OnlineModelConfig(
        transducer: sherpa_onnx.OnlineTransducerModelConfig(
          encoder: p.join(modelDir.path, _encoderFile),
          decoder: p.join(modelDir.path, _decoderFile),
          joiner: p.join(modelDir.path, _joinerFile),
        ),
        tokens: p.join(modelDir.path, _tokensFile),
        modelType: 'zipformer2',
      );

      _recognizer = sherpa_onnx.OnlineRecognizer(sherpa_onnx.OnlineRecognizerConfig(model: modelConfig));
      return _recognizer;
    } catch (e) {
      return null;
    }
  }

  static Float32List _bytesToFloat32(Uint8List bytes, [Endian endian = Endian.little]) {
    final values = Float32List(bytes.length ~/ 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length ~/ 2; i++) {
      values[i] = data.getInt16(i * 2, endian) / 32768.0;
    }
    return values;
  }

  /// Model/mic unavailable -- fall back to the system speech activity so
  /// voice input still works.
  static Future<String?> _tryFallbackPopup() async {
    try {
      final res = await _fallbackChannel.invokeMethod<String>('startListening');
      return res?.trim();
    } catch (e) {
      return null;
    }
  }
}
