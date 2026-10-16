import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../feedback/game_feedback.dart';

/// Couleurs du fond. Les menus sont violets, chaque manche a sa propre
/// palette et la fin de partie passe au doré. Teintes sombres pour que les
/// cartes et les boutons ressortent.
class BackgroundPalette {
  const BackgroundPalette(this.colors);

  final List<Color> colors;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: colors,
  );

  static const menu = BackgroundPalette([
    Color(0xFF7A3FE0),
    Color(0xFF4A23C2),
    Color(0xFF1C0F7A),
  ]);
  static const victory = BackgroundPalette([
    Color(0xFFE0922F),
    Color(0xFFB45A06),
    Color(0xFF5C2600),
  ]);
  static const rounds = [
    BackgroundPalette([
      Color(0xFF4F7BEA),
      Color(0xFF2B3FC4),
      Color(0xFF0F1660),
    ]),
    BackgroundPalette([
      Color(0xFF23B3A4),
      Color(0xFF007F7A),
      Color(0xFF003833),
    ]),
    BackgroundPalette([
      Color(0xFFDC5CA0),
      Color(0xFFA42373),
      Color(0xFF4A0A33),
    ]),
    BackgroundPalette([
      Color(0xFFE38A4C),
      Color(0xFFBF4E2B),
      Color(0xFF5E1B12),
    ]),
    BackgroundPalette([
      Color(0xFF9670E0),
      Color(0xFF6240AE),
      Color(0xFF1D0E60),
    ]),
  ];

  static BackgroundPalette forRound(int number) =>
      rounds[(max(number, 1) - 1) % rounds.length];
}

/// Fond « bonbon » en plusieurs couches, inspiré de la maquette :
/// - de grosses bulles brillantes et translucides,
/// - des lettres 3D floues qui flottent lentement,
/// - de petites formes (étoiles, triangles, losanges, perles),
/// - des lignes de lumière parcourues par des points lumineux.
///
/// Les éléments sont blancs et translucides : ils prennent la teinte de la
/// palette en dessous, qui change à chaque manche. Tout suit une horloge
/// partagée par les écrans, donc rien ne saute.
class GameBackground extends StatefulWidget {
  const GameBackground({
    super.key,
    required this.child,
    this.palette = BackgroundPalette.menu,
  });

  final Widget child;
  final BackgroundPalette palette;

