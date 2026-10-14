import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// 3, 2, 1, GO! — each step slams in with a shockwave ring and a beep.
class CountdownView extends StatefulWidget {
  const CountdownView({super.key, required this.value});

  /// 3, 2, 1, then 0 for "GO!".
  final int value;

  @override
  State<CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends State<CountdownView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  @override
  void didUpdateWidget(CountdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _announce();
  }

  void _announce() {
    if (!mounted) return;
    final feedback = GameFeedbackScope.of(context);
    if (widget.value > 0) {
      feedback.play(Sfx.countdown);
      feedback.haptic(Haptic.light);
    } else {
      feedback.play(Sfx.go);
      feedback.haptic(Haptic.heavy);
    }
    _wave.forward(from: 0);
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isGo = widget.value == 0;
    final color = switch (widget.value) {
      3 => AppColors.cyan,
      2 => AppColors.pink,
      1 => AppColors.orange,
      _ => AppColors.yellow,
    };

    return Center(
      child: SizedBox.square(
        dimension: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _wave,
              builder: (context, _) => CustomPaint(
                size: const Size.square(300),
                painter: _ShockwavePainter(_wave.value, color),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween(begin: 2.4, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Container(
                key: ValueKey(widget.value),
                width: isGo ? 230 : 170,
                height: 170,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(isGo ? 48 : 85),
                  border: Border.all(color: AppColors.white, width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.depthOf(color),
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  isGo ? l10n.go : '${widget.value}',
                  style: fredoka(
                    size: isGo ? 64 : 100,
                    weight: FontWeight.w700,
                    color: isGo ? AppColors.ink : AppColors.white,
                    height: 1,
                    shadows: isGo ? null : textShadow,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShockwavePainter extends CustomPainter {
  _ShockwavePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final center = size.center(Offset.zero);
    for (final lag in [0.0, 0.18]) {
      final p = ((t - lag) / (1 - lag)).clamp(0.0, 1.0);
      if (p == 0) continue;
      canvas.drawCircle(
        center,
        80 + p * 70,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 * (1 - p)
          ..color = Color.lerp(
            color,
            Colors.white,
            0.4,
          )!.withValues(alpha: 1 - p),
      );
    }
  }

  @override
  bool shouldRepaint(_ShockwavePainter oldDelegate) => oldDelegate.t != t;
}
