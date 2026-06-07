import 'dart:async';

/// Unified interface for speech-to-text engines.
/// Implementations: OsSttService (OS speech_to_text, fallback),
/// WhisperSttService (sherpa_onnx, to be added).
abstract class TranscriptionService {
  /// Normalized amplitude 0..1 for waveform display during recording.
  Stream<double> get levelStream;

  /// Initialize the engine. Returns true if ready.
  Future<bool> init();

  /// Begin capturing audio / listening.
  Future<void> start();

  /// Stop capturing. Returns the final transcript string.
  Future<String> stop();

  /// Cancel without returning a transcript.
  Future<void> cancel();

  void dispose();
}
