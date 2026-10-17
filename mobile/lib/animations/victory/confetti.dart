import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/shop/look_styles.dart';

/// Pluie de confettis / effets qui tombe par-dessus son enfant.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.child,
    this.pieces = 90,
    this.colors,
    this.shape = VictoryShape.confetti,
  });

  final Widget child;
  final int pieces;

  /// Teinte achetée. Vide : les couleurs habituelles.
  final List<Color>? colors;

  /// Forme des particules (étoiles, bulles, lettres…).
  final VictoryShape shape;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();
  late final List<_Piece> _pieces = _Piece.burst(
    widget.pieces,
    widget.colors,
    widget.shape,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(
                  _pieces,
                  _controller.value,
                  widget.shape,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Piece {
  _Piece(
    this.x,
    this.vx,
    this.vy,
    this.spin,
    this.size,
    this.color,
    this.round,
    this.letter,
  );

  final double x, vx, vy, spin, size;
  final Color color;
  final bool round;
  final String? letter;

  static const _colors = [
    AppColors.yellow,
    AppColors.pink,
    AppColors.cyan,
    AppColors.green,
    AppColors.orange,
    AppColors.white,
  ];

  static const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static List<_Piece> burst(int count, List<Color>? colors, VictoryShape shape) {
    final random = Random(3);
    final palette = colors ?? _colors;
    return List.generate(count, (_) {
      final letter = shape == VictoryShape.letters
          ? _letters[random.nextInt(_letters.length)]
          : null;
      return _Piece(
        0.3 + random.nextDouble() * 0.4,
        (random.nextDouble() - 0.5) * 1.4,
        -0.6 - random.nextDouble() * 0.9,
        (random.nextDouble() - 0.5) * 20,
        6 + random.nextDouble() * 8,
        palette[random.nextInt(palette.length)],
        shape == VictoryShape.bubbles ||
            (shape == VictoryShape.confetti && random.nextBool()),
        letter,
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.shape);

  final List<_Piece> pieces;
  final double t;
  final VictoryShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    const gravity = 1.6;
    final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
    for (final p in pieces) {
      final x = (p.x + p.vx * t) * size.width;
      final y = size.height * (0.35 + p.vy * t + gravity * t * t);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      switch (shape) {
        case VictoryShape.stars:
          _star(canvas, p.size * 0.7, paint);
        case VictoryShape.bubbles:
          canvas.drawCircle(Offset.zero, p.size * 0.55, paint);
          canvas.drawCircle(
            Offset(-p.size * 0.15, -p.size * 0.15),
            p.size * 0.15,
            Paint()..color = Colors.white.withValues(alpha: fade * 0.7),
          );
        case VictoryShape.letters:
          final builder = TextPainter(
            text: TextSpan(
              text: p.letter ?? 'A',
              style: TextStyle(
                color: p.color.withValues(alpha: fade),
                fontSize: p.size * 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          builder.paint(
            canvas,
            Offset(-builder.width / 2, -builder.height / 2),
          );
        case VictoryShape.confetti:
          if (p.round) {
            canvas.drawCircle(Offset.zero, p.size / 2, paint);
          } else {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: p.size,
                  height: p.size * 0.5,
                ),
                const Radius.circular(2),
              ),
              paint,
            );
          }
      }
      canvas.restore();
    }
  }

  void _star(Canvas canvas, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rad = i.isEven ? radius : radius * 0.42;
      final p = Offset(cos(a), sin(a)) * rad;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.shape != shape;
}
