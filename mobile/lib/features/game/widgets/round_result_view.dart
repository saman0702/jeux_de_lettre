import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/voice/announcements.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_card.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/scroll_under_bars.dart';
import '../../../core/widgets/letter_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import 'labels.dart';
import '../../../core/widgets/game_icon.dart';

/// Les réponses sont dévoilées une à une (ding si juste, buzz si faux), puis le
/// score de la manche défile.
class RoundResultView extends StatefulWidget {
  const RoundResultView({
    super.key,
    required this.result,
    required this.totalRounds,
    required this.totalScore,
    required this.isLastRound,
    required this.onContinue,
    this.goal,
    this.continueLabel,
  });

  /// Bandeau de défi sous l'en-tête (minimum atteint, éliminé…).
  final Widget? goal;
  final String? continueLabel;

  final RoundResult result;
  final int totalRounds;
  final int totalScore;
  final bool isLastRound;
  final VoidCallback onContinue;

  @override
  State<RoundResultView> createState() => _RoundResultViewState();
}

class _RoundResultViewState extends State<RoundResultView>
    with SingleTickerProviderStateMixin {
  static const _firstMs = 300;
  static const _stepMs = 420;
  static const _cardMs = 450;
  static const _countMs = 800;

  late final int _scoreAtMs = _firstMs + widget.result.answers.length * _stepMs;
  late final int _totalMs = _scoreAtMs + _countMs;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs),
  );
  int _revealed = 0;
  bool _scoreAnnounced = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
    _controller.forward();
  }

  double _at(int ms) => ms / _totalMs;

  void _onTick() {
    final feedback = GameFeedbackScope.of(context);
    final answers = widget.result.answers;
    while (_revealed < answers.length &&
        _controller.value >= _at(_firstMs + _revealed * _stepMs)) {
      final valid = answers[_revealed].status == AnswerStatus.valid;
      feedback.play(valid ? Sfx.valid : Sfx.invalid);
      feedback.haptic(valid ? Haptic.light : Haptic.medium);
      _revealed++;
    }
    if (!_scoreAnnounced && _controller.value >= _at(_scoreAtMs)) {
      _scoreAnnounced = true;
      if (widget.result.roundScore > 0) feedback.play(Sfx.points);
      feedback.announce(
        Announcements(AppLocalizations.of(context)).soloRound(
          widget.result.roundScore,
          widget.result.answers.length * 10,
        ),
        Localizations.localeOf(context).languageCode,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progress(
    int startMs,
    int durationMs, [
    Curve curve = Curves.easeOutBack,
  ]) {
    final t = ((_controller.value - _at(startMs)) / _at(durationMs)).clamp(
      0.0,
      1.0,
    );
    return curve.transform(t);
  }

  /// En solo : une réponse possible pour chaque catégorie ratée.
  String? _correction(AppLocalizations l10n, AnswerResult answer) {
    final suggestion = answer.suggestion;
    if (answer.status == AnswerStatus.valid || suggestion == null) return null;
    return l10n.suggestionExample(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = widget.result;
    final seconds = (result.elapsed.inMilliseconds / 1000).toStringAsFixed(1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scoreProgress = _progress(
          _scoreAtMs,
          _countMs,
          Curves.easeOutCubic,
        );
        final shownScore = (result.roundScore * scoreProgress).round();
        final shownTotal = widget.totalScore - result.roundScore + shownScore;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // Les réponses défilent sous l'en-tête et le score, sans bord visible.
          child: ScrollUnderBars(
            header: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      LetterTile(letter: result.letter, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedText(
                              l10n.roundProgress(
                                result.number,
                                widget.totalRounds,
                              ),
                              style: fredoka(
                                size: 20,
                                weight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                            Row(
                              children: [
                                const GameIcon(GameIconKind.timer, size: 18),
                                const SizedBox(width: 4),
                                OutlinedText(
                                  l10n.finishedIn(seconds),
                                  strokeWidth: 3,
                                  style: fredoka(
                                    size: 15,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.goal != null) ...[
                    const SizedBox(height: 8),
                    widget.goal!,
                  ],
                ],
              ),
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GameCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.roundScore.toUpperCase(),
                              style: gameFont(
                                size: 12,
                                color: AppColors.inkSoft,
                                letterSpacing: 1,
                              ),
                            ),
                            Transform.scale(
                              alignment: Alignment.centerLeft,
                              scale:
                                  1 +
                                  0.25 *
                                      (1 - scoreProgress) *
                                      (scoreProgress > 0 ? 1 : 0),
                              child: Text(
                                l10n.roundPoints(shownScore),
                                style: fredoka(
                                  size: 34,
                                  weight: FontWeight.w700,
                                  color: AppColors.purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              l10n.totalScore.toUpperCase(),
                              style: gameFont(
                                size: 12,
                                color: AppColors.inkSoft,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              l10n.pointsShort(shownTotal),
                              style: fredoka(size: 22, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CandyButton(
                    label:
                        widget.continueLabel ??
                        (widget.isLastRound ? l10n.seeResults : l10n.nextRound),
                    icon: widget.isLastRound
                        ? Icons.emoji_events_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: widget.onContinue,
                  ),
                ],
              ),
            ),
            builder: (context, padding) => ListView.separated(
              padding: padding,
              itemCount: result.answers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = _progress(_firstMs + i * _stepMs, _cardMs);
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(60 * (1 - t), 0),
                    child: AnswerCard(
                      answer: result.answers[i],
                      popScale: t,
                      correction: _correction(l10n, result.answers[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.answer,
    this.popScale = 1,
    this.correction,
  });

  final AnswerResult answer;
  final double popScale;

  /// Bonne réponse à montrer sous une réponse ratée
  /// (« Réponse possible : Madrid », « Flore a trouvé : Madrid »).
  final String? correction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valid = answer.status == AnswerStatus.valid;
    final color = answer.status.color;
    final shown =
        answer.matchedValue ?? (answer.value.isEmpty ? '—' : answer.value);

    return GameCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: GameIcon(
              answer.category.icon,
              size: 26,
              color: answer.category.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  answer.category.label(l10n).toUpperCase(),
                  style: gameFont(
                    size: 12,
                    color: answer.category.color,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: fredoka(size: 19, weight: FontWeight.w700),
                ),
                Row(
                  children: [
                    Icon(answer.status.icon, size: 15, color: color),
                    const SizedBox(width: 4),
                    Text(
                      answer.status.label(l10n),
                      style: fredoka(
                        size: 13,
                        weight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (answer.hinted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const GameIcon(
                              GameIconKind.hint,
                              size: 14,
                              color: Color(0xFFB08900),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              l10n.hintedBadge,
                              style: fredoka(size: 12, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (correction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      key: const Key('answer_correction'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const GameIcon(
                            GameIconKind.check,
                            size: 14,
                            color: Color(0xFF1E9E55),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              correction!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: fredoka(
                                size: 13,
                                weight: FontWeight.w600,
                                color: const Color(0xFF1E7A45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Transform.scale(
            scale: popScale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: valid ? AppColors.green : AppColors.cloud,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '+${answer.points}',
                style: fredoka(
                  size: 18,
                  weight: FontWeight.w700,
                  color: valid ? AppColors.white : AppColors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
