import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';

class CreateSkillScreen extends ConsumerStatefulWidget {
  const CreateSkillScreen({super.key});

  @override
  ConsumerState<CreateSkillScreen> createState() => _CreateSkillScreenState();
}

class _CreateSkillScreenState extends ConsumerState<CreateSkillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _iconCtrl = TextEditingController(text: '⚡');
  final _categoryCtrl = TextEditingController(text: 'Custom');
  final _promptCtrl = TextEditingController();
  final _placeholderCtrl = TextEditingController(text: 'Enter your input...');
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _iconCtrl.dispose();
    _categoryCtrl.dispose();
    _promptCtrl.dispose();
    _placeholderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await ref.read(customSkillsServiceProvider).createCustomSkill(
          name: _nameCtrl.text,
          description: _descCtrl.text,
          icon: _iconCtrl.text,
          category: _categoryCtrl.text,
          systemPrompt: _promptCtrl.text,
          inputPlaceholder: _placeholderCtrl.text,
        );

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Custom Skill')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 84,
                  child: TextFormField(
                    controller: _iconCtrl,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Icon'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Skill Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Short Description'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _promptCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'System Prompt',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _placeholderCtrl,
              decoration: const InputDecoration(labelText: 'Input Placeholder'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save Skill'),
            ),
          ],
        ),
      ),
    );
  }
}