  /// Instant figé quand les animations d'ambiance sont coupées (tests, captures).
  @visibleForTesting
  static double debugTime = 0;

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with SingleTickerProviderStateMixin {
  /// Commune à tous les fonds pour que le mouvement continue d'un écran à l'autre.
  static final Stopwatch _clock = Stopwatch()..start();

  final ValueNotifier<double> _time = ValueNotifier(GameBackground.debugTime);
  Ticker? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = GameFeedbackScope.of(context).ambientMotion;
    if (animate && _ticker == null) {
      _ticker = createTicker(
        (_) => _time.value = _clock.elapsedMilliseconds / 1000,
      )..start();
    } else if (!animate) {
      _ticker?.dispose();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(gradient: widget.palette.gradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ScenePainter(_time)),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- éléments

class _Bubble {
  const _Bubble(this.x, this.y, this.radius, this.phase);

  /// Position et rayon en fractions de la largeur de l'écran.
  final double x, y, radius, phase;
}

class _Letter {
  const _Letter(
    this.char,
    this.x,
    this.y,
    this.size,
    this.blur,
    this.speed,
    this.phase,
  );

  final String char;
  final double x, y, size, blur, speed, phase;
}

enum _ShapeKind { star, triangle, diamond, pearl }

class _Shape {
  const _Shape(this.kind, this.x, this.y, this.size, this.phase);

  final _ShapeKind kind;
  final double x, y, size, phase;
}

class _Beam {
  const _Beam(this.points, this.color, this.speed);

  /// Points de contrôle de la courbe, en fractions de l'écran.
  final List<Offset> points;
  final Color color;
  final double speed;
}

const _bubbles = [
  _Bubble(0.02, 0.18, 0.30, 0.0),
  _Bubble(0.98, 0.02, 0.26, 1.7),
  _Bubble(0.98, 0.58, 0.24, 3.1),
  _Bubble(0.05, 0.93, 0.32, 4.2),
  _Bubble(0.99, 0.95, 0.22, 5.4),
  _Bubble(0.0, 0.60, 0.10, 2.4),
];

const _letters = [
  _Letter('A', 0.30, 0.07, 92, 2.5, 0.8, 0.3),
  _Letter('B', 0.88, 0.14, 84, 2.0, 1.0, 1.1),
  _Letter('C', 0.10, 0.24, 104, 3.5, 0.7, 2.0),
  _Letter('D', 0.92, 0.30, 88, 2.0, 0.9, 2.7),
  _Letter('F', 0.12, 0.43, 90, 2.5, 1.1, 3.4),
  _Letter('G', 0.88, 0.44, 86, 3.0, 0.8, 4.0),
  _Letter('M', 0.14, 0.66, 100, 4.0, 0.7, 4.8),
  _Letter('P', 0.80, 0.66, 92, 2.5, 1.0, 5.5),
  _Letter('R', 0.14, 0.80, 88, 3.0, 0.9, 0.9),
  _Letter('S', 0.88, 0.78, 84, 2.0, 1.1, 1.6),
  _Letter('V', 0.58, 0.90, 98, 3.0, 0.8, 2.3),
];

const _shapes = [
  _Shape(_ShapeKind.star, 0.10, 0.04, 16, 0.2),
  _Shape(_ShapeKind.triangle, 0.10, 0.12, 14, 1.0),
  _Shape(_ShapeKind.triangle, 0.33, 0.17, 12, 1.8),
  _Shape(_ShapeKind.pearl, 0.80, 0.07, 9, 2.6),
  _Shape(_ShapeKind.triangle, 0.64, 0.21, 13, 3.3),
  _Shape(_ShapeKind.pearl, 0.84, 0.21, 12, 4.1),
  _Shape(_ShapeKind.pearl, 0.26, 0.29, 8, 4.9),
  _Shape(_ShapeKind.star, 0.36, 0.34, 13, 5.6),
  _Shape(_ShapeKind.triangle, 0.78, 0.50, 14, 0.6),
  _Shape(_ShapeKind.star, 0.68, 0.58, 13, 1.4),
  _Shape(_ShapeKind.pearl, 0.92, 0.58, 9, 2.1),
  _Shape(_ShapeKind.diamond, 0.42, 0.69, 18, 2.9),
  _Shape(_ShapeKind.pearl, 0.66, 0.74, 12, 3.7),
  _Shape(_ShapeKind.star, 0.35, 0.84, 14, 4.4),
  _Shape(_ShapeKind.pearl, 0.06, 0.72, 9, 5.2),
];

const _beams = [
  _Beam(
    [
      Offset(-0.1, 0.32),
      Offset(0.3, 0.45),
      Offset(0.6, 0.20),
      Offset(1.1, 0.24),
    ],
    Color(0xFFFF8BE8),
    0.05,
  ),
  _Beam(
    [
      Offset(-0.1, 0.33),
      Offset(0.25, 0.40),
      Offset(0.5, 0.48),
      Offset(1.1, 0.30),
    ],
    Color(0xFFE3B8FF),
    0.04,
  ),
  _Beam(
    [
      Offset(-0.1, 0.46),
      Offset(0.3, 0.54),
      Offset(0.6, 0.50),
      Offset(1.1, 0.62),
    ],
    Color(0xFF8FB4FF),
    0.06,
  ),
  _Beam(
    [
      Offset(-0.1, 0.72),
      Offset(0.35, 0.74),
      Offset(0.7, 0.66),
      Offset(1.1, 0.70),
    ],
    Color(0xFFFF9CF0),
    0.045,
  ),
  _Beam(
    [
      Offset(0.1, 0.72),
      Offset(0.3, 0.78),
      Offset(0.42, 0.80),
      Offset(0.47, 0.82),
    ],
    Color(0xFFFFC2F7),
    0.07,
  ),
];

/// Lettre [index] à [seconds] secondes de l'horloge partagée : position et
/// inclinaison. Fonction continue du temps : le mouvement ne saute jamais.
@visibleForTesting
(Offset, double) letterPose(int index, double seconds, Size size) {
  final l = _letters[index];
  final dx = sin(seconds * 0.22 * l.speed + l.phase) * 10;
  final dy = sin(seconds * 0.17 * l.speed + l.phase * 1.3) * 14;
  final angle = sin(seconds * 0.12 + l.phase) * 0.10;
  return (Offset(l.x * size.width + dx, l.y * size.height + dy), angle);
}

/// Nombre de lettres flottantes du fond.
@visibleForTesting
int get backgroundLetterCount => _letters.length;

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.time) : super(repaint: time);

  final ValueNotifier<double> time;

  static final Map<(String, double, double, bool), TextPainter> _letterCache =
      {};

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    _paintBubbles(canvas, size, t);
    _paintBeams(canvas, size, t);
    _paintLetters(canvas, size, t);
    _paintShapes(canvas, size, t);
  }

