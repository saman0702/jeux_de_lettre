import 'package:flutter/material.dart';

import '../../animations/countdown/countdown_view.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../l10n/app_localizations.dart';
import 'data/challenge.dart';
import 'data/models.dart';
import 'data/solo_backend.dart';
import 'solo_game_controller.dart';
import '../career/career_levels.dart';
import '../online/online_controller.dart';
import 'solo_launcher.dart';
import 'solo_setup_screen.dart';
import 'widgets/challenge_banner.dart';
import 'widgets/game_over_view.dart';
import 'widgets/labels.dart';
import 'widgets/quit_button.dart';
import 'widgets/round_result_view.dart';
import 'widgets/round_view.dart';
import '../../core/widgets/game_icon.dart';

class SoloGameScreen extends StatefulWidget {
  const SoloGameScreen({
    super.key,
    required this.api,
    required this.game,
    required this.apiClient,
    this.controller,
    this.challenge,
  });

  /// Carrière ou éliminatoires ; null pour une partie libre.
  final SoloChallenge? challenge;

  final SoloBackend api;
  final SoloGame game;
  final ApiClient apiClient;

  /// Injecté dans les tests pour maîtriser les délais.
  final SoloGameController? controller;

  @override
  State<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<SoloGameScreen> {
  late final SoloGameController _controller =
      widget.controller ??
      SoloGameController(
        api: widget.api,
        game: widget.game,
        challenge: widget.challenge,
      );
  GameFeedback? _feedback;

  /// Fin de partie déjà enregistrée (étoiles de carrière, record).
  bool _recorded = false;
  bool _newRecord = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncMusic);
    _controller.addListener(_recordEnd);
    _controller.start();
  }

  /// Une seule fois à la fin : garde les étoiles du niveau ou le record.
  void _recordEnd() {
    if (_recorded || _controller.phase != SoloPhase.finished) return;
    final settings = _feedback?.settings;
    if (settings == null) return;
    _recorded = true;
    switch (widget.challenge) {
      case final CareerLevel level:
        settings.recordCareer(
          level.number,
          level.starsFor(_controller.game.totalScore),
        );
        settings.recordCareerLetters(level.number, [
          for (final result in _controller.results) result.letter,
        ]);
        final used = <Category, List<String>>{};
        for (final result in _controller.results) {
          for (final answer in result.answers) {
            if (answer.status != AnswerStatus.valid) continue;
            final word = answer.matchedValue ?? answer.value;
            if (word.trim().isEmpty) continue;
            used.putIfAbsent(answer.category, () => []).add(word);
          }
        }
        settings.recordCareerAnswers(level.world, used);
      case EliminationChallenge():
        _newRecord = settings.recordElimination(_controller.roundsSurvived);
      case null:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_feedback == null) {
      _feedback = GameFeedbackScope.of(context);
      _syncMusic();
    }
  }

  /// Musique du solo, plus basse pendant le décompte et la manche pour que le
  /// tic-tac ressorte.
  void _syncMusic() {
    final phase = _controller.phase;
    _feedback?.setMusic(
      MusicMood.solo,
      quiet: phase == SoloPhase.countdown || phase == SoloPhase.playing,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_syncMusic);
    _controller.removeListener(_recordEnd);
    _feedback?.setMusic(MusicMood.menu);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _quit() async {
    final navigator = Navigator.of(context);
    if (await _confirmQuit()) navigator.pop();
  }

  Future<bool> _confirmQuit() {
    final l10n = AppLocalizations.of(context);
    return showGameConfirm(
      context,
      icon: GameIconKind.door,
      title: l10n.quitGameTitle,
      message: l10n.quitGameMessage,
      confirmLabel: l10n.quit.toUpperCase(),
      cancelLabel: l10n.dialogStay,
    );
  }

  void _playAgain() {
    final challenge = widget.challenge;
    if (challenge == null) {
      Navigator.of(context).pushReplacement(
        PopRoute(builder: (_) => SoloSetupScreen(apiClient: widget.apiClient)),
      );
      return;
    }
    _launch(challenge);
  }

  /// Relance un défi (même niveau, niveau suivant, ou éliminatoires).
  void _launch(SoloChallenge challenge) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final nickname = _feedback?.settings.nickname ?? l10n.defaultNickname;
    final id = OnlineScope.of(context).clientId;
    final settings = switch (challenge) {
      final CareerLevel level => level.settings(language, nickname, id),
      final EliminationChallenge elimination => elimination.settings(
        language,
        nickname,
        id,
      ),
    };
    launchSoloGame(
      context,
      apiClient: widget.apiClient,
      settings: settings,
      challenge: challenge,
    );
  }

  /// Objectif affiché pendant la manche.
  String? _goal(AppLocalizations l10n) {
    final round = _controller.round;
    return switch (widget.challenge) {
      final CareerLevel level => l10n.goalProgress(
        _controller.game.totalScore,
        level.target,
      ),
      EliminationChallenge() when round != null => l10n.goalMinimum(
        widget.challenge!.requiredPoints(round.number)!,
      ),
      _ => null,
    };
  }

  /// Bandeau sous l'en-tête des résultats de manche.
  Widget? _resultGoal(AppLocalizations l10n) {
    final result = _controller.lastResult;
    if (result == null) return null;
    switch (widget.challenge) {
      case final CareerLevel level:
        final total = _controller.game.totalScore;
        return ChallengeBanner(
          text: l10n.careerProgressBanner(total, level.target),
          success: total >= level.target ? true : null,
        );
      case final EliminationChallenge elimination:
        final required = elimination.requiredPoints(result.number);
        return _controller.eliminatedAt == null
            ? ChallengeBanner(
                text: l10n.challengePassed(required),
                success: true,
              )
            : ChallengeBanner(
                text: l10n.challengeEliminated(required),
                success: false,
              );
      case null:
        return null;
    }
  }

  Widget _gameOver(BuildContext context, AppLocalizations l10n) {
    final c = _controller;
    void home() => Navigator.of(context).pop();
    switch (widget.challenge) {
      case final CareerLevel level:
        final total = c.game.totalScore;
        final stars = level.starsFor(total);
        final next = level.number < careerLevels.length
            ? careerLevels[level.number]
            : null;
        return GameOverView(
          totalScore: total,
          maxScore: level.maxScore,
          results: c.results,
          stars: stars,
          title: stars > 0
              ? l10n.careerWon(level.number)
              : l10n.careerLost(level.number),
          message: l10n.careerMessage(level.target, total),
          banner: ChallengeBanner(
            text: l10n.careerStarsInfo(
              level.target,
              level.twoStars,
              level.threeStars,
            ),
          ),
          onNext: stars > 0 && next != null ? () => _launch(next) : null,
          nextLabel: l10n.nextLevel,
          playAgainLabel: l10n.replayLevel,
          homeLabel: l10n.levelsMap,
          onPlayAgain: _playAgain,
          onHome: home,
        );
      case EliminationChallenge():
        final survived = c.roundsSurvived;
        final champion = c.eliminatedAt == null;
        final best = _feedback?.settings.eliminationBest ?? survived;
        return GameOverView(
          totalScore: c.game.totalScore,
          maxScore: c.game.totalRounds * c.game.categories.length * 10,
          results: c.results,
          stars: champion
              ? 3
              : survived >= 8
              ? 2
              : survived >= 4
              ? 1
              : 0,
          title: champion ? l10n.eliminationChampion : l10n.eliminationOut,
          message: l10n.eliminationMessage(survived, c.game.totalRounds),
          banner: ChallengeBanner(
            text: _newRecord
                ? l10n.eliminationNewRecord(survived)
                : l10n.eliminationRecord(best),
            success: _newRecord ? true : null,
          ),
          onPlayAgain: _playAgain,
          onHome: home,
        );
      case null:
        return GameOverView(
          totalScore: c.game.totalScore,
          maxScore: c.game.totalRounds * c.game.categories.length * 10,
          results: c.results,
          onPlayAgain: _playAgain,
          onHome: home,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final finished = _controller.phase == SoloPhase.finished;
        return PopScope(
          canPop: finished,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await _confirmQuit()) navigator.pop();
          },
          child: Scaffold(
            body: GameBackground(
              palette: _palette,
              child: SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.94, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_phaseKey),
                    child: _buildPhase(context),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Jeu et envoi partagent une clé pour que l'écran de manche ne soit pas
  /// reconstruit.
  String get _phaseKey => switch (_controller.phase) {
    SoloPhase.playing ||
    SoloPhase.submitting => 'round-${_controller.round?.number}',
    SoloPhase.roundResult => 'result-${_controller.lastResult?.number}',
    final phase => phase.name,
  };

  /// Chaque manche a ses couleurs ; la fin de partie passe au doré.
  BackgroundPalette get _palette {
    final c = _controller;
    if (c.phase == SoloPhase.finished) return BackgroundPalette.victory;
    final number = c.phase == SoloPhase.countdown
        ? (c.round?.number ?? 0) + 1
        : c.round?.number ?? 1;
    return BackgroundPalette.forRound(number);
  }

  Widget _buildPhase(BuildContext context) {
    final c = _controller;
    final l10n = AppLocalizations.of(context);

    switch (c.phase) {
      case SoloPhase.countdown:
        return WithQuitButton(
          onQuit: _quit,
          child: CountdownView(value: c.countdown),
        );
      case SoloPhase.playing:
      case SoloPhase.submitting:
        if (c.round == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.white),
          );
        }
        return RoundView(
          round: c.round!,
          totalRounds: c.game.totalRounds,
          remaining: c.remaining,
          fields: c.fields,
          submitting: c.phase == SoloPhase.submitting,
          onFinish: c.submit,
          hints: c.hints,
          onQuit: _quit,
          goal: _goal(l10n),
        );
      case SoloPhase.roundResult:
        return RoundResultView(
          result: c.lastResult!,
          totalRounds: c.game.totalRounds,
          totalScore: c.game.totalScore,
          isLastRound: c.isOver,
          onContinue: c.nextRound,
          onQuit: _quit,
          goal: _resultGoal(l10n),
          onBuyInfo: widget.api.offline
              ? null
              : (category) => widget.api.buyCategoryInfo(
                  c.game.id,
                  c.lastResult!.number,
                  category,
                ),
        );
      case SoloPhase.finished:
        return _gameOver(context, l10n);
      case SoloPhase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GameCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIconBadge(
                    GameIconKind.offline,
                    color: AppColors.red,
                    size: 72,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    errorMessage(l10n, c.errorCode),
                    textAlign: TextAlign.center,
                    style: fredoka(size: 18, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  CandyButton(
                    label: l10n.retry,
                    icon: Icons.refresh_rounded,
                    onPressed: c.retry,
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
