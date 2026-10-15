import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';

/// Background colours. Menus are purple; each round of a game gets its own
/// palette, and the end of a game turns gold.
class BackgroundPalette {
  const BackgroundPalette(this.colors);

  final List<Color> colors;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
  );

  static const menu = BackgroundPalette([
    AppColors.purpleLight,
    AppColors.purple,
    AppColors.purpleDeep,
  ]);
  static const victory = BackgroundPalette([
    Color(0xFFFFB74D),
    Color(0xFFF57C00),
    Color(0xFF8D3B00),
  ]);
  static const rounds = [
    BackgroundPalette([
      Color(0xFF5B8CFF),
      Color(0xFF3D5AFE),
      Color(0xFF1A237E),
    ]),
    BackgroundPalette([
      Color(0xFF2BD9C6),
      Color(0xFF00A39A),
      Color(0xFF00544A),
    ]),
    BackgroundPalette([
      Color(0xFFFF6FB5),
      Color(0xFFD6338A),
      Color(0xFF6E1048),
    ]),
    BackgroundPalette([
      Color(0xFFFFA45B),
      Color(0xFFF2683C),
      Color(0xFF8E2A1B),
    ]),
    BackgroundPalette([
      Color(0xFFB085FF),
      Color(0xFF7E57C2),
      Color(0xFF2A1680),
    ]),
  ];

  static BackgroundPalette forRound(int number) =>
      rounds[(max(number, 1) - 1) % rounds.length];
}

/// Layered, parallax background:
/// - soft light blobs drifting like an aurora,
/// - far letter tiles (small, faint, slow) and near ones (big, bright,
///   faster) that bob, sway and now and then spin like coins,
/// - twinkling sparkles and the occasional shooting star.
///
/// Every layer is a continuous function of one clock shared by all screens,
/// so nothing ever jumps, neither on a loop nor when the screen changes.
class GameBackground extends StatefulWidget {
  const GameBackground({
    super.key,
    required this.child,
    this.palette = BackgroundPalette.menu,
    this.focusLetter,
  });

  final Widget child;
  final BackgroundPalette palette;

  /// During a round, most tiles show the round letter.
  final String? focusLetter;

  /// Frozen time used when ambient motion is off (tests, screenshots).
  @visibleForTesting
  static double debugTime = 0;

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with TickerProviderStateMixin {
  /// Shared by all backgrounds so motion continues across screens.
  static final Stopwatch _clock = Stopwatch()..start();

  final ValueNotifier<double> _time = ValueNotifier(GameBackground.debugTime);
  Ticker? _ticker;
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );
  late List<String> _chars = _charsFor(widget.focusLetter);
  late List<String> _previousChars = _chars;

