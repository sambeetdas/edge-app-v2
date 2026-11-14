import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/games_service.dart';
import '../../engine/models/chat_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/model_loader_helper.dart';
import '../chat/chat_bubble_widget.dart';

class GamePlayScreen extends ConsumerStatefulWidget {
  final String gameId;

  const GamePlayScreen({super.key, required this.gameId});

  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatBubbleModel> _bubbles = [];
  final List<ChatMessage> _history = [];

  static final RegExp _nextLetterRegex =
      RegExp(r'next starts with\s+([A-Za-z])', caseSensitive: false);

  GameDefinition? _game;
  int _playerTurnCount = 0;
  String? _expectedStartLetter;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initGame() async {
    try {
      GameDefinition? found;
      for (final g in GamesService.builtInGames) {
        if (g.id.toLowerCase() == widget.gameId.toLowerCase()) {
          found = g;
          break;
        }
      }
      if (found == null) {
        final customs = await ref.read(gamesServiceProvider).getCustomGames();
        for (final g in customs) {
          if (g.id.toLowerCase() == widget.gameId.toLowerCase()) {
            found = g;
            break;
          }
        }
      }

      if (found == null) {
        setState(() {
          _loadError = 'Game not found.';
          _isLoading = false;
        });
        return;
      }

      await ensureModelLoadedFromWidget(ref);
      if (!mounted) return;

      setState(() {
        _game = found;
        _isLoading = false;
      });
      _startNewGame();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startNewGame() {
    final game = _game;
    if (game == null) return;
    _history.clear();
    _bubbles.clear();
    _playerTurnCount = 0;
    _expectedStartLetter = null;

    if (game.starterMessage.trim().isNotEmpty) {
      _history.add(
        ChatMessage(role: ChatRole.assistant, content: game.starterMessage),
      );
      _bubbles.add(
        ChatBubbleModel(
          id: 'starter',
          isUser: false,
          content: game.starterMessage,
        ),
      );
    }
    setState(() {});
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

  String _phaseDirective(int turn) {
    return switch (turn) {
      3 => '\n\n[Game pacing: Early-mid game — escalate intrigue or challenge.]',
      6 => '\n\n[Game pacing: Mid game — introduce a surprising twist or pivot.]',
      10 => '\n\n[Game pacing: Late game — raise the stakes and move toward a climax.]',
      15 => '\n\n[Game pacing: Final stretch — drive toward a decisive resolution.]',
      _ => '',
    };
  }

  Future<void> _send() async {
    final game = _game;
    final text = _inputController.text.trim();
    if (game == null || text.isEmpty || _isGenerating) return;

    final lower = text.toLowerCase();
    final isEndCommand = lower == 'stop' || lower == 'i give up';

    if (game.inputMode == GameInputMode.word && !isEndCommand) {
      final parts = text.split(RegExp(r'\s+'));
      final isSingleAlpha =
          parts.length <= 1 && RegExp(r'^[a-zA-Z]+$').hasMatch(text);
      if (!isSingleAlpha) {
        _inputController.clear();
        setState(() {
          _bubbles.add(
            ChatBubbleModel(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              isUser: false,
              content: 'Please enter a single English word (letters only).',
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      if (_expectedStartLetter != null &&
          text[0].toUpperCase() != _expectedStartLetter) {
        _inputController.clear();
        setState(() {
          _bubbles.add(
            ChatBubbleModel(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              isUser: false,
              content:
                  "Your word must start with '$_expectedStartLetter'. Try again!",
            ),
          );
        });
        _scrollToBottom();
        return;
      }
    }

    _inputController.clear();
    _playerTurnCount++;
    _history.add(ChatMessage(role: ChatRole.user, content: text));
    setState(() {
      _bubbles.add(
        ChatBubbleModel(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          isUser: true,
          content: text,
        ),
      );
      _isGenerating = true;
    });
    _scrollToBottom();

    await _generateAiTurn();
  }

  Future<void> _generateAiTurn() async {
    final game = _game;
    if (game == null) return;

    final streamingBubble = ChatBubbleModel(
      id: 'streaming',
      isUser: false,
      content: '',
      isStreaming: true,
    );
    setState(() => _bubbles.add(streamingBubble));
    _scrollToBottom();

    final directive =
        game.usePhaseDirectives ? _phaseDirective(_playerTurnCount) : '';
    final lastUser = _history
        .lastWhere(
          (m) => m.role == ChatRole.user,
          orElse: () => const ChatMessage(role: ChatRole.user, content: ''),
        )
        .content
        .toLowerCase()
        .trim();
    final isEndCommand = lastUser == 'stop' || lastUser == 'i give up';
    final maxTokens =
        (game.inputMode == GameInputMode.word && !isEndCommand) ? 50 : 512;

    final request = ChatRequest(
      systemPrompt: '${game.systemPrompt}$directive',
      messages: List.of(_history),
      maxTokens: maxTokens,
    );

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

      final responseText = sb.toString().trim();
      if (game.inputMode == GameInputMode.word) {
        final m = _nextLetterRegex.firstMatch(responseText);
        if (m != null) {
          _expectedStartLetter = m.group(1)!.toUpperCase();
        }
      }

      _history.add(ChatMessage(role: ChatRole.assistant, content: responseText));

      if (mounted) {
        setState(() {
          streamingBubble.content = responseText;
          streamingBubble.isStreaming = false;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          streamingBubble.content =
              'Response failed — tap Retry to try again.\n($e)';
          streamingBubble.isStreaming = false;
          streamingBubble.hasFailed = true;
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _showRules() async {
    final game = _game;
    if (game == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('How to Play: ${game.name}'),
        content: Text(
          game.howToPlay.isEmpty
              ? 'No rules have been defined for this game.'
              : game.howToPlay,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Game'),
        content: const Text('Start over from the beginning?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (ok == true) _startNewGame();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      appBar: AppBar(
        title: Text(game == null ? 'Game' : '${game.icon} ${game.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How to Play',
            onPressed: _showRules,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'New Game',
            onPressed: _confirmRestart,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text(_loadError!))
              : Column(
                  children: [
                    if (game?.inputMode == GameInputMode.word &&
                        _expectedStartLetter != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          'Next word must start with: $_expectedStartLetter',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _bubbles.length,
                        itemBuilder: (_, i) {
                          final b = _bubbles[i];
                          return ChatBubbleWidget(
                            bubble: b,
                            onRetry: b.hasFailed
                                ? () {
                                    setState(() {
                                      _bubbles.remove(b);
                                      _isGenerating = true;
                                    });
                                    _generateAiTurn();
                                  }
                                : null,
                          );
                        },
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
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText: game?.inputMode == GameInputMode.word
                                      ? (_expectedStartLetter != null
                                          ? 'Word starting with $_expectedStartLetter...'
                                          : 'Enter a word...')
                                      : 'Your move...',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _isGenerating
                                  ? () {
                                      ref
                                          .read(chatEngineProvider)
                                          .stopGeneration();
                                      setState(() => _isGenerating = false);
                                    }
                                  : _send,
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
