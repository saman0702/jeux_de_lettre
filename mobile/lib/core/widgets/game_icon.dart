import 'dart:math';

import 'package:flutter/material.dart';

import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Little looping animations that bring icons to life.
enum IconMotion {
  none,
  bob,
  wiggle,
  swing,
  pulse,
  glow,
  spin,
  shake,
  flicker,
  look,
  tick,
  waddle,
}

/// Every pictogram of the game. Drawn by the app (not emojis), so they look
/// the same on every phone and move like game icons.
enum GameIconKind {
  city(Icons.location_city_rounded, IconMotion.bob),
  country(Icons.public_rounded, IconMotion.wiggle),
  animal(Icons.pets_rounded, IconMotion.waddle),
  fruit(null, IconMotion.swing),
  hint(Icons.lightbulb_rounded, IconMotion.glow),
  bot(Icons.smart_toy_rounded, IconMotion.bob),
  bolt(Icons.bolt_rounded, IconMotion.flicker),
  trophy(Icons.emoji_events_rounded, IconMotion.glow),
  timer(Icons.timer_rounded, IconMotion.tick),
  door(Icons.door_front_door_rounded, IconMotion.wiggle),
  check(Icons.check_circle_rounded, IconMotion.pulse),
  eyes(Icons.visibility_rounded, IconMotion.look),
  writing(Icons.edit_rounded, IconMotion.wiggle),
  offline(Icons.wifi_off_rounded, IconMotion.flicker),
  key(Icons.vpn_key_rounded, IconMotion.wiggle),
  smile(Icons.sentiment_very_satisfied_rounded, IconMotion.bob),
  search(Icons.search_rounded, IconMotion.look),
  empty(Icons.weekend_rounded, IconMotion.bob),
  person(Icons.person_rounded, IconMotion.none),
  group(Icons.groups_rounded, IconMotion.bob),
  duel(Icons.sports_kabaddi_rounded, IconMotion.shake),
  public(Icons.public_rounded, IconMotion.spin),
  private(Icons.lock_rounded, IconMotion.wiggle),
  sound(Icons.volume_up_rounded, IconMotion.pulse),
  music(Icons.music_note_rounded, IconMotion.swing),
  vibration(Icons.vibration_rounded, IconMotion.shake),
  keyboard(Icons.keyboard_rounded, IconMotion.bob),
  voice(Icons.record_voice_over_rounded, IconMotion.pulse),
  settings(Icons.settings_rounded, IconMotion.spin),
  warning(Icons.warning_amber_rounded, IconMotion.shake),
  crown(null, IconMotion.bob),
  medal1(null, IconMotion.swing),
  medal2(null, IconMotion.swing),
  medal3(null, IconMotion.swing);

  const GameIconKind(this.icon, this.motion);

  /// Material glyph, or null for icons drawn by hand.
  final IconData? icon;
  final IconMotion motion;

  static GameIconKind medal(int place) =>
      [medal1, medal2, medal3][place.clamp(1, 3) - 1];
}

/// An animated pictogram. Motion stops when ambient motion is off (tests).
class GameIcon extends StatefulWidget {
  const GameIcon(
    this.kind, {
    super.key,
    this.size = 28,
    this.color = AppColors.white,
    this.motion,
  });

  final GameIconKind kind;
  final double size;
  final Color color;

  /// Overrides the icon's own motion.
  final IconMotion? motion;

  @override
  State<GameIcon> createState() => _GameIconState();
}