  List<String> _charsFor(String? focus) => [
    for (final (i, tile) in _tiles.indexed)
      focus != null && i % 3 != 2 ? focus : tile.char,
  ];

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
  void didUpdateWidget(GameBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusLetter != widget.focusLetter) {
      _previousChars = _chars;
      _chars = _charsFor(widget.focusLetter);
      _swap.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _swap.dispose();
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
              child: CustomPaint(
                painter: _BackgroundPainter(
                  chars: _chars,
                  previousChars: _previousChars,
                  time: _time,
                  swap: _swap,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- scenery

class _Tile {
  _Tile(
    this.char,
    this.x,
    this.y,
    this.depth,
    this.speed,
    this.phase,
    this.color,
  );

  final String char;
  final double x, y, phase;

  /// 0 = far away (small, faint, slow), 1 = close (big, bright, fast).
  final double depth;
  final double speed;
  final Color color;

  double get size => 30 + depth * 46;
  double get opacity => 0.13 + depth * 0.25;
}

class _Blob {
  const _Blob(this.radius, this.fx, this.fy, this.phase, this.color);

  final double radius, fx, fy, phase;
  final Color color;
}

class _Sparkle {
  const _Sparkle(this.x, this.y, this.size, this.speed, this.phase);

  final double x, y, size, speed, phase;
}

const _tileColors = [
  AppColors.yellow,
  AppColors.pink,
  AppColors.cyan,
  AppColors.green,
  AppColors.orange,
  AppColors.white,
];

/// Number of floating letter tiles.
const floatingLetterCount = 14;

final List<_Tile> _tiles = () {
  final random = Random(42);
  const alphabet = 'ABCDEFGHIJKLMNOPRSTUVWXYZ';
  return List.generate(floatingLetterCount, (i) {
    // Alternate far and near layers for a parallax effect.
    final depth = i.isEven
        ? 0.15 + random.nextDouble() * 0.25
        : 0.65 + random.nextDouble() * 0.35;
    return _Tile(
      alphabet[random.nextInt(alphabet.length)],
      random.nextDouble(),
      random.nextDouble(),
      depth,
      0.6 + random.nextDouble() * 0.8,
      random.nextDouble() * 2 * pi,
      _tileColors[i % _tileColors.length],
    );
  });
}();

final List<_Blob> _blobs = () {
  final random = Random(7);
  const colors = [
    Colors.white,
    AppColors.yellow,
    AppColors.cyan,
    AppColors.pink,
    Colors.white,
  ];
  return [
    for (final color in colors)
      _Blob(
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
    26,
    (_) => _Sparkle(
      random.nextDouble(),
      random.nextDouble(),
      1.5 + random.nextDouble() * 3.5,
      0.6 + random.nextDouble() * 1.4,
      random.nextDouble() * 2 * pi,
    ),
  );
}();

/// Where tile [index] is at [seconds] on the shared clock: position and sway
/// angle. Continuous in time, so the drift never jumps.
@visibleForTesting
(double x, double y, double angle) floatingLetterPose(
  int index,
  double seconds,
  Size size,
) {
  final pose = _tilePose(_tiles[index], seconds, size);
  return (pose.x, pose.y, pose.angle);
}

({double x, double y, double angle, double flip}) _tilePose(
  _Tile tile,
  double t,
  Size size,
) {
  final travel = size.height + tile.size * 2 + 40;
  // Near tiles rise faster than far ones (parallax).
  final rise = (8 + 26 * tile.depth) * tile.speed;
  final y = (tile.y * travel - t * rise) % travel - tile.size - 20;
  final x =
      tile.x * size.width +
      sin(t * 0.3 * tile.speed + tile.phase) * (10 + 18 * tile.depth);
  final angle = sin(t * 0.45 + tile.phase) * 0.22;

  // Every 9-15 s a tile spins once like a coin (scaleX goes 1 -> -1 -> 1).
  final period = 9 + 6 * (tile.phase / (2 * pi));
  final progress = ((t + tile.phase * 3) % period) / period;
  const spinShare = 0.09;
  final flip = progress < spinShare ? cos(progress / spinShare * 2 * pi) : 1.0;
  return (x: x, y: y, angle: angle, flip: flip);
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({
    required this.chars,
    required this.previousChars,
    required this.time,
    required this.swap,
  }) : super(repaint: Listenable.merge([time, swap]));

  final List<String> chars;
  final List<String> previousChars;
  final ValueNotifier<double> time;
  final Animation<double> swap;

  static final Map<(String, double, double), TextPainter> _text = {};
  static final List<int> _drawOrder = [
    for (var i = 0; i < _tiles.length; i++) i,
  ]..sort((a, b) => _tiles[a].depth.compareTo(_tiles[b].depth));

  static TextPainter _letter(String char, double size, double opacity) =>
      _text.putIfAbsent((char, size, opacity), () {
        return TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: size * 0.62,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
              color: AppColors.ink.withValues(alpha: opacity),
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    _paintBlobs(canvas, size, t);
    // Far tiles first, near tiles on top.
    for (final i in _drawOrder) {
      _paintTile(canvas, size, t, i);
    }
    _paintSparkles(canvas, size, t);
    _paintShootingStar(canvas, size, t);
  }

  void _paintBlobs(Canvas canvas, Size size, double t) {
    for (final blob in _blobs) {
      final center = Offset(
        size.width * (0.5 + 0.48 * sin(t * blob.fx * 2 * pi / 3 + blob.phase)),
        size.height *
            (0.5 + 0.45 * cos(t * blob.fy * 2 * pi / 3 + blob.phase * 1.7)),
      );
      final radius = size.width * blob.radius;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color.withValues(alpha: 0.16),
            blob.color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintTile(Canvas canvas, Size size, double t, int i) {
    final tile = _tiles[i];
    final pose = _tilePose(tile, t, size);
    final s = tile.size;
    final alpha = tile.opacity;

    canvas.save();
    canvas.translate(pose.x, pose.y);
    canvas.rotate(pose.angle);
    canvas.scale(pose.flip.abs().clamp(0.05, 1.0), 1);

    final face = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s, height: s),
      Radius.circular(s * 0.22),
    );
    canvas.drawRRect(
      face.shift(Offset(0, s * 0.1)),
      Paint()..color = AppColors.depthOf(tile.color).withValues(alpha: alpha),
    );
    canvas.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              tile.color,
              Colors.white,
              0.35,
            )!.withValues(alpha: alpha),
            tile.color.withValues(alpha: alpha),
          ],
        ).createShader(face.outerRect),
    );

    // The letter is hidden while the tile shows its edge or back.
    if (pose.flip > 0.25) {
      final mix = swap.value;
      void letter(String char, double weight) {
        if (weight <= 0.02) return;
        final painter = _letter(char, s, (alpha + 0.25).clamp(0.0, 1.0));
        final offset = Offset(-painter.width / 2, -painter.height / 2);
        if (weight >= 0.98) {
          painter.paint(canvas, offset);
          return;
        }
        // Only while letters cross-fade (a fraction of a second).
        canvas.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, weight),
        );
        painter.paint(canvas, offset);
        canvas.restore();
      }

      if (previousChars[i] == chars[i] || mix >= 1) {
        letter(chars[i], 1);
      } else {
        letter(previousChars[i], 1 - mix);
        letter(chars[i], mix);
      }
    }
    canvas.restore();
  }

