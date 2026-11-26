import 'package:flutter_test/flutter_test.dart';

import 'package:edged/data/services/agent_service.dart';
import 'package:edged/data/services/auth_service.dart';
import 'package:edged/engine/models/chat_models.dart';
import 'package:edged/engine/models/model_tier.dart';
import 'package:edged/engine/models/prompt_format.dart';
import 'package:edged/engine/services/skills_engine.dart';

void main() {
  test('ModelTier catalogue has all 7 tiers and recommended Qwen3.5 2B', () {
    expect(ModelTier.availableTiers.length, 7);
    final rec = ModelTier.getById('qwen35-2b');
    expect(rec, isNotNull);
    expect(rec!.isRecommended, isTrue);
    expect(rec.supportsVision, isFalse);
    expect(rec.supportsDocumentQa, isTrue);

    final lite = ModelTier.getById('qwen35-0.8b');
    expect(lite!.supportsDocumentQa, isFalse);
  });

  test('PromptFormat ChatML appends /no_think when suppressThinkingMode is true', () {
    final prompt = PromptFormat.chatML.formatPrompt(
      systemPrompt: 'You are Edged.',
      messages: const [ChatMessage(role: ChatRole.user, content: 'Hello')],
      suppressThinkingMode: true,
    );
    expect(prompt, contains('Hello /no_think'));
    expect(prompt, endsWith('<|im_start|>assistant\n<think>\n\n</think>\n\n'));
  });

  test('Built-in skills and countries match specification counts', () {
    expect(SkillsEngine.builtInSkills.length, 6);
    expect(AuthService.allCountries.length, 25);
  });

  test('AgentService folds built-in skills and automation agents together', () {
    expect(AgentService.builtInAgents.length, 12);
    expect(AgentService.getBuiltInById('scheduled_email')?.hasTool(AgentTool.email), isTrue);
    expect(AgentService.getBuiltInById('scheduled_whatsapp')?.hasTool(AgentTool.whatsapp), isTrue);
    expect(AgentService.getBuiltInById('rag_researcher')?.hasTool(AgentTool.rag), isTrue);
    expect(AgentService.getBuiltInById('ocr_extractor')?.hasTool(AgentTool.ocr), isTrue);
    expect(AgentService.getBuiltInById('summarizer'), isNotNull);

    final encoded = AgentTool.encodeList([AgentTool.rag, AgentTool.email]);
    expect(AgentTool.parseList(encoded), [AgentTool.rag, AgentTool.email]);
  });
}
