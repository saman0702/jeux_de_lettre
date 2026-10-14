import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player preferences: sound effects, music and vibrations.
class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._prefs, {
    this._sound = true,
    this._music = true,
    this._vibration = true,
  });

  /// Not persisted; used by tests.
  AppSettings.inMemory() : this._(null);

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(
      prefs,
      sound: prefs.getBool(_soundKey) ?? true,
      music: prefs.getBool(_musicKey) ?? true,
      vibration: prefs.getBool(_vibrationKey) ?? true,
    );
  }

  static const _soundKey = 'settings.sound';
  static const _musicKey = 'settings.music';
  static const _vibrationKey = 'settings.vibration';

  final SharedPreferences? _prefs;
  bool _sound;
  bool _music;
  bool _vibration;

  bool get sound => _sound;
  bool get music => _music;
  bool get vibration => _vibration;

  set sound(bool value) => _update(_soundKey, value, () => _sound = value);
  set music(bool value) => _update(_musicKey, value, () => _music = value);
  set vibration(bool value) =>
      _update(_vibrationKey, value, () => _vibration = value);

  void _update(String key, bool value, VoidCallback apply) {
    apply();
    _prefs?.setBool(key, value);
    notifyListeners();
  }
}
