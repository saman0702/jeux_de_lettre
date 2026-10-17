enum Category {
  city('city'),
  country('country'),
  animal('animal'),
  fruit('fruit'),
  femaleName('female_name'),
  maleName('male_name');

  const Category(this.wire);

  /// Identifiant échangé avec le serveur (et dans le dictionnaire hors ligne).
  final String wire;

  static Category fromWire(String value) =>
      values.firstWhere((c) => c.wire == value);

  /// Catégories cochées par défaut : le Petit Bac classique.
  static const classic = [city, country, animal, fruit];

  /// À partir de ce nombre de catégories, une manche dure plus de 30 s.
  static const many = 5;
  static const manyMinDuration = 45;
}

enum Difficulty { easy, normal, hard }

enum AnswerStatus {
  valid,
  empty,
  wrongLetter,
  notFound,
  late,
  hintWrong,
  alreadyUsed,
}

AnswerStatus _parseStatus(String value) => switch (value) {
  'valid' => AnswerStatus.valid,
  'empty' => AnswerStatus.empty,
  'wrong_letter' => AnswerStatus.wrongLetter,
  'not_found' => AnswerStatus.notFound,
  'hint_wrong' => AnswerStatus.hintWrong,
  'already_used' => AnswerStatus.alreadyUsed,
  _ => AnswerStatus.late,
};

class SoloGameSettings {
  const SoloGameSettings({
    required this.language,
    this.difficulty = Difficulty.normal,
    this.categories = Category.classic,
    this.rounds = 5,
    this.roundDuration = 30,
    this.nickname = 'Player',
    this.clientId,
    this.avoidLetters = '',
    this.bannedAnswers = const {},
  });

  static const roundOptions = [5, 10, 15];
  static const durationOptions = [15, 30, 45, 60];

  final String language;
  final Difficulty difficulty;
  final List<Category> categories;
  final int rounds;
  final int roundDuration;
  final String nickname;

  /// Profil à créditer en pièces (parties sur le serveur uniquement).
  final String? clientId;

  /// Lettres à ne pas retirer (revanche d'un niveau déjà joué).
  final String avoidLetters;

  /// Mots déjà validés dans le même monde de carrière (catégorie → valeurs).
  final Map<Category, List<String>> bannedAnswers;

  Map<String, dynamic> toJson() => {
    'language': language,
    'difficulty': difficulty.name,
    'categories': [for (final c in categories) c.wire],
    'rounds': rounds,
    'round_duration': roundDuration,
    'nickname': nickname,
    if (clientId != null) 'client_id': clientId,
    if (avoidLetters.isNotEmpty) 'avoid_letters': avoidLetters,
    if (bannedAnswers.isNotEmpty)
      'banned_answers': {
        for (final e in bannedAnswers.entries)
          if (e.value.isNotEmpty) e.key.wire: e.value,
      },
  };
}

class SoloGame {
  const SoloGame({
    required this.id,
    required this.categories,
    required this.totalRounds,
    required this.roundDuration,
    required this.status,
    required this.totalScore,
    required this.roundsPlayed,
    this.hintsLeft = 0,
  });

  factory SoloGame.fromJson(Map<String, dynamic> json) => SoloGame(
    id: json['id'] as String,
    categories: [
      for (final c in json['categories'] as List)
        Category.fromWire(c as String),
    ],
    totalRounds: json['total_rounds'] as int,
    roundDuration: json['round_duration'] as int,
    status: json['status'] as String,
    totalScore: json['total_score'] as int,
    roundsPlayed: json['rounds_played'] as int,
    hintsLeft: json['hints_left'] as int? ?? 0,
  );

  final String id;
  final List<Category> categories;
  final int totalRounds;
  final int roundDuration;
  final String status;
  final int totalScore;
  final int roundsPlayed;
  final int hintsLeft;

  bool get isFinished => status == 'finished';
}

class GameRound {
  GameRound({
    required this.number,
    required this.letter,
    required this.duration,
    required this.endsAt,
    required this.clockOffset,
  });

  /// L'horloge du serveur fait référence : `clockOffset` indique le retard de
  /// l'horloge de l'appareil, pour qu'une mauvaise heure sur le téléphone ne
  /// puisse pas ajouter de secondes.
  factory GameRound.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    final serverTime = DateTime.parse(json['server_time'] as String);
    return GameRound(
      number: json['number'] as int,
      letter: json['letter'] as String,
      duration: json['duration'] as int,
      endsAt: DateTime.parse(json['ends_at'] as String),
      clockOffset: serverTime.difference(receivedAt ?? DateTime.now()),
    );
  }

  final int number;
  final String letter;
  final int duration;
  final DateTime endsAt;
  final Duration clockOffset;

  Duration remaining([DateTime? now]) {
    final left = endsAt.difference((now ?? DateTime.now()).add(clockOffset));
    return left.isNegative ? Duration.zero : left;
  }
}

