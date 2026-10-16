import 'dart:math';

import 'package:flutter/material.dart';

import '../../../animations/letter/letter_reveal.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../core/widgets/scroll_under_bars.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import '../hints/hint_controller.dart';
import 'answer_slot.dart';
import 'game_keyboard.dart';
import 'quit_button.dart';

class RoundView extends StatefulWidget {
  const RoundView({
    super.key,
    required this.round,
    required this.totalRounds,
    required this.remaining,
    required this.fields,
    required this.onFinish,
    this.submitting = false,
    this.hints,
    this.onQuit,
    this.goal,
  });

  /// Objectif affiché en haut (carrière, éliminatoires).
  final String? goal;

  final GameRound round;
  final int totalRounds;
  final Duration remaining;
  final Map<Category, TextEditingController> fields;
  final VoidCallback onFinish;
  final bool submitting;

  /// Jokers de cette manche ; pas de bouton joker quand null.
  final HintController? hints;

  /// Affiche un bouton pour quitter la partie.
  final VoidCallback? onQuit;

  @override
  State<RoundView> createState() => _RoundViewState();
}

class _RoundViewState extends State<RoundView> {
  final Map<Category, FocusNode> _focus = {};
  final Map<Category, GlobalKey> _slotKeys = {};

  List<Category> get _categories => widget.fields.keys.toList();

