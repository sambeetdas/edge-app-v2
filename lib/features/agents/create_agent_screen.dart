import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/agent_service.dart';
import '../../providers/app_providers.dart';

class CreateAgentScreen extends ConsumerStatefulWidget {
  const CreateAgentScreen({super.key});

  @override
  ConsumerState<CreateAgentScreen> createState() => _CreateAgentScreenState();
}

class _CreateAgentScreenState extends ConsumerState<CreateAgentScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _placeholderCtrl = TextEditingController();

  String _icon = '🤖';
  String _category = 'Custom';
  String? _nextAgentId;
  final Set<AgentTool> _tools = {AgentTool.llm};
  bool _saving = false;

  static const _icons = ['🤖', '📧', '💬', '📚', '🧾', '⏰', '🧠', '🔍'];
  static const _categories = ['Custom', 'Automation', 'Knowledge', 'Writing'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    _placeholderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _promptCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and System Prompt are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    await ref.read(agentServiceProvider).createCustomAgent(
          name: _nameCtrl.text,
          description: _descCtrl.text.trim().isEmpty
              ? 'Custom offline AI agent'
              : _descCtrl.text,
          icon: _icon,
          category: _category,
          systemPrompt: _promptCtrl.text,
          inputPlaceholder: _placeholderCtrl.text,
          tools: _tools.toList(),
          nextAgentId: _nextAgentId,
        );
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Custom Agent')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: _icons
                .map(
                  (e) => ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 18)),
                    selected: _icon == e,
                    onSelected: (_) => setState(() => _icon = e),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Agent Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Short Description'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Agent Tools',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: AgentTool.values
                .map(
                  (t) => FilterChip(
                    label: Text(t.label),
                    selected: _tools.contains(t),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _tools.add(t);
                        } else if (_tools.length > 1) {
                          _tools.remove(t);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _nextAgentId,
            decoration: const InputDecoration(
              labelText: 'Default A2A Handoff Agent (Optional)',
              prefixIcon: Icon(Icons.hub_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('None (Single Agent)'),
              ),
              for (final a in AgentService.builtInAgents)
                DropdownMenuItem<String?>(
                  value: a.id,
                  child: Text('Handoff → ${a.icon} ${a.name}'),
                ),
            ],
            onChanged: (v) => setState(() => _nextAgentId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _promptCtrl,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'System Prompt / Agent Role',
              hintText: 'Define how this agent thinks and formats output...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _placeholderCtrl,
            decoration: const InputDecoration(
              labelText: 'Input Placeholder (optional)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save Agent'),
          ),
        ],
      ),
    );
  }
}
