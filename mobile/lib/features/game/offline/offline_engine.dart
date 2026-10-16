import 'dart:math';

import '../data/models.dart';
import '../data/solo_backend.dart';
import 'normalization.dart';
import 'offline_dictionary.dart';

/// Same rules as the server (backend/app/core/game_rules.py).
abstract final class OfflineRules {
  static const hardLetters = 'KQWXYZ';
  static const allLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const letterPools = {
    Difficulty.easy: 'ABCDEFGLMPRST',
    Difficulty.normal: 'ABCDEFGHIJLMNOPRSTUV',
    Difficulty.hard: allLetters,
  };
  static const minAnswers = {
    Difficulty.easy: 5,
    Difficulty.normal: 3,
    Difficulty.hard: 1,
  };
  static const pointsUnique = 10;
  static const hintPoints = 5;
  static const hintsPerGame = 3;
  static const submitGrace = Duration(seconds: 2);
  static const hintOptions = 4;
}

class _Game {
  _Game(this.id, this.settings);

  final String id;
  final SoloGameSettings settings;
  final List<String> letters = [];
  final Map<Category, _Hint> hints = {};
  int hintsUsed = 0;
  int totalScore = 0;
  int roundsPlayed = 0;
  DateTime? startedAt;
  DateTime? endsAt;
  bool roundOpen = false;
}

class _Hint {
  _Hint(this.options, this.answer);

  final List<String> options;
  final String answer;
  String? picked;
}

