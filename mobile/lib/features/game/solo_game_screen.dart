import 'package:flutter/material.dart';

import '../../animations/countdown/countdown_view.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../l10n/app_localizations.dart';
import 'data/models.dart';
import 'data/solo_backend.dart';
import 'solo_game_controller.dart';
import 'solo_setup_screen.dart';
import 'widgets/game_over_view.dart';
import 'widgets/labels.dart';
import 'widgets/quit_button.dart';
import 'widgets/round_result_view.dart';
import 'widgets/round_view.dart';

class SoloGameScreen extends StatefulWidget {
  const SoloGameScreen({
    super.key,
    required this.api,
    required this.game,
    required this.apiClient,
    this.controller,
  });

  final SoloBackend api;
  final SoloGame game;
  final ApiClient apiClient;

  /// Injected in tests to control timings.
  final SoloGameController? controller;

  @override
  State<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<SoloGameScreen> {
  late final SoloGameController _controller =
      widget.controller ??
      SoloGameController(api: widget.api, game: widget.game);
  GameFeedback? _feedback;

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The menu music stops while playing so the countdown and ticks stand out.
    _feedback ??= GameFeedbackScope.of(context)..musicWanted = false;
  }

  @override
  void dispose() {
    _feedback?.musicWanted = true;
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
      emoji: '🚪',
      title: l10n.quitGameTitle,
      message: l10n.quitGameMessage,
      confirmLabel: l10n.quit.toUpperCase(),
      cancelLabel: l10n.dialogStay,
    );
  }

  void _playAgain() {
    Navigator.of(context).pushReplacement(
      PopRoute(builder: (_) => SoloSetupScreen(apiClient: widget.apiClient)),
    );
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
              focusLetter: _focusLetter,
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

  /// Playing and submitting share a key so the round screen is not rebuilt.
  String get _phaseKey => switch (_controller.phase) {
    SoloPhase.playing ||
    SoloPhase.submitting => 'round-${_controller.round?.number}',
    SoloPhase.roundResult => 'result-${_controller.lastResult?.number}',
    final phase => phase.name,
  };

  /// Each round has its own colours; the end of the game turns gold.
  BackgroundPalette get _palette {
    final c = _controller;
    if (c.phase == SoloPhase.finished) return BackgroundPalette.victory;
    final number = c.phase == SoloPhase.countdown
        ? (c.round?.number ?? 0) + 1
        : c.round?.number ?? 1;
    return BackgroundPalette.forRound(number);
  }

  String? get _focusLetter {
    final c = _controller;
    final playing =
        c.phase == SoloPhase.playing || c.phase == SoloPhase.submitting;
    return playing ? c.round?.letter : null;
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
        );
      case SoloPhase.roundResult:
        return WithQuitButton(
          onQuit: _quit,
          child: RoundResultView(
            result: c.lastResult!,
            totalRounds: c.game.totalRounds,
            totalScore: c.game.totalScore,
            isLastRound: c.game.isFinished,
            onContinue: c.nextRound,
          ),
        );
      case SoloPhase.finished:
        return GameOverView(
          totalScore: c.game.totalScore,
          maxScore: c.game.totalRounds * c.game.categories.length * 10,
          results: c.results,
          onPlayAgain: _playAgain,
          onHome: () => Navigator.of(context).pop(),
        );
      case SoloPhase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GameCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📡', style: TextStyle(fontSize: 56)),
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
