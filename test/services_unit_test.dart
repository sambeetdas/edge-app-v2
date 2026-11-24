import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edged/core/utils/formatters.dart';
import 'package:edged/data/services/device_service.dart';
import 'package:edged/data/services/document_service.dart';
import 'package:edged/engine/models/chat_models.dart';
import 'package:edged/engine/models/prompt_format.dart';
import 'package:edged/engine/services/chat_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentService', () {
    late Directory tempDir;
    late DocumentService docService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('edged_doc_test_');
      docService = DocumentService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('extracts .txt and truncates when exceeding context window', () async {
      final file = File('${tempDir.path}/notes.txt');
      // 1024 context - 750 reserved = 274 tokens -> 1096 chars max
      final longText = 'A' * 3000;
      await file.writeAsString(longText);

      final result = await docService.extractAndFit(
        file: file,
        modelMaxContextTokens: 1024,
      );

      expect(result.wasTruncated, isTrue);
      expect(result.contextText.length, 274 * 4);
      expect(result.percentUsed, lessThan(50));
    });

    test('extracts .docx word/document.xml paragraphs', () async {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Hello Edged</w:t></w:r></w:p>
    <w:p><w:r><w:t>Offline DOCX test</w:t></w:r></w:p>
  </w:body>
</w:document>''';

      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'word/document.xml',
            utf8.encode(xml).length,
            utf8.encode(xml),
          ),
        );
      final bytes = ZipEncoder().encode(archive)!;
      final file = File('${tempDir.path}/sample.docx');
      await file.writeAsBytes(bytes);

      final result = await docService.extractAndFit(
        file: file,
        modelMaxContextTokens: 4096,
      );

      expect(result.wasTruncated, isFalse);
      expect(result.contextText, contains('Hello Edged'));
      expect(result.contextText, contains('Offline DOCX test'));
    });

    test('rejects empty files and unsupported extensions', () async {
      final emptyFile = File('${tempDir.path}/empty.txt');
      await emptyFile.writeAsString('   ');

      await expectLater(
        () => docService.extractAndFit(
          file: emptyFile,
          modelMaxContextTokens: 2048,
        ),
        throwsException,
      );

      final badExt = File('${tempDir.path}/image.png');
      await badExt.writeAsBytes([1, 2, 3]);

      await expectLater(
        () => docService.extractAndFit(
          file: badExt,
          modelMaxContextTokens: 2048,
        ),
        throwsException,
      );
    });

    test('DocumentService.chunkText splits long text with overlap', () {
      final docService = DocumentService();
      final text = List.generate(300, (i) => 'sentence$i.').join(' ');
      final chunks = docService.chunkText(text, chunkChars: 400, overlapChars: 60);
      expect(chunks.length, greaterThan(2));
      expect(chunks.every((c) => c.length <= 405), isTrue);
    });
  });

  group('DeviceCompatibilityReport', () {
    test('enforces 1.5 GB OS RAM headroom and 200 MB storage buffer', () {
      const report = DeviceCompatibilityReport(
        totalRamGb: 6.0,
        effectiveRamGb: 4.5,
        availableStorageBytes: 2 * 1024 * 1024 * 1024,
      );

      expect(report.hasEnoughRam(4), isTrue);
      expect(report.hasEnoughRam(5), isFalse);
      expect(report.hasEnoughStorage(1500 * 1024 * 1024), isTrue);
      expect(report.hasEnoughStorage(2000 * 1024 * 1024), isFalse);
    });
  });

  group('PromptFormat & ChatEngine', () {
    test('Gemma and Phi3 formats render expected turn delimiters', () {
      final gemma = PromptFormat.gemma.formatPrompt(
        systemPrompt: 'Sys',
        messages: const [ChatMessage(role: ChatRole.user, content: 'Hi')],
      );
      expect(gemma, contains('<start_of_turn>system\nSys<end_of_turn>'));
      expect(gemma, endsWith('<start_of_turn>model\n'));

      final phi3 = PromptFormat.phi3.formatPrompt(
        systemPrompt: 'Sys',
        messages: const [ChatMessage(role: ChatRole.user, content: 'Hi')],
      );
      expect(phi3, contains('<|system|>\nSys\n<|end|>'));
      expect(phi3, endsWith('<|assistant|>\n'));
    });

    test('ChatEngine streams offline fallback and handles Word Chain', () async {
      final engine = ChatEngine();
      await engine.loadModel(
        modelPath: '/tmp/mock.gguf',
        promptFormat: PromptFormat.chatML,
      );
      expect(engine.isLoaded, isTrue);

      final tokens = await engine
          .generateStream(
            const ChatRequest(
              systemPrompt: 'You are playing Word Chain.',
              messages: [ChatMessage(role: ChatRole.user, content: 'apple')],
            ),
          )
          .toList();

      final full = tokens.join();
      expect(full, contains('next starts with X'));
    });

    test('ChatEngine.trimRequestToContext drops oldest turns and fits budget', () async {
      final engine = ChatEngine();
      await engine.loadModel(
        modelPath: '/tmp/mock.gguf',
        promptFormat: PromptFormat.chatML,
        options: const ModelOptions(contextSize: 1024, maxTokens: 256),
      );

      final longMsg = List.filled(400, 'word').join(' ');
      final req = ChatRequest(
        systemPrompt: 'System prompt.',
        messages: [
          ChatMessage(role: ChatRole.user, content: 'OLDEST: $longMsg'),
          ChatMessage(role: ChatRole.assistant, content: 'MIDDLE: $longMsg'),
          const ChatMessage(role: ChatRole.user, content: 'LATEST QUESTION'),
        ],
      );

      final trimmed = engine.trimRequestToContext(req);
      expect(trimmed.messages.last.content, equals('LATEST QUESTION'));
      expect(
        trimmed.messages.any((m) => m.content.startsWith('OLDEST:')),
        isFalse,
      );
    });

    test('Formatters.stripMarkdown removes think blocks and formats bullets', () {
      const raw = '<think>\ninternal reasoning\n</think>\n\n'
          '### Summary\n* **First** point\n- *Second* `point`\n\n<think>partial';
      final cleaned = Formatters.stripMarkdown(raw);
      expect(cleaned, equals('Summary\n• First point\n• Second point'));
    });
  });
}
