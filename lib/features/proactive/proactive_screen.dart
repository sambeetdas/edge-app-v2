import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/services/proactive_service.dart';
import '../../engine/models/chat_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/model_loader_helper.dart';

class ProactiveScreen extends ConsumerStatefulWidget {
  const ProactiveScreen({super.key});

  @override
  ConsumerState<ProactiveScreen> createState() => _ProactiveScreenState();
}

class _ProactiveScreenState extends ConsumerState<ProactiveScreen> {
  final _reminderCtrl = TextEditingController();
  List<ProactiveReminderEntity> _reminders = [];
  Duration _selectedDelay = const Duration(minutes: 15);
  bool _dailyBriefing = false;
  bool _isSummarizing = false;
  String _summary = '';
  int _briefingChatsCount = 0;
  int _briefingDocsCount = 0;
  int _briefingRemindersCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _reminderCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final items = await ref.read(proactiveServiceProvider).getReminders();
    if (!mounted) return;
    setState(() => _reminders = items);
  }

  Future<void> _addReminder() async {
    final title = _reminderCtrl.text.trim();
    if (title.isEmpty) return;
    _reminderCtrl.clear();

    await ref.read(proactiveServiceProvider).addReminder(
          title: title,
          delay: _selectedDelay,
        );
    await _loadReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scheduled offline reminder: "$title"'),
      ),
    );
  }

  Future<void> _generateSummary() async {
    if (_isSummarizing) return;
    setState(() {
      _isSummarizing = true;
      _summary = '';
      _error = null;
    });

    try {
      await ensureModelLoadedFromWidget(ref);
      final sessions = await ref.read(chatHistoryServiceProvider).getSessions();
      final docs = await ref.read(knowledgeServiceProvider).getDocuments();
      final pendingReminders =
          _reminders.where((r) => !r.isCompleted).toList();

      if (mounted) {
        setState(() {
          _briefingChatsCount = sessions.length;
          _briefingDocsCount = docs.length;
          _briefingRemindersCount = pendingReminders.length;
        });
      }

      final chatLines = sessions
          .take(5)
          .map((s) =>
              '- "${s.title}" (${Formatters.formatRelativeDate(s.updatedAt)})')
          .join('\n');
      final docLines = docs
          .take(5)
          .map((d) => '- ${d.fileName} (${d.chunkCount} chunks)')
          .join('\n');
      final remLines = pendingReminders
          .take(5)
          .map((r) =>
              '- ${r.title} (due ${Formatters.formatRelativeDate(r.triggerAt)})')
          .join('\n');

      final contextText = [
        if (chatLines.isNotEmpty) 'Recent Chats:\n$chatLines',
        if (docLines.isNotEmpty) 'Indexed Knowledge Docs:\n$docLines',
        if (remLines.isNotEmpty) 'Pending Reminders:\n$remLines',
      ].join('\n\n');

      if (contextText.isEmpty) {
        setState(() {
          _summary =
              'OVERVIEW:\nNo recent chats, documents, or reminders yet. Start a chat, index a document, or add a reminder to generate your offline daily briefing.';
          _isSummarizing = false;
        });
        return;
      }

      final request = ChatRequest(
        systemPrompt:
            'You are Edged Proactive Assistant. Write a crisp, scannable daily briefing '
            'using ONLY these three plain-text section headers (no markdown #, **, or code blocks):\n\n'
            'OVERVIEW:\n'
            '<1-2 concise sentences summarizing current focus>\n\n'
            'HIGHLIGHTS:\n'
            '• <bullet 1>\n'
            '• <bullet 2>\n\n'
            'NEXT ACTIONS:\n'
            '• <actionable step 1>\n'
            '• <actionable step 2>\n\n'
            'Keep each bullet under 18 words and complete every sentence.',
        messages: [
          ChatMessage(
            role: ChatRole.user,
            content: 'Generate my daily briefing from this offline data:\n\n$contextText',
          ),
        ],
        temperature: 0.3,
        maxTokens: 450,
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
            setState(() => _summary = Formatters.stripMarkdown(sb.toString()));
          }
        }
      }
      if (mounted) {
        setState(() {
          _summary = Formatters.stripMarkdown(sb.toString());
          _isSummarizing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSummarizing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Proactive Assistant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Offline Daily Summary',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Summarizes your local chats, knowledge docs, and reminders on-device.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isSummarizing ? null : _generateSummary,
                    icon: Icon(
                      _isSummarizing
                          ? Icons.hourglass_top_rounded
                          : Icons.summarize_outlined,
                    ),
                    label: Text(
                      _isSummarizing
                          ? 'Generating Briefing…'
                          : 'Generate Daily Briefing',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (_summary.isNotEmpty) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        _StatPill(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '$_briefingChatsCount chats',
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          icon: Icons.menu_book_outlined,
                          label: '$_briefingDocsCount docs',
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          icon: Icons.notifications_none_rounded,
                          label: '$_briefingRemindersCount due',
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Copy briefing',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _summary));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Briefing copied to clipboard'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StructuredBriefingView(text: _summary),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              title: const Text('Daily Briefing Notification'),
              subtitle: const Text('Runs offline every 24 hours via Workmanager'),
              value: _dailyBriefing,
              onChanged: (val) async {
                await ref
                    .read(proactiveServiceProvider)
                    .setDailyBriefingEnabled(val);
                if (mounted) setState(() => _dailyBriefing = val);
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart Reminder', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reminderCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Review Q3 PDF summary',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final opt in const [
                        ('15 min', Duration(minutes: 15)),
                        ('1 hour', Duration(hours: 1)),
                        ('3 hours', Duration(hours: 3)),
                        ('Tomorrow', Duration(hours: 24)),
                      ])
                        ChoiceChip(
                          label: Text(opt.$1),
                          selected: _selectedDelay == opt.$2,
                          onSelected: (_) =>
                              setState(() => _selectedDelay = opt.$2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _addReminder,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Schedule Offline Reminder'),
                  ),
                ],
              ),
            ),
          ),
          if (_reminders.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Scheduled Reminders (${_reminders.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            for (final rem in _reminders)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: rem.isCompleted,
                  onChanged: (v) async {
                    await ref
                        .read(proactiveServiceProvider)
                        .toggleCompleted(rem.id, v ?? false);
                    _loadReminders();
                  },
                  title: Text(
                    rem.title,
                    style: TextStyle(
                      decoration: rem.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    'Due ${Formatters.formatRelativeDate(rem.triggerAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await ref
                          .read(proactiveServiceProvider)
                          .deleteReminder(rem.id);
                      _loadReminders();
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StructuredBriefingView extends StatelessWidget {
  final String text;

  const _StructuredBriefingView({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _parseSections(text);

    if (sections.isEmpty) {
      return SelectableText(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _BriefingSectionCard(section: sections[i]),
        ],
      ],
    );
  }

  List<_BriefingSection> _parseSections(String raw) {
    final lines = raw.split('\n');
    final result = <_BriefingSection>[];
    String? currentTitle;
    final currentLines = <String>[];

    final headerPattern = RegExp(
      r'^(OVERVIEW|HIGHLIGHTS|NEXT ACTIONS)\s*:?\s*(.*)$',
      caseSensitive: false,
    );

    void flush() {
      if (currentTitle != null && currentLines.isNotEmpty) {
        result.add(
          _BriefingSection(
            title: currentTitle,
            lines: List.unmodifiable(currentLines),
          ),
        );
      }
      currentLines.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = headerPattern.firstMatch(trimmed);
      if (match != null) {
        flush();
        currentTitle = match.group(1)!.toUpperCase();
        final rest = match.group(2)?.trim() ?? '';
        if (rest.isNotEmpty) currentLines.add(rest);
      } else if (currentTitle != null) {
        currentLines.add(trimmed);
      }
    }
    flush();
    return result;
  }
}

class _BriefingSection {
  final String title;
  final List<String> lines;

  const _BriefingSection({required this.title, required this.lines});
}

class _BriefingSectionCard extends StatelessWidget {
  final _BriefingSection section;

  const _BriefingSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color accent) = switch (section.title) {
      'OVERVIEW' => (Icons.wb_sunny_outlined, theme.colorScheme.primary),
      'HIGHLIGHTS' => (Icons.insights_outlined, theme.colorScheme.tertiary),
      'NEXT ACTIONS' => (Icons.task_alt_rounded, theme.colorScheme.secondary),
      _ => (Icons.notes_rounded, theme.colorScheme.primary),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                section.title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in section.lines) _buildLine(theme, accent, line),
        ],
      ),
    );
  }

  Widget _buildLine(ThemeData theme, Color accent, String line) {
    final isBullet =
        line.startsWith('•') || line.startsWith('- ') || line.startsWith('* ');
    final clean = isBullet ? line.replaceFirst(RegExp(r'^[•\-*]\s*'), '') : line;

    if (!isBullet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SelectableText(
          clean,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              clean,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