/// Prix en pièces (alignés sur le serveur).
const categoryInfoPriceFound = 1;
const categoryInfoPriceMissed = 2;
const extraHintPrice = 5;

class AnswerResult {
  const AnswerResult({
    required this.category,
    required this.value,
    required this.status,
    required this.points,
    this.matchedValue,
    this.hinted = false,
    this.suggestion,
    this.infoAvailable = false,
    this.infoPrice = 0,
    this.infoUnlocked = false,
    this.infoLines,
  });

  factory AnswerResult.fromJson(Map<String, dynamic> json) {
    final status = _parseStatus(json['status'] as String);
    final available = json['info_available'] as bool? ?? false;
    final unlocked = json['info_unlocked'] as bool? ?? false;
    final lines = json['info_lines'] as List?;
    final price =
        json['info_price'] as int? ??
        (available && !unlocked
            ? (status == AnswerStatus.valid
                  ? categoryInfoPriceFound
                  : categoryInfoPriceMissed)
            : 0);
    return AnswerResult(
      category: Category.fromWire(json['category'] as String),
      value: json['value'] as String,
      status: status,
      points: json['points'] as int,
      matchedValue: json['matched_value'] as String?,
      hinted: json['hinted'] as bool? ?? false,
      suggestion: json['suggestion'] as String?,
      infoAvailable: available,
      infoPrice: price,
      infoUnlocked: unlocked,
      infoLines: lines == null
          ? null
          : [for (final line in lines) line as String],
    );
  }

  final Category category;
  final String value;
  final AnswerStatus status;
  final int points;
  final String? matchedValue;

  /// Réponse obtenue grâce à un joker (moitié des points).
  final bool hinted;

  /// Réponse valide proposée quand celle du joueur ne l'était pas.
  final String? suggestion;

  /// Une fiche info est achetable pour ce mot.
  final bool infoAvailable;

  /// Prix affiché : 1 si trouvé, 2 sinon ; 0 si déjà débloqué.
  final int infoPrice;

  /// Infos déjà débloquées pour ce joueur (permanentes).
  final bool infoUnlocked;

  /// Lignes déjà connues (si débloqué).
  final List<String>? infoLines;
}

/// Infos pédagogiques débloquées avec des pièces.
class CategoryInfo {
  const CategoryInfo({
    required this.category,
    required this.word,
    required this.lines,
    required this.price,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) => CategoryInfo(
    category: Category.fromWire(json['category'] as String),
    word: json['word'] as String,
    lines: [for (final line in json['lines'] as List) line as String],
    price: json['price'] as int? ?? categoryInfoPriceMissed,
  );

  final Category category;
  final String word;
  final List<String> lines;
  final int price;
}

/// Résultat d'un achat de joker.
class BuyHintResult {
  const BuyHintResult({required this.hintsLeft, required this.price});

  factory BuyHintResult.fromJson(Map<String, dynamic> json) => BuyHintResult(
    hintsLeft: json['hints_left'] as int,
    price: json['price'] as int? ?? extraHintPrice,
  );

  final int hintsLeft;
  final int price;
}

/// Les trois propositions d'un joker ; la bonne reste sur le serveur.
class HintOptions {
  const HintOptions({
    required this.category,
    required this.options,
    required this.hintsLeft,
  });

  factory HintOptions.fromJson(Map<String, dynamic> json) => HintOptions(
    category: Category.fromWire(json['category'] as String),
    options: [for (final o in json['options'] as List) o as String],
    hintsLeft: json['hints_left'] as int,
  );

  final Category category;
  final List<String> options;
  final int hintsLeft;
}

class HintPick {
  const HintPick({
    required this.category,
    required this.correct,
    required this.answer,
  });

  factory HintPick.fromJson(Map<String, dynamic> json) => HintPick(
    category: Category.fromWire(json['category'] as String),
    correct: json['correct'] as bool,
    answer: json['answer'] as String,
  );

  final Category category;
  final bool correct;
  final String answer;
}

class RoundResult {
  const RoundResult({
    required this.number,
    required this.letter,
    required this.answers,
    required this.roundScore,
    required this.elapsed,
  });

  factory RoundResult.fromJson(Map<String, dynamic> json) => RoundResult(
    number: json['number'] as int,
    letter: json['letter'] as String,
    answers: [
      for (final a in json['answers'] as List)
        AnswerResult.fromJson(a as Map<String, dynamic>),
    ],
    roundScore: json['round_score'] as int,
    elapsed: Duration(milliseconds: json['elapsed_ms'] as int),
  );

  final int number;
  final String letter;
  final List<AnswerResult> answers;
  final int roundScore;
  final Duration elapsed;
}