  void _paintSparkles(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (final sparkle in _sparkles) {
      final twinkle = pow(
        max(0.0, sin(t * sparkle.speed + sparkle.phase)),
        6,
      ).toDouble();
      if (twinkle < 0.02) continue;
      final center = Offset(
        sparkle.x * size.width,
        (sparkle.y * size.height - t * 4) % size.height,
      );
      final r = sparkle.size * (0.6 + 0.6 * twinkle);
      paint.color = Colors.white.withValues(alpha: 0.85 * twinkle);
      // Four-pointed star.
      final path = Path()
        ..moveTo(center.dx, center.dy - r * 2)
        ..quadraticBezierTo(center.dx, center.dy, center.dx + r * 2, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + r * 2)
        ..quadraticBezierTo(center.dx, center.dy, center.dx - r * 2, center.dy)
        ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - r * 2);
      canvas.drawPath(path, paint);
    }
  }

  void _paintShootingStar(Canvas canvas, Size size, double t) {
    const period = 7.0;
    const flight = 1.1;
    final cycle = (t / period).floor();
    final local = t - cycle * period;
    if (t <= 0 || local > flight) return;
    final p = Curves.easeOut.transform(local / flight);
    final random = Random(cycle);
    final start = Offset(
      size.width * (0.1 + random.nextDouble() * 0.5),
      size.height * (0.05 + random.nextDouble() * 0.25),
    );
    final direction = Offset(size.width * 0.55, size.height * 0.18);
    final head = start + direction * p;
    final tail = start + direction * max(0.0, p - 0.25);
    final fade = 1 - p;
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.9 * fade),
          ],
        ).createShader(Rect.fromPoints(tail, head)),
    );
    canvas.drawCircle(
      head,
      3,
      Paint()..color = Colors.white.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) =>
      oldDelegate.chars != chars || oldDelegate.previousChars != previousChars;
}
