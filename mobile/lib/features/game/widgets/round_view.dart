import 'dart:math';

import 'package:flutter/material.dart';

import '../../../animations/letter/letter_reveal.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import '../hints/hint_controller.dart';
import 'answer_slot.dart';
import 'game_keyboard.dart';

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
  });

  final GameRound round;
  final int totalRounds;
  final Duration remaining;
  final Map<Category, TextEditingController> fields;
  final VoidCallback onFinish;
  final bool submitting;

  /// Jokers for this round; no hint buttons when null.
  final HintController? hints;

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
      // Keep the field being typed in visible above the keyboard.
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

  /// The field the game keyboard types into (the first free one by default).
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

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      l10n.roundProgress(round.number, widget.totalRounds),
                      style: fredoka(
                        size: 16,
                        weight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
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
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: LetterReveal(
                  key: ValueKey(round.number),
                  letter: round.letter,
                  size: 110,
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
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

/// Circular countdown. Ticks, vibrates and pulses during the last 5 seconds.
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