class _GameIconState extends State<GameIcon>
    with SingleTickerProviderStateMixin {
  static final _random = Random();

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _durationOf(_motion),
  );

  IconMotion get _motion => widget.motion ?? widget.kind.motion;

  static Duration _durationOf(IconMotion motion) => switch (motion) {
    IconMotion.shake ||
    IconMotion.flicker => const Duration(milliseconds: 1600),
    IconMotion.spin => const Duration(seconds: 8),
    IconMotion.tick => const Duration(seconds: 2),
    _ => const Duration(milliseconds: 2200),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        GameFeedbackScope.of(context).ambientMotion &&
        _motion != IconMotion.none;
    if (animate && !_loop.isAnimating) {
      // Start at a random point so a row of icons does not move in lockstep.
      _loop.value = _random.nextDouble();
      _loop.repeat();
    } else if (!animate) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final glyph = _Glyph(kind: widget.kind, size: size, color: widget.color);
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: _loop,
        child: glyph,
        builder: (context, child) => _move(_motion, _loop.value, size, child!),
      ),
    );
  }

  /// Applies a motion at loop progress [t] (0..1).
  static Widget _move(IconMotion motion, double t, double size, Widget child) {
    final wave = sin(t * 2 * pi);
    switch (motion) {
      case IconMotion.none:
        return child;
      case IconMotion.bob:
        return Transform.translate(
          offset: Offset(0, wave * size * 0.06),
          child: child,
        );
      case IconMotion.wiggle:
        return Transform.rotate(angle: wave * 0.12, child: child);
      case IconMotion.waddle:
        return Transform.translate(
          offset: Offset(0, -(sin(t * 4 * pi)).abs() * size * 0.06),
          child: Transform.rotate(angle: wave * 0.14, child: child),
        );
      case IconMotion.swing:
        return Transform.rotate(
          alignment: Alignment.topCenter,
          angle: wave * 0.18,
          child: child,
        );
      case IconMotion.pulse:
        return Transform.scale(
          scale: 1 + 0.08 * (0.5 + 0.5 * wave),
          child: child,
        );
      case IconMotion.glow:
        final strength = 0.5 + 0.5 * wave;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size * 0.7,
              height: size * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.yellow.withValues(
                      alpha: 0.25 + 0.45 * strength,
                    ),
                    blurRadius: size * 0.45,
                    spreadRadius: size * 0.05,
                  ),
                ],
              ),
            ),
            Transform.scale(scale: 1 + 0.06 * strength, child: child),
          ],
        );
      case IconMotion.spin:
        return Transform.rotate(angle: t * 2 * pi, child: child);
      case IconMotion.shake:
        // Short bursts of shaking, then rest.
        final burst = t < 0.25 ? sin(t * 40 * pi) * (1 - t / 0.25) : 0.0;
        return Transform.translate(
          offset: Offset(burst * size * 0.08, 0),
          child: child,
        );
      case IconMotion.flicker:
        final dim = (t > 0.62 && t < 0.66) || (t > 0.72 && t < 0.75);
        return Opacity(
          opacity: dim ? 0.35 : 1,
          child: Transform.scale(scale: dim ? 0.92 : 1, child: child),
        );
      case IconMotion.look:
        return Transform.translate(
          offset: Offset(wave * size * 0.08, 0),
          child: child,
        );
      case IconMotion.tick:
        // The timer jumps a notch each second.
        final step = (t * 2).floor();
        return Transform.rotate(
          angle: (step.isEven ? -1 : 1) * 0.1,
          child: child,
        );
    }
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.kind, required this.size, required this.color});

  final GameIconKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shadow = [
      Shadow(
        color: const Color(0x55000000),
        offset: Offset(0, size * 0.05),
        blurRadius: 0,
      ),
    ];
    final icon = kind.icon;
    if (icon != null) {
      return Icon(icon, size: size, color: color, shadows: shadow);
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _DrawnIcon(kind, color),
    );
  }
}

/// Hand-drawn icons that Material does not provide.
class _DrawnIcon extends CustomPainter {
  _DrawnIcon(this.kind, this.color);

