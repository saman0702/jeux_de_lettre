import 'package:flutter/material.dart';

import '../../animations/countdown/countdown_view.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../l10n/app_localizations.dart';
import 'data/models.dart';
import 'data/solo_game_api.dart';
import 'solo_game_controller.dart';
import 'solo_setup_screen.dart';
import 'widgets/game_over_view.dart';
import 'widgets/labels.dart';
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

  final SoloGameApi api;
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

  Future<bool> _confirmQuit() async {
    final l10n = AppLocalizations.of(context);
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          l10n.quitGameTitle,
          style: fredoka(size: 22, weight: FontWeight.w700),
        ),
        content: Text(l10n.quitGameMessage, style: fredoka(size: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.cancel,
              style: fredoka(size: 16, color: AppColors.inkSoft),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.quit,
              style: fredoka(
                size: 16,
                weight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
    return quit ?? false;
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

  Widget _buildPhase(BuildContext context) {
    final c = _controller;
    final l10n = AppLocalizations.of(context);

    switch (c.phase) {
      case SoloPhase.countdown:
        return CountdownView(value: c.countdown);
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
        );
      case SoloPhase.roundResult:
        return RoundResultView(
          result: c.lastResult!,
          totalRounds: c.game.totalRounds,
          totalScore: c.game.totalScore,
          isLastRound: c.game.isFinished,
          onContinue: c.nextRound,
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
