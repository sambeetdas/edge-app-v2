import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/structured_response_card.dart';
import '../../data/services/knowledge_service.dart';
import '../../engine/models/chat_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/model_loader_helper.dart';

class DocumentQaScreen extends ConsumerStatefulWidget {
  const DocumentQaScreen({super.key});

  @override
  ConsumerState<DocumentQaScreen> createState() => _DocumentQaScreenState();
}

class _DocumentQaScreenState extends ConsumerState<DocumentQaScreen> {
  static const MethodChannel _deviceChannel =
      MethodChannel('com.edgedai.app/device');

  final _questionCtrl = TextEditingController();
  List<KnowledgeDocumentEntity> _docs = [];
  List<KnowledgeChunkMatch> _citations = [];
  String _answer = '';
  bool _isExtracting = false;
  bool _isAsking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDocs() async {
    final docs = await ref.read(knowledgeServiceProvider).getDocuments();
    if (!mounted) return;
    setState(() => _docs = docs);
  }

  Future<void> _pickDocument() async {
    setState(() {
      _error = null;
      _isExtracting = true;
    });

    try {
      String fileName;
      Uint8List bytes;

      if (!kIsWeb && Platform.isAndroid) {
        final raw = await _deviceChannel.invokeMapMethod<String, dynamic>(
          'pickDocument',
        );
        if (raw == null) {
          setState(() => _isExtracting = false);
          return;
        }
        fileName = (raw['name'] as String?) ?? 'document';
        final tempPath = raw['path'] as String?;
        if (tempPath != null && tempPath.isNotEmpty) {
          final tempFile = File(tempPath);
          try {
            bytes = await tempFile.readAsBytes();
          } finally {
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
        } else {
          final rawBytes = raw['bytes'];
          if (rawBytes is Uint8List) {
            bytes = rawBytes;
          } else if (rawBytes is List) {
            bytes = Uint8List.fromList(rawBytes.cast<int>());
          } else {
            throw Exception('Selected file returned invalid data.');
          }
        }
      } else {
        final picked = await FilePicker.pickFile(type: FileType.any);
        if (picked == null) {
          setState(() => _isExtracting = false);
          return;
        }
        fileName = picked.name;
        bytes = await picked.readAsBytes();
      }

      await ref.read(knowledgeServiceProvider).addDocument(
            fileName: fileName,
            bytes: bytes,
          );
      await _loadDocs();
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _answer = '';
        _citations = [];
      });
    } catch (e, st) {
      debugPrint('Knowledge upload error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isExtracting = false;
      });
    }
  }

  Future<void> _deleteDoc(KnowledgeDocumentEntity doc) async {
    await ref.read(knowledgeServiceProvider).deleteDocument(doc.id);
    await _loadDocs();
  }

  Future<void> _ask() async {
    final question = _questionCtrl.text.trim();
    if (_docs.isEmpty || question.isEmpty || _isAsking) return;

    setState(() {
      _isAsking = true;
      _answer = '';
      _citations = [];
      _error = null;
    });

    try {
      await ensureModelLoadedFromWidget(ref);
      final matches = await ref
          .read(knowledgeServiceProvider)
          .searchChunks(question, topK: 4);

      if (matches.isEmpty) {
        setState(() {
          _error = 'No indexed content found. Upload a document first.';
          _isAsking = false;
        });
        return;
      }

      final contextBlock = matches
          .map((m) => '[${m.citationLabel}]\n${m.content}')
          .join('\n\n---\n\n');

      final request = ChatRequest(
        systemPrompt:
            'You are Edged Knowledge, an offline document assistant. '
            'Answer strictly using the provided excerpts and cite sources inline like [filename §chunk]. '
            'Use ONLY these plain-text sections (no markdown #, **, or code blocks):\n\n'
            'ANSWER:\n'
            '<1-3 clear sentences directly answering the question with inline citations>\n\n'
            'KEY POINTS:\n'
            '• <supporting point with citation>\n'
            '• <supporting point with citation>',
        messages: [
          ChatMessage(
            role: ChatRole.user,
            content: 'Excerpts:\n\n$contextBlock\n\nQuestion: $question',
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
          if (mounted) {
            setState(() {
              _answer = Formatters.stripMarkdown(sb.toString());
              _citations = matches;
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _answer = Formatters.stripMarkdown(sb.toString());
          _citations = matches;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Base')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _isExtracting ? null : _pickDocument,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 22,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.upload_file_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isExtracting
                          ? 'Indexing document offline…'
                          : 'Add Document to Knowledge Base',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Offline RAG across .txt, .md, .docx, and .pdf (up to 10 MB)',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_docs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Indexed Documents (${_docs.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            for (final doc in _docs)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    doc.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${Formatters.formatBytes(doc.fileSizeBytes)} · ${doc.chunkCount} chunks',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Remove document',
                    onPressed: () => _deleteDoc(doc),
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
              hintText: 'Search & ask across your indexed documents...',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_docs.isEmpty || _isAsking) ? null : _ask,
            icon: Icon(_isAsking ? Icons.hourglass_top : Icons.search_rounded),
            label: Text(_isAsking ? 'Searching & Answering…' : 'Ask Knowledge Base'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_answer.isNotEmpty) ...[
            const SizedBox(height: 18),
            StructuredResponseCard(
              title: 'Knowledge Answer',
              icon: Icons.auto_awesome_outlined,
              text: _answer,
              footer: _citations.isEmpty
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sources',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _citations
                              .map(
                                (c) => Chip(
                                  avatar: Icon(
                                    Icons.article_outlined,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  label: Text(c.citationLabel),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
