import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../game/data/models.dart';
import 'iq_models.dart';

/// Même montée de difficulté que le serveur : facile au début, difficile à la
/// fin ; « facile » et « difficile » décalent d'un cran.
int iqLevelFor(int number, int total, Difficulty difficulty) {
  final progress = (number - 1) / max(1, total - 1);
  final base = progress < 0.34 ? 1 : (progress < 0.67 ? 2 : 3);
  final shift = switch (difficulty) {
    Difficulty.easy => -1,
    Difficulty.normal => 0,
    Difficulty.hard => 1,
  };
  return (base + shift).clamp(1, 3);
}

/// Énigmes d'une partie solo : celles du serveur, ou sans connexion celles
/// embarquées dans l'appli (assets/data/iq_puzzles.json).
Future<List<IqPuzzle>> loadSoloPuzzles({
  required int count,
  required Difficulty difficulty,
  ApiClient? api,
  AssetBundle? bundle,
  Random? random,
  Iterable<String> avoid = const [],
}) async {
  final avoidList = [for (final id in avoid) if (id.isNotEmpty) id];
  if (api != null) {
    try {
      final avoidQuery = avoidList.isEmpty
          ? ''
          : '&avoid=${Uri.encodeQueryComponent(avoidList.join(','))}';
      final raw = await api.getJsonList(
        '/api/v1/iq/puzzles?count=$count&difficulty=${difficulty.name}$avoidQuery',
      );
      final puzzles = [
        for (final p in raw) IqPuzzle.fromJson(p as Map<String, dynamic>),
      ];
      if (puzzles.length == count) return puzzles;
    } on ApiException {
      // Hors ligne : on pioche dans le fichier embarqué.
    }
  }
  return offlinePuzzles(
    jsonDecode(
      await (bundle ?? rootBundle).loadString('assets/data/iq_puzzles.json'),
    ) as List,
    count: count,
    difficulty: difficulty,
    random: random,
    avoid: avoidList,
  );
}

/// Tire [count] énigmes différentes dans le fichier embarqué, selon la montée
/// de difficulté. [avoid] = ids déjà vus (rejouer).
List<IqPuzzle> offlinePuzzles(
  List<dynamic> raw, {
  required int count,
  required Difficulty difficulty,
  Random? random,
  Iterable<String> avoid = const [],
}) {
  final rng = random ?? Random();
  final all = [
    for (final p in raw) IqPuzzle.fromJson(p as Map<String, dynamic>),
  ];
  final byLevel = <int, List<IqPuzzle>>{};
  for (final p in all) {
    byLevel.putIfAbsent(p.level, () => []).add(p);
  }
  for (final list in byLevel.values) {
    list.shuffle(rng);
  }
  final recent = avoid.toSet();
  final used = <String>{};
  final recentKinds = <String>[];
  final picked = <IqPuzzle>[];
  for (var n = 1; n <= count; n++) {
    final level = iqLevelFor(n, count, difficulty);
    final softKinds = recentKinds.length >= 2
        ? recentKinds.sublist(recentKinds.length - 2).toSet()
        : <String>{};
    IqPuzzle? pickFrom(Iterable<IqPuzzle> pool, {required bool skipRecent}) {
      final list = [
        for (final p in pool)
          if (!used.contains(p.id) && (!skipRecent || !recent.contains(p.id)))
            p,
      ];
      // Préfère un type pas vu sur les 2 dernières manches.
      final varied = [
        for (final p in list)
          if (!softKinds.contains(p.kind)) p,
      ];
      final choice = varied.isNotEmpty ? varied : list;
      if (choice.isEmpty) return null;
      return choice[rng.nextInt(choice.length)];
    }

    final levelPool = byLevel[level] ?? const <IqPuzzle>[];
    var puzzle =
        pickFrom(levelPool, skipRecent: true) ??
        pickFrom(all, skipRecent: true) ??
        pickFrom(levelPool, skipRecent: false) ??
        pickFrom(all, skipRecent: false);
    if (puzzle == null) break;
    used.add(puzzle.id);
    recentKinds.add(puzzle.kind);
    picked.add(puzzle);
  }
  return picked;
}
