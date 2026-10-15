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

/// Gradient with big translucent letters drifting slowly upwards.
///
/// The drift follows one clock shared by every screen, so letters never jump
/// back to a starting position: not when a loop would restart, nor when the
/// player moves to another screen. Palette and letters blend smoothly.
class GameBackground extends StatefulWidget {
  const GameBackground({
    super.key,
    required this.child,
    this.palette = BackgroundPalette.menu,
    this.focusLetter,
  });

  final Widget child;
  final BackgroundPalette palette;

  /// During a round, most floating letters show the round letter.
  final String? focusLetter;

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with TickerProviderStateMixin {
  /// Shared by all backgrounds so motion continues across screens.
  static final Stopwatch _clock = Stopwatch()..start();
  static final List<_FloatingLetter> _letters = _FloatingLetter.generate(
    floatingLetterCount,
  );

  final ValueNotifier<double> _time = ValueNotifier(0);
  Ticker? _ticker;
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );
  late List<String> _chars = _charsFor(widget.focusLetter);
  late List<String> _previousChars = _chars;

  List<String> _charsFor(String? focus) => [
    for (final (i, letter) in _letters.indexed)
      focus != null && i % 3 != 2 ? focus : letter.char,
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
                painter: _LettersPainter(
                  letters: _letters,
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

/// Where floating letter [index] is at [seconds] on the shared clock:
/// a continuous function of time, so the drift never jumps.
@visibleForTesting
(double x, double y, double angle) floatingLetterPose(
  int index,
  double seconds,
  Size size,
) {
  final letter = _GameBackgroundState._letters[index];
  final travel = size.height + 160;
  // Pixels per second; letters only wrap around while off-screen.
  final y =
      (letter.y * travel - seconds * (10 + 14 * letter.speed)) % travel - 80;
  final x =
      letter.x * size.width +
      sin(seconds * 0.35 * letter.speed + letter.phase) * 16;
  final angle =
      letter.spin * 0.4 +
      sin(seconds * 0.25 + letter.phase) * 0.12 * letter.spin;
  return (x, y, angle);
}

/// Number of floating letters.
const floatingLetterCount = 14;

class _FloatingLetter {
  _FloatingLetter(
    this.char,
    this.x,
    this.y,
    this.size,
    this.speed,
    this.spin,
    this.opacity,
    this.phase,
  );

  final String char;
  final double x, y, size, speed, spin, opacity, phase;

  static List<_FloatingLetter> generate(int count) {
    final random = Random(42);
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return List.generate(
      count,
      (_) => _FloatingLetter(
        alphabet[random.nextInt(alphabet.length)],
        random.nextDouble(),
        random.nextDouble(),
        40 + random.nextDouble() * 70,
        0.5 + random.nextDouble(),
        (random.nextDouble() - 0.5) * 2,
        0.06 + random.nextDouble() * 0.08,
        random.nextDouble() * 2 * pi,
      ),
    );
  }
}

class _LettersPainter extends CustomPainter {
  _LettersPainter({
    required this.letters,
    required this.chars,
    required this.previousChars,
    required this.time,
    required this.swap,
  }) : super(repaint: Listenable.merge([time, swap]));

  final List<_FloatingLetter> letters;
  final List<String> chars;
  final List<String> previousChars;
  final ValueNotifier<double> time;
  final Animation<double> swap;

  static final Map<(String, double, double), TextPainter> _cache = {};

  static TextPainter _painter(String char, double size, double opacity) =>
      _cache.putIfAbsent((char, size, opacity), () {
        return TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: size,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
              color: Colors.white.withValues(alpha: opacity),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final mix = swap.value;
    for (var i = 0; i < letters.length; i++) {
      final letter = letters[i];
      final (x, y, angle) = floatingLetterPose(i, t, size);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      void draw(String char, double alpha) {
        if (alpha <= 0.01) return;
        final p = _painter(char, letter.size, letter.opacity);
        final offset = Offset(-p.width / 2, -p.height / 2);
        if (alpha >= 0.99) {
          p.paint(canvas, offset);
          return;
        }
        // Only while letters cross-fade (a fraction of a second).
        canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
        p.paint(canvas, offset);
        canvas.restore();
      }

      if (previousChars[i] == chars[i] || mix >= 1) {
        draw(chars[i], 1);
      } else {
        draw(previousChars[i], 1 - mix);
        draw(chars[i], mix);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LettersPainter oldDelegate) =>
      oldDelegate.chars != chars || oldDelegate.previousChars != previousChars;
}
