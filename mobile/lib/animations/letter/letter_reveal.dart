import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/widgets/letter_tile.dart';

/// Slot-machine reveal: random letters flick by, slow down, then the real
/// letter lands with a bounce.
class LetterReveal extends StatefulWidget {
  const LetterReveal({super.key, required this.letter, this.size = 120});

  final String letter;
  final double size;

  @override
  State<LetterReveal> createState() => _LetterRevealState();
}

class _LetterRevealState extends State<LetterReveal>
    with SingleTickerProviderStateMixin {
  static const _spinShare = 0.55;
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final _random = Random();
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
    _controller.forward();
  }

  void _onTick() {
    if (!_landed && _controller.value >= _spinShare) {
      _landed = true;
      final feedback = GameFeedbackScope.of(context);
      feedback.play(Sfx.reveal);
      feedback.haptic(Haptic.medium);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        if (t < _spinShare) {
          // Decelerating flicker: the letter changes less and less often.
          final step = pow(t / _spinShare, 0.5) * 14;
          final char =
              _alphabet[(step.floor() * 7 + _random.nextInt(3)) %
                  _alphabet.length];
          return Opacity(
            opacity: 0.7,
            child: LetterTile(letter: char, size: widget.size),
          );
        }
        final landing = Curves.elasticOut.transform(
          ((t - _spinShare) / (1 - _spinShare)).clamp(0, 1),
        );
        return Transform.scale(
          scale: 0.6 + 0.4 * landing,
          child: Transform.rotate(
            angle: (1 - landing) * 0.25,
            child: LetterTile(
              letter: widget.letter,
              size: widget.size,
              textKey: const Key('letter'),
            ),
          ),
        );
      },
    );
  }
}
