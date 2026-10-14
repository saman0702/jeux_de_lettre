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
import 'labels.dart';

class RoundView extends StatelessWidget {
  const RoundView({
    super.key,
    required this.round,
    required this.totalRounds,
    required this.remaining,
    required this.fields,
    required this.onFinish,
    this.submitting = false,
  });

  final GameRound round;
  final int totalRounds;
  final Duration remaining;
  final Map<Category, TextEditingController> fields;
  final VoidCallback onFinish;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final categories = fields.keys.toList();

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
                  l10n.roundProgress(round.number, totalRounds),
                  style: fredoka(
                    size: 16,
                    weight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
              const Spacer(),
              TimerBadge(
                remaining: remaining,
                total: Duration(seconds: round.duration),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: keyboardOpen ? 4 : 12),
            child: LetterReveal(
              key: ValueKey(round.number),
              letter: round.letter,
              size: keyboardOpen ? 64 : 110,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _AnswerField(
              category: categories[index],
              controller: fields[categories[index]]!,
              letter: round.letter,
              enabled: !submitting,
              autofocus: index == 0,
              isLast: index == categories.length - 1,
              onDone: onFinish,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: CandyButton(
            label: l10n.finish,
            icon: Icons.check_rounded,
            color: AppColors.green,
            textColor: AppColors.white,
            loading: submitting,
            onPressed: onFinish,
          ),
        ),
      ],
    );
  }
}

class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.category,
    required this.controller,
    required this.letter,
    required this.enabled,
    required this.autofocus,
    required this.isLast,
    required this.onDone,
  });

  final Category category;
  final TextEditingController controller;
  final String letter;
  final bool enabled;
  final bool autofocus;
  final bool isLast;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final matches = firstLetterOf(value.text) == letter;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: matches ? AppColors.green : AppColors.white,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x40250E6B), offset: Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label(l10n),
                        style: fredoka(
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      TextField(
                        key: Key('field_${category.name}'),
                        controller: controller,
                        enabled: enabled,
                        autofocus: autofocus,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: isLast
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onSubmitted: isLast ? (_) => onDone() : null,
                        style: fredoka(size: 20, weight: FontWeight.w600),
                        cursorColor: AppColors.purple,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          hintText: '$letter…',
                          hintStyle: fredoka(size: 20, color: AppColors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedScale(
                scale: matches ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.green,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
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
