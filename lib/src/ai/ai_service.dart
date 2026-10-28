import 'dart:convert';
import 'dart:io';

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
}
