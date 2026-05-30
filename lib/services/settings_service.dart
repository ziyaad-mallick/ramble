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
}
