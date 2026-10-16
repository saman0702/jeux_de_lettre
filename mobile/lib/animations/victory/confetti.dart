import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Pluie de confettis unique qui tombe par-dessus son enfant.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.child, this.pieces = 90});

  final Widget child;
  final int pieces;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();
  late final List<_Piece> _pieces = _Piece.burst(widget.pieces);

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
                painter: _ConfettiPainter(_pieces, _controller.value),
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
  );

  final double x, vx, vy, spin, size;
  final Color color;
  final bool round;

  static const _colors = [
    AppColors.yellow,
    AppColors.pink,
    AppColors.cyan,
    AppColors.green,
    AppColors.orange,
    AppColors.white,
  ];

  static List<_Piece> burst(int count) {
    final random = Random(3);
    return List.generate(
      count,
      (_) => _Piece(
        0.3 + random.nextDouble() * 0.4,
        (random.nextDouble() - 0.5) * 1.4,
        -0.6 - random.nextDouble() * 0.9,
        (random.nextDouble() - 0.5) * 20,
        6 + random.nextDouble() * 8,
        _colors[random.nextInt(_colors.length)],
        random.nextBool(),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

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
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
