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
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/round_view.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import 'iq_models.dart';
import 'iq_solo_source.dart';
import 'iq_widgets.dart';

/// Partie de QI en solo, jouée sur le téléphone : pas de pièces ni de niveau,
/// juste un score et un QI estimé pour s'amuser.
class IqSoloScreen extends StatefulWidget {
  const IqSoloScreen({
    super.key,
    required this.rounds,
    required this.duration,
    required this.difficulty,
    required this.scoring,
    this.apiClient,
    this.puzzles,
    this.now = DateTime.now,
  });

  final int rounds;

  /// Secondes par énigme.
  final int duration;
  final Difficulty difficulty;
  final IqScoring scoring;
  final ApiClient? apiClient;

  /// Énigmes déjà choisies (tests) ; sinon serveur, puis fichier embarqué.
  final List<IqPuzzle>? puzzles;
  final DateTime Function() now;

  @override
  State<IqSoloScreen> createState() => _IqSoloScreenState();
}

class _Answer {
  const _Answer(this.puzzle, this.answer, this.correct, this.points);

  final IqPuzzle puzzle;
  final String? answer;
  final bool correct;
  final int points;
}

class _IqSoloScreenState extends State<IqSoloScreen> {
  List<IqPuzzle>? _puzzles;
  int _index = 0;
  DateTime _startedAt = DateTime.now();
  _Answer? _current;
  final _answers = <_Answer>[];
  Timer? _ticker;
  bool _done = false;

  Duration get _total => Duration(seconds: widget.duration);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameFeedbackScope.of(context).setMusic(MusicMood.solo);
    });
    _load();
  }

  Future<void> _load() async {
    final given = widget.puzzles;
    if (given != null) {
      _begin(given);
      return;
    }
    final online = context
        .getInheritedWidgetOfExactType<OnlineScope>()
        ?.controller;
    final api = online != null && online.client.unreachable
        ? null
        : (widget.apiClient ?? ApiClient());
    final puzzles = await loadSoloPuzzles(
      count: widget.rounds,
      difficulty: widget.difficulty,
      api: api,
    );
    if (mounted) _begin(puzzles);
  }

  void _begin(List<IqPuzzle> puzzles) {
    setState(() {
      _puzzles = puzzles;
      _startedAt = widget.now();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _current != null || _done || _puzzles == null) return;
    if (widget.now().difference(_startedAt) >= _total) {
      _answer(null);
    } else {
      setState(() {});
    }
  }

  void _answer(String? raw) {
    final puzzles = _puzzles;
    if (puzzles == null || _current != null) return;
    final puzzle = puzzles[_index];
    final correct = puzzle.isCorrect(raw);
    final answered = raw != null && raw.trim().isNotEmpty;
    final points = widget.scoring.points(
      correct: correct,
      answered: answered,
      elapsed: widget.now().difference(_startedAt),
      duration: _total,
    );
    GameFeedbackScope.of(context).play(correct ? Sfx.valid : Sfx.invalid);
    setState(() {
      _current = _Answer(puzzle, answered ? raw.trim() : null, correct, points);
      _answers.add(_current!);
    });
  }

  void _next() {
    final puzzles = _puzzles!;
    setState(() {
      _current = null;
      if (_index + 1 >= puzzles.length) {
        _done = true;
        _ticker?.cancel();
        GameFeedbackScope.of(context).play(Sfx.victory);
      } else {
        _index++;
        _startedAt = widget.now();
      }
    });
  }

  void _restart() {
    _ticker?.cancel();
    setState(() {
      _puzzles = null;
      _index = 0;
      _current = null;
      _answers.clear();
      _done = false;
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
        child: SafeArea(
          child: Column(
            children: [
              OnlineHeader(
                title: l10n.iqSoloTitle,
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
    final puzzles = _puzzles;
    if (puzzles == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      );
    }
    if (_done || puzzles.isEmpty) return _result(l10n);
    final language = Localizations.localeOf(context).languageCode;
    final puzzle = puzzles[_index];
    final current = _current;
    final elapsed = widget.now().difference(_startedAt);
    final remaining = _total - elapsed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        IqHeader(
          number: _index + 1,
          total: puzzles.length,
          trailing: current == null
              ? TimerBadge(
                  remaining: remaining.isNegative ? Duration.zero : remaining,
                  total: _total,
                )
              : null,
        ),
        const SizedBox(height: 10),
        IqPuzzleCard(
          key: ValueKey(puzzle.id),
          puzzle: puzzle,
          language: language,
        ),
        const SizedBox(height: 14),
        if (current == null)
          IqAnswerPad(
            key: ValueKey('pad_${puzzle.id}'),
            puzzle: puzzle,
            language: language,
            onAnswer: _answer,
          )
        else ...[
          IqRevealCard(
            puzzle: puzzle,
            language: language,
            players: [
              IqPlayerResult(
                name: l10n.iqYou,
                answer: current.answer,
                correct: current.correct,
                points: current.points,
                isMe: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          CandyButton(
            key: const Key('iq_next'),
            label: _index + 1 >= puzzles.length
                ? l10n.iqSeeResult
                : l10n.iqNext,
            icon: Icons.arrow_forward_rounded,
            color: AppColors.green,
            textColor: AppColors.white,
            onPressed: _next,
          ),
        ],
      ],
    );
  }

  Widget _result(AppLocalizations l10n) {
    final correct = _answers.where((a) => a.correct).length;
    final points = _answers.fold(0, (s, a) => s + a.points);
    final iq = iqEstimate([
      for (final a in _answers) (a.puzzle.level, a.correct),
    ]);
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
                  l10n.iqResultScore(correct, _answers.length, points),
                  key: const Key('iq_score'),
                  textAlign: TextAlign.center,
                  style: fredoka(size: 16, color: AppColors.ink),
                ),
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
