import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/structured_response_card.dart';
import '../../data/services/agent_service.dart';
import '../../engine/services/agent_orchestrator.dart';
import '../../providers/app_providers.dart';
import '../../providers/model_loader_helper.dart';

class AgentRunScreen extends ConsumerStatefulWidget {
  final String agentId;

  const AgentRunScreen({super.key, required this.agentId});

  @override
  ConsumerState<AgentRunScreen> createState() => _AgentRunScreenState();
}

class _AgentRunScreenState extends ConsumerState<AgentRunScreen> {
  final _inputCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _picker = ImagePicker();

  AgentDefinition? _agent;
  List<AgentDefinition> _allAgents = [];
  String? _handoffAgentId;
  File? _imageFile;
  Duration _scheduleDelay = Duration.zero;
  bool _isRunning = false;
  String? _error;
  final List<AgentStepEvent> _steps = [];

  @override
  void initState() {
    super.initState();
    _loadAgent();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _recipientCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAgent() async {
    final svc = ref.read(agentServiceProvider);
    final agent = await svc.getAgentById(widget.agentId);
    final custom = await svc.getCustomAgents();
    if (!mounted) return;
    setState(() {
      _agent = agent;
      _allAgents = [...AgentService.builtInAgents, ...custom];
      _handoffAgentId = agent?.nextAgentId;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _imageFile = File(picked.path));
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _run() async {
    final agent = _agent;
    if (agent == null || _isRunning) return;
    final input = _inputCtrl.text.trim();
    if (input.isEmpty && agent.id != 'daily_briefing' && _imageFile == null) {
      setState(() => _error = 'Please enter instructions or select an image.');
      return;
    }

    setState(() {
      _isRunning = true;
      _error = null;
      _steps.clear();
    });

    try {
      await ensureModelLoadedFromWidget(ref);
      AgentDefinition? handoff;
      if (_handoffAgentId != null &&
          _handoffAgentId!.isNotEmpty &&
          _handoffAgentId != agent.nextAgentId) {
        handoff = _allAgents.where((a) => a.id == _handoffAgentId).firstOrNull;
      }

      await for (final event in ref.read(agentOrchestratorProvider).runAgentChain(
            primaryAgent: agent,
            userInput: input,
            handoffAgent: handoff,
            imageFile: _imageFile,
            recipientTarget: _recipientCtrl.text.trim(),
            scheduleDelay: _scheduleDelay,
          )) {
        if (!mounted) return;
        setState(() {
          if (event.stepIndex < _steps.length) {
            _steps[event.stepIndex] = event;
          } else {
            _steps.add(event);
          }
        });
      }
      if (mounted) setState(() => _isRunning = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _launchAction(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = _agent;
    final theme = Theme.of(context);

    if (agent == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agent')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final handoffAgent = _allAgents
        .where((a) => a.id == _handoffAgentId)
        .firstOrNull;
    final needsRecipient = agent.hasTool(AgentTool.email) ||
        agent.hasTool(AgentTool.whatsapp) ||
        (handoffAgent?.hasTool(AgentTool.email) ?? false) ||
        (handoffAgent?.hasTool(AgentTool.whatsapp) ?? false);
    final needsSchedule = needsRecipient ||
        agent.hasTool(AgentTool.reminder) ||
        (handoffAgent?.hasTool(AgentTool.reminder) ?? false);

    return Scaffold(
      appBar: AppBar(title: Text('${agent.icon} ${agent.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agent.description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in agent.tools)
                        Chip(
                          label: Text(t.label),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (agent.hasTool(AgentTool.ocr)) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Pick Image'),
                  ),
                ),
              ],
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _inputCtrl,
            minLines: 3,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: agent.inputPlaceholder,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _handoffAgentId,
            decoration: const InputDecoration(
              labelText: 'Agent-to-Agent Handoff (Optional)',
              prefixIcon: Icon(Icons.hub_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('None (Single Agent)'),
              ),
              for (final other in _allAgents.where((a) => a.id != agent.id))
                DropdownMenuItem<String?>(
                  value: other.id,
                  child: Text('Handoff → ${other.icon} ${other.name}'),
                ),
            ],
            onChanged: (v) => setState(() => _handoffAgentId = v),
          ),
          if (needsRecipient) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _recipientCtrl,
              decoration: InputDecoration(
                labelText: (agent.hasTool(AgentTool.whatsapp) ||
                        (handoffAgent?.hasTool(AgentTool.whatsapp) ?? false))
                    ? 'Recipient Phone (with country code, e.g. +9198...)'
                    : 'Recipient Email (optional)',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
            ),
          ],
          if (needsSchedule) ...[
            const SizedBox(height: 12),
            Text(
              'Schedule Delivery',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final opt in const [
                  ('Now', Duration.zero),
                  ('15 min', Duration(minutes: 15)),
                  ('1 hour', Duration(hours: 1)),
                  ('3 hours', Duration(hours: 3)),
                  ('Tomorrow', Duration(hours: 24)),
                ])
                  ChoiceChip(
                    label: Text(opt.$1),
                    selected: _scheduleDelay == opt.$2,
                    onSelected: (_) => setState(() => _scheduleDelay = opt.$2),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _isRunning ? null : _run,
            icon: Icon(
              _isRunning ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              _isRunning
                  ? 'Running Agent…'
                  : (_handoffAgentId != null ? 'Run Agent Chain' : 'Run Agent'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          for (final step in _steps) ...[
            const SizedBox(height: 16),
            StructuredResponseCard(
              title: '${step.agentIcon} ${step.agentName}  ·  ${step.targetLabel}',
              icon: Icons.smart_toy_outlined,
              text: step.output.isEmpty ? 'Thinking…' : step.output,
              footer: (step.actionLabel != null && step.actionUrl != null)
                  ? FilledButton.tonalIcon(
                      onPressed: () => _launchAction(step.actionUrl!),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(step.actionLabel!),
                    )
                  : (step.actionLabel != null
                      ? Chip(
                          avatar: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(step.actionLabel!),
                        )
                      : null),
            ),
          ],
        ],
      ),
    );
  }
}
