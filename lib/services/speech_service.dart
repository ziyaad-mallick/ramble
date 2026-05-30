import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  String _lastWords = '';
  bool _available = false;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    try {
      _available = await _speech.initialize(onError: (_) {}, onStatus: (_) {});
      return _available;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  /// Start listening. onPartial fires with the running transcript; onLevel fires
  /// with sound level (raw dB-ish value from the plugin) — caller normalizes.
  Future<void> start({
    required void Function(String) onPartial,
    void Function(double)? onLevel,
  }) async {
    if (!_available) {
      final ok = await init();
      if (!ok) throw StateError('Speech recognition unavailable');
    }
    _lastWords = '';
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        _lastWords = r.recognizedWords;
        onPartial(_lastWords);
      },
      onSoundLevelChange: onLevel,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 30),
      ),
    );
  }

  Future<String> stop() async {
    await _speech.stop();
    return _lastWords;
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _lastWords = '';
  }
}
