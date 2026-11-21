import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart'
    show LlamaController;

import '../models/chat_models.dart';
import '../models/prompt_format.dart';

/// Serialized on-device LLM inference engine.
/// Uses `llama_flutter_android` (llama.cpp) on Android and a native
/// MethodChannel ('com.edgedai.app/llama') when linked on other platforms,
/// falling back to an offline local stream if no native runtime is available.
class ChatEngine {
  static const MethodChannel _llamaChannel =
      MethodChannel('com.edgedai.app/llama');

  LlamaController? _llamaController;
  bool _isLoaded = false;
  bool _nativeBackendAvailable = false;
  String? _loadedModelPath;
  PromptFormat _promptFormat = PromptFormat.chatML;
  bool _suppressThinkingMode = false;
  ModelOptions _options = ModelOptions.defaults;
  bool _isCancelled = false;

  // Single-flight mutex ensuring only one inference/load/unload runs at a time.
  Future<void> _lock = Future.value();

  bool get isLoaded => _isLoaded;
  bool get isNativeBackendAvailable => _nativeBackendAvailable;
  String? get loadedModelPath => _loadedModelPath;
  PromptFormat get promptFormat => _promptFormat;

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> loadModel({
    required String modelPath,
    required PromptFormat promptFormat,
    bool suppressThinkingMode = false,
    ModelOptions options = ModelOptions.defaults,
  }) {
    return _synchronized(() async {
      if (_isLoaded && _loadedModelPath == modelPath) return;

      _promptFormat = promptFormat;
      _suppressThinkingMode = suppressThinkingMode;
      _options = options;

      if (!kIsWeb && Platform.isAndroid) {
        try {
          if (_llamaController != null) {
            await _llamaController!.dispose();
            _llamaController = null;
          }
          final controller = LlamaController();
          var gpuLayers = options.gpuLayers;
          if (gpuLayers == 0) {
            try {
              final gpu = await controller.detectGpu();
              if (gpu.vulkanSupported) {
                gpuLayers = gpu.recommendedGpuLayers;
              }
            } catch (_) {}
          }
          await controller.loadModel(
            modelPath: modelPath,
            threads: options.threadCount,
            contextSize: options.contextSize,
            gpuLayers: gpuLayers,
          );
          _llamaController = controller;
          _nativeBackendAvailable = true;
        } on MissingPluginException {
          _nativeBackendAvailable = false;
        }
      } else {
        try {
          await _llamaChannel.invokeMethod<bool>('loadModel', {
            'modelPath': modelPath,
            'contextSize': options.contextSize,
            'batchSize': options.batchSize,
            'gpuLayers': options.gpuLayers,
            'threadCount': options.threadCount,
          });
          _nativeBackendAvailable = true;
        } on MissingPluginException {
          // Native llama.cpp plugin not linked yet — run with offline local fallback.
          _nativeBackendAvailable = false;
        }
      }

      _loadedModelPath = modelPath;
      _isLoaded = true;
    });
  }

  Future<void> unloadModel() {
    return _synchronized(() async {
      if (_llamaController != null) {
        try {
          await _llamaController!.dispose();
        } catch (_) {}
        _llamaController = null;
      } else if (_nativeBackendAvailable) {
        try {
          await _llamaChannel.invokeMethod('unloadModel');
        } catch (_) {}
      }
      _isLoaded = false;
      _loadedModelPath = null;
    });
  }

  void stopGeneration() {
    _isCancelled = true;
    if (_llamaController != null) {
      _llamaController!.stop().catchError((_) {});
    } else if (_nativeBackendAvailable) {
      _llamaChannel.invokeMethod('stopGeneration').catchError((_) {});
    }
  }

  /// Streams generated tokens while holding back potential partial anti-prompt sequences.
  Stream<String> generateStream(ChatRequest request) async* {
    if (!_isLoaded) {
      throw StateError('No model is loaded.');
    }

    _isCancelled = false;
    final formattedPrompt = _promptFormat.formatPrompt(
      systemPrompt: request.systemPrompt,
      messages: request.messages,
      suppressThinkingMode: _suppressThinkingMode,
    );

    final antiPrompts = _promptFormat.antiPrompts;
    final maxAntiLen = antiPrompts.fold<int>(
      0,
      (max, s) => s.length > max ? s.length : max,
    );

    final buffer = StringBuffer();
    final rawStream = _nativeBackendAvailable
        ? _streamNativeLlama(formattedPrompt, request)
        : _streamLocalFallback(request);

    await for (final token in rawStream) {
      if (_isCancelled) break;
      buffer.write(token);

      final current = buffer.toString();
      final stopHit = _findFirstAntiPrompt(current, antiPrompts);
      if (stopHit != null) {
        final clean = current.substring(0, stopHit);
        if (clean.isNotEmpty) yield clean;
        return;
      }

      if (current.length > maxAntiLen) {
        final safeEnd = current.length - maxAntiLen;
        final safePart = current.substring(0, safeEnd);
        final remainder = current.substring(safeEnd);
        buffer
          ..clear()
          ..write(remainder);
        yield safePart;
      }
    }

    if (!_isCancelled && buffer.isNotEmpty) {
      var tail = buffer.toString();
      for (final anti in antiPrompts) {
        tail = tail.replaceAll(anti, '');
      }
      if (tail.isNotEmpty) yield tail;
    }
  }

