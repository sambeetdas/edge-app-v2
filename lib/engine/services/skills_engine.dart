import '../models/chat_models.dart';
import 'chat_engine.dart';

class SkillsEngine {
  final ChatEngine _chatEngine;

  SkillsEngine(this._chatEngine);

  static const List<SkillDefinition> builtInSkills = [
    SkillDefinition(
      id: 'summarizer',
      name: 'Summarizer',
      description: 'Condense long text into key points',
      icon: '📋',
      category: 'Writing',
      inputPlaceholder: 'Paste the text you want to summarize...',
      systemPrompt:
          'You are an expert summarizer. Read the provided text carefully and produce a clear, concise summary that captures the main points and key takeaways. Use bullet points for clarity. Keep the summary to about 20-30% of the original length.',
    ),
    SkillDefinition(
      id: 'translator',
      name: 'Translator',
      description: 'Translate text between languages',
      icon: '🌐',
      category: 'Language',
      inputPlaceholder:
          'Enter text to translate...\n\nTip: Specify the target language, e.g. "Translate to Spanish: Hello world"',
      systemPrompt:
          'You are a professional translator. Translate the given text accurately while preserving tone, context, and nuances. If the target language is not specified, translate to English.',
    ),
    SkillDefinition(
      id: 'code_explainer',
      name: 'Code Explainer',
      description: 'Explain code in simple terms',
      icon: '💻',
      category: 'Development',
      inputPlaceholder: 'Paste the code you want explained...',
      systemPrompt:
          'You are a patient programming teacher. Explain the provided code in simple, clear language that a beginner could understand. Break down each important part, explain what it does and why.',
    ),
    SkillDefinition(
      id: 'writing_assistant',
      name: 'Writing Assistant',
      description: 'Improve and polish your writing',
      icon: '✏️',
      category: 'Writing',
      inputPlaceholder: 'Paste your text to improve...',
      systemPrompt:
          'You are a professional writing assistant. Improve the provided text by enhancing clarity, flow, grammar, and style while preserving the original meaning and voice.',
    ),
    SkillDefinition(
      id: 'grammar_fixer',
      name: 'Grammar Fixer',
      description: 'Fix grammar and spelling errors',
      icon: '✅',
      category: 'Writing',
      inputPlaceholder: 'Paste text with errors to fix...',
      systemPrompt:
          'You are a grammar and spelling expert. Fix all grammatical errors, spelling mistakes, and punctuation issues in the provided text. Provide the corrected version, then list each correction.',
    ),
    SkillDefinition(
      id: 'brainstorm',
      name: 'Brainstorm Helper',
      description: 'Generate creative ideas on any topic',
      icon: '💡',
      category: 'Creative',
      inputPlaceholder: 'What topic do you want to brainstorm about?',
      systemPrompt:
          'You are a creative brainstorming partner. Generate diverse, innovative ideas related to the given topic. Provide at least 8-10 ideas ranging from practical to creative.',
    ),
  ];

  SkillDefinition? getBuiltInById(String id) {
    for (final s in builtInSkills) {
      if (s.id == id) return s;
    }
    return null;
  }

  Stream<String> executeSkill({
    required SkillDefinition skill,
    required String userInput,
    int? maxTokens,
  }) {
    final request = ChatRequest(
      systemPrompt: skill.systemPrompt,
      messages: [ChatMessage(role: ChatRole.user, content: userInput)],
      maxTokens: maxTokens ?? (skill.isBuiltIn ? 512 : 1024),
    );
    return _chatEngine.generateStream(request);
  }
}
