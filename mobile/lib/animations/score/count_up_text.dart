import 'package:flutter/material.dart';

/// Animates an integer from [from] to [value].
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.from = 0,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    this.textKey,
    this.textAlign,
  });

  final int value;
  final int from;
  final String Function(int value) format;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final Key? textKey;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final total = delay + duration;
    final start = total.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, t, _) {
        final progress = Curves.easeOutCubic.transform(
          ((t - start) / (1 - start)).clamp(0, 1),
        );
        final shown = (from + (value - from) * progress).round();
        return Text(
          format(shown),
          key: textKey,
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}
