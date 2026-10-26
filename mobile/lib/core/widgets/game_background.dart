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
    this.theme = BackgroundTheme.letters,
  });

  final Widget child;
  final BackgroundPalette palette;

  /// Lettres (Géographie & Nature) ou chiffres, symboles et cerveaux (QI).
  final BackgroundTheme theme;

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
              child: CustomPaint(painter: _ScenePainter(_time, widget.theme)),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Ce qui flotte sur le fond.
enum BackgroundTheme {
  /// Lettres 3D : le Petit Bac.
  letters,

  /// Chiffres, symboles mathématiques, cerveaux et petits schémas : le QI.
  iq,
}

// ---------------------------------------------------------------- éléments

class _Bubble {
  const _Bubble(this.x, this.y, this.radius, this.phase);

  /// Position et rayon en fractions de la largeur de l'écran.
  final double x, y, radius, phase;
}

class _Letter {
  const _Letter(this.char, this.x, this.y, this.size, this.speed, this.phase);

  final String char;
  final double x, y, size, speed, phase;
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
  _Letter('A', 0.30, 0.07, 92, 0.8, 0.3),
  _Letter('B', 0.88, 0.14, 84, 1.0, 1.1),
  _Letter('C', 0.10, 0.24, 104, 0.7, 2.0),
  _Letter('D', 0.92, 0.30, 88, 0.9, 2.7),
  _Letter('F', 0.12, 0.43, 90, 1.1, 3.4),
  _Letter('G', 0.88, 0.44, 86, 0.8, 4.0),
  _Letter('M', 0.14, 0.66, 100, 0.7, 4.8),
  _Letter('P', 0.80, 0.66, 92, 1.0, 5.5),
  _Letter('R', 0.14, 0.80, 88, 0.9, 0.9),
  _Letter('S', 0.88, 0.78, 84, 1.1, 1.6),
  _Letter('V', 0.58, 0.90, 98, 0.8, 2.3),
];

/// Fond du QI : chiffres et symboles mathématiques, et quelques icônes
/// (cerveau, pièce de puzzle, ampoule, ∑, ∞) aux mêmes places que les
/// lettres. Les symboles absents de la police du jeu passent par les icônes.
class _Glyph {
  const _Glyph(this.x, this.y, this.size, this.speed, this.phase,
      {this.text, this.icon});

  final String? text;
  final IconData? icon;
  final double x, y, size, speed, phase;
}

const _iqGlyphs = [
  _Glyph(0.30, 0.07, 92, 0.8, 0.3, text: '7'),
  _Glyph(0.88, 0.14, 80, 1.0, 1.1, icon: Icons.psychology_rounded),
  _Glyph(0.10, 0.24, 92, 0.7, 2.0, text: '%'),
  _Glyph(0.92, 0.31, 76, 0.9, 2.7, icon: Icons.calculate_rounded),
  _Glyph(0.12, 0.43, 78, 1.1, 3.4, icon: Icons.extension_rounded),
  _Glyph(0.88, 0.45, 86, 0.8, 4.0, text: '÷'),
  _Glyph(0.14, 0.66, 84, 0.7, 4.8, icon: Icons.functions_rounded),
  _Glyph(0.80, 0.66, 78, 1.0, 5.5, icon: Icons.lightbulb_rounded),
  _Glyph(0.14, 0.81, 88, 0.9, 0.9, text: '3'),
  _Glyph(0.88, 0.79, 84, 1.1, 1.6, icon: Icons.all_inclusive_rounded),
  _Glyph(0.58, 0.91, 84, 0.8, 2.3, icon: Icons.psychology_rounded),
  _Glyph(0.52, 0.40, 58, 1.2, 3.0, text: '×'),
  _Glyph(0.44, 0.76, 58, 1.0, 4.4, text: '='),
];

/// Petits schémas tracés au trait : un réseau de points reliés et une figure
/// géométrique, qui tournent doucement.
class _Diagram {
  const _Diagram(this.x, this.y, this.size, this.phase, {required this.network});

  final double x, y, size, phase;
  final bool network;
}

