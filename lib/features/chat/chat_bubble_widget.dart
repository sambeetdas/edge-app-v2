import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

class ChatBubbleModel {
  final String id;
  final bool isUser;
  String content;
  bool isStreaming;
  bool hasStartedStreaming;
  bool isStillThinking;
  bool hasFailed;
  final DateTime timestamp;

  ChatBubbleModel({
    required this.id,
    required this.isUser,
    required this.content,
    this.isStreaming = false,
    this.hasStartedStreaming = false,
    this.isStillThinking = false,
    this.hasFailed = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatBubbleWidget extends StatelessWidget {
  final ChatBubbleModel bubble;
  final VoidCallback? onRetry;

  const ChatBubbleWidget({
    super.key,
    required this.bubble,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userBg = isDark ? AppColors.userBubbleDark : AppColors.userBubbleLight;
    final aiBg = isDark ? AppColors.aiBubbleDark : AppColors.aiBubbleLight;
    final aiText =
        isDark ? AppColors.aiBubbleTextDark : AppColors.aiBubbleTextLight;

    final alignment =
        bubble.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = bubble.isUser ? userBg : aiBg;
    final textColor = bubble.isUser ? Colors.white : aiText;

    final displayContent = bubble.isUser
        ? bubble.content
        : Formatters.stripMarkdown(bubble.content);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(bubble.isUser ? 18 : 4),
            bottomRight: Radius.circular(bubble.isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bubble.isStreaming && !bubble.hasStartedStreaming)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bubble.isStillThinking
                        ? 'Still thinking…'
                        : 'Responding…',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.85),
                      fontStyle: FontStyle.italic,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              )
            else
              SelectableText(
                displayContent,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            if (!bubble.isUser && !bubble.isStreaming && displayContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: displayContent));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: textColor.withValues(alpha: 0.65),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textColor.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (bubble.hasFailed && onRetry != null) ...[
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: onRetry,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
