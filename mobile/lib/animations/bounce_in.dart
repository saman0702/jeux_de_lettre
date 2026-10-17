import 'package:flutter/material.dart';

/// Fait apparaître un widget (échelle + fondu), éventuellement après un délai,
/// sans minuteur pour que les tests puissent se stabiliser.
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

  /// Distance de glissement vertical, en fraction de la hauteur de l'enfant.
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
