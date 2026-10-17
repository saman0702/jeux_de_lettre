import '../../game/data/models.dart';

enum RoomPhase { waiting, countdown, round, results, finished }

/// Salon normal, ou salon de paris où chacun mise des pièces.
/// Toutes les manches (meilleur total) ou éliminatoires (le plus petit score
/// de chaque manche sort).
enum RoomFormat { rounds, elimination }

enum RoomKind {
  classic,
  bet;

  static const stakeOptions = [5, 10, 25, 50, 100];
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

class RoomSettings {
  const RoomSettings({
    required this.language,
    this.difficulty = Difficulty.normal,
    this.categories = Category.classic,
    this.rounds = 5,
    this.roundDuration = 30,
    this.maxPlayers = 8,
    this.public = false,
    this.kind = RoomKind.classic,
    this.stake = 0,
    this.format = RoomFormat.rounds,
  });

  factory RoomSettings.fromJson(
    Map<String, dynamic> json, {
    bool public = false,
  }) => RoomSettings(
    language: json['language'] as String,
    difficulty: Difficulty.values.byName(json['difficulty'] as String),
    categories: [
      for (final c in json['categories'] as List)
        Category.fromWire(c as String),
    ],
    rounds: json['rounds'] as int,
    roundDuration: json['round_duration'] as int,
    maxPlayers: json['max_players'] as int,
    public: public,
    kind: RoomKind.values.byName(json['kind'] as String? ?? 'classic'),
    stake: json['stake'] as int? ?? 0,
    format: RoomFormat.values.byName(json['format'] as String? ?? 'rounds'),
  );

  final String language;
  final Difficulty difficulty;
  final List<Category> categories;
  final int rounds;
  final int roundDuration;
  final int maxPlayers;
  final bool public;
  final RoomKind kind;

  /// Pièces misées par chaque joueur dans un salon de paris.
  final int stake;

  bool get betting => kind == RoomKind.bet;

  final RoomFormat format;
  bool get elimination => format == RoomFormat.elimination;

  Map<String, dynamic> toJson() => {
    'language': language,
    'difficulty': difficulty.name,
    'categories': [for (final c in categories) c.wire],
    'rounds': rounds,
    'round_duration': roundDuration,
    'max_players': maxPlayers,
    'public': public,
    'kind': kind.name,
    'stake': stake,
    'format': format.name,
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
    this.botLevel,
    this.hintsLeft = 0,
    this.avatarPreset = 0,
    this.avatarUrl,
    this.level = 1,
    this.eliminatedRound,
    this.hair = '',
    this.hat = '',
    this.frame = '',
    this.nameStyle = '',
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
    clientId: json['client_id'] as String,
    nickname: json['nickname'] as String,
    ready: json['ready'] as bool,
    connected: json['connected'] as bool,
    score: json['score'] as int,
    finished: json['finished'] as bool,
    playing: json['playing'] as bool,
    botLevel: json['bot_level'] == null
        ? null
        : Difficulty.values.byName(json['bot_level'] as String),
    hintsLeft: json['hints_left'] as int? ?? 0,
    avatarPreset: json['avatar_preset'] as int? ?? 0,
    avatarUrl: json['avatar_url'] as String?,
    level: json['level'] as int? ?? 1,
    eliminatedRound: json['eliminated_round'] as int?,
    hair: json['hair'] as String? ?? '',
    hat: json['hat'] as String? ?? '',
    frame: json['frame'] as String? ?? '',
    nameStyle: json['name_style'] as String? ?? '',
  );

  final String clientId;
  final String nickname;
  final bool ready;
  final bool connected;
  final int score;

  /// A envoyé ses réponses pour la manche en cours.
  final bool finished;

  /// Participe à la manche en cours (faux pour un joueur arrivé en retard).
  final bool playing;

  /// Renseigné pour les adversaires contrôlés par l'ordinateur.
  final Difficulty? botLevel;

  bool get bot => botLevel != null;

  /// Jokers restants dans cette partie.
  final int hintsLeft;

  final int avatarPreset;

  /// Photo transformée en avatar (chemin sur le serveur), sinon avatar dessiné.
  final String? avatarUrl;

  /// Niveau du joueur (les bots restent au niveau 1).
  final int level;

  /// Éliminatoires : manche où le joueur est sorti.
  final int? eliminatedRound;
  bool get eliminated => eliminatedRound != null;

