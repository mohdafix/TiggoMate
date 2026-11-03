import 'package:flutter_test/flutter_test.dart';
import 'package:tiggomate_app/src/ai/ai_service.dart';

void main() {
  group('AiConfigResolver Unit Tests', () {
    test('routes custom router.kedaimurah.my URL correctly with OpenRouter selected', () {
      final config = AiConfigResolver.resolve(
        apiKey: 'sk-testkey123',
        provider: 'OpenRouter',
        modelInput: 'claude-opus-5.5',
        customHost: 'https://router.kedaimurah.my/v1',
      );

      expect(config.endpoint, 'https://router.kedaimurah.my/v1/chat/completions');
      expect(config.model, 'claude-opus-5.5');
      expect(config.headers['authorization'], 'Bearer sk-testkey123');
      expect(config.providerName, 'OpenRouter Relay');
    });

    test('routes custom host with Custom Backend and handles trailing slashes', () {
      final config = AiConfigResolver.resolve(
        apiKey: 'sk-my-key',
        provider: 'Custom Backend',
        modelInput: 'claude-opus-5.5',
        customHost: 'https://router.kedaimurah.my/v1/',
      );

      expect(config.endpoint, 'https://router.kedaimurah.my/v1/chat/completions');
      expect(config.model, 'claude-opus-5.5');
      expect(config.headers['authorization'], 'Bearer sk-my-key');
    });

    test('routes to official OpenRouter when no custom host is provided', () {
      final config = AiConfigResolver.resolve(
        apiKey: 'sk-or-v1-abc123456789',
        provider: 'OpenRouter',
        modelInput: 'anthropic/claude-3.5-haiku',
      );

      expect(config.endpoint, 'https://openrouter.ai/api/v1/chat/completions');
      expect(config.providerName, 'OpenRouter');
      expect(config.headers['authorization'], 'Bearer sk-or-v1-abc123456789');
    });

    test('routes to Direct OpenAI correctly', () {
      final config = AiConfigResolver.resolve(
        apiKey: 'sk-proj-xyz123',
        provider: 'Direct OpenAI',
        modelInput: 'openai/gpt-4o',
      );

      expect(config.endpoint, 'https://api.openai.com/v1/chat/completions');
      expect(config.model, 'gpt-4o');
      expect(config.headers['authorization'], 'Bearer sk-proj-xyz123');
    });
  });
}
