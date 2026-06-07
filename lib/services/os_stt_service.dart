import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'transcription_service.dart';

class OsSttService implements TranscriptionService {
  final SpeechToText _speech = SpeechToText();
  final _levelController = StreamController<double>.broadcast();
  String _accumulated = '';
  bool _available = false;

  @override
  Stream<double> get levelStream => _levelController.stream;

  @override
  Future<bool> init() async {
    try {
      _available = await _speech.initialize(onError: (_) {}, onStatus: (_) {});
      return _available;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (!_available) return;
    _accumulated = '';
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        // Prefer final results; keep best partial as running fallback
        if (r.finalResult) {
          _accumulated = r.recognizedWords;
        } else if (r.recognizedWords.length > _accumulated.length) {
          _accumulated = r.recognizedWords;
        }
      },
      onSoundLevelChange: (level) {
        if (!_levelController.isClosed) {
          _levelController.add(((level + 2) / 12).clamp(0.0, 1.0));
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        listenFor: const Duration(minutes: 15),
        pauseFor: const Duration(seconds: 60),
      ),
    );
  }

  @override
  Future<String> stop() async {
    await _speech.stop();
    return _accumulated;
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _accumulated = '';
  }

  @override
  void dispose() {
    _speech.cancel();
    if (!_levelController.isClosed) _levelController.close();
  }
}
