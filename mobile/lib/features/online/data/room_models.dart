import '../../game/data/models.dart';

enum RoomPhase { waiting, countdown, round, results, lightning, finished }

/// Toutes les manches (meilleur total), éliminatoires, ou relais (catégories
/// réparties).
enum RoomFormat { rounds, elimination, relay }

/// Thème du jour : score ×2 sur ces catégories.
enum RoomTheme {
  none(''),
  geography('geography'),
  names('names'),
  nature('nature');

  const RoomTheme(this.wire);
  final String wire;

  static RoomTheme fromWire(String? value) => values.firstWhere(
        (t) => t.wire == (value ?? ''),
        orElse: () => none,
      );
}

/// Stickers de réaction (pas un vrai chat).
enum RoomSticker {
  fire,
  sleep,
  clap,
  wow;

  String get emoji => switch (this) {
        fire => '🔥',
        sleep => '😴',
        clap => '👏',
        wow => '😱',
      };
}

/// Classique (gratuit), paris (chacun mise), ou dotation (l'hôte place le gain).
enum RoomKind {
  classic,
  bet,
  prize;

  static const stakeOptions = [5, 10, 25, 50, 100];
  static const maxStake = 1000;
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
    this.strictSpelling = false,
    this.maxPlayers = 8,
    this.public = false,
    this.kind = RoomKind.classic,
    this.stake = 0,
    this.format = RoomFormat.rounds,
    this.theme = RoomTheme.none,
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
    strictSpelling: json['strict_spelling'] as bool? ?? false,
    maxPlayers: json['max_players'] as int,
    public: public,
    kind: RoomKind.values.byName(json['kind'] as String? ?? 'classic'),
    stake: json['stake'] as int? ?? 0,
    format: RoomFormat.values.byName(json['format'] as String? ?? 'rounds'),
    theme: RoomTheme.fromWire(json['theme'] as String?),
  );

  final String language;
  final Difficulty difficulty;
  final List<Category> categories;
  final int rounds;
  final int roundDuration;
  final bool strictSpelling;
  final int maxPlayers;
  final bool public;
  final RoomKind kind;

  /// Mise (paris) ou montant de la dotation (prize).
  final int stake;

  bool get betting => kind == RoomKind.bet;
  bool get prize => kind == RoomKind.prize;

  final RoomFormat format;
  bool get elimination => format == RoomFormat.elimination;
  bool get relay => format == RoomFormat.relay;

  final RoomTheme theme;

  Map<String, dynamic> toJson() => {
    'language': language,
    'difficulty': difficulty.name,
    'categories': [for (final c in categories) c.wire],
    'rounds': rounds,
    'round_duration': roundDuration,
    'strict_spelling': strictSpelling,
    'max_players': maxPlayers,
    'public': public,
    'kind': kind.name,
    'stake': stake,
    'format': format.name,
    'theme': theme.wire,
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
    this.freezesLeft = 0,
    this.frozenUntil,
    this.chatUnlocked = false,
    this.rematchVote = false,
    this.title = '',
    this.assignments = const [],
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
    freezesLeft: json['freezes_left'] as int? ?? 0,
    frozenUntil: _date(json['frozen_until']),
    chatUnlocked: json['chat_unlocked'] as bool? ?? false,
    rematchVote: json['rematch_vote'] as bool? ?? false,
    title: json['title'] as String? ?? '',
    assignments: [
      for (final c in (json['assignments'] as List?) ?? const [])
        Category.fromWire(c as String),
    ],
    avatarPreset: json['avatar_preset'] as int? ?? 0,
    avatarUrl: json['avatar_url'] as String?,
    level: json['level'] as int? ?? 1,
    eliminatedRound: json['eliminated_round'] as int?,
    hair: json['hair'] as String? ?? '',
    hat: json['hat'] as String? ?? '',
    frame: json['frame'] as String? ?? '',
    nameStyle: json['name_style'] as String? ?? '',
  );

  bool get frozen {
    final until = frozenUntil;
    return until != null && until.isAfter(DateTime.now());
  }

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

  /// Charges Freeze restantes.
  final int freezesLeft;
  final DateTime? frozenUntil;
  final bool chatUnlocked;
  final bool rematchVote;
  final String title;
  final List<Category> assignments;

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

class RoomReaction {
  const RoomReaction({
    required this.clientId,
    required this.nickname,
    required this.sticker,
  });

  factory RoomReaction.fromJson(Map<String, dynamic> json) => RoomReaction(
        clientId: json['client_id'] as String,
        nickname: json['nickname'] as String,
        sticker: RoomSticker.values.byName(json['sticker'] as String),
      );

  final String clientId;
  final String nickname;
  final RoomSticker sticker;
}

class RoomChatMessage {
  const RoomChatMessage({
    required this.clientId,
    required this.nickname,
    required this.text,
  });

  factory RoomChatMessage.fromJson(Map<String, dynamic> json) =>
      RoomChatMessage(
        clientId: json['client_id'] as String,
        nickname: json['nickname'] as String,
        text: json['text'] as String,
      );

