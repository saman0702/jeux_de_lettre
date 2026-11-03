import 'dart:async';

import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/round_view.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import '../perks/coins_video_offer.dart';
import '../perks/perks_controller.dart';
import 'iq_daily_screen.dart';
import 'iq_models.dart';
import 'iq_recent.dart';
import 'iq_run.dart';
import 'iq_solo_draft.dart';
import 'iq_solo_source.dart';
import 'iq_widgets.dart';

/// Partie de QI en solo (ou défi du jour). En ligne, elle se joue contre le
/// serveur : réponses vérifiées, points convertis en pièces, jokers payants.
/// Hors ligne, elle se joue sur le téléphone, sans pièces ni jokers.
/// Pause possible après une manche : on peut quitter et reprendre plus tard.
class IqSoloScreen extends StatefulWidget {
  const IqSoloScreen({
    super.key,
    required this.rounds,
    required this.duration,
    required this.difficulty,
    required this.scoring,
    this.apiClient,
    this.puzzles,
    this.daily = false,
    this.draft,
    this.now = DateTime.now,
  });

  final int rounds;

  /// Secondes par énigme.
  final int duration;
  final Difficulty difficulty;
  final IqScoring scoring;
  final ApiClient? apiClient;

  /// Énigmes déjà choisies (tests) : partie hors ligne.
  final List<IqPuzzle>? puzzles;

  /// Défi du jour (en ligne seulement).
  final bool daily;

  /// Partie en pause à reprendre (pas le défi du jour).
  final IqSoloDraft? draft;
  final DateTime Function() now;

  @override
  State<IqSoloScreen> createState() => _IqSoloScreenState();
}

class _IqSoloScreenState extends State<IqSoloScreen> {
  IqRun? _run;
  DateTime _startedAt = DateTime.now();

  /// Vidéo en cours (pas assez de pièces pour un joker) : chrono figé.
  DateTime? _pausedAt;
  IqTurn? _turn;
  final _turns = <IqTurn>[];
  Timer? _ticker;
  bool _done = false;
  bool _busy = false;
  int _coinsWon = 0;
  int? _iq;

  // Jokers de l'énigme en cours.
  Set<int> _removed = {};
  (int, int)? _range;
  int? _traceStart;

  OnlineController? get _online =>
      context.getInheritedWidgetOfExactType<OnlineScope>()?.controller;

