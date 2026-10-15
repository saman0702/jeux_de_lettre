import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player preferences (sound, music, vibrations) and guest identity.
class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._prefs, {
    required this.clientId,
    this._sound = true,
    this._music = true,
    this._vibration = true,
    this._nickname,
  });

  /// Not persisted; used by tests.
  AppSettings.inMemory({String? nickname, String clientId = 'test-client-id'})
    : this._(null, clientId: clientId, nickname: nickname);

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    var clientId = prefs.getString(_clientIdKey);
    if (clientId == null) {
      clientId = _randomId();
      await prefs.setString(_clientIdKey, clientId);
    }
    return AppSettings._(
      prefs,
      clientId: clientId,
      sound: prefs.getBool(_soundKey) ?? true,
      music: prefs.getBool(_musicKey) ?? true,
      vibration: prefs.getBool(_vibrationKey) ?? true,
      nickname: prefs.getString(_nicknameKey),
    );
  }

  static String _randomId() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  static const _soundKey = 'settings.sound';
  static const _musicKey = 'settings.music';
  static const _vibrationKey = 'settings.vibration';
  static const _nicknameKey = 'player.nickname';
  static const _clientIdKey = 'player.client_id';

  final SharedPreferences? _prefs;

  /// Random id kept on the device: it lets a guest get their seat back after
  /// losing the connection.
  final String clientId;
  bool _sound;
  bool _music;
  bool _vibration;
  String? _nickname;

  bool get sound => _sound;
  bool get music => _music;
  bool get vibration => _vibration;
  String? get nickname => _nickname;

  set sound(bool value) => _update(_soundKey, value, () => _sound = value);
  set music(bool value) => _update(_musicKey, value, () => _music = value);
  set vibration(bool value) =>
      _update(_vibrationKey, value, () => _vibration = value);

  set nickname(String? value) {
    _nickname = value;
    if (value == null) {
      _prefs?.remove(_nicknameKey);
    } else {
      _prefs?.setString(_nicknameKey, value);
    }
    notifyListeners();
  }

  void _update(String key, bool value, VoidCallback apply) {
    apply();
    _prefs?.setBool(key, value);
    notifyListeners();
  }
}