  final String clientId;
  final String nickname;
  final String text;
}

class LightningState {
  const LightningState({
    required this.letter,
    required this.category,
    required this.options,
    required this.endsAt,
    required this.picks,
  });

  factory LightningState.fromJson(Map<String, dynamic> json) {
    final rawPicks = json['picks'];
    final picks = <String, (String, int)>{};
    if (rawPicks is Map) {
      for (final e in rawPicks.entries) {
        final value = e.value;
        if (value is! Map) continue;
        final choice = value['choice'];
        if (choice is! String) continue;
        final points = value['points'];
        picks['${e.key}'] = (
          choice,
          points is int ? points : int.tryParse('$points') ?? 0,
        );
      }
    }
    return LightningState(
      letter: json['letter'] as String,
      category: Category.fromWire(json['category'] as String),
      options: [for (final o in json['options'] as List) '$o'],
      endsAt: DateTime.parse(json['ends_at'] as String),
      picks: picks,
    );
  }

  final String letter;
  final Category category;
  final List<String> options;
  final DateTime endsAt;
  final Map<String, (String, int)> picks;
}

class WordReviewItem {
  const WordReviewItem({
    required this.category,
    required this.word,
    required this.letter,
    required this.unique,
    required this.by,
    this.facts = const [],
  });

  factory WordReviewItem.fromJson(Map<String, dynamic> json) => WordReviewItem(
        category: Category.fromWire(json['category'] as String),
        word: json['word'] as String,
        letter: json['letter'] as String? ?? '',
        unique: json['unique'] as bool? ?? false,
        by: [for (final n in (json['by'] as List?) ?? const []) n as String],
        facts: [
          for (final f in (json['facts'] as List?) ?? const []) '$f',
        ],
      );

  final Category category;
  final String word;
  final String letter;
  final bool unique;
  final List<String> by;

  /// Infos pédagogiques (capitale, continent, régime…).
  final List<String> facts;
}

/// Salon vocal pendant la partie (Agora).
class RoomVoice {
  const RoomVoice({
    this.enabled = false,
    this.open = false,
    this.channel = '',
    this.muted = const [],
    this.excluded = const [],
  });

  factory RoomVoice.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RoomVoice();
    return RoomVoice(
      enabled: json['enabled'] as bool? ?? false,
      open: json['open'] as bool? ?? false,
      channel: json['channel'] as String? ?? '',
      muted: [
        for (final id in (json['muted'] as List?) ?? const []) id as String,
      ],
      excluded: [
        for (final id in (json['excluded'] as List?) ?? const []) id as String,
      ],
    );
  }

  final bool enabled;
  final bool open;
  final String channel;
  final List<String> muted;
  final List<String> excluded;

  bool isMuted(String clientId) => muted.contains(clientId);
  bool isExcluded(String clientId) => excluded.contains(clientId);
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
    this.lightning,
    this.reactions = const [],
    this.chat = const [],
    this.wordReview = const [],
    this.bonusPlayed = false,
    this.rematchVotes = 0,
    this.rematchNeed = 1,
    this.freezePrice = 15,
    this.chatUnlockPrice = 25,
    this.voice = const RoomVoice(),
  });

  factory RoomState.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    final serverTime = DateTime.parse(json['server_time'] as String);
    final roundJson = json['round'] as Map<String, dynamic>?;
    final prices = (json['prices'] as Map?) ?? const {};
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
      lightning: json['lightning'] == null
          ? null
          : LightningState.fromJson(json['lightning'] as Map<String, dynamic>),
      reactions: [
        for (final r in (json['reactions'] as List?) ?? const [])
          RoomReaction.fromJson(r as Map<String, dynamic>),
      ],
      chat: [
        for (final m in (json['chat'] as List?) ?? const [])
          RoomChatMessage.fromJson(m as Map<String, dynamic>),
      ],
      wordReview: [
        for (final w in (json['word_review'] as List?) ?? const [])
          WordReviewItem.fromJson(w as Map<String, dynamic>),
      ],
      bonusPlayed: json['bonus_played'] as bool? ?? false,
      rematchVotes: json['rematch_votes'] as int? ?? 0,
      rematchNeed: json['rematch_need'] as int? ?? 1,
      freezePrice: prices['freeze'] as int? ?? 15,
      chatUnlockPrice: prices['chat_unlock'] as int? ?? 25,
      voice: RoomVoice.fromJson(json['voice'] as Map<String, dynamic>?),
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
  final LightningState? lightning;
  final List<RoomReaction> reactions;
  final List<RoomChatMessage> chat;
  final List<WordReviewItem> wordReview;
  final bool bonusPlayed;
  final int rematchVotes;
  final int rematchNeed;
  final int freezePrice;
  final int chatUnlockPrice;
  final RoomVoice voice;

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
    this.strictSpelling = false,
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
    strictSpelling: json['strict_spelling'] as bool? ?? false,
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
  final bool strictSpelling;
}
