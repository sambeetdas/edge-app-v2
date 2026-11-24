import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/edged_logo.dart';
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
  bool _voiceReplyEnabled = false;
  bool _isListening = false;
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
    ref.read(voiceServiceProvider).dispose();
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

    setState(() {
      _bubbles.add(
        ChatBubbleModel(
          id: userMsg.id,
          isUser: true,
          content: text,
          timestamp: userMsg.timestamp,
        ),
      );
    });

    await _streamAssistantReply();
  }

  Future<void> _regenerateAt(int index) async {
    if (_isGenerating || index < 0 || index >= _bubbles.length) return;

    final target = _bubbles[index];
    final cutStart = target.isUser ? index + 1 : index;

    if (cutStart < _bubbles.length) {
      final idsToDelete = _bubbles
          .sublist(cutStart)
          .map((b) => b.id)
          .where((id) => id != 'streaming')
          .toList();
      await ref
          .read(chatHistoryServiceProvider)
          .deleteMessagesByIds(widget.sessionId, idsToDelete);
      if (!mounted) return;
      setState(() {
        _bubbles.removeRange(cutStart, _bubbles.length);
      });
    }

    await _streamAssistantReply();
  }

  Future<void> _streamAssistantReply() async {
    final history = ref.read(chatHistoryServiceProvider);
    final streamingBubble = ChatBubbleModel(
      id: 'streaming',
      isUser: false,
      content: '',
      isStreaming: true,
    );

    setState(() {
      _bubbles.add(streamingBubble);
      _isGenerating = true;
    });
    _scrollToBottom();

    // Load last 10 messages for context window safety
    final allMsgs = await history.getMessages(widget.sessionId);
    final recent = allMsgs.length > 10
        ? allMsgs.sublist(allMsgs.length - 10)
        : allMsgs;

    final latestUserText = recent
            .where((m) => m.role == 'user')
            .lastOrNull
            ?.content
            .toLowerCase() ??
        '';
    final asksAboutDevice = RegExp(
      r'\b(device|phone|battery|storage|ram|memory|android|ios|model|os)\b',
    ).hasMatch(latestUserText);

    final deviceCtx = asksAboutDevice
        ? '\n${await ref.read(deviceServiceProvider).buildDeviceContextString()}'
        : '';
    final systemPrompt =
        'You are Edged, a helpful, private, offline AI assistant. '
        'Answer the user\'s request directly, concisely, and accurately.$deviceCtx';

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
    final speechBuffer = StringBuffer();
    int lastUiMs = DateTime.now().millisecondsSinceEpoch;

    try {
      await for (final token
          in ref.read(chatEngineProvider).generateStream(request)) {
        sb.write(token);
        if (_voiceReplyEnabled) {
          speechBuffer.write(token);
          final pending = Formatters.stripMarkdown(speechBuffer.toString());
          if (RegExp(r'[.!?]\s*$').hasMatch(pending) && pending.length >= 16) {
            speechBuffer.clear();
            unawaited(ref.read(voiceServiceProvider).speak(pending));
          }
        }
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

      if (_voiceReplyEnabled && speechBuffer.isNotEmpty) {
        final tail = Formatters.stripMarkdown(speechBuffer.toString());
        if (tail.isNotEmpty) {
          unawaited(ref.read(voiceServiceProvider).speak(tail));
        }
      }

      final finalContent = sb.toString().trim();
      String? savedId;
      if (finalContent.isNotEmpty) {
        final saved = await history.addMessage(
          sessionId: widget.sessionId,
          role: 'assistant',
          content: finalContent,
        );
        savedId = saved.id;
      }

      if (mounted) {
        setState(() {
          if (savedId != null) {
            streamingBubble.id = savedId;
          }
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
    ref.read(voiceServiceProvider).stopSpeaking();
    setState(() => _isGenerating = false);
  }

  Future<void> _toggleListening() async {
    final voice = ref.read(voiceServiceProvider);
    if (_isGenerating) {
      _stopGeneration();
    }
    if (_isListening) {
      await voice.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final started = await voice.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _inputController.text = text;
          _inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
          if (isFinal) {
            _isListening = false;
          }
        });
        if (isFinal && text.trim().isNotEmpty) {
          _sendMessage();
        }
      },
    );

    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline speech recognition is unavailable on this device.'),
        ),
      );
      return;
    }
    setState(() => _isListening = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: _voiceReplyEnabled ? 'Mute voice replies' : 'Speak replies offline',
            icon: Icon(
              _voiceReplyEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
            onPressed: () {
              final next = !_voiceReplyEnabled;
              if (!next) {
                ref.read(voiceServiceProvider).stopSpeaking();
              }
              setState(() => _voiceReplyEnabled = next);
            },
          ),
        ],
      ),
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
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const EdgedLogo(
                                      size: 56,
                                      borderRadius: 16,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'How can I help today?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Your messages stay 100% private on your device.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        for (final prompt in const [
                                          'Summarize a topic in 3 bullets',
                                          'Write a polite follow-up email',
                                          'Explain how neural networks work',
                                        ])
                                          ActionChip(
                                            label: Text(prompt),
                                            onPressed: () {
                                              _inputController.text = prompt;
                                              _sendMessage();
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: _bubbles.length,
                              itemBuilder: (_, i) => ChatBubbleWidget(
                                bubble: _bubbles[i],
                                onRetry: _isGenerating
                                    ? null
                                    : () => _regenerateAt(i),
                                onRegenerate: _isGenerating
                                    ? null
                                    : () => _regenerateAt(i),
                              ),
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.surfaceContainerDark
                                : AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.outlineDark
                                      : AppColors.outline)
                                  .withValues(alpha: 0.75),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
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
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: _isListening ? 'Stop listening' : 'Voice input (offline)',
                                onPressed: _toggleListening,
                                color: _isListening
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                icon: Icon(
                                  _isListening
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: _isGenerating
                                      ? null
                                      : AppColors.brandGradient,
                                  color: _isGenerating
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: _isGenerating
                                      ? _stopGeneration
                                      : _sendMessage,
                                  color: Colors.white,
                                  icon: Icon(
                                    _isGenerating
                                        ? Icons.stop_rounded
                                        : Icons.arrow_upward_rounded,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
