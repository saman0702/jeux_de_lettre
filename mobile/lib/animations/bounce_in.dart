import 'package:flutter/material.dart';

/// Pops a widget in (scale + fade), optionally after a delay, without timers
/// so tests can settle.
class BounceIn extends StatefulWidget {
  const BounceIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.from = 0.4,
    this.slideY = 0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double from;

  /// Vertical slide distance, as a fraction of the child's height.
  final double slideY;

  @override
  State<BounceIn> createState() => _BounceInState();
}

class _BounceInState extends State<BounceIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMilliseconds /
          (widget.delay + widget.duration).inMilliseconds,
      1,
      curve: Curves.easeOutBack,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: FractionalTranslation(
            translation: Offset(0, widget.slideY * (1 - t)),
            child: Transform.scale(
              scale: widget.from + (1 - widget.from) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
