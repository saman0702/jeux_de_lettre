import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../animations/score/count_up_text.dart';
import '../../../animations/victory/confetti.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_card.dart';
import '../../../core/widgets/letter_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';

class GameOverView extends StatefulWidget {
  const GameOverView({
    super.key,
    required this.totalScore,
    required this.maxScore,
    required this.results,
    required this.onPlayAgain,
    required this.onHome,
  });

  final int totalScore;
  final int maxScore;
  final List<RoundResult> results;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  State<GameOverView> createState() => _GameOverViewState();
}

class _GameOverViewState extends State<GameOverView> {
  int get _stars {
    if (widget.maxScore == 0 || widget.totalScore == 0) return 0;
    final ratio = widget.totalScore / widget.maxScore;
    return ratio >= 0.6 ? 3 : (ratio >= 0.35 ? 2 : 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final feedback = GameFeedbackScope.of(context);
      feedback.play(Sfx.victory);
      feedback.haptic(Haptic.heavy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (_stars) {
      3 => l10n.gameOverGreat,
      2 => l10n.gameOverGood,
      _ => l10n.gameOverTry,
    };

    return ConfettiOverlay(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BounceIn(
              from: 0,
              child: Text(
                '🏆',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 80),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  BounceIn(
                    delay: Duration(milliseconds: 400 + i * 180),
                    from: 0,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 4,
                        right: 4,
                        bottom: i == 1 ? 14 : 0,
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        size: i == 1 ? 58 : 46,
                        color: i < _stars
                            ? AppColors.yellow
                            : AppColors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              l10n.gameOver,
              textAlign: TextAlign.center,
              style: fredoka(
                size: 26,
                weight: FontWeight.w700,
                color: AppColors.white,
                shadows: textShadow,
              ),
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: fredoka(
                size: 18,
                color: AppColors.white.withValues(alpha: 0.9),
              ),
            ),
            CountUpText(
              value: widget.totalScore,
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 1200),
              format: l10n.pointsShort,
              textKey: const Key('total_score'),
              textAlign: TextAlign.center,
              style: fredoka(
                size: 56,
                weight: FontWeight.w700,
                color: AppColors.yellow,
                shadows: textShadow,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: GameCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (i, r) in widget.results.indexed)
                        BounceIn(
                          delay: Duration(milliseconds: 600 + i * 90),
                          from: 0.7,
                          child: ListTile(
                            leading: LetterTile(letter: r.letter, size: 36),
                            title: Text(
                              l10n.roundProgress(
                                r.number,
                                widget.results.length,
                              ),
                              style: fredoka(size: 16, weight: FontWeight.w600),
                            ),
                            trailing: Text(
                              l10n.pointsShort(r.roundScore),
                              style: fredoka(
                                size: 18,
                                weight: FontWeight.w700,
                                color: AppColors.purple,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            CandyButton(
              label: l10n.playAgain,
              icon: Icons.replay_rounded,
              onPressed: widget.onPlayAgain,
            ),
            const SizedBox(height: 10),
            CandyButton(
              label: l10n.backHome,
              icon: Icons.home_rounded,
              color: AppColors.white,
              height: 54,
              fontSize: 19,
              onPressed: widget.onHome,
            ),
          ],
        ),
      ),
    );
  }
}