/// Solo games played entirely on the device, for when the server is
/// unreachable. Validation and scoring match the server.
class OfflineSoloBackend implements SoloBackend {
  OfflineSoloBackend(
    this._dictionary, {
    Random? random,
    DateTime Function()? now,
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;

  final OfflineDictionary _dictionary;
  final Random _random;
  final DateTime Function() _now;
  final Map<String, _Game> _games = {};

  Normalizer get _norm => _dictionary.normalizer;

  @override
  bool get offline => true;

  @override
  Future<SoloGame> createGame(SoloGameSettings settings) async {
    final game = _Game('offline-${_now().microsecondsSinceEpoch}', settings);
    _games[game.id] = game;
    return _snapshot(game);
  }

  SoloGame _snapshot(_Game game) => SoloGame(
    id: game.id,
    categories: game.settings.categories,
    totalRounds: game.settings.rounds,
    roundDuration: game.settings.roundDuration,
    status: game.roundsPlayed >= game.settings.rounds ? 'finished' : 'playing',
    totalScore: game.totalScore,
    roundsPlayed: game.roundsPlayed,
    hintsLeft: OfflineRules.hintsPerGame - game.hintsUsed,
  );

  _Game _game(String id) =>
      _games[id] ?? (throw StateError('unknown offline game $id'));

  // ------------------------------------------------------------------ letters

  String _drawLetter(_Game game) {
    final settings = game.settings;
    final minimum = OfflineRules.minAnswers[settings.difficulty]!;
    final eligible = [
      for (final letter in OfflineRules.letterPools[settings.difficulty]!.split(
        '',
      ))
        if (settings.categories.every(
          (c) => _dictionary.count(c, settings.language, letter) >= minimum,
        ))
          letter,
    ];
    if (eligible.isEmpty) throw StateError('no letter available');
    final fresh = eligible.where((l) => !game.letters.contains(l)).toList();
    final pool = fresh.isEmpty ? eligible : fresh;
    return pool[_random.nextInt(pool.length)];
  }

  @override
  Future<GameRound> startRound(String gameId) async {
    final game = _game(gameId);
    final letter = _drawLetter(game);
    game.letters.add(letter);
    game.hints.clear();
    game.roundOpen = true;
    final now = _now();
    game.startedAt = now;
    game.endsAt = now.add(Duration(seconds: game.settings.roundDuration));
    return GameRound(
      number: game.letters.length,
      letter: letter,
      duration: game.settings.roundDuration,
      endsAt: game.endsAt!,
      clockOffset: Duration.zero,
    );
  }

  // --------------------------------------------------------------- validation

  /// Port of validation_service.validate_answer.
  (AnswerStatus, String?) validate(
    Category category,
    String language,
    String letter,
    String raw,
  ) {
    final keys = _norm.lookupKeys(raw, category);
    if (keys.isEmpty) return (AnswerStatus.empty, null);
    for (final key in keys) {
      final value = _dictionary.find(category, language, key);
      if (value != null) {
        if (!Normalizer.startsWithLetter(key, letter)) {
          return (AnswerStatus.wrongLetter, null);
        }
        return (AnswerStatus.valid, value);
      }
    }
    if (!Normalizer.startsWithLetter(_norm.normalize(raw), letter)) {
      return (AnswerStatus.wrongLetter, null);
    }
    return (AnswerStatus.notFound, null);
  }

  @override
  Future<(RoundResult, SoloGame)> submit(
    String gameId,
    int roundNumber,
    Map<Category, String> answers,
  ) async {
    final game = _game(gameId);
    final now = _now();
    final late = now.isAfter(game.endsAt!.add(OfflineRules.submitGrace));
    final letter = game.letters.last;
    final settings = game.settings;

    final results = <AnswerResult>[];
    for (final category in settings.categories) {
      final hint = game.hints[category];
      final raw = hint?.picked ?? answers[category] ?? '';
      final hinted = hint?.picked != null;
      final (status, matched) = late
          ? (AnswerStatus.late, null)
          : (hinted && hint!.picked != hint.answer)
          ? (AnswerStatus.hintWrong, null)
          : validate(category, settings.language, letter, raw);
      final valid = status == AnswerStatus.valid;
      results.add(
        AnswerResult(
          category: category,
          value: raw,
          status: status,
          points: valid
              ? (hinted ? OfflineRules.hintPoints : OfflineRules.pointsUnique)
              : 0,
          matchedValue: matched,
          hinted: hinted,
          suggestion: valid
              ? null
              : _example(category, settings.language, letter),
        ),
      );
    }

    final score = results.fold(0, (sum, r) => sum + r.points);
    game.totalScore += score;
    game.roundsPlayed++;
    game.roundOpen = false;
    final submittedAt = now.isAfter(game.endsAt!) ? game.endsAt! : now;
    return (
      RoundResult(
        number: roundNumber,
        letter: letter,
        answers: results,
        roundScore: score,
        elapsed: submittedAt.difference(game.startedAt!),
      ),
      _snapshot(game),
    );
  }

  /// Une réponse connue de la catégorie, montrée quand le joueur s'est trompé.
  String? _example(Category category, String language, String letter) {
    final answers = _dictionary.answers(category, language, letter, limit: 10);
    return answers.isEmpty
        ? null
        : answers[_random.nextInt(answers.length)].value;
  }

  // -------------------------------------------------------------------- hints

  @override
  Future<HintOptions> requestHint(
    String gameId,
    int roundNumber,
    Category category,
  ) async {
    final game = _game(gameId);
    final existing = game.hints[category];
    if (existing == null) {
      if (game.hintsUsed >= OfflineRules.hintsPerGame) {
        throw const OfflineError('no_hints_left');
      }
      game.hints[category] = _buildHint(
        category,
        game.settings.language,
        game.letters.last,
      );
      game.hintsUsed++;
    }
    return HintOptions(
      category: category,
      options: game.hints[category]!.options,
      hintsLeft: OfflineRules.hintsPerGame - game.hintsUsed,
    );
  }

  @override
  Future<HintPick> pickHint(
    String gameId,
    int roundNumber,
    Category category,
    String choice,
  ) async {
    final hint = _game(gameId).hints[category];
    if (hint == null) throw const OfflineError('no_hint_requested');
    if (hint.picked != null) throw const OfflineError('hint_already_picked');
    hint.picked = choice;
    return HintPick(
      category: category,
      correct: choice == hint.answer,
      answer: hint.answer,
    );
  }

  /// Port of hint_service.build_hint.
  _Hint _buildHint(Category category, String language, String letter) {
    int pool(Category c) => c == Category.city ? 12 : 40;
    final answers = _dictionary.answers(
      category,
      language,
      letter,
      limit: category == Category.city ? 12 : 20,
    );
    if (answers.isEmpty) throw const OfflineError('no_hint_available');
    final answer = answers[_random.nextInt(answers.length)].value;

    final decoys = <String>[];
    final others = [...Category.values.where((c) => c != category)]
      ..shuffle(_random);
    for (final other in others) {
      final candidates = [
        ..._dictionary.answers(other, language, letter, limit: pool(other)),
      ]..shuffle(_random);
      for (final candidate in candidates) {
        final fitsCategory =
            _dictionary.find(category, language, candidate.key) != null;
        if (!fitsCategory && !decoys.contains(candidate.value)) {
          decoys.add(candidate.value);
          break;
        }
      }
    }
    for (
      var i = 0;
      i < 20 && decoys.length < OfflineRules.hintOptions - 1;
      i++
    ) {
      final source = [answer, ...decoys][_random.nextInt(decoys.length + 1)];
      final decoy = _scramble(source);
      if (!decoys.contains(decoy) &&
          _norm.normalize(decoy) != _norm.normalize(answer)) {
        decoys.add(decoy);
      }
    }
    final options = [answer, ...decoys.take(OfflineRules.hintOptions - 1)]
      ..shuffle(_random);
    return _Hint(options, answer);
  }

  String _scramble(String word) {
    if (word.length < 4) return '$word${word[word.length - 1].toLowerCase()}';
    final middle = word.substring(1).split('');
    for (var i = 0; i < 10; i++) {
      middle.shuffle(_random);
      final candidate = word[0] + middle.join();
      if (candidate != word) return candidate;
    }
    return '$word${word[word.length - 1].toLowerCase()}';
  }
}

class OfflineError implements Exception {
  const OfflineError(this.code);

  final String code;

  @override
  String toString() => 'OfflineError($code)';
}
