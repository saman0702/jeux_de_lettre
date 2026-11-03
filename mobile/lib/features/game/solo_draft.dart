import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'data/models.dart';

/// Brouillon d'une partie solo Geo : pause après une manche, reprise plus tard.
class SoloDraft {
  const SoloDraft({
    required this.offline,
    required this.game,
    required this.settings,
    required this.results,
    this.letters = const [],
    this.usedKeys = const {},
    this.hintsUsed = 0,
  });

  final bool offline;
  final SoloGame game;
  final SoloGameSettings settings;
  final List<RoundResult> results;

  /// Hors ligne uniquement : lettres déjà tirées et mots déjà validés.
  final List<String> letters;
  final Map<Category, Set<String>> usedKeys;
  final int hintsUsed;

  int get answeredCount => results.length;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'offline': offline,
    'game': {
      'id': game.id,
      'language': game.language,
      'categories': [for (final c in game.categories) c.wire],
      'total_rounds': game.totalRounds,
      'round_duration': game.roundDuration,
      'strict_spelling': game.strictSpelling,
      'status': game.status,
      'total_score': game.totalScore,
      'rounds_played': game.roundsPlayed,
      'hints_left': game.hintsLeft,
    },
    'settings': settings.toJson(),
    'results': [for (final r in results) r.toJson()],
    'letters': letters,
    'used_keys': {
      for (final e in usedKeys.entries) e.key.wire: e.value.toList(),
    },
    'hints_used': hintsUsed,
  };

  factory SoloDraft.fromJson(Map<String, dynamic> json) {
    final used = json['used_keys'] as Map<String, dynamic>? ?? const {};
    return SoloDraft(
      offline: json['offline'] as bool? ?? false,
      game: SoloGame.fromJson(
        Map<String, dynamic>.from(json['game'] as Map? ?? const {}),
      ),
      settings: SoloGameSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      ),
      results: [
        for (final r in (json['results'] as List?) ?? const [])
          RoundResult.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
      letters: [
        for (final l in (json['letters'] as List?) ?? const []) l as String,
      ],
      usedKeys: {
        for (final e in used.entries)
          Category.fromWire(e.key): {
            for (final k in e.value as List) k as String,
          },
      },
      hintsUsed: json['hints_used'] as int? ?? 0,
    );
  }
}

/// Une seule partie solo Geo en pause à la fois.
class SoloDraftStore {
  SoloDraftStore._();

  static const _key = 'geo.solo_draft';

  static Future<SoloDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SoloDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_key);
      return null;
    }
  }

  static Future<void> save(SoloDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
