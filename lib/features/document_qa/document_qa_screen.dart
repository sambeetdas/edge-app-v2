import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/document_service.dart';
import '../../engine/models/chat_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/model_loader_helper.dart';

class DocumentQaScreen extends ConsumerStatefulWidget {
  const DocumentQaScreen({super.key});

  @override
  ConsumerState<DocumentQaScreen> createState() => _DocumentQaScreenState();
}

class _DocumentQaScreenState extends ConsumerState<DocumentQaScreen> {
  final _questionCtrl = TextEditingController();
  ExtractedDocument? _doc;
  String _answer = '';
  bool _isExtracting = false;
  bool _isAsking = false;
  String? _error;

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    setState(() {
      _error = null;
      _isExtracting = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: DocumentService.supportedExtensions,
      );
      if (result.isEmpty || result.single.path == null) {
        setState(() => _isExtracting = false);
        return;
      }

      final tier = ref.read(activeModelTierProvider);
      final maxCtx = tier?.maxContextTokens ?? 2048;

      final extracted = await ref.read(documentServiceProvider).extractAndFit(
            file: File(result.single.path!),
            modelMaxContextTokens: maxCtx,
          );

      if (!mounted) return;
      setState(() {
        _doc = extracted;
        _answer = '';
        _isExtracting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isExtracting = false;
      });
    }
  }

  Future<void> _ask() async {
    final doc = _doc;
    final question = _questionCtrl.text.trim();
    if (doc == null || question.isEmpty || _isAsking) return;

    setState(() {
      _isAsking = true;
      _answer = '';
      _error = null;
    });

    try {
      await ensureModelLoadedFromWidget(ref);

      final request = ChatRequest(
        systemPrompt:
            'You are a helpful document assistant. Answer the user\'s question '
            'based strictly on the provided document content. Be concise and accurate.',
        messages: [
          ChatMessage(
            role: ChatRole.user,
            content:
                'Document (${doc.fileName}):\n\n${doc.contextText}\n\nQuestion: $question',
          ),
        ],
        temperature: 0.3,
        topP: 0.9,
        maxTokens: 512,
        repeatPenalty: 1.1,
      );

      final sb = StringBuffer();
      int lastUiMs = DateTime.now().millisecondsSinceEpoch;

      await for (final token
          in ref.read(chatEngineProvider).generateStream(request)) {
        sb.write(token);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastUiMs >= 80) {
          lastUiMs = nowMs;
          if (mounted) setState(() => _answer = sb.toString());
        }
      }

      if (mounted) {
        setState(() {
          _answer = Formatters.stripMarkdown(sb.toString());
          _isAsking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isAsking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = _doc;

    return Scaffold(
      appBar: AppBar(title: const Text('Docs Q&A')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.tonalIcon(
            onPressed: _isExtracting ? null : _pickDocument,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              _isExtracting
                  ? 'Extracting text…'
                  : 'Pick Document (.txt, .md, .docx, .pdf)',
            ),
          ),
          if (doc != null) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            doc.fileName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          Formatters.formatBytes(doc.fileSizeBytes),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: doc.wasTruncated
                            ? AppColors.warning.withValues(alpha: 0.16)
                            : theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            doc.wasTruncated
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline_rounded,
                            size: 18,
                            color: doc.wasTruncated
                                ? AppColors.warning
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              doc.wasTruncated
                                  ? 'Truncated to ${doc.percentUsed.toStringAsFixed(0)}% (${doc.usedTokens} / ${doc.estimatedTokens} est. tokens) to fit model context.'
                                  : 'Full document loaded (${doc.usedTokens} est. tokens).',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _questionCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ask a question about this document...',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (doc == null || _isAsking) ? null : _ask,
            icon: Icon(_isAsking ? Icons.hourglass_top : Icons.question_answer),
            label: Text(_isAsking ? 'Answering…' : 'Ask Document'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_answer.isNotEmpty) ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _answer,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
