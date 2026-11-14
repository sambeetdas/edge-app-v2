import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/chat_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/model_loader_helper.dart';
import 'chat_bubble_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ChatScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatBubbleModel> _bubbles = [];

  String _title = 'New Chat';
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _loadError;
  Timer? _thinkingTimer;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _timeoutTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final history = ref.read(chatHistoryServiceProvider);
      final session = await history.getSession(widget.sessionId);
      final messages = await history.getMessages(widget.sessionId);

      await ensureModelLoadedFromWidget(ref);

      if (!mounted) return;
      setState(() {
        _title = session?.title ?? 'New Chat';
        _bubbles
          ..clear()
          ..addAll(
            messages.map(
              (m) => ChatBubbleModel(
                id: m.id,
                isUser: m.role == 'user',
                content: m.content,
                timestamp: m.timestamp,
              ),
            ),
          );
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    _inputController.clear();
    final history = ref.read(chatHistoryServiceProvider);

    final userMsg = await history.addMessage(
      sessionId: widget.sessionId,
      role: 'user',
      content: text,
    );

    if (_bubbles.isEmpty) {
      final autoTitle =
          text.length > 40 ? '${text.substring(0, 40)}...' : text;
      await history.updateSessionTitle(widget.sessionId, autoTitle);
      _title = autoTitle;
    }

    final streamingBubble = ChatBubbleModel(
      id: 'streaming',
      isUser: false,
      content: '',
      isStreaming: true,
    );

    setState(() {
      _bubbles.add(
        ChatBubbleModel(
          id: userMsg.id,
          isUser: true,
          content: text,
          timestamp: userMsg.timestamp,
        ),
      );
      _bubbles.add(streamingBubble);
      _isGenerating = true;
    });
    _scrollToBottom();

    // Load last 10 messages for context window safety
    final allMsgs = await history.getMessages(widget.sessionId);
    final recent = allMsgs.length > 10
        ? allMsgs.sublist(allMsgs.length - 10)
        : allMsgs;

    final deviceCtx =
        await ref.read(deviceServiceProvider).buildDeviceContextString();
    final systemPrompt =
        'You are Edged, a helpful, private, offline AI assistant running on-device. '
        'Be concise and clear.\n$deviceCtx';

    final request = ChatRequest(
      systemPrompt: systemPrompt,
      messages: recent
          .map(
            (m) => ChatMessage(
              role: m.role == 'user' ? ChatRole.user : ChatRole.assistant,
              content: m.content,
            ),
          )
          .toList(),
      maxTokens: 512,
    );

    _thinkingTimer?.cancel();
    _thinkingTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && streamingBubble.isStreaming) {
        setState(() => streamingBubble.isStillThinking = true);
      }
    });

    bool timedOut = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 120), () {
      timedOut = true;
      ref.read(chatEngineProvider).stopGeneration();
    });

    final sb = StringBuffer();
    int lastUiMs = DateTime.now().millisecondsSinceEpoch;

    try {
      await for (final token
          in ref.read(chatEngineProvider).generateStream(request)) {
        sb.write(token);
        if (!streamingBubble.hasStartedStreaming) {
          streamingBubble.hasStartedStreaming = true;
        }
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastUiMs >= 80) {
          lastUiMs = nowMs;
          if (mounted) {
            setState(() => streamingBubble.content = sb.toString());
            _scrollToBottom();
          }
        }
      }

      final finalContent = sb.toString().trim();
      if (finalContent.isNotEmpty) {
        await history.addMessage(
          sessionId: widget.sessionId,
          role: 'assistant',
          content: finalContent,
        );
      }

      if (mounted) {
        setState(() {
          streamingBubble.content = finalContent.isEmpty
              ? (timedOut ? 'Generation timed out.' : 'Stopped.')
              : finalContent;
          streamingBubble.isStreaming = false;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          streamingBubble.content = 'Failed to generate response: $e';
          streamingBubble.isStreaming = false;
          streamingBubble.hasFailed = true;
          _isGenerating = false;
        });
      }
    } finally {
      _thinkingTimer?.cancel();
      _timeoutTimer?.cancel();
    }
  }

  void _stopGeneration() {
    ref.read(chatEngineProvider).stopGeneration();
    setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _bubbles.isEmpty
                          ? Center(
                              child: Text(
                                'Ask anything — 100% offline on your device.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: _bubbles.length,
                              itemBuilder: (_, i) => ChatBubbleWidget(
                                bubble: _bubbles[i],
                              ),
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: const InputDecoration(
                                  hintText: 'Message Edged...',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed:
                                  _isGenerating ? _stopGeneration : _sendMessage,
                              icon: Icon(
                                _isGenerating
                                    ? Icons.stop_rounded
                                    : Icons.send_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
