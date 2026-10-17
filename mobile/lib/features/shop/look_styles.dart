import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Forme du cadre autour de l'avatar.
enum FrameShape { ring, ornament, flames, stars }

/// Motif peint sur les tuiles de lettres.
enum TilePattern { plain, stripes, dots, metal }

/// Forme des particules de victoire.
enum VictoryShape { confetti, stars, bubbles, letters }

FrameShape frameShapeOf(String id) => switch (id) {
  'frame_ornament' => FrameShape.ornament,
  'frame_flames' => FrameShape.flames,
  'frame_stars' => FrameShape.stars,
  _ => FrameShape.ring,
};

TilePattern tilePatternOf(String id) => switch (id) {
  'tiles_stripes' => TilePattern.stripes,
  'tiles_dots' => TilePattern.dots,
  'tiles_metal' => TilePattern.metal,
  _ => TilePattern.plain,
};

VictoryShape victoryShapeOf(String id) => switch (id) {
  'victory_stars' => VictoryShape.stars,
  'victory_bubbles' => VictoryShape.bubbles,
  'victory_letters' => VictoryShape.letters,
  _ => VictoryShape.confetti,
};

/// Pseudo stylé (couleur, dégradé, contour, badge).
class StyledNickname extends StatelessWidget {
  const StyledNickname(
    this.text, {
    super.key,
    required this.styleId,
    this.size = 14,
    this.weight = FontWeight.w700,
    this.maxLines = 1,
    this.textAlign,
    this.fallbackColor,
  });

  final String text;
  final String styleId;
  final double size;
  final FontWeight weight;
  final int maxLines;
  final TextAlign? textAlign;

  /// Couleur si aucun style boutique n'est équipé.
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final base = fredoka(size: size, weight: weight, height: 1.1);
    final plain = fallbackColor ?? AppColors.ink;
    final child = switch (styleId) {
      'name_gradient' => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [AppColors.pink, AppColors.cyan],
        ).createShader(bounds),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: base.copyWith(color: AppColors.white),
        ),
      ),
      'name_outline' => Stack(
        alignment: Alignment.center,
        children: [
          Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.18
                ..color = AppColors.ink,
            ),
          ),
          Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: base.copyWith(color: AppColors.yellow),
          ),
        ],
      ),
      'name_badge' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: size * 0.95, color: AppColors.orange),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: base.copyWith(color: AppColors.orange),
            ),
          ),
        ],
      ),
      'name_rose' => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: base.copyWith(color: AppColors.pink),
      ),
      'name_violet' => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: base.copyWith(color: AppColors.purple),
      ),
      'name_orange' => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: base.copyWith(color: AppColors.orange),
      ),
      _ => Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: base.copyWith(color: plain),
      ),
    };
    return child;
  }
}

/// Calque décoratif autour d'un avatar (flammes, étoiles, ornement).
class AvatarFrameLayer extends StatelessWidget {
  const AvatarFrameLayer({
    super.key,
    required this.frameId,
    required this.size,
    required this.child,
  });

  final String frameId;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = frameShapeOf(frameId);
    final color = switch (frameId) {
      'frame_gold' || 'frame_ornament' => AppColors.yellow,
      'frame_pink' => AppColors.pink,
      'frame_cyan' => AppColors.cyan,
      'frame_flames' => AppColors.orange,
      'frame_stars' => AppColors.purple,
      _ => AppColors.white,
    };
    final pad = shape == FrameShape.ring ? 0.0 : size * 0.14;
    final total = size + pad * 2;
    return SizedBox(
      width: total,
      height: total,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (shape != FrameShape.ring)
            CustomPaint(
              size: Size.square(total),
              painter: _FramePainter(shape: shape, color: color),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: shape == FrameShape.ring ? color : color.withValues(alpha: 0.9),
                width: shape == FrameShape.ring ? 3 : 2.5,
              ),
            ),
            child: ClipOval(child: child),
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.shape, required this.color});

  final FrameShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.38;
    switch (shape) {
      case FrameShape.ornament:
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.045;
        canvas.drawCircle(c, r * 1.08, paint);
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          final tip = c + Offset(cos(a), sin(a)) * r * 1.28;
          canvas.drawCircle(tip, size.width * 0.04, Paint()..color = color);
        }
      case FrameShape.flames:
        final flame = Paint()..color = color;
        final tip = Paint()..color = Color.lerp(color, AppColors.yellow, 0.45)!;
        for (var i = 0; i < 10; i++) {
          final a = -pi / 2 + i * (2 * pi / 10);
          final outer = c + Offset(cos(a), sin(a)) * r * 1.35;
          final left = c + Offset(cos(a - 0.22), sin(a - 0.22)) * r * 1.02;
          final right = c + Offset(cos(a + 0.22), sin(a + 0.22)) * r * 1.02;
          canvas.drawPath(
            Path()
              ..moveTo(left.dx, left.dy)
              ..lineTo(outer.dx, outer.dy)
              ..lineTo(right.dx, right.dy)
              ..close(),
            flame,
          );
          canvas.drawCircle(outer, size.width * 0.03, tip);
        }
      case FrameShape.stars:
        final paint = Paint()..color = color;
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 - pi / 2;
          final tip = c + Offset(cos(a), sin(a)) * r * 1.3;
          _star(canvas, tip, size.width * 0.07, paint);
        }
      case FrameShape.ring:
        break;
    }
  }

  void _star(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rad = i.isEven ? radius : radius * 0.42;
      final p = center + Offset(cos(a), sin(a)) * rad;
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
  bool shouldRepaint(_FramePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}

/// Motif décoratif pour l'aperçu boutique d'une tuile.
class TilePatternPreview extends StatelessWidget {
  const TilePatternPreview({super.key, required this.patternId, this.size = 34});

  final String patternId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (patternId) {
      'tiles_stripes' || 'tiles_ocean' => AppColors.cyan,
      'tiles_dots' || 'tiles_candy' => AppColors.pink,
      'tiles_metal' => const Color(0xFF9AA3B5),
      'tiles_sunset' => AppColors.orange,
      _ => AppColors.yellow,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color),
            CustomPaint(
              painter: TilePatternPainter(pattern: tilePatternOf(patternId)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calque de motif (rayures, pois, métal) par-dessus une tuile déjà colorée.
class TilePatternPainter extends CustomPainter {
  TilePatternPainter({required this.pattern});

  final TilePattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    switch (pattern) {
      case TilePattern.stripes:
        final stripe = Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = size.width * 0.12;
        for (var x = -size.width; x < size.width * 2; x += size.width * 0.28) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            stripe,
          );
        }
      case TilePattern.dots:
        final dot = Paint()..color = Colors.white.withValues(alpha: 0.4);
        for (var y = size.height * 0.2; y < size.height; y += size.height * 0.28) {
          for (
            var x = size.width * 0.2;
            x < size.width;
            x += size.width * 0.28
          ) {
            canvas.drawCircle(Offset(x, y), size.width * 0.06, dot);
          }
        }
      case TilePattern.metal:
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              Offset(size.width, size.height),
              [
                Colors.white.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.22),
              ],
              const [0, 0.45, 1],
            ),
        );
      case TilePattern.plain:
        break;
    }
  }

  @override
  bool shouldRepaint(TilePatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern;
}
