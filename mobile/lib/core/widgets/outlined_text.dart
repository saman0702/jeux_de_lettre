import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Texte cerné d'un contour foncé, comme les titres de jeux : il reste
/// lisible au-dessus des cartes blanches qui défilent dessous. Le contour est
/// dessiné derrière un seul [Text] (une seule lecture pour l'accessibilité).
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    required this.style,
    this.outline = AppColors.ink,
    this.strokeWidth = 3,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final Color outline;
  final double strokeWidth;
  final int? maxLines;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OutlinePainter(
        text: text,
        style: style.copyWith(
          color: null,
          shadows: const [],
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..color = outline,
        ),
        maxLines: maxLines,
        textAlign: textAlign,
        textScaler: MediaQuery.textScalerOf(context),
        direction: Directionality.of(context),
      ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter({
    required this.text,
    required this.style,
    required this.maxLines,
    required this.textAlign,
    required this.textScaler,
    required this.direction,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextAlign textAlign;
  final TextScaler textScaler;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      ellipsis: '…',
      textAlign: textAlign,
      textScaler: textScaler,
      textDirection: direction,
    )..layout(minWidth: size.width, maxWidth: size.width);
    painter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.text != text ||
      old.style != style ||
      old.maxLines != maxLines ||
      old.textAlign != textAlign;
}