  final GameIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case GameIconKind.fruit:
        _apple(canvas, size);
      case GameIconKind.crown:
        _crown(canvas, size);
      case GameIconKind.medal1:
        _medal(canvas, size, 1, const Color(0xFFFFC93C));
      case GameIconKind.medal2:
        _medal(canvas, size, 2, const Color(0xFFD5DCE8));
      case GameIconKind.medal3:
        _medal(canvas, size, 3, const Color(0xFFE59A5B));
      default:
        break;
    }
  }

  void _apple(Canvas canvas, Size s) {
    final w = s.width;
    final body = Path()
      ..moveTo(w * 0.5, w * 0.3)
      ..cubicTo(w * 0.2, w * 0.12, w * 0.02, w * 0.38, w * 0.12, w * 0.62)
      ..cubicTo(w * 0.2, w * 0.86, w * 0.38, w * 0.96, w * 0.5, w * 0.88)
      ..cubicTo(w * 0.62, w * 0.96, w * 0.8, w * 0.86, w * 0.88, w * 0.62)
      ..cubicTo(w * 0.98, w * 0.38, w * 0.8, w * 0.12, w * 0.5, w * 0.3)
      ..close();
    canvas.drawPath(
      body.shift(Offset(0, w * 0.05)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawPath(body, Paint()..color = color);
    // Stem and leaf.
    canvas.drawLine(
      Offset(w * 0.5, w * 0.3),
      Offset(w * 0.55, w * 0.1),
      Paint()
        ..color = color
        ..strokeWidth = w * 0.08
        ..strokeCap = StrokeCap.round,
    );
    final leaf = Path()
      ..moveTo(w * 0.56, w * 0.18)
      ..quadraticBezierTo(w * 0.78, w * 0.02, w * 0.86, w * 0.16)
      ..quadraticBezierTo(w * 0.72, w * 0.3, w * 0.56, w * 0.18)
      ..close();
    canvas.drawPath(leaf, Paint()..color = color);
    // Shine.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.24, w * 0.42, w * 0.12, w * 0.2),
      Paint()
        ..color = (color == AppColors.white ? AppColors.ink : AppColors.white)
            .withValues(alpha: 0.25),
    );
  }

  void _crown(Canvas canvas, Size s) {
    final w = s.width;
    final path = Path()
      ..moveTo(w * 0.1, w * 0.78)
      ..lineTo(w * 0.06, w * 0.3)
      ..lineTo(w * 0.32, w * 0.52)
      ..lineTo(w * 0.5, w * 0.18)
      ..lineTo(w * 0.68, w * 0.52)
      ..lineTo(w * 0.94, w * 0.3)
      ..lineTo(w * 0.9, w * 0.78)
      ..close();
    canvas.drawPath(
      path.shift(Offset(0, w * 0.05)),
      Paint()..color = const Color(0x55B45309),
    );
    canvas.drawPath(path, Paint()..color = AppColors.yellow);
    for (final x in [0.06, 0.5, 0.94]) {
      canvas.drawCircle(
        Offset(w * x, x == 0.5 ? w * 0.18 : w * 0.3),
        w * 0.07,
        Paint()..color = AppColors.yellow,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(w * 0.1, w * 0.7, w * 0.8, w * 0.08),
      Paint()..color = const Color(0xFFE0A800),
    );
  }

  void _medal(Canvas canvas, Size s, int place, Color metal) {
    final w = s.width;
    final ribbon = Paint()
      ..color = place == 1
          ? AppColors.red
          : (place == 2 ? AppColors.cyan : AppColors.green);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, 0)
        ..lineTo(w * 0.44, 0)
        ..lineTo(w * 0.56, w * 0.42)
        ..lineTo(w * 0.4, w * 0.42)
        ..close(),
      ribbon,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.72, 0)
        ..lineTo(w * 0.56, 0)
        ..lineTo(w * 0.44, w * 0.42)
        ..lineTo(w * 0.6, w * 0.42)
        ..close(),
      ribbon..color = ribbon.color.withValues(alpha: 0.8),
    );
    final center = Offset(w * 0.5, w * 0.64);
    canvas.drawCircle(
      center + Offset(0, w * 0.04),
      w * 0.3,
      Paint()..color = AppColors.depthOf(metal),
    );
    canvas.drawCircle(center, w * 0.3, Paint()..color = metal);
    canvas.drawCircle(
      center,
      w * 0.22,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03,
    );
    final number = TextPainter(
      text: TextSpan(
        text: '$place',
        style: fredoka(
          size: w * 0.3,
          weight: FontWeight.w700,
          color: AppColors.ink,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    number.paint(canvas, center - Offset(number.width / 2, number.height / 2));
  }

  @override
  bool shouldRepaint(_DrawnIcon oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

/// Icon in a round candy badge (category badges, settings rows...).
class GameIconBadge extends StatelessWidget {
  const GameIconBadge(
    this.kind, {
    super.key,
    required this.color,
    this.size = 46,
    this.dimmed = false,
  });

  final GameIconKind kind;
  final Color color;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final base = dimmed ? AppColors.grey : color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(base, Colors.white, 0.35)!, base],
        ),
        border: Border.all(color: AppColors.white, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.depthOf(base), offset: const Offset(0, 3)),
        ],
      ),
      child: GameIcon(
        kind,
        size: size * 0.56,
        motion: dimmed ? IconMotion.none : null,
      ),
    );
  }
}
