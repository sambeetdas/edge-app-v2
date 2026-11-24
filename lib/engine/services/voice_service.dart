import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 100% offline-first Voice Service (on-device English STT + local TTS with barge-in).
class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttInitialized = false;
  bool _ttsInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initStt() async {
    if (_sttInitialized) return true;
    _sttInitialized = await _stt.initialize(
      onError: (_) => _isListening = false,
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _sttInitialized;
  }

  Future<void> initTts() async {
    if (_ttsInitialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _ttsInitialized = true;
  }

  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    await stopSpeaking();
    final ok = await initStt();
    if (!ok) return false;

    _isListening = true;
    await _stt.listen(
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        onDevice: true,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
      onResult: (res) {
        if (res.finalResult) {
          _isListening = false;
        }
        onResult(res.recognizedWords, res.finalResult);
      },
    );
    return true;
  }

  Future<void> stopListening() async {
    _isListening = false;
    if (_sttInitialized) {
      await _stt.stop();
    }
  }

  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await initTts();
    await _tts.speak(clean);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
  }
}
