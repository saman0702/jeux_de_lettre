import '../../game/data/models.dart';

enum RoomPhase { waiting, countdown, round, results, finished }

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

class RoomSettings {
  const RoomSettings({
    required this.language,
    this.difficulty = Difficulty.normal,
    this.categories = Category.values,
    this.rounds = 5,
    this.roundDuration = 30,
    this.maxPlayers = 8,
    this.public = false,
  });

  factory RoomSettings.fromJson(
    Map<String, dynamic> json, {
    bool public = false,
  }) => RoomSettings(
    language: json['language'] as String,
    difficulty: Difficulty.values.byName(json['difficulty'] as String),
    categories: [
      for (final c in json['categories'] as List)
        Category.values.byName(c as String),
    ],
    rounds: json['rounds'] as int,
    roundDuration: json['round_duration'] as int,
    maxPlayers: json['max_players'] as int,
    public: public,
  );

  final String language;
  final Difficulty difficulty;
  final List<Category> categories;
  final int rounds;
  final int roundDuration;
  final int maxPlayers;
  final bool public;

  Map<String, dynamic> toJson() => {
    'language': language,
    'difficulty': difficulty.name,
    'categories': [for (final c in categories) c.name],
    'rounds': rounds,
    'round_duration': roundDuration,
    'max_players': maxPlayers,
    'public': public,
  };
}

class RoomPlayer {
  const RoomPlayer({
    required this.clientId,
    required this.nickname,
    required this.ready,
    required this.connected,
    required this.score,
    required this.finished,
    required this.playing,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
    clientId: json['client_id'] as String,
    nickname: json['nickname'] as String,
    ready: json['ready'] as bool,
    connected: json['connected'] as bool,
    score: json['score'] as int,
    finished: json['finished'] as bool,
    playing: json['playing'] as bool,
  );

  final String clientId;
  final String nickname;
  final bool ready;
  final bool connected;
  final int score;

  /// Has sent their answers for the current round.
  final bool finished;

  /// Takes part in the current round (false for a late joiner).
  final bool playing;
}

class PlayerRoundResult {
  const PlayerRoundResult({
    required this.clientId,
    required this.nickname,
    required this.answers,
    required this.roundScore,
    this.elapsed,
  });

  factory PlayerRoundResult.fromJson(Map<String, dynamic> json) =>
      PlayerRoundResult(
        clientId: json['client_id'] as String,
        nickname: json['nickname'] as String,
        answers: [
          for (final a in json['answers'] as List)
            AnswerResult.fromJson(a as Map<String, dynamic>),
        ],
        roundScore: json['round_score'] as int,
        elapsed: json['elapsed_ms'] == null
            ? null
            : Duration(milliseconds: json['elapsed_ms'] as int),
      );

  final String clientId;
  final String nickname;
  final List<AnswerResult> answers;
  final int roundScore;
  final Duration? elapsed;
}

class RoomRoundResults {
  const RoomRoundResults({
    required this.number,
    required this.letter,
    required this.players,
  });

  factory RoomRoundResults.fromJson(Map<String, dynamic> json) =>
      RoomRoundResults(
        number: json['number'] as int,
        letter: json['letter'] as String,
        players: [
          for (final p in json['players'] as List)
            PlayerRoundResult.fromJson(p as Map<String, dynamic>),
        ],
      );

  final int number;
  final String letter;
  final List<PlayerRoundResult> players;
}

class RoomState {
  const RoomState({
    required this.code,
    required this.quick,
    required this.hostId,
    required this.phase,
    required this.settings,
    required this.players,
    required this.roundNumber,
    required this.clockOffset,
    this.round,
    this.results,
    this.startsAt,
    this.goAt,
    this.nextRoundAt,
  });

  factory RoomState.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    final serverTime = DateTime.parse(json['server_time'] as String);
    final roundJson = json['round'] as Map<String, dynamic>?;
    return RoomState(
      code: json['code'] as String,
      quick: json['quick'] as bool,
      hostId: json['host_id'] as String,
      phase: RoomPhase.values.byName(json['phase'] as String),
      settings: RoomSettings.fromJson(
        json['settings'] as Map<String, dynamic>,
        public: json['public'] as bool,
      ),
      players: [
        for (final p in json['players'] as List)
          RoomPlayer.fromJson(p as Map<String, dynamic>),
      ],
      roundNumber: json['round_number'] as int,
      round: roundJson == null
          ? null
          : GameRound.fromJson({
              ...roundJson,
              'server_time': json['server_time'],
            }, receivedAt: receivedAt),
      results: json['results'] == null
          ? null
          : RoomRoundResults.fromJson(json['results'] as Map<String, dynamic>),
      startsAt: _date(json['starts_at']),
      goAt: _date(json['go_at']),
      nextRoundAt: _date(json['next_round_at']),
      clockOffset: serverTime.difference(receivedAt ?? DateTime.now()),
    );
  }

  final String code;
  final bool quick;
  final String hostId;
  final RoomPhase phase;
  final RoomSettings settings;
  final List<RoomPlayer> players;
  final int roundNumber;
  final GameRound? round;
  final RoomRoundResults? results;
  final DateTime? startsAt;
  final DateTime? goAt;
  final DateTime? nextRoundAt;

  /// Server clock minus device clock, to count down to server deadlines.
  final Duration clockOffset;

  RoomPlayer? player(String clientId) {
    for (final p in players) {
      if (p.clientId == clientId) return p;
    }
    return null;
  }

  /// Time left until a server deadline, measured on the server clock.
  Duration until(DateTime? deadline, [DateTime? now]) {
    if (deadline == null) return Duration.zero;
    final left = deadline.difference((now ?? DateTime.now()).add(clockOffset));
    return left.isNegative ? Duration.zero : left;
  }

  /// Players ranked by total score.
  List<RoomPlayer> get ranking =>
      [...players]..sort((a, b) => b.score.compareTo(a.score));
}

class RoomSummary {
  const RoomSummary({
    required this.code,
    required this.quick,
    required this.host,
    required this.players,
    required this.maxPlayers,
    required this.language,
    required this.rounds,
    required this.roundDuration,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> json) => RoomSummary(
    code: json['code'] as String,
    quick: json['quick'] as bool,
    host: json['host'] as String,
    players: json['players'] as int,
    maxPlayers: json['max_players'] as int,
    language: json['language'] as String,
    rounds: json['rounds'] as int,
    roundDuration: json['round_duration'] as int,
  );

  final String code;
  final bool quick;
  final String host;
  final int players;
  final int maxPlayers;
  final String language;
  final int rounds;
  final int roundDuration;
}
