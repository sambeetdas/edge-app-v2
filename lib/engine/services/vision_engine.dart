import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/chat_models.dart';
import 'chat_engine.dart';

/// 100% offline Image & Receipt Q&A powered by on-device ML Kit OCR + ChatEngine.
class VisionEngine {
  final ChatEngine _chatEngine;

  VisionEngine(this._chatEngine);

  Future<String> extractText(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  Stream<String> askAboutImage({
    required File imageFile,
    required String question,
    String? mmProjPath,
    String? preExtractedText,
  }) async* {
    final ocrText = preExtractedText ?? await extractText(imageFile);
    if (ocrText.isEmpty) {
      yield 'No readable text was detected in this image. Try a clearer photo of a receipt, document, or screenshot.';
      return;
    }

    final prompt = 'Extracted text from image (offline OCR):\n\n'
        '$ocrText\n\n'
        'Question: $question';

    final request = ChatRequest(
      systemPrompt:
          'You are Edged Scan, an offline image text assistant. '
          'Answer the user\'s question directly from the extracted OCR text '
          '(whether it is a note, document, screenshot, sign, or receipt) using ONLY these plain-text sections '
          '(no markdown #, **, or code blocks). Do not mention missing receipt fields like merchant or total unless asked:\n\n'
          'SUMMARY:\n'
          '<1-2 concise sentences answering the question>\n\n'
          'DETAILS:\n'
          '• <Key: Value or concise fact>\n'
          '• <Key: Value or concise fact>',
      messages: [ChatMessage(role: ChatRole.user, content: prompt)],
      temperature: 0.2,
      maxTokens: 512,
    );

    yield* _chatEngine.generateStream(request);
  }
}
