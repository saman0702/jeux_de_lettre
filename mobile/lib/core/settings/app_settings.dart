import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/game/data/models.dart';

/// Préférences du joueur (son, musique, vibrations) et identité d'invité.
class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._prefs, {
    required this.clientId,
    required this.clientToken,
    this._sound = true,
    this._music = true,
    this._vibration = true,
    this._gameKeyboard = true,
    this._voice = true,
    this._musicVolume = 0.7,
    this._nickname,
    this._languageCode,
    this._gender,
    this._country,
    this._onboardingDone = false,
    this._avatarPreset = 0,
    this._avatarPending = false,
    bool careerRulesSeen = false,
    bool eliminationRulesSeen = false,
    Map<int, int>? careerStars,
    Map<int, String>? careerLetters,
    Map<int, Map<String, List<String>>>? careerAnswers,
    this._eliminationBest = 0,
    this._tileStyle = '',
    this._victoryStyle = '',
  }) : _careerStars = careerStars ?? {},
       _careerLetters = careerLetters ?? {},
       _careerAnswers = careerAnswers ?? {},
       _careerRulesSeen = careerRulesSeen,
       _eliminationRulesSeen = eliminationRulesSeen;

  /// Non persisté ; utilisé par les tests (règles déjà « lues » pour ne pas
  /// bloquer les widgets).
  AppSettings.inMemory({String? nickname, String clientId = 'test-client-id'})
    : this._(
        null,
        clientId: clientId,
        clientToken: 'test-client-token-$clientId',
        nickname: nickname,
        careerRulesSeen: true,
        eliminationRulesSeen: true,
      );

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    var clientId = prefs.getString(_clientIdKey);
    if (clientId == null) {
      clientId = _randomId();
      await prefs.setString(_clientIdKey, clientId);
    }
    // Jeton secret, créé une fois : jamais montré aux autres joueurs.
    var clientToken = prefs.getString(_clientTokenKey);
    if (clientToken == null) {
      clientToken = _randomId(length: 48);
      await prefs.setString(_clientTokenKey, clientToken);
    }
    return AppSettings._(
      prefs,
      clientId: clientId,
      clientToken: clientToken,
      sound: prefs.getBool(_soundKey) ?? true,
      music: prefs.getBool(_musicKey) ?? true,
      vibration: prefs.getBool(_vibrationKey) ?? true,
      gameKeyboard: prefs.getBool(_gameKeyboardKey) ?? true,
      voice: prefs.getBool(_voiceKey) ?? true,
      musicVolume: (prefs.getDouble(_musicVolumeKey) ?? 0.7).clamp(0.0, 1.0),
      nickname: prefs.getString(_nicknameKey),
      languageCode: prefs.getString(_languageKey),
      gender: prefs.getString(_genderKey),
      country: prefs.getString(_countryKey),
      // Déjà joué avant l'écran d'accueil : ne pas reforcer l'onboarding.
      onboardingDone: prefs.getBool(_onboardingDoneKey) ??
          (prefs.getString(_nicknameKey) != null ||
              prefs.containsKey(_languageKey) ||
              prefs.getBool(_careerRulesSeenKey) == true),
      avatarPreset: prefs.getInt(_avatarPresetKey) ?? 0,
      avatarPending: prefs.getBool(_avatarPendingKey) ?? false,
      careerRulesSeen: prefs.getBool(_careerRulesSeenKey) ?? false,
      eliminationRulesSeen: prefs.getBool(_eliminationRulesSeenKey) ?? false,
      careerStars: _decodeStars(prefs.getString(_careerKey)),
      careerLetters: _decodeLetters(prefs.getString(_careerLettersKey)),
      careerAnswers: _decodeAnswers(prefs.getString(_careerAnswersKey)),
      eliminationBest: prefs.getInt(_eliminationKey) ?? 0,
      tileStyle: prefs.getString(_tileStyleKey) ?? '',
      victoryStyle: prefs.getString(_victoryStyleKey) ?? '',
    );
  }

  static Map<int, String> _decodeLetters(String? raw) {
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          int.parse(e.key): e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  static Map<int, Map<String, List<String>>> _decodeAnswers(String? raw) {
    if (raw == null) return {};
    try {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final world in root.entries)
          int.parse(world.key): {
            for (final cat in (world.value as Map<String, dynamic>).entries)
              cat.key: [
                for (final word in cat.value as List)
                  if (word is String && word.trim().isNotEmpty) word.trim(),
              ],
          },
      };
    } catch (_) {
      return {};
    }
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

  static String _randomId({int length = 24}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  static const _soundKey = 'settings.sound';
  static const _musicKey = 'settings.music';
  static const _musicVolumeKey = 'settings.music_volume';
  static const _vibrationKey = 'settings.vibration';
  static const _gameKeyboardKey = 'settings.game_keyboard';
  static const _voiceKey = 'settings.voice';
  static const _languageKey = 'settings.language';
  static const _genderKey = 'player.gender';
  static const _countryKey = 'player.country';
  static const _onboardingDoneKey = 'onboarding.done';
  static const _nicknameKey = 'player.nickname';
  static const _clientIdKey = 'player.client_id';
  static const _clientTokenKey = 'player.client_token';
  static const _avatarPresetKey = 'player.avatar_preset';
  static const _avatarPendingKey = 'player.avatar_pending';
  static const _careerRulesSeenKey = 'career.rules_seen';
  static const _eliminationRulesSeenKey = 'elimination.rules_seen';
  static const _careerKey = 'career.stars';
  static const _careerLettersKey = 'career.letters';
  static const _careerAnswersKey = 'career.answers';
  static const _eliminationKey = 'elimination.best';
  static const _tileStyleKey = 'player.tile_style';
  static const _victoryStyleKey = 'player.victory_style';

  final SharedPreferences? _prefs;

  /// Identifiant aléatoire gardé sur l'appareil : il permet à un invité de
  /// retrouver sa place après une perte de connexion. Il est public : les
  /// autres joueurs du salon le voient.
  final String clientId;

  /// Secret gardé sur l'appareil, envoyé seulement au serveur : sans lui,
  /// personne ne peut agir sur le profil (pièces, achats, messages privés).
  final String clientToken;
  bool _sound;
  bool _music;
  bool _vibration;
  bool _gameKeyboard;
  bool _voice;
  double _musicVolume;
  String? _nickname;
  String? _languageCode;
  String? _gender;
  String? _country;
  bool _onboardingDone;
  int _avatarPreset;
  bool _avatarPending;
  bool _careerRulesSeen;
  bool _eliminationRulesSeen;
  final Map<int, int> _careerStars;

  /// Lettres de la dernière partie de chaque niveau, pour ne pas les retirer.
  final Map<int, String> _careerLetters;

  /// Mots validés par monde de carrière (catégorie fil → valeurs affichées).
  final Map<int, Map<String, List<String>>> _careerAnswers;
  int _eliminationBest;
  String _tileStyle;
  String _victoryStyle;

  /// Tuiles de saisie achetées (identifiant, ou vide).
  String get tileStyle => _tileStyle;

  /// Confettis de fin de partie achetés (identifiant, ou vide).
  String get victoryStyle => _victoryStyle;

  void setStyles({required String tiles, required String victory}) {
    if (_tileStyle == tiles && _victoryStyle == victory) return;
    _tileStyle = tiles;
    _victoryStyle = victory;
    _prefs?.setString(_tileStyleKey, tiles);
    _prefs?.setString(_victoryStyleKey, victory);
    notifyListeners();
  }

  /// Étoiles obtenues par niveau de carrière (meilleur résultat).
  Map<int, int> get careerStars => Map.unmodifiable(_careerStars);

  /// Les règles de la carrière ont déjà été montrées au premier passage.
  bool get careerRulesSeen => _careerRulesSeen;

  void markCareerRulesSeen() {
    if (_careerRulesSeen) return;
    _careerRulesSeen = true;
    _prefs?.setBool(_careerRulesSeenKey, true);
  }

  /// Les règles des éliminatoires ont déjà été lues au premier passage.
  bool get eliminationRulesSeen => _eliminationRulesSeen;

  void markEliminationRulesSeen() {
    if (_eliminationRulesSeen) return;
    _eliminationRulesSeen = true;
    _prefs?.setBool(_eliminationRulesSeenKey, true);
  }

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

  /// Lettres tirées la dernière fois sur ce niveau (vide si jamais joué).
  String careerLettersOf(int level) => _careerLetters[level] ?? '';

  /// Mémorise les lettres d'une partie terminée, pour la revanche suivante.
  void recordCareerLetters(int level, Iterable<String> letters) {
    final seen = <String>{};
    final buffer = StringBuffer();
    for (final letter in letters) {
      final char = letter.trim().toUpperCase();
      if (char.length == 1 && seen.add(char)) buffer.write(char);
    }
    if (buffer.isEmpty) return;
    _careerLetters[level] = buffer.toString();
    _prefs?.setString(
      _careerLettersKey,
      jsonEncode({for (final e in _careerLetters.entries) '${e.key}': e.value}),
    );
    notifyListeners();
  }

  /// Mots déjà validés dans ce monde : interdits si la lettre revient.
  Map<Category, List<String>> careerBannedAnswers(int world) {
    final byCategory = _careerAnswers[world];
    if (byCategory == null || byCategory.isEmpty) return const {};
    final out = <Category, List<String>>{};
    for (final e in byCategory.entries) {
      if (e.value.isEmpty) continue;
      try {
        out[Category.fromWire(e.key)] = List.of(e.value);
      } on StateError {
        // Catégorie inconnue en mémoire : on ignore.
      }
    }
    return out;
  }

  /// Ajoute les réponses validées d'une partie au stock du monde.
  void recordCareerAnswers(int world, Map<Category, Iterable<String>> answers) {
    if (answers.isEmpty) return;
    final byCategory = _careerAnswers.putIfAbsent(world, () => {});
    var changed = false;
    for (final entry in answers.entries) {
      final list = byCategory.putIfAbsent(entry.key.wire, () => []);
      final seen = {for (final w in list) w.toLowerCase()};
      for (final raw in entry.value) {
        final word = raw.trim();
        if (word.isEmpty || !seen.add(word.toLowerCase())) continue;
        list.add(word);
        changed = true;
      }
    }
    if (!changed) return;
    _prefs?.setString(
      _careerAnswersKey,
      jsonEncode({
        for (final worldEntry in _careerAnswers.entries)
          '${worldEntry.key}': {
            for (final cat in worldEntry.value.entries)
              if (cat.value.isNotEmpty) cat.key: cat.value,
          },
      }),
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

  /// Volume musique (0–1), indépendant du mute.
  double get musicVolume => _musicVolume;

  /// Clavier de jeu intégré à la place de celui du téléphone.
  bool get gameKeyboard => _gameKeyboard;

  /// Voix du présentateur en fin de manche.
  bool get voice => _voice;
  String? get nickname => _nickname;

  /// Langue choisie pour l'appli ('fr', 'en'), ou null pour suivre le
  /// téléphone.
  String? get languageCode => _languageCode;

  /// Genre déclaré : `male`, `female`, `other`, ou null.
  String? get gender => _gender;

  /// Pays d'origine (nom anglais, ex. « Ivory Coast ») : drapeau à côté du
  /// pseudo dans les salons ; null tant qu'il n'est pas choisi.
  String? get country => _country;

  set country(String? value) {
    _country = value;
    if (value == null) {
      _prefs?.remove(_countryKey);
    } else {
      _prefs?.setString(_countryKey, value);
    }
    notifyListeners();
  }

  /// Premier paramétrage déjà terminé.
  bool get onboardingDone => _onboardingDone;

  set languageCode(String? value) {
    _languageCode = value;
    if (value == null) {
      _prefs?.remove(_languageKey);
    } else {
      _prefs?.setString(_languageKey, value);
    }
    notifyListeners();
  }

  set gender(String? value) {
    _gender = value;
    if (value == null) {
      _prefs?.remove(_genderKey);
    } else {
      _prefs?.setString(_genderKey, value);
    }
    notifyListeners();
  }

  set musicVolume(double value) {
    final v = value.clamp(0.0, 1.0);
    if (_musicVolume == v) return;
    _musicVolume = v;
    _prefs?.setDouble(_musicVolumeKey, v);
    notifyListeners();
  }

  void completeOnboarding() {
    if (_onboardingDone) return;
    _onboardingDone = true;
    _prefs?.setBool(_onboardingDoneKey, true);
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
