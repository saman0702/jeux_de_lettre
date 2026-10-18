import 'dart:math' as math;

import 'models.dart';

/// Règles en plus d'une partie solo : objectif de la carrière ou minimum à
/// atteindre à chaque manche des éliminatoires.
sealed class SoloChallenge {
  const SoloChallenge();

  /// Points à marquer dans la manche [round] pour continuer, ou null s'il n'y
  /// a pas d'élimination.
  int? requiredPoints(int round) => null;
}

/// Un niveau du mode carrière.
class CareerLevel extends SoloChallenge {
  const CareerLevel({
    required this.number,
    required this.world,
    required this.difficulty,
    required this.categories,
    required this.roundDuration,
    required this.target,
    this.rounds = 5,
  });

  final int number;

  /// 0 : débutant, 1 : confirmé, 2 : expert, 3 : maître.
  final int world;
  final Difficulty difficulty;
  final List<Category> categories;
  final int roundDuration;
  final int rounds;

  /// Total de points à atteindre pour réussir le niveau (1 étoile).
  final int target;

  int get maxScore => rounds * categories.length * 10;

  /// Paliers des 2 et 3 étoiles, entre l'objectif et le score parfait, avec au
  /// moins 10 points d'écart entre deux paliers.
  int get twoStars =>
      math.max(target + 10, _roundTen(target + (maxScore - target) * 0.35));
  int get threeStars =>
      math.max(twoStars + 10, _roundTen(target + (maxScore - target) * 0.65));

  /// Étoiles gagnées avec [score] : 0 si l'objectif n'est pas atteint.
  int starsFor(int score) => score >= threeStars
      ? 3
      : score >= twoStars
      ? 2
      : score >= target
      ? 1
      : 0;

  SoloGameSettings settings(
    String language,
    String nickname,
    String? id, {
    String avoidLetters = '',
    Map<Category, List<String>> bannedAnswers = const {},
  }) => SoloGameSettings(
    language: language,
    difficulty: difficulty,
    categories: categories,
    rounds: rounds,
    roundDuration: roundDuration,
    nickname: nickname,
    clientId: id,
    avoidLetters: avoidLetters,
    bannedAnswers: bannedAnswers,
  );
}

/// Éliminatoires en solo : minimum de points par manche, de plus en plus haut.
class EliminationChallenge extends SoloChallenge {
  const EliminationChallenge({
    this.rounds = defaultRounds,
    this.roundDuration = defaultDuration,
    this.strictSpelling = false,
  });

  static const defaultRounds = 15;
  static const defaultDuration = 30;

  final int rounds;
  final int roundDuration;
  final bool strictSpelling;

  @override
  int requiredPoints(int round) {
    // Paliers proportionnels au nombre de manches choisies.
    final t = rounds <= 1 ? 1.0 : round / rounds;
    if (t <= 0.25) return 10;
    if (t <= 0.5) return 20;
    if (t <= 0.75) return 30;
    return 40;
  }

  SoloGameSettings settings(
    String language,
    String nickname,
    String? id, {
    Difficulty difficulty = Difficulty.normal,
  }) => SoloGameSettings(
    language: language,
    difficulty: difficulty,
    categories: Category.classic,
    rounds: rounds,
    roundDuration: roundDuration,
    strictSpelling: strictSpelling,
    nickname: nickname,
    clientId: id,
  );
}

int _roundTen(double value) => (value / 10).round() * 10;