const _diagrams = [
  _Diagram(0.60, 0.20, 110, 0.6, network: true),
  _Diagram(0.36, 0.56, 96, 2.1, network: false),
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
  _ScenePainter(this.time, this.theme) : super(repaint: time);

  final ValueNotifier<double> time;
  final BackgroundTheme theme;

  static final Map<(String, double, bool), TextPainter> _letterCache = {};
  static final Map<(int, double, bool), TextPainter> _iconCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    _paintBubbles(canvas, size, t);
    if (theme == BackgroundTheme.iq) {
      _paintDiagrams(canvas, size, t);
      _paintGlyphs(canvas, size, t);
    } else {
      _paintLetters(canvas, size, t);
    }
  }

  /// Icône dessinée comme une lettre (même teinte, même ombre).
  static TextPainter _iconPainter(IconData icon, double size,
          {bool shadow = false}) =>
      _iconCache.putIfAbsent((icon.codePoint, size, shadow), () {
        return TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: size,
              height: 1,
              foreground: Paint()
                ..color = shadow
                    ? const Color(0xFF1A0A55).withValues(alpha: 0.22)
                    : const Color(0xFFD9C8FF).withValues(alpha: 0.30)
                ..maskFilter = shadow
                    ? const MaskFilter.blur(BlurStyle.normal, 2)
                    : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });

  void _paintGlyphs(Canvas canvas, Size size, double t) {
    for (final g in _iqGlyphs) {
      // Même mouvement lent que les lettres.
      final dx = sin(t * 0.22 * g.speed + g.phase) * 10;
      final dy = sin(t * 0.17 * g.speed + g.phase * 1.3) * 14;
      final angle = sin(t * 0.12 + g.phase) * 0.10;
      final icon = g.icon;
      final shadow = icon != null
          ? _iconPainter(icon, g.size, shadow: true)
          : _letter(g.text!, g.size, shadow: true);
      final body =
          icon != null ? _iconPainter(icon, g.size) : _letter(g.text!, g.size);
      canvas.save();
      canvas.translate(g.x * size.width + dx, g.y * size.height + dy);
      canvas.rotate(angle);
      shadow.paint(
        canvas,
        Offset(-shadow.width / 2 + 3, -shadow.height / 2 + 6),
      );
      body.paint(canvas, Offset(-body.width / 2, -body.height / 2));
      canvas.restore();
    }
  }

  void _paintDiagrams(Canvas canvas, Size size, double t) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD9C8FF).withValues(alpha: 0.22);
    final dot = Paint()..color = const Color(0xFFD9C8FF).withValues(alpha: 0.32);
    for (final d in _diagrams) {
      final r = d.size / 2;
      canvas.save();
      canvas.translate(
        d.x * size.width + sin(t * 0.15 + d.phase) * 10,
        d.y * size.height + cos(t * 0.12 + d.phase) * 12,
      );
      canvas.rotate(t * 0.05 + d.phase);
      if (d.network) {
        // Réseau : 6 points sur un cercle et un au centre, reliés.
        final points = [
          Offset.zero,
          for (var i = 0; i < 6; i++)
            Offset(cos(i * pi / 3) * r, sin(i * pi / 3) * r),
        ];
        for (var i = 1; i < points.length; i++) {
          canvas.drawLine(points[0], points[i], line);
          canvas.drawLine(
            points[i],
            points[i == points.length - 1 ? 1 : i + 1],
            line,
          );
        }
        for (final p in points) {
          canvas.drawCircle(p, 5, dot);
        }
      } else {
        // Figure : un triangle dans un cercle, avec ses sommets marqués.
        canvas.drawCircle(Offset.zero, r, line);
        final corners = [
          for (var i = 0; i < 3; i++)
            Offset(cos(-pi / 2 + i * 2 * pi / 3) * r,
                sin(-pi / 2 + i * 2 * pi / 3) * r),
        ];
        canvas.drawPath(Path()..addPolygon(corners, true), line);
        canvas.drawLine(corners[0], Offset.zero, line);
        for (final c in corners) {
          canvas.drawCircle(c, 5, dot);
        }
      }
      canvas.restore();
    }
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
          ..strokeWidth = 0.6
          ..color = Colors.white.withValues(alpha: 0.10),
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

  /// Lettre nette ; [shadow] dessine l'ombre légère qui donne le volume.
  static TextPainter _letter(String char, double size, {bool shadow = false}) =>
      _letterCache.putIfAbsent((char, size, shadow), () {
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
                ..maskFilter = shadow
                    ? const MaskFilter.blur(BlurStyle.normal, 2)
                    : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });

  void _paintLetters(Canvas canvas, Size size, double t) {
    for (var i = 0; i < _letters.length; i++) {
      final l = _letters[i];
      final (center, angle) = letterPose(i, t, size);
      final shadow = _letter(l.char, l.size, shadow: true);
      final body = _letter(l.char, l.size);
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

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.theme != theme;
}
