import 'chat_models.dart';

enum PromptFormat {
  chatML,
  gemma,
  phi3;

  List<String> get antiPrompts => switch (this) {
        PromptFormat.chatML => const ['<|im_end|>', '<|im_start|>', '<|endoftext|>'],
        PromptFormat.gemma => const ['<end_of_turn>', '<start_of_turn>'],
        PromptFormat.phi3 => const ['<|end|>', '<|user|>', '</s>'],
      };

  String formatPrompt({
    required String? systemPrompt,
    required List<ChatMessage> messages,
    bool suppressThinkingMode = false,
  }) {
    final sb = StringBuffer();

    switch (this) {
      case PromptFormat.chatML:
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
          sb.writeln('<|im_start|>system');
          sb.write(systemPrompt.trim());
          sb.writeln('<|im_end|>');
        }
        for (final msg in messages) {
          final role = switch (msg.role) {
            ChatRole.system => 'system',
            ChatRole.user => 'user',
            ChatRole.assistant => 'assistant',
          };
          var content = msg.content;
          if (suppressThinkingMode && msg.role == ChatRole.user) {
            content = '$content /no_think';
          }
          sb.writeln('<|im_start|>$role');
          sb.write(content);
          sb.writeln('<|im_end|>');
        }
        sb.write('<|im_start|>assistant\n');
        if (suppressThinkingMode) {
          sb.write('<think>\n\n</think>\n\n');
        }
        break;

      case PromptFormat.gemma:
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
          sb.writeln('<start_of_turn>system');
          sb.write(systemPrompt.trim());
          sb.writeln('<end_of_turn>');
        }
        for (final msg in messages) {
          final role = msg.role == ChatRole.assistant ? 'model' : 'user';
          sb.writeln('<start_of_turn>$role');
          sb.write(msg.content);
          sb.writeln('<end_of_turn>');
        }
        sb.write('<start_of_turn>model\n');
        break;

      case PromptFormat.phi3:
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
          sb.writeln('<|system|>');
          sb.writeln(systemPrompt.trim());
          sb.writeln('<|end|>');
        }
        for (final msg in messages) {
          final role = switch (msg.role) {
            ChatRole.system => 'system',
            ChatRole.user => 'user',
            ChatRole.assistant => 'assistant',
          };
          sb.writeln('<|$role|>');
          sb.writeln(msg.content);
          sb.writeln('<|end|>');
        }
        sb.write('<|assistant|>\n');
        break;
    }

    return sb.toString();
  }
}
