import '../game/data/challenge.dart';
import '../game/data/models.dart';

/// Nombre de niveaux par monde.
const levelsPerWorld = 10;

/// Les 30 niveaux de la carrière, en 3 mondes de difficulté croissante :
/// - Débutant (1–10) : lettres faciles, d'abord 2 puis 3 et 4 catégories,
///   60 puis 45 secondes ;
/// - Confirmé (11–20) : lettres normales, 4 catégories, 45 puis 30 secondes ;
/// - Expert (21–30) : toutes les lettres (K, Q, W, X, Y, Z…), 30 puis 15 s.
/// L'objectif monte de ~30 % à ~60 % du score parfait.
final List<CareerLevel> careerLevels = [
  for (var i = 0; i < 3 * levelsPerWorld; i++) _level(i),
];

CareerLevel _level(int index) {
  final world = index ~/ levelsPerWorld;
  final step = index % levelsPerWorld; // 0 à 9 dans le monde
  final categories = world == 0
      ? Category.classic.take(step < 3 ? 2 : (step < 6 ? 3 : 4)).toList()
      : Category.classic;
  final duration = switch (world) {
    0 => step < 5 ? 60 : 45,
    1 => step < 5 ? 45 : 30,
    _ => step < 7 ? 30 : 15,
  };
  final share = [0.30, 0.40, 0.45][world] + step * 0.015;
  final max = 5 * categories.length * 10;
  return CareerLevel(
    number: index + 1,
    world: world,
    difficulty: Difficulty.values[world],
    categories: categories,
    roundDuration: duration,
    target: ((max * share) / 10).round() * 10,
  );
}
