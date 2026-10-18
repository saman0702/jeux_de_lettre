import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/voice/announcements.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_card.dart';
import '../../../core/widgets/game_dialog.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/scroll_under_bars.dart';
import '../../../core/widgets/letter_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import 'country_flag.dart';
import 'labels.dart';
import 'quit_button.dart';

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
    this.onBuyInfo,
    this.onQuit,
  });

  /// Bandeau de défi sous l'en-tête (minimum atteint, éliminé…).
  final Widget? goal;
  final String? continueLabel;

  final RoundResult result;
  final int totalRounds;
  final int totalScore;
  final bool isLastRound;
  final VoidCallback onContinue;

  /// Achète les infos d'une catégorie (null hors ligne).
  final Future<CategoryInfo?> Function(Category category)? onBuyInfo;

  /// Si fourni : Quitter, manche et score sur la même ligne en haut.
  final VoidCallback? onQuit;

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
  final Map<Category, List<String>> _infoLines = {};
  bool _infoBusy = false;

  @override
  void initState() {
    super.initState();
    for (final answer in widget.result.answers) {
      final lines = answer.infoLines;
      if (lines != null && lines.isNotEmpty) {
        _infoLines[answer.category] = lines;
      }
    }
    _controller.addListener(_onTick);
    _controller.forward();
  }

  Future<void> _unlockInfo(AnswerResult answer) async {
    final buy = widget.onBuyInfo;
    final category = answer.category;
    if (buy == null || _infoBusy || _infoLines.containsKey(category)) return;
    final price = answer.infoPrice;
    final l10n = AppLocalizations.of(context);
    if (price > 0) {
      final ok = await showGameConfirm(
        context,
        icon: GameIconKind.eyes,
        title: l10n.buyInfoTitle,
        message: l10n.buyInfoMessage(price),
        confirmLabel: l10n.buyInfoConfirm(price),
        cancelLabel: l10n.cancel,
        accent: AppColors.cyan,
      );
      if (!ok || !mounted) return;
    }
    _infoBusy = true;
    try {
      final info = await buy(category);
      if (info != null && mounted) {
        setState(() => _infoLines[category] = info.lines);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hintErrorMessage(l10n, e.code))),
        );
      }
    } finally {
      _infoBusy = false;
    }
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

        final topBar = widget.onQuit == null
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                child: Row(
                  children: [
                    QuitButton(onQuit: widget.onQuit!),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedText(
                        l10n.roundProgress(result.number, widget.totalRounds),
                        textAlign: TextAlign.center,
                        style: fredoka(
                          size: 16,
                          weight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedText(
                      l10n.pointsShort(shownTotal),
                      style: fredoka(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // Les réponses défilent sous l'en-tête et le score, sans bord visible.
          child: ScrollUnderBars(
            header: Padding(
              padding: EdgeInsets.only(
                top: topBar == null ? 16 : 8,
                bottom: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?topBar,
                  Row(
                    children: [
                      LetterTile(letter: result.letter, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            const GameIcon(GameIconKind.timer, size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: OutlinedText(
                                l10n.finishedIn(seconds),
                                strokeWidth: 3,
                                style: fredoka(
                                  size: 15,
                                  color: AppColors.white,
                                ),
                              ),
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
              child: CandyButton(
                label:
                    widget.continueLabel ??
                    (widget.isLastRound ? l10n.seeResults : l10n.nextRound),
                icon: widget.isLastRound
                    ? Icons.emoji_events_rounded
                    : Icons.arrow_forward_rounded,
                badge: l10n.roundPoints(shownScore),
                onPressed: widget.onContinue,
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
                      infoLines: _infoLines[result.answers[i].category],
                      onBuyInfo:
                          widget.onBuyInfo != null &&
                              result.answers[i].infoAvailable &&
                              !_infoLines.containsKey(
                                result.answers[i].category,
                              )
                          ? () => _unlockInfo(result.answers[i])
                          : null,
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
    this.infoLines,
    this.onBuyInfo,
  });

  final AnswerResult answer;
  final double popScale;

  /// Bonne réponse à montrer sous une réponse ratée
  /// (« Réponse possible : Madrid », « Flore a trouvé : Madrid »).
  final String? correction;

  /// Infos déjà débloquées (après achat).
  final List<String>? infoLines;

  /// Bouton pour acheter les infos (null si indisponible / déjà acheté).
  final VoidCallback? onBuyInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valid = answer.status == AnswerStatus.valid;
    final color = answer.status.color;
    final shown =
        answer.matchedValue ?? (answer.value.isEmpty ? '—' : answer.value);
    final flag = answer.category == Category.country
        ? flagSpecFor(shown == '—' ? answer.value : shown)
        : null;

    return GameCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          flag != null
              ? CountryFlag(spec: flag, width: 46)
              : Container(
                  width: 48,
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
                if (infoLines != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      key: Key('answer_info_${answer.category.name}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (flag != null) ...[
                          CountryFlag(spec: flag, width: 56),
                          const SizedBox(height: 6),
                        ],
                        for (final line in infoLines!)
                          Text(
                            line,
                            style: fredoka(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                  )
                else if (onBuyInfo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: answer.infoPrice > 0 ? 176 : 120,
                        child: CandyButton(
                          key: Key('buy_info_${answer.category.name}'),
                          label: answer.infoPrice > 0
                              ? AppLocalizations.of(
                                  context,
                                ).buyInfoButton(answer.infoPrice)
                              : AppLocalizations.of(context).buyInfoFree,
                          gameIcon: GameIconKind.eyes,
                          color: AppColors.cyan,
                          textColor: AppColors.ink,
                          onPressed: onBuyInfo,
                        ),
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
