import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ids d'énigmes QI déjà vues sur l'appareil : on les évite au prochain tirage
/// pour que rejouer ne ressorte pas tout de suite les mêmes suites / figures.
class IqRecentStore {
  IqRecentStore._();

  static const _key = 'iq.recent_ids';

  /// Garde assez d'historique pour plusieurs parties (ex. 5 × 15 énigmes).
  static const maxKeep = 80;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
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

  /// Ajoute les ids à la fin ; les plus anciens sortent si on dépasse [maxKeep].
  static Future<void> remember(Iterable<String> ids) async {
    final next = [...await load()];
    for (final id in ids) {
      if (id.isEmpty) continue;
      next.remove(id);
      next.add(id);
    }
    while (next.length > maxKeep) {
      next.removeAt(0);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }
}
