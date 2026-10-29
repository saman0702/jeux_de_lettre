import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../animations/bounce_in.dart';
import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';
import 'letter_tile.dart';

/// Logo écrit en tuiles « MIND / RACE » (accueil + splash).
class LetterRaceLogo extends StatefulWidget {
  const LetterRaceLogo({super.key, this.animate = true, this.tileSize = 44});

  /// Sur le splash, on peut couper l'animation pour un affichage immédiat.
  final bool animate;
  final double tileSize;

  @override
  State<LetterRaceLogo> createState() => _LetterRaceLogoState();
}

class _LetterRaceLogoState extends State<LetterRaceLogo>
    with SingleTickerProviderStateMixin {
  static const _colors = [
    AppColors.yellow,
    AppColors.pink,
    AppColors.cyan,
    AppColors.green,
    AppColors.orange,
  ];

  static const _loop = 5.0;
  static const _tiles = 8;
  static const _start = 1.6;

  late final Ticker _ticker = createTicker(
    (elapsed) => _time.value = elapsed.inMilliseconds / 1000,
  );
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final want =
        widget.animate && GameFeedbackScope.of(context).ambientMotion;
    if (want && !_ticker.isActive) {
      _ticker.start();
    } else if (!want && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  static (double, double) _jump(int index, double local) {
    final p = (local - index * 0.075) / 0.45;
    if (p <= 0 || p >= 1.25) return (0, 1);
    if (p < 1) return (sin(p * pi), 1);
    return (0, 1 - 0.12 * sin((p - 1) / 0.25 * pi));
  }

  Widget _tile(String char, int index, double t) {
    final active = widget.animate && t > _start;
    final elapsed = active ? t - _start : 0.0;
    final loop = (elapsed / _loop).floor();
    final local = elapsed % _loop;

    final (lift, squash) = active ? _jump(index, local) : (0.0, 1.0);
    final sway = active ? sin(elapsed * 1.6 + index * 0.7) * 0.04 : 0.0;
    final flipping = active && (loop * 5) % _tiles == index;
    final flip = flipping
        ? Curves.easeInOutBack.transform(((local - 2.4) / 0.7).clamp(0.0, 1.0))
        : 0.0;
    final base = (index.isEven ? 1 : -1) * 0.06;

    return Transform.translate(
      offset: Offset(0, -lift * 14),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()..scaleByDouble(2 - squash, squash, 1, 1),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateZ(base + sway + lift * 0.08 * (index.isEven ? -1 : 1))
            ..rotateY(flip * 2 * pi),
          child: LetterTile(
            letter: char,
            size: widget.tileSize,
            color: _colors[index % _colors.length],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String word, int offset) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (j, char) in word.split('').indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: BounceIn(
              delay: Duration(milliseconds: widget.animate ? 60 * (offset + j) : 0),
              slideY: widget.animate ? -1.5 : 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _time,
                builder: (context, t, _) => _tile(char, offset + j, t),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      label: 'Mind Race',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row('MIND', 0),
          const SizedBox(height: 8),
          row('RACE', 4),
        ],
      ),
    );
  }
}