  FocusNode _node(Category category) => _focus.putIfAbsent(category, () {
    final node = FocusNode();
    node.addListener(() {
      // Garde le champ en cours de saisie visible au-dessus du clavier.
      final context = _slotKeys[category]?.currentContext;
      if (node.hasFocus && context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          alignment: 0.3,
        );
      }
    });
    return node;
  });

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  bool _editable(Category category) =>
      !widget.submitting && !(widget.hints?.field(category)?.locked ?? false);

  /// Le champ dans lequel tape le clavier du jeu (le premier libre par défaut).
  Category? _activeField() {
    for (final c in _categories) {
      if (_focus[c]?.hasFocus ?? false) return _editable(c) ? c : null;
    }
    for (final c in _categories) {
      if (_editable(c)) {
        _node(c).requestFocus();
        return c;
      }
    }
    return null;
  }

  void _type(String char) {
    final category = _activeField();
    if (category == null) return;
    final controller = widget.fields[category]!;
    final text = controller.text;
    if (char == ' ' && (text.isEmpty || text.endsWith(' '))) return;
    if (text.length >= answerMaxLength) return;
    controller.value = TextEditingValue(
      text: text + char,
      selection: TextSelection.collapsed(offset: text.length + 1),
    );
  }

  void _backspace() {
    final category = _activeField();
    if (category == null) return;
    final controller = widget.fields[category]!;
    final text = controller.text;
    if (text.isEmpty) return;
    final shorter = text.characters.skipLast(1).toString();
    controller.value = TextEditingValue(
      text: shorter,
      selection: TextSelection.collapsed(offset: shorter.length),
    );
  }

  void _next() {
    final categories = _categories;
    final current = categories.indexWhere((c) => _focus[c]?.hasFocus ?? false);
    for (var step = 1; step <= categories.length; step++) {
      final candidate = categories[(current + step) % categories.length];
      if (_editable(candidate)) {
        _node(candidate).requestFocus();
        return;
      }
    }
  }

  void _finish() {
    GameFeedbackScope.of(context).play(Sfx.finish);
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = GameFeedbackScope.of(context).settings;
    final round = widget.round;
    final categories = _categories;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final gameKeyboard = settings.gameKeyboard;
        final compact =
            gameKeyboard || MediaQuery.viewInsetsOf(context).bottom > 0;

        final topBar = Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              // Rétrécit sur les téléphones étroits plutôt que de déborder.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      if (widget.onQuit != null) ...[
                        QuitButton(onQuit: widget.onQuit!),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        // Pastille opaque : lisible quand les champs
                        // défilent dessous.
                        decoration: BoxDecoration(
                          color: AppColors.purpleDeep.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              l10n.roundLabel,
                              style: fredoka(
                                size: 10,
                                weight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              '${round.number}/${widget.totalRounds}',
                              style: fredoka(
                                size: 18,
                                weight: FontWeight.w700,
                                color: AppColors.white,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.goal != null) ...[
                        const SizedBox(width: 8),
                        _GoalChip(text: widget.goal!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (compact)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: LetterReveal(
                    key: ValueKey(round.number),
                    letter: round.letter,
                    size: 56,
                  ),
                ),
              TimerBadge(
                remaining: widget.remaining,
                total: Duration(seconds: round.duration),
              ),
            ],
          ),
        );
        // La grande lettre fait partie de la liste : elle défile avec les
        // champs, sous la barre du haut transparente.
        final offset = compact ? 0 : 1;

        return Column(
          children: [
            Expanded(
              child: ScrollUnderBars(
                header: topBar,
                builder: (context, padding) => ListView.separated(
                  padding: padding.copyWith(left: 20, right: 20),
                  itemCount: categories.length + offset,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i < offset) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Center(
                          child: LetterReveal(
                            key: ValueKey(round.number),
                            letter: round.letter,
                            size: 110,
                          ),
                        ),
                      );
                    }
                    final index = i - offset;
                    final category = categories[index];
                    return AnswerSlot(
                      key: _slotKeys.putIfAbsent(category, GlobalKey.new),
                      category: category,
                      controller: widget.fields[category]!,
                      letter: round.letter,
                      enabled: !widget.submitting,
                      autofocus: index == 0,
                      isLast: index == categories.length - 1,
                      onDone: widget.onFinish,
                      hints: widget.hints,
                      focusNode: _node(category),
                      systemKeyboard: !gameKeyboard,
                    );
                  },
                ),
              ),
            ),
            if (gameKeyboard)
              GameKeyboard(
                letter: round.letter,
                enabled: !widget.submitting,
                loading: widget.submitting,
                onKey: _type,
                onBackspace: _backspace,
                onNext: _next,
                onFinish: _finish,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: CandyButton(
                  label: l10n.finish,
                  icon: Icons.check_rounded,
                  color: AppColors.green,
                  textColor: AppColors.white,
                  loading: widget.submitting,
                  onPressed: _finish,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Chrono circulaire. Fait tic-tac, vibre et pulse pendant les 5 dernières
/// secondes.
class TimerBadge extends StatefulWidget {
  const TimerBadge({super.key, required this.remaining, required this.total});

  final Duration remaining;
  final Duration total;

  @override
  State<TimerBadge> createState() => _TimerBadgeState();
}

class _TimerBadgeState extends State<TimerBadge>
    with SingleTickerProviderStateMixin {
  static const _urgentSeconds = 5;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  int get _seconds => (widget.remaining.inMilliseconds / 1000).ceil();

  @override
  void didUpdateWidget(TimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = (oldWidget.remaining.inMilliseconds / 1000).ceil();
    if (_seconds != before && _seconds > 0 && _seconds <= _urgentSeconds) {
      final feedback = GameFeedbackScope.of(context);
      feedback.play(Sfx.tick);
      feedback.haptic(Haptic.light);
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction = widget.total.inMilliseconds == 0
        ? 0.0
        : (widget.remaining.inMilliseconds / widget.total.inMilliseconds).clamp(
            0.0,
            1.0,
          );
    final urgent = _seconds <= _urgentSeconds;
    final color = urgent
        ? AppColors.red
        : fraction < 0.5
        ? AppColors.orange
        : AppColors.green;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.18 * sin(_pulse.value * pi),
        child: child,
      ),
      child: SizedBox.square(
        dimension: 66,
        child: CustomPaint(
          painter: _RingPainter(fraction, color),
          child: Center(
            child: Text(
              '$_seconds',
              key: const Key('timer'),
              style: fredoka(
                size: 24,
                weight: FontWeight.w700,
                color: urgent ? AppColors.red : AppColors.ink,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius, Paint()..color = AppColors.white);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -pi / 2,
      2 * pi * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

/// Pastille jaune de l'objectif : « Minimum 20 pts », « Objectif 80 pts »…
class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('goal_chip'),
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(AppColors.yellow),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon(GameIconKind.flag, size: 18, color: AppColors.ink),
          const SizedBox(width: 4),
          Text(text, style: gameFont(size: 15, color: AppColors.ink)),
        ],
      ),
    );
  }
}
