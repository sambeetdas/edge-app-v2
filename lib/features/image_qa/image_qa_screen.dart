import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../../providers/model_loader_helper.dart';

class ImageQaScreen extends ConsumerStatefulWidget {
  const ImageQaScreen({super.key});

  @override
  ConsumerState<ImageQaScreen> createState() => _ImageQaScreenState();
}

class _ImageQaScreenState extends ConsumerState<ImageQaScreen> {
  final _picker = ImagePicker();
  final _questionCtrl = TextEditingController();
  File? _selectedImage;
  String _answer = '';
  bool _isAsking = false;
  String? _error;

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _selectedImage = File(picked.path);
        _answer = '';
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _ask() async {
    final file = _selectedImage;
    final question = _questionCtrl.text.trim();
    if (file == null || question.isEmpty || _isAsking) return;

    setState(() {
      _isAsking = true;
      _answer = '';
      _error = null;
    });

    try {
      await ensureModelLoadedFromWidget(ref);
      final info = await ref.read(modelManagerProvider).getDownloadedModel();

      final sb = StringBuffer();
      int lastUiMs = DateTime.now().millisecondsSinceEpoch;

      await for (final token in ref.read(visionEngineProvider).askAboutImage(
            imageFile: file,
            question: question,
            mmProjPath: info?.mmProjPath,
          )) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Image Q&A')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pick Image'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _selectedImage!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 44,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select or capture an image to analyze offline',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _questionCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ask a question about this image...',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_selectedImage == null || _isAsking) ? null : _ask,
            icon: Icon(_isAsking ? Icons.hourglass_top : Icons.search_rounded),
            label: Text(_isAsking ? 'Analyzing…' : 'Ask About Image'),
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
