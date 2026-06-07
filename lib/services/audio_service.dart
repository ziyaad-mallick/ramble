import 'dart:async';
import 'package:record/record.dart';

/// Records audio to a WAV file (16kHz mono) and streams normalized amplitude (0..1).
/// Created per recording session; call dispose() when done.
class AudioService {
  AudioRecorder? _recorder;
  final _levelController = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _amplitudeSub;

  /// Normalized amplitude 0..1 for waveform display.
  Stream<double> get levelStream => _levelController.stream;

  /// Returns true if the app has microphone permission.
  Future<bool> hasPermission() async {
    final tmp = AudioRecorder();
    final result = await tmp.hasPermission();
    tmp.dispose();
    return result;
  }

  /// Start recording to [path]. Path should end in `.wav`.
  /// Amplitude events fire every ~80ms.
  Future<void> start(String path) async {
    _recorder = AudioRecorder();
    _amplitudeSub = _recorder!
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
      // amp.current is roughly -60..0 dBFS; normalize to 0..1
      final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      if (!_levelController.isClosed) _levelController.add(normalized);
    });
    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  /// Stop recording. Returns the path of the written WAV file, or null on error.
  Future<String?> stop() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final path = await _recorder?.stop();
    _recorder?.dispose();
    _recorder = null;
    return path;
  }

  /// Cancel without saving.
  Future<void> cancel() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorder?.cancel();
    _recorder?.dispose();
    _recorder = null;
  }

  void dispose() {
    _amplitudeSub?.cancel();
    if (!_levelController.isClosed) _levelController.close();
    _recorder?.dispose();
  }
}
