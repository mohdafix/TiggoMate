import 'package:flutter_test/flutter_test.dart';
import 'package:tiggomate_app/src/ai/ai_service.dart';
import 'package:tiggomate_app/src/ai/chery_club_knowledge.dart';

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

    test('routes to Direct OpenAI correctly even when custom host text is left in settings', () {
      final config = AiConfigResolver.resolve(
        apiKey: 'sk-proj-xyz123',
        provider: 'Direct OpenAI',
        modelInput: 'gpt-5-nano',
        customHost: 'https://router.kedaimurah.my/v1',
      );

      expect(config.endpoint, 'https://api.openai.com/v1/chat/completions');
      expect(config.model, 'gpt-5-nano');
      expect(config.providerName, 'OpenAI');
      expect(config.headers['authorization'], 'Bearer sk-proj-xyz123');
    });
  });

  group('CheryClubKnowledge Database & Q&A Matching Tests', () {
    test('contains verified emergency contacts and official helplines', () {
      expect(CheryClubKnowledge.emergencyContacts.containsKey('Chery Auto Assist 24/7 Hotline'), isTrue);
      expect(CheryClubKnowledge.emergencyContacts['Chery Auto Assist 24/7 Hotline'], '+60 3-7989 0349');
      expect(CheryClubKnowledge.emergencyContacts.containsKey('Kota Damansara (KD) SC Hotline'), isTrue);
      expect(CheryClubKnowledge.emergencyContacts.containsKey('SSH - Li Ling Insurance & Road Tax'), isTrue);
    });

    test('knowledgePromptBlock formats structured guidelines for LLM system prompt', () {
      final block = CheryClubKnowledge.knowledgePromptBlock;
      expect(block.contains('Chery Auto Assist 24/7 Hotline: +60 3-7989 0349'), isTrue);
      expect(block.contains('Charging Cable Stuck / Cannot Unplug Gun'), isTrue);
      expect(block.contains('Puchong Service Centre'), isTrue);
      expect(block.contains('Kota Damansara'), isTrue);
      expect(block.contains('230 kPa'), isTrue);
      expect(block.contains('RM50/day'), isTrue);
    });

    test('matches charger stuck query and instructs unlocking doors', () {
      final match = CheryClubKnowledge.matchQuestion('my charger is stuck how to unplug the gun?');
      expect(match, isNotNull);
      expect(match!.id, 'charger_stuck');
      expect(match.quickAnswer.contains('Unlock the car doors'), isTrue);
    });

    test('matches roadside assistance and towing inquiries', () {
      final match = CheryClubKnowledge.matchQuestion('car breakdown need towing how to call roadside assist');
      expect(match, isNotNull);
      expect(match!.id, 'roadside_assist');
      expect(match.quickAnswer.contains('+60 3-7989 0349'), isTrue);
      expect(match.detailedAdvice.contains('RM50/day'), isTrue);
    });

    test('matches fuel flap stuck issue with warranty advice', () {
      final match = CheryClubKnowledge.matchQuestion('why my fuel flap stuck cannot open');
      expect(match, isNotNull);
      expect(match!.id, 'fuel_flap_stuck');
      expect(match.quickAnswer.contains('warranty claim'), isTrue);
    });

    test('matches rear cabin / boot rattle to sunroof and parcel shelf', () {
      final match = CheryClubKnowledge.matchQuestion('strange loose sound boot noise over bumps');
      expect(match, isNotNull);
      expect(match!.id, 'boot_rattle');
      expect(match.detailedAdvice.contains('sunroof'), isTrue);
    });

    test('matches tyre pressure questions and cold target spec', () {
      final match = CheryClubKnowledge.matchQuestion('what is the best tyre pressure in kpa?');
      expect(match, isNotNull);
      expect(match!.id, 'tpms_tyre_pressure');
      expect(match.quickAnswer.contains('230 kPa'), isTrue);
    });

    test('matches emergency manual boot opening when battery dead', () {
      final match = CheryClubKnowledge.matchQuestion('bagaimana nak buka boot kalau bateri kong?');
      expect(match, isNotNull);
      expect(match!.id, 'emergency_boot_release');
      expect(match.quickAnswer.contains('Fold down the rear passenger seats'), isTrue);
    });

    test('matches Puchong SC closure notice and redirects to Kota Damansara', () {
      final match = CheryClubKnowledge.matchQuestion('is puchong sc closed?');
      expect(match, isNotNull);
      expect(match!.id, 'sc_updates');
      expect(match.quickAnswer.contains('Kota Damansara'), isTrue);
    });

    test('matches windscreen insurance coverage recommendations', () {
      final match = CheryClubKnowledge.matchQuestion('how much windscreen insurance coverage for tiggo 7');
      expect(match, isNotNull);
      expect(match!.id, 'windscreen_insurance');
      expect(match.quickAnswer.contains('RM 3,500 to RM 5,000'), isTrue);
    });
  });
}

