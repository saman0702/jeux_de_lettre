import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Une figure d'énigme à schémas : 1 à 4 formes identiques dans une case.
class IqFigure {
  const IqFigure({
    required this.shape,
    this.color = 0,
    this.count = 1,
    this.filled = true,
    this.rotation = 0,
  });

  factory IqFigure.fromJson(Map<String, dynamic> json) => IqFigure(
    shape: json['s'] as String,
    color: json['c'] as int? ?? 0,
    count: json['n'] as int? ?? 1,
    filled: json['f'] as bool? ?? true,
    rotation: json['r'] as int? ?? 0,
  );

  /// circle, square, triangle, diamond, pentagon, hexagon, star, arrow.
  final String shape;
  final int color;
  final int count;
  final bool filled;

  /// Degrés, sens des aiguilles d'une montre.
  final int rotation;
}

/// Les schémas d'une énigme : la grille (ou la suite) et les 4 choix.
class IqFigures {
  const IqFigures({
    required this.layout,
    required this.cells,
    required this.options,
  });

  factory IqFigures.fromJson(Map<String, dynamic> json) => IqFigures(
    layout: json['layout'] as String? ?? 'none',
    cells: [
      for (final c in (json['cells'] as List?) ?? const [])
        c == null ? null : IqFigure.fromJson(c as Map<String, dynamic>),
    ],
    options: [
      for (final o in (json['options'] as List?) ?? const [])
        IqFigure.fromJson(o as Map<String, dynamic>),
    ],
  );

  /// grid (3 × 3), row (suite), none (seulement les choix).
  final String layout;

  /// null = la case à trouver.
  final List<IqFigure?> cells;
  final List<IqFigure> options;
}

const _figureColors = [
  AppColors.purple,
  AppColors.orange,
  AppColors.cyan,
  AppColors.pink,
];

/// Dessin d'une figure dans un carré.
class IqFigureView extends StatelessWidget {
  const IqFigureView(this.figure, {super.key, this.size = 64});

  final IqFigure figure;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _FigurePainter(figure)),
  );
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.figure);

  final IqFigure figure;

  /// Centres (en fractions de la case) et taille selon le nombre de formes.
  static const _layouts = {
    1: ([Offset(0.5, 0.5)], 0.34),
    2: ([Offset(0.27, 0.5), Offset(0.73, 0.5)], 0.21),
    3: ([Offset(0.5, 0.28), Offset(0.27, 0.72), Offset(0.73, 0.72)], 0.2),
    4: (
      [
        Offset(0.28, 0.28),
        Offset(0.72, 0.28),
        Offset(0.28, 0.72),
        Offset(0.72, 0.72),
      ],
      0.19,
    ),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final color = _figureColors[figure.color % _figureColors.length];
    final (centers, radius) = _layouts[figure.count.clamp(1, 4)]!;
    final r = radius * size.width;
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2, size.width * 0.04)
      ..strokeJoin = StrokeJoin.round
      ..color = figure.filled ? AppColors.depthOf(color) : color;
    for (final c in centers) {
      final center = Offset(c.dx * size.width, c.dy * size.height);
      final path = _shape(figure.shape, r).transform(
        (Matrix4.identity()
              ..translateByDouble(center.dx, center.dy, 0, 1)
              ..rotateZ(figure.rotation * pi / 180))
            .storage,
      );
      if (figure.filled) canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  /// Forme centrée sur l'origine, de rayon [r], pointe vers le haut.
  static Path _shape(String shape, double r) {
    Path polygon(int sides, {double turn = 0}) => Path()
      ..addPolygon([
        for (var i = 0; i < sides; i++)
          Offset(
            r * cos(-pi / 2 + turn + i * 2 * pi / sides),
            r * sin(-pi / 2 + turn + i * 2 * pi / sides),
          ),
      ], true);
    return switch (shape) {
      'circle' =>
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)),
      'square' => polygon(4, turn: pi / 4),
      'triangle' => polygon(3),
      'diamond' =>
        Path()..addPolygon([
          Offset(0, -r),
          Offset(r * 0.7, 0),
          Offset(0, r),
          Offset(-r * 0.7, 0),
        ], true),
      'pentagon' => polygon(5),
      'hexagon' => polygon(6),
      'star' =>
        Path()..addPolygon([
          for (var i = 0; i < 10; i++)
            Offset(
              (i.isEven ? r : r * 0.45) * cos(-pi / 2 + i * pi / 5),
              (i.isEven ? r : r * 0.45) * sin(-pi / 2 + i * pi / 5),
            ),
        ], true),
      // Flèche vers le haut : la rotation se voit tout de suite.
      _ =>
        Path()..addPolygon([
          Offset(0, -r),
          Offset(r * 0.8, -r * 0.1),
          Offset(r * 0.32, -r * 0.1),
          Offset(r * 0.32, r),
          Offset(-r * 0.32, r),
          Offset(-r * 0.32, -r * 0.1),
          Offset(-r * 0.8, -r * 0.1),
        ], true),
    };
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.figure != figure;
}

/// Case d'une grille ou d'une suite : la figure, ou « ? » pour celle à trouver.
class IqFigureCell extends StatelessWidget {
  const IqFigureCell(this.figure, {super.key, this.size = 70});

  final IqFigure? figure;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hidden = figure == null;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hidden ? AppColors.yellow : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hidden ? AppColors.orange : const Color(0xFFDCD3F2),
          width: 2.5,
        ),
      ),
      child: hidden
          ? Text(
              '?',
              style: gameFont(size: size * 0.45, color: AppColors.ink),
            )
          : IqFigureView(figure!, size: size - 8),
    );
  }
}

/// La grille 3 × 3 ou la suite de figures de l'énoncé.
class IqFigureBoard extends StatelessWidget {
  const IqFigureBoard(this.figures, {super.key});

  final IqFigures figures;

  @override
  Widget build(BuildContext context) {
    if (figures.layout == 'grid') {
      return Center(
        child: Column(
          key: const Key('iq_figure_grid'),
          children: [
            for (var r = 0; r < 3; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var c = 0; c < 3; c++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: IqFigureCell(figures.cells[r * 3 + c]),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = max(1, figures.cells.length);
        final size = min(62.0, (constraints.maxWidth - 6 * n) / n);
        return Wrap(
          key: const Key('iq_figure_row'),
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            for (final f in figures.cells) IqFigureCell(f, size: size),
          ],
        );
      },
    );
  }
}

/// Les 4 choix dessinés, notés A à D.
class IqFigureChoices extends StatelessWidget {
  const IqFigureChoices({
    super.key,
    required this.figures,
    required this.onAnswer,
    this.enabled = true,
    this.removed = const {},
  });

  final IqFigures figures;
  final ValueChanged<String> onAnswer;
  final bool enabled;

  /// Choix retirés par le joker 50/50.
  final Set<int> removed;

  static const _labels = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        for (final (i, figure) in figures.options.indexed)
          GestureDetector(
            key: Key('iq_choice_$i'),
            onTap: enabled && !removed.contains(i)
                ? () => onAnswer('$i')
                : null,
            child: Opacity(
              opacity: removed.contains(i) ? 0.3 : 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.purpleLight, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.depthOf(AppColors.purpleLight),
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 4,
                      child: Text(
                        _labels[i],
                        style: gameFont(size: 16, color: AppColors.purple),
                      ),
                    ),
                    Center(child: IqFigureView(figure, size: 64)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
