import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Schéma « compter les triangles » : segments + polygones d'explication.
class IqDiagram {
  const IqDiagram({required this.segments, this.highlights = const []});

  factory IqDiagram.fromJson(Map<String, dynamic> json) => IqDiagram(
    segments: [
      for (final s in (json['segments'] as List?) ?? const [])
        (
          (s[0] as num).toDouble(),
          (s[1] as num).toDouble(),
          (s[2] as num).toDouble(),
          (s[3] as num).toDouble(),
        ),
    ],
    highlights: [
      for (final poly in (json['highlights'] as List?) ?? const [])
        [
          for (final p in poly as List)
            ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
    ],
  );

  /// Lignes (x1, y1, x2, y2) en coords 0–1.
  final List<(double, double, double, double)> segments;

  /// Triangles à teinter en révélation.
  final List<List<(double, double)>> highlights;

  Map<String, dynamic> toJson() => {
    'segments': [
      for (final s in segments) [s.$1, s.$2, s.$3, s.$4],
    ],
    'highlights': [
      for (final poly in highlights)
        [
          for (final p in poly) [p.$1, p.$2],
        ],
    ],
  };
}

/// Figure pendant la manche (sans surbrillance).
class IqDiagramView extends StatelessWidget {
  const IqDiagramView({
    super.key,
    required this.diagram,
    this.showHighlights = false,
    this.size = 200,
  });

  final IqDiagram diagram;
  final bool showHighlights;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        key: const Key('iq_diagram'),
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DiagramPainter(
            diagram: diagram,
            showHighlights: showHighlights,
          ),
        ),
      ),
    );
  }
}

class _DiagramPainter extends CustomPainter {
  _DiagramPainter({required this.diagram, required this.showHighlights});

  final IqDiagram diagram;
  final bool showHighlights;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.shortestSide * 0.06;
    final box = Rect.fromLTWH(
      pad,
      pad,
      size.width - 2 * pad,
      size.height - 2 * pad,
    );
    Offset map((double x, double y) p) =>
        Offset(box.left + p.$1 * box.width, box.top + p.$2 * box.height);

    if (showHighlights) {
      final fill = Paint()
        ..color = AppColors.green.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      for (final poly in diagram.highlights) {
        if (poly.length < 3) continue;
        final path = Path()..moveTo(map(poly.first).dx, map(poly.first).dy);
        for (final p in poly.skip(1)) {
          path.lineTo(map(p).dx, map(p).dy);
        }
        path.close();
        canvas.drawPath(path, fill);
      }
    }

    final stroke = Paint()
      ..color = const Color(0xFF2E7D4F)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final s in diagram.segments) {
      canvas.drawLine(map((s.$1, s.$2)), map((s.$3, s.$4)), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagramPainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.showHighlights != showHighlights;
}