  void _paintBubbles(Canvas canvas, Size size, double t) {
    for (final b in _bubbles) {
      final r = b.radius * size.width;
      final center = Offset(
        b.x * size.width + sin(t * 0.08 + b.phase) * 12,
        b.y * size.height + cos(t * 0.06 + b.phase) * 16,
      );
      final rect = Rect.fromCircle(center: center, radius: r);
      // Corps : plus clair en haut à gauche, comme une bulle éclairée.
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [
              Colors.white.withValues(alpha: 0.20),
              Colors.white.withValues(alpha: 0.04),
            ],
          ).createShader(rect),
      );
      // Liseré lumineux.
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.18),
      );
      // Reflet.
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(-r * 0.35, -r * 0.55),
          width: r * 0.6,
          height: r * 0.22,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  void _paintBeams(Canvas canvas, Size size, double t) {
    for (final beam in _beams) {
      final p = [
        for (final o in beam.points)
          Offset(o.dx * size.width, o.dy * size.height),
      ];
      final path = Path()
        ..moveTo(p[0].dx, p[0].dy)
        ..cubicTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy, p[3].dx, p[3].dy);
      // Ligne : un halo flou sous un trait fin.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = beam.color.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = beam.color.withValues(alpha: 0.35),
      );
      // Point de lumière qui parcourt la ligne (il réapparaît à l'autre
      // bout en restant hors écran ou en fondu, donc sans à-coup visible).
      final metric = path.computeMetrics().first;
      final progress = (t * beam.speed + beam.points[0].dy) % 1.0;
      final fade = sin(progress * pi);
      final pos = metric
          .getTangentForOffset(metric.length * progress)
          ?.position;
      if (pos != null && fade > 0.02) {
        canvas.drawCircle(
          pos,
          12,
          Paint()
            ..color = beam.color.withValues(alpha: 0.55 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        canvas.drawCircle(
          pos,
          3.4,
          Paint()..color = Colors.white.withValues(alpha: 0.95 * fade),
        );
      }
    }
  }

  /// Lettre « gelée » : [shadow] dessine l'ombre douce qui donne le volume.
  static TextPainter _letter(
    String char,
    double size,
    double blur, {
    bool shadow = false,
  }) => _letterCache.putIfAbsent((char, size, blur, shadow), () {
    return TextPainter(
      text: TextSpan(
        text: char,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontVariations: const [ui.FontVariation('wght', 700)],
          height: 1,
          foreground: Paint()
            ..color = shadow
                ? const Color(0xFF1A0A55).withValues(alpha: 0.22)
                : const Color(0xFFD9C8FF).withValues(alpha: 0.30)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              shadow ? blur + 4 : blur,
            ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  });

  void _paintLetters(Canvas canvas, Size size, double t) {
    for (var i = 0; i < _letters.length; i++) {
      final l = _letters[i];
      final (center, angle) = letterPose(i, t, size);
      final shadow = _letter(l.char, l.size, l.blur, shadow: true);
      final body = _letter(l.char, l.size, l.blur);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      shadow.paint(
        canvas,
        Offset(-shadow.width / 2 + 3, -shadow.height / 2 + 6),
      );
      body.paint(canvas, Offset(-body.width / 2, -body.height / 2));
      canvas.restore();
    }
  }

  void _paintShapes(Canvas canvas, Size size, double t) {
    for (final s in _shapes) {
      final center = Offset(
        s.x * size.width + sin(t * 0.3 + s.phase) * 5,
        s.y * size.height + sin(t * 0.4 + s.phase * 1.4) * 8,
      );
      final angle = sin(t * 0.25 + s.phase) * 0.35;
      final r = s.size;
      final rect = Rect.fromCircle(center: center, radius: r);
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC9A7FF).withValues(alpha: 0.85),
            const Color(0xFF7B4DFF).withValues(alpha: 0.75),
          ],
        ).createShader(rect);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final path = switch (s.kind) {
        _ShapeKind.star => _star(r),
        _ShapeKind.triangle => _roundedPolygon(3, r),
        _ShapeKind.diamond => _roundedPolygon(4, r),
        _ShapeKind.pearl => null,
      };
      if (path == null) {
        canvas.drawCircle(Offset.zero, r, fill);
      } else {
        // Le trait épais aux jointures arrondies adoucit les angles (effet bonbon).
        canvas.drawPath(path, fill);
        canvas.drawPath(
          path,
          Paint()
            ..shader = fill.shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.45
            ..strokeJoin = StrokeJoin.round,
        );
      }
      // Reflet.
      canvas.drawCircle(
        Offset(-r * 0.3, -r * 0.35),
        r * 0.28,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
      );
      canvas.restore();
    }
  }

  static Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.48;
      final a = -pi / 2 + i * pi / 5;
      final point = Offset(cos(a) * radius, sin(a) * radius);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  static Path _roundedPolygon(int sides, double r) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = -pi / 2 + i * 2 * pi / sides;
      final point = Offset(cos(a) * r, sin(a) * r);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => false;
}