  /// Coiffure boutique, ou vide.
  final String hair;

  /// Chapeau / couronne boutique, ou vide.
  final String hat;

  /// Cadre d'avatar acheté, ou vide.
  final String frame;

  /// Couleur de pseudo achetée, ou vide.
  final String nameStyle;
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
    this.examples = const {},
    this.eliminated = const [],
  });

  factory RoomRoundResults.fromJson(Map<String, dynamic> json) =>
      RoomRoundResults(
        number: json['number'] as int,
        letter: json['letter'] as String,
        players: [
          for (final p in json['players'] as List)
            PlayerRoundResult.fromJson(p as Map<String, dynamic>),
        ],
        examples: {
          for (final e in ((json['examples'] as Map?) ?? const {}).entries)
            Category.fromWire(e.key as String): e.value as String,
        },
        eliminated: [
          for (final id in (json['eliminated'] as List?) ?? const [])
            id as String,
        ],
      );

  final int number;
  final String letter;
  final List<PlayerRoundResult> players;

  /// Une réponse valide par catégorie ratée par au moins un joueur.
  final Map<Category, String> examples;

  /// Éliminatoires : joueurs sortis à cette manche.
  final List<String> eliminated;

  /// Ce que les autres joueurs ont trouvé dans [category] : (pseudo, réponse).
  List<(String, String)> foundByOthers(Category category, String me) => [
    for (final p in players)
      if (p.clientId != me)
        for (final a in p.answers)
          if (a.category == category && a.status == AnswerStatus.valid)
            (p.nickname, a.matchedValue ?? a.value),
  ];
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
    this.pot = 0,
    this.winnings = const {},
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
      pot: json['pot'] as int? ?? 0,
      winnings: {
        for (final e in ((json['winnings'] as Map?) ?? const {}).entries)
          e.key as String: e.value as int,
      },
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

  /// Salon de paris : pièces en jeu, puis ce que chaque gagnant a remporté.
  final int pot;
  final Map<String, int> winnings;

  /// Horloge du serveur moins horloge de l'appareil, pour décompter jusqu'aux
  /// échéances du serveur.
  final Duration clockOffset;

  RoomPlayer? player(String clientId) {
    for (final p in players) {
      if (p.clientId == clientId) return p;
    }
    return null;
  }

  /// Temps restant avant une échéance du serveur, mesuré sur l'horloge du
  /// serveur.
  Duration until(DateTime? deadline, [DateTime? now]) {
    if (deadline == null) return Duration.zero;
    final left = deadline.difference((now ?? DateTime.now()).add(clockOffset));
    return left.isNegative ? Duration.zero : left;
  }

  /// Joueurs classés par score total. En éliminatoires, ceux encore en lice
  /// d'abord, puis les éliminés du plus tardif au plus précoce.
  List<RoomPlayer> get ranking => [...players]
    ..sort((a, b) {
      if (settings.elimination) {
        final ra = a.eliminatedRound ?? 1 << 20;
        final rb = b.eliminatedRound ?? 1 << 20;
        if (ra != rb) return rb.compareTo(ra);
      }
      return b.score.compareTo(a.score);
    });
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
    this.nicknames = const [],
    this.kind = RoomKind.classic,
    this.stake = 0,
    this.format = RoomFormat.rounds,
  });

  factory RoomSummary.fromJson(Map<String, dynamic> json) => RoomSummary(
    code: json['code'] as String,
    quick: json['quick'] as bool,
    host: json['host'] as String,
    nicknames: [
      for (final name in (json['nicknames'] as List?) ?? const [])
        name as String,
    ],
    players: json['players'] as int,
    maxPlayers: json['max_players'] as int,
    language: json['language'] as String,
    rounds: json['rounds'] as int,
    roundDuration: json['round_duration'] as int,
    kind: RoomKind.values.byName(json['kind'] as String? ?? 'classic'),
    stake: json['stake'] as int? ?? 0,
    format: RoomFormat.values.byName(json['format'] as String? ?? 'rounds'),
  );

  final String code;
  final bool quick;
  final String host;

  /// Pseudos des joueurs déjà dans la salle, hôte en premier.
  final List<String> nicknames;
  final RoomFormat format;
  final RoomKind kind;
  final int stake;
  final int players;
  final int maxPlayers;
  final String language;
  final int rounds;
  final int roundDuration;
}
