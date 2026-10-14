import 'dart:math';

import 'package:flutter/material.dart';

import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';

/// Purple gradient with big translucent letters drifting slowly upwards.
class GameBackground extends StatefulWidget {
  const GameBackground({super.key, required this.child});

  final Widget child;

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );
  late final List<_FloatingLetter> _letters = _FloatingLetter.generate(14);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GameFeedbackScope.of(context).ambientMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _LettersPainter(_letters, _controller),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _FloatingLetter {
  _FloatingLetter(
    this.char,
    this.x,
    this.y,
    this.size,
    this.speed,
    this.spin,
    this.opacity,
  );

  final String char;
  final double x, y, size, speed, spin, opacity;

  static List<_FloatingLetter> generate(int count) {
    final random = Random(42);
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(
      count,
      (_) => _FloatingLetter(
        alphabet[random.nextInt(alphabet.length)],
        random.nextDouble(),
        random.nextDouble(),
        40 + random.nextDouble() * 70,
        0.5 + random.nextDouble(),
        (random.nextDouble() - 0.5) * 2,
        0.06 + random.nextDouble() * 0.08,
      ),
    );
  }
}

class _LettersPainter extends CustomPainter {
  _LettersPainter(this.letters, this.animation)
    : _painters = [
        for (final letter in letters)
          TextPainter(
            text: TextSpan(
              text: letter.char,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: letter.size,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
                color: Colors.white.withValues(alpha: letter.opacity),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
      ],
      super(repaint: animation);

  final List<_FloatingLetter> letters;
  final Animation<double> animation;
  final List<TextPainter> _painters;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    for (var i = 0; i < letters.length; i++) {
      final letter = letters[i];
      final painter = _painters[i];
      final y =
          ((letter.y - t * letter.speed) % 1.0) * (size.height + 120) - 60;
      final x =
          letter.x * size.width +
          sin((t * 2 * pi * letter.speed) + letter.x * 6) * 14;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(letter.spin * 0.4 + sin(t * 2 * pi) * 0.1 * letter.spin);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LettersPainter oldDelegate) => false;
}
