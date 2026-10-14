enum Category { city, country, animal, fruit }

enum Difficulty { easy, normal, hard }

enum AnswerStatus { valid, empty, wrongLetter, notFound, late }

AnswerStatus _parseStatus(String value) => switch (value) {
  'valid' => AnswerStatus.valid,
  'empty' => AnswerStatus.empty,
  'wrong_letter' => AnswerStatus.wrongLetter,
  'not_found' => AnswerStatus.notFound,
  _ => AnswerStatus.late,
};

class SoloGameSettings {
  const SoloGameSettings({
    required this.language,
    this.difficulty = Difficulty.normal,
    this.categories = Category.values,
    this.rounds = 5,
    this.roundDuration = 30,
    this.nickname = 'Player',
  });

  static const roundOptions = [5, 10, 15];
  static const durationOptions = [15, 30, 45, 60];

  final String language;
  final Difficulty difficulty;
  final List<Category> categories;
  final int rounds;
  final int roundDuration;
  final String nickname;

  Map<String, dynamic> toJson() => {
    'language': language,
    'difficulty': difficulty.name,
    'categories': [for (final c in categories) c.name],
    'rounds': rounds,
    'round_duration': roundDuration,
    'nickname': nickname,
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
  });

  factory SoloGame.fromJson(Map<String, dynamic> json) => SoloGame(
    id: json['id'] as String,
    categories: [
      for (final c in json['categories'] as List)
        Category.values.byName(c as String),
    ],
    totalRounds: json['total_rounds'] as int,
    roundDuration: json['round_duration'] as int,
    status: json['status'] as String,
    totalScore: json['total_score'] as int,
    roundsPlayed: json['rounds_played'] as int,
  );

  final String id;
  final List<Category> categories;
  final int totalRounds;
  final int roundDuration;
  final String status;
  final int totalScore;
  final int roundsPlayed;

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

  /// The server clock is the reference: `clockOffset` is how far the device
  /// clock is behind it, so a wrong phone time cannot add seconds.
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

class AnswerResult {
  const AnswerResult({
    required this.category,
    required this.value,
    required this.status,
    required this.points,
    this.matchedValue,
  });

  factory AnswerResult.fromJson(Map<String, dynamic> json) => AnswerResult(
    category: Category.values.byName(json['category'] as String),
    value: json['value'] as String,
    status: _parseStatus(json['status'] as String),
    points: json['points'] as int,
    matchedValue: json['matched_value'] as String?,
  );

  final Category category;
  final String value;
  final AnswerStatus status;
  final int points;
  final String? matchedValue;
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
