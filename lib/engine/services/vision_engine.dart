import 'dart:io';

import '../models/chat_models.dart';
import 'chat_engine.dart';

class VisionEngine {
  final ChatEngine _chatEngine;

  VisionEngine(this._chatEngine);

  Stream<String> askAboutImage({
    required File imageFile,
    required String question,
    String? mmProjPath,
  }) async* {
    final bytes = await imageFile.length();
    final kb = (bytes / 1024).round();

    final prompt =
        '[Image provided — $kb KB${mmProjPath != null ? ', mmproj ready' : ''}]\n\n'
        'User question about the image: $question';

    final request = ChatRequest(
      systemPrompt:
          'You are a helpful vision AI assistant. Answer the user\'s question about the provided image clearly and concisely.',
      messages: [ChatMessage(role: ChatRole.user, content: prompt)],
      maxTokens: 512,
    );

    yield* _chatEngine.generateStream(request);
  }
}
