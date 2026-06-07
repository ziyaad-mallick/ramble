import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'settings_service.dart';

/// On-device LLM (Gemma 3 1B, int4 ~550MB) via flutter_gemma / MediaPipe.
///
/// This is Miko's *everyday* brain: it structures every ramble — summary, the
/// thought-arc, context tag, and basic reasoning/checks — entirely on-device,
/// for free, with no network. The cloud (see [LlmClient]) is reserved for the
/// explicit "Ask Miko" deep dives that genuinely need live web data.
///
/// The model is downloaded once on demand (Settings), not bundled, so the APK
/// stays small. Everything is guarded: if the model isn't installed or fails
/// to load, callers fall back to rule-based structuring — the app never breaks
/// and never silently costs money.
class LocalLlmService {
  LocalLlmService._();
  static final LocalLlmService instance = LocalLlmService._();

  // Typed dynamic on purpose: keeps us decoupled from flutter_gemma's exact
  // model class so a minor API drift can't break the build.
  dynamic _model;
  bool _initializing = false;

  /// Loaded into memory and ready to infer.
  bool get isReady => _model != null;

  /// The user has downloaded the model at least once.
  bool get isInstalled => SettingsService.instance.localModelInstalled;

  /// Load the already-downloaded model into memory. No-op if not installed.
  /// Returns true when [isReady].
  Future<bool> ensureReady() async {
    if (_model != null) return true;
    if (!isInstalled || _initializing) return _model != null;
    _initializing = true;
    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.cpu,
      );
      return _model != null;
    } catch (e) {
      debugPrint('LocalLlmService: failed to load model: $e');
      _model = null;
      return false;
    } finally {
      _initializing = false;
    }
  }

  /// Download + install the model from [SettingsService.localModelUrl].
  /// [onProgress] reports 0-100. Marks it installed and loads it on success.
  Future<void> download({required void Function(int) onProgress}) async {
    final url = SettingsService.instance.localModelUrl;
    final token = SettingsService.instance.hfToken.trim();
    await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
        .fromNetwork(url, token: token.isEmpty ? null : token)
        .withProgress((p) => onProgress(p))
        .install();
    SettingsService.instance.localModelInstalled = true;
    await ensureReady();
  }

  /// Single-shot completion. Throws [StateError] if the model isn't ready so
  /// the caller can fall back. A fresh chat per call keeps analyses independent.
  Future<String> complete({required String prompt}) async {
    final ok = await ensureReady();
    if (!ok || _model == null) {
      throw StateError('Local model not ready');
    }
    final chat = await _model.createChat();
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final resp = await chat.generateChatResponse();
    return resp.toString().trim();
  }
}
