import 'package:flutter_test/flutter_test.dart';

import 'package:edged/data/services/auth_service.dart';
import 'package:edged/data/services/games_service.dart';
import 'package:edged/engine/models/chat_models.dart';
import 'package:edged/engine/models/model_tier.dart';
import 'package:edged/engine/models/prompt_format.dart';
import 'package:edged/engine/services/skills_engine.dart';

void main() {
  test('ModelTier catalogue has all 7 tiers and recommended Qwen2.5-VL 3B', () {
    expect(ModelTier.availableTiers.length, 7);
    final rec = ModelTier.getById('qwen25-vl-3b');
    expect(rec, isNotNull);
    expect(rec!.isRecommended, isTrue);
    expect(rec.supportsVision, isTrue);
    expect(rec.supportsDocumentQa, isTrue);

    final lite = ModelTier.getById('smolvlm2-500m');
    expect(lite!.supportsDocumentQa, isFalse);
  });

  test('PromptFormat ChatML appends /no_think when suppressThinkingMode is true', () {
    final prompt = PromptFormat.chatML.formatPrompt(
      systemPrompt: 'You are Edged.',
      messages: const [ChatMessage(role: ChatRole.user, content: 'Hello')],
      suppressThinkingMode: true,
    );
    expect(prompt, contains('Hello /no_think'));
    expect(prompt, endsWith('<|im_start|>assistant\n'));
  });

  test('Built-in skills and games match specification counts', () {
    expect(SkillsEngine.builtInSkills.length, 6);
    expect(GamesService.builtInGames.length, 9);
    expect(AuthService.allCountries.length, 25);
  });
}
