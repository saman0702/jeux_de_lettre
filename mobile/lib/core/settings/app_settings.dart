import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences du joueur (son, musique, vibrations) et identité d'invité.
class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._prefs, {
    required this.clientId,
    this._sound = true,
    this._music = true,
    this._vibration = true,
    this._gameKeyboard = true,
    this._voice = true,
    this._nickname,
    this._languageCode,
    this._avatarPreset = 0,
    this._avatarPending = false,
    Map<int, int>? careerStars,
    this._eliminationBest = 0,
  }) : _careerStars = careerStars ?? {};

  /// Non persisté ; utilisé par les tests.
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
      gameKeyboard: prefs.getBool(_gameKeyboardKey) ?? true,
      voice: prefs.getBool(_voiceKey) ?? true,
      nickname: prefs.getString(_nicknameKey),
      languageCode: prefs.getString(_languageKey),
      avatarPreset: prefs.getInt(_avatarPresetKey) ?? 0,
      avatarPending: prefs.getBool(_avatarPendingKey) ?? false,
      careerStars: _decodeStars(prefs.getString(_careerKey)),
      eliminationBest: prefs.getInt(_eliminationKey) ?? 0,
    );
  }

  static Map<int, int> _decodeStars(String? raw) {
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          int.parse(e.key): e.value as int,
      };
    } catch (_) {
      return {};
    }
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
  static const _gameKeyboardKey = 'settings.game_keyboard';
  static const _voiceKey = 'settings.voice';
  static const _languageKey = 'settings.language';
  static const _nicknameKey = 'player.nickname';
  static const _clientIdKey = 'player.client_id';
  static const _avatarPresetKey = 'player.avatar_preset';
  static const _avatarPendingKey = 'player.avatar_pending';
  static const _careerKey = 'career.stars';
  static const _eliminationKey = 'elimination.best';

  final SharedPreferences? _prefs;

  /// Identifiant aléatoire gardé sur l'appareil : il permet à un invité de
  /// retrouver sa place après une perte de connexion.
  final String clientId;
  bool _sound;
  bool _music;
  bool _vibration;
  bool _gameKeyboard;
  bool _voice;
  String? _nickname;
  String? _languageCode;
  int _avatarPreset;
  bool _avatarPending;
  final Map<int, int> _careerStars;
  int _eliminationBest;

  /// Étoiles obtenues par niveau de carrière (meilleur résultat).
  Map<int, int> get careerStars => Map.unmodifiable(_careerStars);

  /// Un niveau est ouvert quand le précédent a au moins une étoile.
  bool careerUnlocked(int level) =>
      level <= 1 || (_careerStars[level - 1] ?? 0) > 0;

  /// Garde le meilleur nombre d'étoiles du niveau.
  void recordCareer(int level, int stars) {
    if (stars <= (_careerStars[level] ?? 0)) return;
    _careerStars[level] = stars;
    _prefs?.setString(
      _careerKey,
      jsonEncode({for (final e in _careerStars.entries) '${e.key}': e.value}),
    );
    notifyListeners();
  }

  /// Record des éliminatoires : manches réussies.
  int get eliminationBest => _eliminationBest;

  /// Renvoie vrai si [rounds] bat le record.
  bool recordElimination(int rounds) {
    if (rounds <= _eliminationBest) return false;
    _eliminationBest = rounds;
    _prefs?.setInt(_eliminationKey, rounds);
    notifyListeners();
    return true;
  }

  /// Personnage dessiné choisi, gardé sur le téléphone pour l'afficher hors
  /// ligne.
  int get avatarPreset => _avatarPreset;

  /// Choisi hors ligne : à envoyer au serveur dès la reconnexion.
  bool get avatarPending => _avatarPending;

  void setAvatarPreset(int preset, {required bool pending}) {
    _avatarPreset = preset;
    _avatarPending = pending;
    _prefs?.setInt(_avatarPresetKey, preset);
    _prefs?.setBool(_avatarPendingKey, pending);
    notifyListeners();
  }

  bool get sound => _sound;
  bool get music => _music;
  bool get vibration => _vibration;

  /// Clavier de jeu intégré à la place de celui du téléphone.
  bool get gameKeyboard => _gameKeyboard;

  /// Voix du présentateur en fin de manche.
  bool get voice => _voice;
  String? get nickname => _nickname;

  /// Langue choisie pour l'appli ('fr', 'en'), ou null pour suivre le
  /// téléphone.
  String? get languageCode => _languageCode;

  set languageCode(String? value) {
    _languageCode = value;
    if (value == null) {
      _prefs?.remove(_languageKey);
    } else {
      _prefs?.setString(_languageKey, value);
    }
    notifyListeners();
  }

  set sound(bool value) => _update(_soundKey, value, () => _sound = value);
  set music(bool value) => _update(_musicKey, value, () => _music = value);
  set vibration(bool value) =>
      _update(_vibrationKey, value, () => _vibration = value);
  set gameKeyboard(bool value) =>
      _update(_gameKeyboardKey, value, () => _gameKeyboard = value);
  set voice(bool value) => _update(_voiceKey, value, () => _voice = value);

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