  int? _findFirstAntiPrompt(String text, List<String> antiPrompts) {
    int? earliest;
    for (final anti in antiPrompts) {
      final idx = text.indexOf(anti);
      if (idx >= 0 && (earliest == null || idx < earliest)) {
        earliest = idx;
      }
    }
    return earliest;
  }

  Stream<String> _streamNativeLlama(
    String formattedPrompt,
    ChatRequest request,
  ) async* {
    final controller = _llamaController;
    if (controller != null) {
      yield* controller.generate(
        prompt: formattedPrompt,
        maxTokens: request.maxTokens ?? _options.maxTokens,
        temperature: request.temperature ?? _options.temperature,
        topP: request.topP ?? _options.topP,
        repeatPenalty: request.repeatPenalty ?? _options.repeatPenalty,
      );
      return;
    }

    const EventChannel tokenChannel =
        EventChannel('com.edgedai.app/llama_tokens');
    await _llamaChannel.invokeMethod('startGeneration', {
      'prompt': formattedPrompt,
      'temperature': request.temperature ?? _options.temperature,
      'topP': request.topP ?? _options.topP,
      'maxTokens': request.maxTokens ?? _options.maxTokens,
      'repeatPenalty': request.repeatPenalty ?? _options.repeatPenalty,
    });

    await for (final event in tokenChannel.receiveBroadcastStream()) {
      if (_isCancelled) break;
      if (event is String) {
        yield event;
      } else if (event == null) {
        break;
      }
    }
  }

  /// Offline deterministic token streamer used when native llama.cpp AAR/XCFramework
  /// is not yet linked into the runner, so all UI flows, games, skills, and Q&A work.
  Stream<String> _streamLocalFallback(ChatRequest request) async* {
    final lastUser = request.messages
        .lastWhere(
          (m) => m.role == ChatRole.user,
          orElse: () => const ChatMessage(role: ChatRole.user, content: ''),
        )
        .content
        .trim();

    final reply = _buildOfflineFallbackReply(request.systemPrompt ?? '', lastUser);
    final words = reply.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (_isCancelled) break;
      await Future.delayed(const Duration(milliseconds: 22));
      yield i == 0 ? words[i] : ' ${words[i]}';
    }
  }

  String _buildOfflineFallbackReply(String systemPrompt, String userInput) {
    final lowerSys = systemPrompt.toLowerCase();
    final lowerUser = userInput.toLowerCase();

    if (lowerSys.contains('word chain') || lowerSys.contains('vocabulary chain')) {
      if (lowerUser == 'stop' || lowerUser == 'i give up') {
        return 'Vocabulary Report: Great effort! You kept the chain moving with strong word choices. Rating: 8/10.';
      }
      final clean = userInput.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      final lastChar = clean.isNotEmpty
          ? clean[clean.length - 1].toUpperCase()
          : 'E';
      final wordMap = <String, String>{
        'A': 'Apex — next starts with X',
        'B': 'Blitz — next starts with Z',
        'C': 'Cortex — next starts with X',
        'D': 'Dusk — next starts with K',
        'E': 'Equinox — next starts with X',
        'F': 'Flux — next starts with X',
        'G': 'Glimpse — next starts with E',
        'H': 'Helix — next starts with X',
        'I': 'Index — next starts with X',
        'J': 'Jinx — next starts with X',
        'K': 'Kayak — next starts with K',
        'L': 'Lynx — next starts with X',
        'M': 'Matrix — next starts with X',
        'N': 'Nexus — next starts with S',
        'O': 'Onyx — next starts with X',
        'P': 'Phoenix — next starts with X',
        'Q': 'Quartz — next starts with Z',
        'R': 'Reflex — next starts with X',
        'S': 'Sphinx — next starts with X',
        'T': 'Topaz — next starts with Z',
        'U': 'Umbra — next starts with A',
        'V': 'Vortex — next starts with X',
        'W': 'Waltz — next starts with Z',
        'X': 'Xenon — next starts with N',
        'Y': 'Yacht — next starts with T',
        'Z': 'Zenith — next starts with H',
      };
      return wordMap[lastChar] ?? 'Echo — next starts with O';
    }

    if (lowerSys.contains('summarizer')) {
      final preview = userInput.length > 140
          ? '${userInput.substring(0, 140)}...'
          : userInput;
      return '• Key takeaway: $preview\n• On-device model is ready (link native llama.cpp AAR/XCFramework for full GGUF token inference).';
    }

    return 'Running in offline Edged preview mode on your downloaded model (${_loadedModelPath?.split('/').last ?? 'GGUF'}). '
        'You asked: "$userInput". To enable full hardware GGUF token generation, attach the llama.cpp native library to the com.edgedai.app/llama channel.';
  }
}