  @override
  void initState() {
    super.initState();
    // Après le premier affichage : _load lit les textes et le ScaffoldMessenger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameFeedbackScope.of(context).setMusic(MusicMood.solo);
      _load();
    });
  }

  Future<void> _load() async {
    final draft = widget.draft;
    if (draft != null && !widget.daily) {
      await _resumeDraft(draft);
      return;
    }
    final given = widget.puzzles;
    if (given != null) {
      await IqSoloDraftStore.clear();
      _begin(
        LocalIqRun(given, scoring: widget.scoring, duration: widget.duration),
      );
      return;
    }
    final online = _online;
    final api = widget.apiClient ?? ApiClient();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reachable = online != null && !online.client.unreachable;
    if (reachable) {
      try {
        await IqSoloDraftStore.clear();
        final avoid = await IqRecentStore.load();
        final run = widget.daily
            ? await ServerIqRun.dailyChallenge(api, online.clientId)
            : await ServerIqRun.solo(
                api,
                online.clientId,
                rounds: widget.rounds,
                duration: widget.duration,
                difficulty: widget.difficulty.name,
                scoring: widget.scoring,
                avoid: avoid,
              );
        if (mounted) _begin(run);
        return;
      } on ApiException catch (e) {
        if (widget.daily || e.code != 'network_error') {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                e.code == 'daily_done'
                    ? l10n.iqDailyDone
                    : errorMessage(l10n, e.code),
              ),
            ),
          );
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
    } else if (widget.daily) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.iqDailyNeedsOnline)));
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // Pas de serveur : partie sur le téléphone, sans pièces.
    await IqSoloDraftStore.clear();
    final avoid = await IqRecentStore.load();
    final puzzles = await loadSoloPuzzles(
      count: widget.rounds,
      difficulty: widget.difficulty,
      avoid: avoid,
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.iqOfflineNoCoins)));
    _begin(
      LocalIqRun(puzzles, scoring: widget.scoring, duration: widget.duration),
    );
  }

  Future<void> _resumeDraft(IqSoloDraft draft) async {
    _turns
      ..clear()
      ..addAll(draft.turns);
    _coinsWon = draft.coinsWon;
    _iq = draft.iq;
    if (draft.finished) {
      setState(() {
        _done = true;
        _run = draft.online
            ? null
            : LocalIqRun(
                draft.puzzles,
                scoring: draft.scoring,
                duration: draft.duration,
                startIndex: draft.puzzles.isEmpty
                    ? 0
                    : draft.puzzles.length - 1,
              );
      });
      return;
    }
    if (draft.online) {
      final online = _online;
      final sessionId = draft.sessionId;
      final api = widget.apiClient ?? ApiClient();
      if (online == null || sessionId == null || online.client.unreachable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).iqResumeNeedsOnline)),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      try {
        final resumed = await ServerIqRun.resume(
          api,
          online.clientId,
          sessionId,
        );
        if (!mounted) return;
        if (resumed.finished) {
          setState(() {
            _iq = resumed.iq ?? _iq;
            _done = true;
          });
          await IqSoloDraftStore.clear();
          return;
        }
        _begin(resumed.run!);
      } on ApiException catch (e) {
        await IqSoloDraftStore.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(AppLocalizations.of(context), e.code))),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    if (draft.nextIndex >= draft.puzzles.length) {
      setState(() => _done = true);
      return;
    }
    _begin(
      LocalIqRun(
        draft.puzzles,
        scoring: draft.scoring,
        duration: draft.duration,
        startIndex: draft.nextIndex,
      ),
    );
  }

  bool get _canPause =>
      !widget.daily && _turn != null && !_done && _run != null && !_busy;

  Future<void> _pauseAndLeave() async {
    if (!_canPause) return;
    setState(() => _busy = true);
    try {
      final run = _run!;
      var finished = run.number >= run.total;
      // Hors ligne : nextIndex = énigme suivante (number est 1-based de l'actuelle).
      var nextIndex = finished ? run.total : run.number;
      String? sessionId;
      if (run is ServerIqRun) {
        final paused = await run.pause();
        finished = paused['finished'] == true;
        sessionId = run.sessionId;
        if (paused['iq'] != null) _iq = paused['iq'] as int;
        nextIndex = finished
            ? run.total
            : ((paused['number'] as int? ?? run.number) - 1);
      }
      await IqSoloDraftStore.save(
        IqSoloDraft(
          online: run.online,
          sessionId: sessionId,
          rounds: widget.rounds,
          duration: widget.duration,
          difficulty: widget.difficulty,
          scoring: widget.scoring,
          nextIndex: nextIndex,
          finished: finished,
          puzzles: run is LocalIqRun ? run.puzzles : const [],
          turns: List.of(_turns),
          coinsWon: _coinsWon,
          iq: _iq,
        ),
      );
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      } else {
        setState(() {
          _done = finished;
          _turn = null;
          _busy = false;
        });
      }
    } on ApiException catch (e) {
      _error(e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onBack() async {
    if (_done || widget.daily) {
      if (_done) await IqSoloDraftStore.clear();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_canPause) {
      await _pauseAndLeave();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final leave = await showGameConfirm(
      context,
      icon: GameIconKind.door,
      title: l10n.quitGameTitle,
      message: l10n.iqQuitMidRound,
      confirmLabel: l10n.quit.toUpperCase(),
      cancelLabel: l10n.dialogStay,
    );
    if (!leave || !mounted) return;
    await IqSoloDraftStore.clear();
    if (mounted) Navigator.of(context).pop();
  }

  void _begin(IqRun run) {
    setState(() {
      _run = run;
      _startedAt = widget.now();
      _removed = {};
      _range = null;
    });
    // Mémorise les ids pour les prochaines parties (rejouer ≠ mêmes énigmes).
    if (run is LocalIqRun) {
      unawaited(IqRecentStore.remember(run.puzzles.map((p) => p.id)));
    } else {
      unawaited(IqRecentStore.remember([run.puzzle.id]));
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  Duration _elapsed() => (_pausedAt ?? widget.now()).difference(_startedAt);

  void _tick() {
    final run = _run;
    if (!mounted || run == null || _turn != null || _done || _busy) return;
    // Illimité (duration 0) : pas d'auto-envoi ; le temps réel compte au submit.
    if (run.allowed.inMilliseconds <= 0) {
      setState(() {});
      return;
    }
    if (_elapsed() >= run.allowed) {
      _answer(null);
    } else {
      setState(() {});
    }
  }

  void _applyWallet(IqTurn turn) {
    final wallet = turn.wallet;
    if (wallet == null) return;
    _coinsWon += wallet.coinsGained;
    _online?.applyWallet(wallet);
  }

  Future<void> _answer(String? raw) async {
    final run = _run;
    if (run == null || _turn != null || _busy) return;
    final feedback = GameFeedbackScope.of(context);
    setState(() => _busy = true);
    try {
      final turn = await run.answer(raw, _elapsed());
      if (!mounted) return;
      feedback.play(turn.correct ? Sfx.valid : Sfx.invalid);
      _applyWallet(turn);
      setState(() {
        _turn = turn;
        _turns.add(turn);
        _iq = turn.iq ?? _iq;
      });
      unawaited(IqRecentStore.remember([turn.puzzle.id]));
    } on ApiException catch (e) {
      _error(e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    final run = _run!;
    if (run.number >= run.total) {
      _ticker?.cancel();
      unawaited(IqSoloDraftStore.clear());
      GameFeedbackScope.of(context).play(Sfx.victory);
      setState(() {
        _turn = null;
        _done = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await run.next();
      if (!mounted) return;
      setState(() {
        _turn = null;
        _startedAt = widget.now();
        _removed = {};
        _range = null;
        _traceStart = null;
      });
      unawaited(IqRecentStore.remember([run.puzzle.id]));
    } on ApiException catch (e) {
      _error(e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joker(String kind) async {
    final run = _run;
    if (run == null || _turn != null || _busy) return;
    setState(() => _busy = true);
    bool? credited;
    try {
      final effect = await run.joker(kind);
      if (!mounted) return;
      GameFeedbackScope.of(context).play(Sfx.reveal);
      final wallet = effect.wallet;
      if (wallet != null) _online?.applyWallet(wallet);
      final turn = effect.turn;
      setState(() {
        if (turn != null) {
          // Solution achetée : on montre la bonne réponse, puis « suivante ».
          _turn = turn;
          _turns.add(turn);
          _iq = turn.iq ?? _iq;
          _removed = {};
          _range = null;
          _traceStart = null;
          unawaited(IqRecentStore.remember([turn.puzzle.id]));
          return;
        }
        _removed = {..._removed, ...effect.removed};
        if (effect.low != null) _range = (effect.low!, effect.high!);
        if (effect.start != null) _traceStart = effect.start;
        if (effect.replaced) {
          _startedAt = widget.now();
          _removed = {};
          _range = null;
          _traceStart = null;
          unawaited(IqRecentStore.remember([run.puzzle.id]));
        }
      });
    } on ApiException catch (e) {
      if (e.code == 'not_enough_coins') {
        credited = await _videoForJoker(kind);
        if (credited == null) _error(e.code);
      } else {
        _error(e.code);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Pièces gagnées avec la vidéo : le joker est pris tout de suite.
    if (credited == true && mounted) await _joker(kind);
  }

  /// Pas assez de pièces : chrono en pause et vidéo proposée. Renvoie null si
  /// aucune vidéo n'est disponible, vrai si les pièces ont été créditées.
  Future<bool?> _videoForJoker(String kind) async {
    final perks = _perks;
    final run = _run;
    if (perks == null || run == null || !canOfferCoinsVideo(perks)) return null;
    final server = run is ServerIqRun && run.allowed > Duration.zero ? run : null;
    var frozen = false;
    _pausedAt = widget.now();
    try {
      if (server != null) {
        try {
          await server.startAdBreak(kind);
          frozen = true;
        } on ApiException {
          // Pause déjà prise sur cette énigme : la vidéo reste possible, sans pause.
        }
      }
      if (!mounted) return false;
      return await offerCoinsVideo(
        context,
        perks: perks,
        price: run.jokerPrices[kind] ?? 0,
        coins: _online?.wallet?.coins ?? 0,
      );
    } finally {
      var paused = Duration.zero;
      if (frozen) {
        try {
          paused = await server!.endAdBreak();
        } on ApiException {
          paused = Duration.zero;
        }
      }
      _pausedAt = null;
      if (mounted) setState(() => _startedAt = _startedAt.add(paused));
    }
  }

  void _error(String code) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage(AppLocalizations.of(context), code))),
    );
  }

  void _restart() {
    _ticker?.cancel();
    unawaited(IqSoloDraftStore.clear());
    setState(() {
      _run = null;
      _turn = null;
      _turns.clear();
      _done = false;
      _coinsWon = 0;
      _iq = null;
    });
    _load();
  }

  PerksController? _perks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _perks ??= PerksScope.maybeOf(context);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_done) unawaited(_perks?.onGameFinished() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: GameBackground(
        theme: BackgroundTheme.iq,
        child: SafeArea(
          child: Column(
            children: [
              OnlineHeader(
                title: widget.daily ? l10n.iqDailyTitle : l10n.iqSoloTitle,
                quitStyle: !_done,
                onBack: _onBack,
                trailing: _canPause
                    ? RoundIconButton(
                        key: const Key('iq_pause'),
                        icon: Icons.pause_rounded,
                        tooltip: l10n.iqPause,
                        color: AppColors.white,
                        iconColor: AppColors.purple,
                        size: 40,
                        onPressed: _busy ? () {} : _pauseAndLeave,
                      )
                    : null,
              ),
              Expanded(child: _body(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_done) return _result(l10n);
    final run = _run;
    if (run == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      );
    }
    if (run.total == 0) return _result(l10n);
    final language = Localizations.localeOf(context).languageCode;
    final turn = _turn;
    final puzzle = turn?.puzzle ?? run.puzzle;
    final remaining = run.allowed - _elapsed();
    // Chrono en haut, réponse en bas ; l'énigme se compacte et n'affiche un
    // indice de scroll que si le contenu dépasse vraiment.
    final compact = iqCompactScreen(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, 0),
          child: IqHeader(
            number: run.number,
            total: run.total,
            // Après réponse : plus de chrono (le temps est déjà jugé en bas).
            // Illimité : ∞ pendant l'énigme seulement.
            trailing: turn != null
                ? null
                : TimerBadge(
                    remaining: remaining.isNegative ? Duration.zero : remaining,
                    total: run.allowed,
                    size: compact ? 48 : 56,
                  ),
          ),
        ),
        Expanded(
          child: IqScrollArea(
            padding: EdgeInsets.fromLTRB(16, compact ? 6 : 8, 16, 10),
            children: [
              IqPuzzleCard(
                key: ValueKey(puzzle.id),
                puzzle: puzzle,
                language: language,
              ),
              if (turn != null) ...[
                if (turn.late)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.iqLate,
                      textAlign: TextAlign.center,
                      style: gameFont(size: 16, color: AppColors.white),
                    ),
                  ),
                const SizedBox(height: 8),
                IqRevealCard(
                  puzzle: puzzle,
                  language: language,
                  players: [
                    IqPlayerResult(
                      name: l10n.iqYou,
                      answer: turn.answer,
                      correct: turn.correct,
                      points: turn.points,
                      isMe: true,
                      elapsed: turn.elapsed,
                      speed: turn.speed,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Aides décollées du cadre d'énoncé, au-dessus des choix.
        if (turn == null) ...[
          if (run.jokerPrices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: IqJokerBar(
                puzzle: run.puzzle,
                prices: run.jokerPrices,
                used: run.usedJokers,
                busy: _busy,
                unlimitedTime: widget.duration <= 0,
                onUse: _joker,
              ),
            ),
          if (_traceStart != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.iqTraceStartHint,
                key: const Key('iq_trace_hint'),
                textAlign: TextAlign.center,
                style: gameFont(size: 15, color: AppColors.yellow),
              ),
            ),
          if (_range != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.iqHintRange(_range!.$1, _range!.$2),
                key: const Key('iq_hint_range'),
                textAlign: TextAlign.center,
                style: gameFont(size: 15, color: AppColors.yellow),
              ),
            ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, compact ? 8 : 12),
          child: turn == null
              ? IqAnswerPad(
                  key: ValueKey('pad_${puzzle.id}'),
                  puzzle: puzzle,
                  language: language,
                  enabled: !_busy,
                  removed: _removed,
                  traceStart: _traceStart,
                  onAnswer: _answer,
                )
              : CandyButton(
                  key: const Key('iq_next'),
                  label: run.number >= run.total
                      ? l10n.iqSeeResult
                      : l10n.iqNext,
                  icon: Icons.arrow_forward_rounded,
                  color: AppColors.green,
                  textColor: AppColors.white,
                  loading: _busy,
                  onPressed: _next,
                ),
        ),
      ],
    );
  }

  Widget _result(AppLocalizations l10n) {
    final correct = _turns.where((t) => t.correct).length;
    final points = _turns.fold(0, (s, t) => s + t.points);
    final iq =
        _iq ??
        iqEstimate([
          for (final t in _turns) (t.puzzle.level, t.correct, t.speed),
        ]);
    final daily = _run?.daily ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        BounceIn(
          from: 0.6,
          child: GameCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  l10n.iqResultTitle,
                  style: gameFont(size: 22, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  '$iq',
                  key: const Key('iq_estimate'),
                  style: gameFont(size: 64, color: AppColors.purple),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.iqResultScore(correct, _turns.length, points),
                  key: const Key('iq_score'),
                  textAlign: TextAlign.center,
                  style: fredoka(size: 16, color: AppColors.ink),
                ),
                if (_coinsWon > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const GameIcon(GameIconKind.coin, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        l10n.iqCoinsWon(_coinsWon),
                        key: const Key('iq_coins_won'),
                        style: gameFont(size: 17, color: AppColors.orange),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  l10n.iqResultNote,
                  textAlign: TextAlign.center,
                  style: fredoka(size: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (daily)
          CandyButton(
            key: const Key('iq_daily_board'),
            label: l10n.iqDailyLeaderboard,
            icon: Icons.leaderboard_rounded,
            color: AppColors.yellow,
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => IqDailyScreen(apiClient: widget.apiClient),
              ),
            ),
          )
        else
          CandyButton(
            key: const Key('iq_replay'),
            label: l10n.playAgain,
            icon: Icons.replay_rounded,
            color: AppColors.yellow,
            onPressed: _restart,
          ),
        const SizedBox(height: 12),
        CandyButton(
          label: l10n.backHome,
          icon: Icons.home_rounded,
          color: AppColors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
