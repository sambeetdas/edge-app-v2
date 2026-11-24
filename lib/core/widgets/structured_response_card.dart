import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders structured AI responses (sections, key-value pairs, and bullets)
/// cleanly without raw markdown artifacts.
class StructuredResponseCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String text;
  final Widget? topBadges;
  final Widget? footer;

  const StructuredResponseCard({
    super.key,
    required this.title,
    required this.icon,
    required this.text,
    this.topBadges,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _parseSections(text);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            if (topBadges != null) ...[
              const SizedBox(height: 8),
              topBadges!,
            ],
            const Divider(height: 20),
            if (sections.isEmpty)
              _PlainLinesView(text: text)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _SectionBox(section: sections[i]),
                  ],
                ],
              ),
            if (footer != null) ...[
              const Divider(height: 24),
              footer!,
            ],
          ],
        ),
      ),
    );
  }

  static List<_ParsedSection> _parseSections(String raw) {
    final lines = raw.split('\n');
    final result = <_ParsedSection>[];
    String? currentTitle;
    final currentLines = <String>[];

    final headerPattern = RegExp(
      r'^(OVERVIEW|SUMMARY|DETAILS|ANSWER|KEY POINTS|HIGHLIGHTS|NEXT ACTIONS)\s*:?\s*(.*)$',
      caseSensitive: false,
    );

    void flush() {
      if (currentTitle != null && currentLines.isNotEmpty) {
        result.add(
          _ParsedSection(
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

class _ParsedSection {
  final String title;
  final List<String> lines;

  const _ParsedSection({required this.title, required this.lines});
}

class _SectionBox extends StatelessWidget {
  final _ParsedSection section;

  const _SectionBox({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color accent) = switch (section.title) {
      'OVERVIEW' || 'SUMMARY' => (
          Icons.wb_sunny_outlined,
          theme.colorScheme.primary,
        ),
      'ANSWER' => (Icons.auto_awesome_outlined, theme.colorScheme.primary),
      'HIGHLIGHTS' || 'KEY POINTS' => (
          Icons.insights_outlined,
          theme.colorScheme.tertiary,
        ),
      'DETAILS' => (Icons.receipt_long_outlined, theme.colorScheme.secondary),
      'NEXT ACTIONS' => (
          Icons.task_alt_rounded,
          theme.colorScheme.secondary,
        ),
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
              Icon(icon, size: 15, color: accent),
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
          for (final line in section.lines) _StyledLine(line: line, accent: accent),
        ],
      ),
    );
  }
}

class _PlainLinesView extends StatelessWidget {
  final String text;

  const _PlainLinesView({required this.text});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) _StyledLine(line: line, accent: accent),
      ],
    );
  }
}

class _StyledLine extends StatelessWidget {
  final String line;
  final Color accent;

  const _StyledLine({required this.line, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBullet =
        line.startsWith('•') || line.startsWith('- ') || line.startsWith('* ');
    final clean = isBullet ? line.replaceFirst(RegExp(r'^[•\-*]\s*'), '') : line;

    final kvMatch = RegExp(r'^([A-Za-z][A-Za-z0-9 /&()-]{1,28}):\s+(.+)$')
        .firstMatch(clean);

    Widget textWidget;
    if (kvMatch != null) {
      textWidget = SelectableText.rich(
        TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          children: [
            TextSpan(
              text: '${kvMatch.group(1)}: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: kvMatch.group(2)),
          ],
        ),
      );
    } else {
      textWidget = SelectableText(
        clean,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
      );
    }

    if (!isBullet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: textWidget,
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
          Expanded(child: textWidget),
        ],
      ),
    );
  }
}
