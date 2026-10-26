import '../../core/network/api_client.dart';
import '../wallet/wallet.dart';
import 'iq_models.dart';

/// Résultat d'une énigme.
class IqTurn {
  const IqTurn({
    required this.puzzle,
    required this.answer,
    required this.correct,
    required this.points,
    this.late = false,
    this.wallet,
    this.iq,
  });

  /// L'énigme avec sa réponse et son explication.
  final IqPuzzle puzzle;
  final String? answer;
  final bool correct;
  final int points;
  final bool late;
  final WalletSnapshot? wallet;

  /// QI estimé, donné par le serveur à la dernière énigme.
  final int? iq;
}

/// Effet d'un joker.
class IqJokerEffect {
  const IqJokerEffect({
    this.removed = const {},
    this.low,
    this.high,
    this.wallet,
    this.replaced = false,
  });

  /// 50/50 : choix retirés.
  final Set<int> removed;

  /// Indice : la réponse est entre [low] et [high].
  final int? low;
  final int? high;
  final WalletSnapshot? wallet;

  /// Passer : une nouvelle énigme, chrono relancé.
  final bool replaced;
}

/// Une partie de QI en cours : contre le serveur (réponses vérifiées, pièces,
/// jokers) ou sur le téléphone (hors ligne, sans pièces).
abstract class IqRun {
  int get number;
  int get total;
  IqPuzzle get puzzle;

  /// Temps pour l'énigme en cours (avec le joker +15 s).
  Duration get allowed;

  /// Jokers proposés et leur prix ; vide hors ligne et au défi du jour.
  Map<String, int> get jokerPrices;
  Set<String> get usedJokers;

  /// Défi du jour (une tentative, classement).
  bool get daily;
  bool get online;

  Future<IqTurn> answer(String? raw, Duration elapsed);
  Future<void> next();
  Future<IqJokerEffect> joker(String kind);
}

/// Hors ligne : énigmes embarquées, vérifiées sur le téléphone.
class LocalIqRun implements IqRun {
  LocalIqRun(this.puzzles, {required this.scoring, required int duration})
    : _duration = Duration(seconds: duration);

  final List<IqPuzzle> puzzles;
  final IqScoring scoring;
  final Duration _duration;
  int _index = 0;

  @override
  int get number => _index + 1;
  @override
  int get total => puzzles.length;
  @override
  IqPuzzle get puzzle => puzzles[_index];
  @override
  Duration get allowed => _duration;
  @override
  Map<String, int> get jokerPrices => const {};
  @override
  Set<String> get usedJokers => const {};
  @override
  bool get daily => false;
  @override
  bool get online => false;

  @override
  Future<IqTurn> answer(String? raw, Duration elapsed) async {
    final answered = raw != null && raw.trim().isNotEmpty;
    final correct = puzzle.isCorrect(raw);
    return IqTurn(
      puzzle: puzzle,
      answer: answered ? raw.trim() : null,
      correct: correct,
      points: scoring.points(
        correct: correct,
        answered: answered,
        elapsed: elapsed,
        duration: _duration,
      ),
    );
  }

  @override
  Future<void> next() async => _index++;

  @override
  Future<IqJokerEffect> joker(String kind) =>
      throw ApiException('jokers_not_allowed');
}

/// En ligne : la partie vit sur le serveur.
class ServerIqRun implements IqRun {
  ServerIqRun._(this._api, this._clientId, Map<String, dynamic> game) {
    _apply(game);
  }

  final ApiClient _api;
  final String _clientId;
  late String _id;
  late int _number;
  late int _total;
  late IqPuzzle _puzzle;
  late int _duration;
  int _extra = 0;
  bool _daily = false;
  Map<String, int> _prices = const {};
  Set<String> _used = {};

  static Future<ServerIqRun> solo(
    ApiClient api,
    String clientId, {
    required int rounds,
    required int duration,
    required String difficulty,
    required IqScoring scoring,
  }) async => ServerIqRun._(
    api,
    clientId,
    await api.postJson('/api/v1/iq/solo', {
      'client_id': clientId,
      'rounds': rounds,
      'duration': duration,
      'difficulty': difficulty,
      'speed_bonus': scoring.speedBonus,
      'penalty': scoring.penalty,
    }),
  );

  static Future<ServerIqRun> dailyChallenge(
    ApiClient api,
    String clientId,
  ) async => ServerIqRun._(
    api,
    clientId,
    await api.postJson('/api/v1/iq/daily', {'client_id': clientId}),
  );

  void _apply(Map<String, dynamic> game) {
    _id = game['id'] as String;
    _number = game['number'] as int;
    _total = game['total'] as int;
    _duration = game['duration'] as int;
    _extra = game['extra_seconds'] as int? ?? 0;
    _daily = game['mode'] == 'daily';
    _prices = {
      for (final e in ((game['joker_prices'] as Map?) ?? const {}).entries)
        e.key as String: e.value as int,
    };
    _used = {for (final j in (game['jokers_used'] as List?) ?? const []) '$j'};
    _puzzle = IqPuzzle.fromJson(game['puzzle'] as Map<String, dynamic>);
  }

  @override
  int get number => _number;
  @override
  int get total => _total;
  @override
  IqPuzzle get puzzle => _puzzle;
  @override
  Duration get allowed => Duration(seconds: _duration + _extra);
  @override
  Map<String, int> get jokerPrices => _prices;
  @override
  Set<String> get usedJokers => _used;
  @override
  bool get daily => _daily;
  @override
  bool get online => true;

  static WalletSnapshot? _wallet(Object? raw) =>
      raw == null ? null : WalletSnapshot.fromJson(raw as Map<String, dynamic>);

  @override
  Future<IqTurn> answer(String? raw, Duration elapsed) async {
    final result = await _api.postJson('/api/v1/iq/sessions/$_id/answer', {
      'client_id': _clientId,
      'answer': raw,
    });
    return IqTurn(
      puzzle: IqPuzzle.fromJson(result['puzzle'] as Map<String, dynamic>),
      answer: result['answer'] as String?,
      correct: result['correct'] as bool,
      points: result['points'] as int,
      late: result['late'] as bool? ?? false,
      wallet: _wallet(result['wallet']),
      iq: result['iq'] as int?,
    );
  }

  @override
  Future<void> next() async => _apply(
    await _api.postJson('/api/v1/iq/sessions/$_id/next', {
      'client_id': _clientId,
    }),
  );

  @override
  Future<IqJokerEffect> joker(String kind) async {
    final effect = await _api.postJson('/api/v1/iq/sessions/$_id/joker', {
      'client_id': _clientId,
      'kind': kind,
    });
    _apply(effect['game'] as Map<String, dynamic>);
    return IqJokerEffect(
      removed: {
        for (final i in (effect['removed'] as List?) ?? const []) i as int,
      },
      low: effect['low'] as int?,
      high: effect['high'] as int?,
      wallet: _wallet(effect['wallet']),
      replaced: kind == 'skip',
    );
  }
}
