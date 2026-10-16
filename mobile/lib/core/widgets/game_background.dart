import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../feedback/game_feedback.dart';

/// Couleurs du fond. Les menus sont violets, chaque manche a sa propre
/// palette et la fin de partie passe au doré. Teintes volontairement
/// sombres pour que les cartes et les boutons ressortent.
class BackgroundPalette {
  const BackgroundPalette(this.colors);

  final List<Color> colors;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
  );

  static const menu = BackgroundPalette([
    Color(0xFF6F45D6),
    Color(0xFF4C27AE),
    Color(0xFF251066),
  ]);
  static const victory = BackgroundPalette([
    Color(0xFFD9892C),
    Color(0xFFB45A06),
    Color(0xFF5C2600),
  ]);
  static const rounds = [
    BackgroundPalette([
      Color(0xFF4A72D9),
      Color(0xFF2F47C2),
      Color(0xFF131A63),
    ]),
    BackgroundPalette([
      Color(0xFF1FA89A),
      Color(0xFF00807A),
      Color(0xFF003B34),
    ]),
    BackgroundPalette([
      Color(0xFFD45A97),
      Color(0xFFA82670),
      Color(0xFF4E0B33),
    ]),
    BackgroundPalette([
      Color(0xFFD9844A),
      Color(0xFFC0512D),
      Color(0xFF631D13),
    ]),
    BackgroundPalette([
      Color(0xFF8D6AD6),
      Color(0xFF6244A3),
      Color(0xFF1E0F5C),
    ]),
  ];

  static BackgroundPalette forRound(int number) =>
      rounds[(max(number, 1) - 1) % rounds.length];
}

/// Fond sobre : un dégradé sombre, des halos de lumière qui dérivent
/// lentement et quelques scintillements discrets.
///
/// Le mouvement suit une horloge partagée par tous les écrans : rien ne
/// saute, ni quand une boucle recommence, ni quand on change d'écran.
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
              child: CustomPaint(painter: _AmbiencePainter(_time)),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Halo {
  const _Halo(this.radius, this.fx, this.fy, this.phase, this.color);

  final double radius, fx, fy, phase;
  final Color color;
}

class _Sparkle {
  const _Sparkle(this.x, this.y, this.size, this.speed, this.phase);

  final double x, y, size, speed, phase;
}

final List<_Halo> _halos = () {
  final random = Random(7);
  const colors = [
    Colors.white,
    Color(0xFFFFE08A),
    Color(0xFF9BE7FF),
    Colors.white,
  ];
  return [
    for (final color in colors)
      _Halo(
        0.45 + random.nextDouble() * 0.35,
        0.04 + random.nextDouble() * 0.05,
        0.03 + random.nextDouble() * 0.05,
        random.nextDouble() * 2 * pi,
        color,
      ),
  ];
}();

final List<_Sparkle> _sparkles = () {
  final random = Random(11);
  return List.generate(
    16,
    (_) => _Sparkle(
      random.nextDouble(),
      random.nextDouble(),
      1.2 + random.nextDouble() * 2.3,
      0.5 + random.nextDouble() * 1.2,
      random.nextDouble() * 2 * pi,
    ),
  );
}();

/// Position du halo [index] à [seconds] secondes de l'horloge partagée.
/// Fonction continue du temps : le mouvement ne saute jamais.
@visibleForTesting
Offset haloCenter(int index, double seconds, Size size) {
  final halo = _halos[index];
  return Offset(
    size.width *
        (0.5 + 0.48 * sin(seconds * halo.fx * 2 * pi / 3 + halo.phase)),
    size.height *
        (0.5 + 0.45 * cos(seconds * halo.fy * 2 * pi / 3 + halo.phase * 1.7)),
  );
}

/// Nombre de halos de lumière.
@visibleForTesting
int get haloCount => _halos.length;

class _AmbiencePainter extends CustomPainter {
  _AmbiencePainter(this.time) : super(repaint: time);

  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (var i = 0; i < _halos.length; i++) {
      final center = haloCenter(i, t, size);
      final radius = size.width * _halos[i].radius;
      final color = _halos[i].color;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Petites étoiles à quatre branches qui scintillent sur place.
    final paint = Paint();
    for (final sparkle in _sparkles) {
      final twinkle = pow(
        max(0.0, sin(t * sparkle.speed + sparkle.phase)),
        6,
      ).toDouble();
      if (twinkle < 0.02) continue;
      final c = Offset(sparkle.x * size.width, sparkle.y * size.height);
      final r = sparkle.size * (0.6 + 0.6 * twinkle);
      paint.color = Colors.white.withValues(alpha: 0.6 * twinkle);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r * 2)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
          ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AmbiencePainter oldDelegate) => false;
}
