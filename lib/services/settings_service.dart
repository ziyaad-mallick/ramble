import 'package:hive_flutter/hive_flutter.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox('settings');
  }

  String get userName => _box.get('userName', defaultValue: '') as String;
  set userName(String v) => _box.put('userName', v);

  String get apiKey => _box.get('apiKey', defaultValue: '') as String;
  set apiKey(String v) => _box.put('apiKey', v);

  bool get mikoEnabled => _box.get('mikoEnabled', defaultValue: true) as bool;
  set mikoEnabled(bool v) => _box.put('mikoEnabled', v);

  bool get onboarded => _box.get('onboarded', defaultValue: false) as bool;
  set onboarded(bool v) => _box.put('onboarded', v);

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  // ── Miko's local brain (on-device LLM) ──────────────────────────────────
  /// Default: Gemma 3 1B IT, int4 quantized (~550MB) from the LiteRT community.
  static const defaultModelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  bool get localModelInstalled =>
      _box.get('localModelInstalled', defaultValue: false) as bool;
  set localModelInstalled(bool v) => _box.put('localModelInstalled', v);

  String get localModelUrl =>
      _box.get('localModelUrl', defaultValue: defaultModelUrl) as String;
  set localModelUrl(String v) => _box.put('localModelUrl', v);

  /// Optional Hugging Face token, only if the model host requires auth.
  String get hfToken => _box.get('hfToken', defaultValue: '') as String;
  set hfToken(String v) => _box.put('hfToken', v);
}
