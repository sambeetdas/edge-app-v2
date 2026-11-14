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

  /// Strips basic markdown markers for clean bubble display (matching StripMarkdownConverter).
  static String stripMarkdown(String input) {
    var out = input;
    out = out.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    out = out.replaceAll('**', '');
    out = out.replaceAll('__', '');
    out = out.replaceAll('`', '');
    out = out.replaceAllMapped(
      RegExp(r'(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)'),
      (m) => m.group(1) ?? '',
    );
    return out.trim();
  }
}
