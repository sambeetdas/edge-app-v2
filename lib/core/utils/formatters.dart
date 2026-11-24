import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIdx = 0;
    while (size >= 1024 && unitIdx < units.length - 1) {
      size /= 1024;
      unitIdx++;
    }
    if (unitIdx >= 2) {
      return '${size.toStringAsFixed(1)} ${units[unitIdx]}';
    }
    return '${size.toStringAsFixed(0)} ${units[unitIdx]}';
  }

  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1 && local.day == now.day) {
      return DateFormat.jm().format(local);
    }
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat.E().format(local);
    return DateFormat.MMMd().format(local);
  }

  /// Strips thinking tags and markdown markers for clean bubble display.
  static String stripMarkdown(String input) {
    var out = input;
    // Remove complete <think>...</think> blocks and any unclosed <think>... tail.
    out = out.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'</think>', caseSensitive: false), '');

    // Remove any stray chat-template control tokens.
    out = out.replaceAll(
      RegExp(r'<\|?(?:im_start|im_end|endoftext|end|start_of_turn|end_of_turn)\|?>'),
      '',
    );

    // Remove code fence lines (```dart, ```) while keeping the code inside.
    out = out.replaceAll(RegExp(r'^```[^\n]*\n?', multiLine: true), '');
    out = out.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    out = out.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');

    // Convert markdown list markers (* item or - item) to clean bullets.
    out = out.replaceAllMapped(
      RegExp(r'^([ \t]*)[*-]\s+', multiLine: true),
      (m) => '${m.group(1) ?? ''}• ',
    );

    out = out.replaceAll('**', '');
    out = out.replaceAll('__', '');
    out = out.replaceAll('`', '');
    out = out.replaceAllMapped(
      RegExp(r'(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)'),
      (m) => m.group(1) ?? '',
    );
    out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return out.trim();
  }
}
