import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../engine/models/chat_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/model_loader_helper.dart';

class SkillExecutionScreen extends ConsumerStatefulWidget {
  final String skillId;

  const SkillExecutionScreen({super.key, required this.skillId});

  @override
  ConsumerState<SkillExecutionScreen> createState() =>
      _SkillExecutionScreenState();
}

class _SkillExecutionScreenState extends ConsumerState<SkillExecutionScreen> {
  final _inputController = TextEditingController();
  SkillDefinition? _skill;
  String _output = '';
  bool _isRunning = false;
  bool _stillThinking = false;
  String? _error;
  Timer? _thinkingTimer;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _loadSkill();
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _timeoutTimer?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadSkill() async {
    var skill = ref.read(skillsEngineProvider).getBuiltInById(widget.skillId);
    if (skill == null) {
      final customs =
          await ref.read(customSkillsServiceProvider).getCustomSkills();
      for (final c in customs) {
        if (c.id == widget.skillId) {
          skill = c;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() => _skill = skill);
  }

  Future<void> _run() async {
    final skill = _skill;
    final input = _inputController.text.trim();
    if (skill == null || input.isEmpty || _isRunning) return;

    setState(() {
      _isRunning = true;
      _stillThinking = false;
      _output = '';
      _error = null;
    });

    try {
      await ensureModelLoadedFromWidget(ref);

      _thinkingTimer?.cancel();
      _thinkingTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _isRunning && _output.isEmpty) {
          setState(() => _stillThinking = true);
        }
      });

      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 120), () {
        ref.read(chatEngineProvider).stopGeneration();
      });

      final sb = StringBuffer();
      int lastUiMs = DateTime.now().millisecondsSinceEpoch;

      await for (final token in ref
          .read(skillsEngineProvider)
          .executeSkill(skill: skill, userInput: input)) {
        sb.write(token);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastUiMs >= 80) {
          lastUiMs = nowMs;
          if (mounted) setState(() => _output = sb.toString());
        }
      }

      if (mounted) {
        setState(() {
          _output = Formatters.stripMarkdown(sb.toString());
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isRunning = false;
        });
      }
    } finally {
      _thinkingTimer?.cancel();
      _timeoutTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skill = _skill;
    return Scaffold(
      appBar: AppBar(
        title: Text(skill == null ? 'Skill' : '${skill.icon} ${skill.name}'),
      ),
      body: skill == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  skill.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _inputController,
                  minLines: 5,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: skill.inputPlaceholder,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isRunning
                            ? () {
                                ref.read(chatEngineProvider).stopGeneration();
                                setState(() => _isRunning = false);
                              }
                            : _run,
                        icon: Icon(
                          _isRunning
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(_isRunning ? 'Stop' : 'Run Skill'),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_isRunning && _output.isEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _stillThinking ? 'Still thinking…' : 'Generating…',
                      ),
                    ],
                  ),
                ],
                if (_output.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Result',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _output),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Copied result'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Divider(),
                          SelectableText(
                            _output,
                            style: const TextStyle(height: 1.45, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
