import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/network/api_client.dart';
import 'data/models.dart';
import 'data/solo_backend.dart';
import 'hints/hint_controller.dart';

enum SoloPhase { countdown, playing, submitting, roundResult, finished, error }

class SoloGameController extends ChangeNotifier {
  SoloGameController({
    required this._api,
    required SoloGame game,
    this.countdownStep = const Duration(seconds: 1),
    this.tick = const Duration(milliseconds: 100),
    this.now = DateTime.now,
  }) : _game = game,
       fields = {for (final c in game.categories) c: TextEditingController()};

  static const countdownFrom = 3;

  final SoloBackend _api;
  final Duration countdownStep;
  final Duration tick;
  final DateTime Function() now;
  final Map<Category, TextEditingController> fields;

  SoloGame _game;
  GameRound? _round;
  HintController? _hints;
  final List<RoundResult> _results = [];
  SoloPhase _phase = SoloPhase.countdown;
  int _countdown = countdownFrom;
  Duration _remaining = Duration.zero;
  String? _errorCode;
  Future<void> Function()? _retry;
  Timer? _timer;
  bool _disposed = false;

  SoloGame get game => _game;

  /// Jokers for the current round.
  HintController? get hints => _hints;
  GameRound? get round => _round;
  List<RoundResult> get results => List.unmodifiable(_results);
  RoundResult? get lastResult => _results.isEmpty ? null : _results.last;
  SoloPhase get phase => _phase;

  /// 3, 2, 1, then 0 for "GO!".
  int get countdown => _countdown;
  Duration get remaining => _remaining;
  String? get errorCode => _errorCode;

  void start() => _startCountdown();

  /// Leaves the round result: next countdown, or the final screen.
  void nextRound() {
    if (_phase != SoloPhase.roundResult) return;
    if (_game.isFinished) {
      _setPhase(SoloPhase.finished);
    } else {
      _startCountdown();
    }
  }

  Future<void> retry() async => _retry?.call();

  void _startCountdown() {
    _timer?.cancel();
    _countdown = countdownFrom;
    _setPhase(SoloPhase.countdown);
    _timer = Timer.periodic(countdownStep, (timer) {
      if (_countdown > 0) {
        _countdown--;
        _notify();
      } else {
        timer.cancel();
        _startRound();
      }
    });
  }

  Future<void> _startRound() async {
    try {
      _round = await _api.startRound(_game.id);
    } on ApiException catch (e) {
      return _fail(e, _startRound);
    }
    for (final field in fields.values) {
      field.clear();
    }
    _hints?.dispose();
    _hints = HintController(
      source: _SoloHintSource(_api, _game.id, _round!.number),
      hintsLeft: _game.hintsLeft,
      letter: _round!.letter,
    );
    _remaining = _round!.remaining(now());
    _setPhase(SoloPhase.playing);
    _timer = Timer.periodic(tick, (_) {
      _remaining = _round!.remaining(now());
      if (_remaining == Duration.zero) {
        submit();
      } else {
        _notify();
      }
    });
  }

  /// Sends the answers; called by the "Finish" button or when time runs out.
  Future<void> submit() async {
    if (_phase != SoloPhase.playing) return;
    _timer?.cancel();
    _setPhase(SoloPhase.submitting);
    await _sendAnswers();
  }

  Future<void> _sendAnswers() async {
    final answers = {
      for (final e in fields.entries) e.key: e.value.text.trim(),
    };
    try {
      final (result, game) = await _api.submit(
        _game.id,
        _round!.number,
        answers,
      );
      _results.add(result);
      _game = game;
    } on ApiException catch (e) {
      return _fail(e, _sendAnswers);
    }
    _setPhase(SoloPhase.roundResult);
  }

  void _fail(ApiException error, Future<void> Function() retry) {
    _errorCode = error.code;
    _retry = () async {
      _errorCode = null;
      _setPhase(SoloPhase.submitting);
      await retry();
    };
    _setPhase(SoloPhase.error);
  }

  void _setPhase(SoloPhase phase) {
    _phase = phase;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _hints?.dispose();
    _timer?.cancel();
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }
}

class _SoloHintSource implements HintSource {
  _SoloHintSource(this._api, this._gameId, this._round);

  final SoloBackend _api;
  final String _gameId;
  final int _round;

  @override
  Future<HintOptions> request(Category category) =>
      _api.requestHint(_gameId, _round, category);

  @override
  Future<HintPick> pick(Category category, String choice) =>
      _api.pickHint(_gameId, _round, category, choice);
}
