import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'quiz_models.dart';

/// Ids déjà vus en solo Chrono / Mot : on évite longtemps de les rejouer.
class QuizRecentStore {
  QuizRecentStore._();

  /// Conserve un long historique (banques ~100) pour ne recycler que tard.
  static const maxKeep = 200;

  static String _key(String game) => 'quiz.recent_ids.$game';

  /// Ordre : plus anciens → plus récents.
  static Future<List<String>> load(String game) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(game));
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final id in jsonDecode(raw) as List)
          if (id is String && id.isNotEmpty) id,
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> remember(String game, Iterable<String> ids) async {
    final next = [...await load(game)];
    for (final id in ids) {
      if (id.isEmpty) continue;
      next.remove(id);
      next.add(id);
    }
    while (next.length > maxKeep) {
      next.removeAt(0);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(game), jsonEncode(next));
  }

  /// Jamais vues d'abord (mélangées), puis les plus anciennes déjà vues.
  static List<QuizQuestion> pickDeck({
    required List<QuizQuestion> questions,
    required List<String> recentOldestFirst,
    required int rounds,
    Random? random,
  }) {
    if (questions.isEmpty) return const [];
    final rng = random ?? Random();
    final need = rounds.clamp(1, questions.length);
    final recentSet = recentOldestFirst.toSet();
    final byId = {for (final q in questions) q.id: q};

    final neverSeen = [
      for (final q in questions)
        if (!recentSet.contains(q.id)) q,
    ]..shuffle(rng);

    final recycled = [
      for (final id in recentOldestFirst)
        ?byId[id],
    ];

    final picked = <QuizQuestion>[];
    final used = <String>{};
    for (final q in [...neverSeen, ...recycled]) {
      if (!used.add(q.id)) continue;
      picked.add(q);
      if (picked.length >= need) break;
    }
    return picked;
  }
}
