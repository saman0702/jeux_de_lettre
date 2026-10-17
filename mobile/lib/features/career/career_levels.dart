import '../game/data/challenge.dart';
import '../game/data/models.dart';

/// Nombre de niveaux par monde.
const levelsPerWorld = 15;

/// Nombre de mondes de la carrière.
const careerWorldCount = 4;

/// Ordre d'apparition : Ville, Pays, Animal, Fruit, puis les prénoms.
const careerCategoryOrder = [
  Category.city,
  Category.country,
  Category.animal,
  Category.fruit,
  Category.femaleName,
  Category.maleName,
];

/// Les 60 niveaux de la carrière, en 4 mondes de difficulté croissante :
/// - Débutant (1–15) : lettres faciles, 2 puis 3 puis 4 catégories ;
/// - Confirmé (16–30) : lettres normales, jusqu'au prénom féminin ;
/// - Expert (31–45) : toutes les lettres, les 6 catégories ;
/// - Maître (46–60) : même exigence, objectifs plus hauts ; les mots déjà
///   validés dans le monde restent interdits (pression qui monte).
final List<CareerLevel> careerLevels = [
  for (var i = 0; i < careerWorldCount * levelsPerWorld; i++) _level(i),
];

/// Nombre de catégories débloquées selon le monde et l'étape (0 à 14).
int _categoryCount(int world, int step) => switch (world) {
  0 => step < 4 ? 2 : (step < 9 ? 3 : 4),
  1 => step < 5 ? 4 : 5,
  _ => 6,
};

CareerLevel _level(int index) {
  final world = index ~/ levelsPerWorld;
  final step = index % levelsPerWorld;
  final count = _categoryCount(world, step);
  final categories = careerCategoryOrder.take(count).toList();
  var duration = switch (world) {
    0 => step < 5 ? 60 : (step < 10 ? 45 : 30),
    1 => step < 8 ? 45 : 30,
    2 => step < 10 ? 45 : 30,
    _ => 45,
  };
  if (count >= Category.many && duration < Category.manyMinDuration) {
    duration = Category.manyMinDuration;
  }
  final share = switch (world) {
        0 => 0.28,
        1 => 0.36,
        2 => 0.44,
        _ => 0.52,
      } +
      step * 0.012;
  final max = 5 * categories.length * 10;
  return CareerLevel(
    number: index + 1,
    world: world,
    difficulty: Difficulty.values[world.clamp(0, Difficulty.values.length - 1)],
    categories: categories,
    roundDuration: duration,
    target: ((max * share) / 10).round() * 10,
  );
}
