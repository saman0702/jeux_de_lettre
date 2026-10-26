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
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/round_view.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import 'iq_daily_screen.dart';
import 'iq_models.dart';
import 'iq_run.dart';
import 'iq_solo_source.dart';
import 'iq_widgets.dart';

/// Partie de QI en solo (ou défi du jour). En ligne, elle se joue contre le
/// serveur : réponses vérifiées, points convertis en pièces, jokers payants.
/// Hors ligne, elle se joue sur le téléphone, sans pièces ni jokers.
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
  final DateTime Function() now;

  @override
  State<IqSoloScreen> createState() => _IqSoloScreenState();
}

class _IqSoloScreenState extends State<IqSoloScreen> {
  IqRun? _run;
  DateTime _startedAt = DateTime.now();
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
    final given = widget.puzzles;
    if (given != null) {
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
        final run = widget.daily
            ? await ServerIqRun.dailyChallenge(api, online.clientId)
            : await ServerIqRun.solo(
                api,
                online.clientId,
                rounds: widget.rounds,
                duration: widget.duration,
                difficulty: widget.difficulty.name,
                scoring: widget.scoring,
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
    final puzzles = await loadSoloPuzzles(
      count: widget.rounds,
      difficulty: widget.difficulty,
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.iqOfflineNoCoins)));
    _begin(
      LocalIqRun(puzzles, scoring: widget.scoring, duration: widget.duration),
    );
  }

  void _begin(IqRun run) {
    setState(() {
      _run = run;
      _startedAt = widget.now();
      _removed = {};
      _range = null;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final run = _run;
    if (!mounted || run == null || _turn != null || _done || _busy) return;
    if (widget.now().difference(_startedAt) >= run.allowed) {
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
      final turn = await run.answer(raw, widget.now().difference(_startedAt));
      if (!mounted) return;
      feedback.play(turn.correct ? Sfx.valid : Sfx.invalid);
      _applyWallet(turn);
      setState(() {
        _turn = turn;
        _turns.add(turn);
        _iq = turn.iq ?? _iq;
      });
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
      });
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
    try {
      final effect = await run.joker(kind);
      if (!mounted) return;
      GameFeedbackScope.of(context).play(Sfx.reveal);
      final wallet = effect.wallet;
      if (wallet != null) _online?.applyWallet(wallet);
      setState(() {
        _removed = {..._removed, ...effect.removed};
        if (effect.low != null) _range = (effect.low!, effect.high!);
        if (effect.replaced) {
          _startedAt = widget.now();
          _removed = {};
          _range = null;
        }
      });
    } on ApiException catch (e) {
      _error(e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
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

  @override
  void dispose() {
    _ticker?.cancel();
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
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(child: _body(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    final run = _run;
    if (run == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      );
    }
    if (_done || run.total == 0) return _result(l10n);
    final language = Localizations.localeOf(context).languageCode;
    final turn = _turn;
    final puzzle = turn?.puzzle ?? run.puzzle;
    final remaining = run.allowed - widget.now().difference(_startedAt);
    // Numéro et chrono fixes en haut ; seule l'énigme défile.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: IqHeader(
            number: run.number,
            total: run.total,
            trailing: turn == null
                ? TimerBadge(
                    remaining: remaining.isNegative ? Duration.zero : remaining,
                    total: run.allowed,
                  )
                : null,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              IqPuzzleCard(
                key: ValueKey(puzzle.id),
                puzzle: puzzle,
                language: language,
              ),
              const SizedBox(height: 10),
              if (turn == null) ...[
                if (run.jokerPrices.isNotEmpty) ...[
                  IqJokerBar(
                    puzzle: run.puzzle,
                    prices: run.jokerPrices,
                    used: run.usedJokers,
                    busy: _busy,
                    onUse: _joker,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_range != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      l10n.iqHintRange(_range!.$1, _range!.$2),
                      key: const Key('iq_hint_range'),
                      textAlign: TextAlign.center,
                      style: gameFont(size: 17, color: AppColors.yellow),
                    ),
                  ),
                IqAnswerPad(
                  key: ValueKey('pad_${puzzle.id}'),
                  puzzle: puzzle,
                  language: language,
                  enabled: !_busy,
                  removed: _removed,
                  onAnswer: _answer,
                ),
              ] else ...[
                if (turn.late)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.iqLate,
                      textAlign: TextAlign.center,
                      style: gameFont(size: 18, color: AppColors.white),
                    ),
                  ),
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
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CandyButton(
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
              ],
            ],
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
        iqEstimate([for (final t in _turns) (t.puzzle.level, t.correct)]);
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
