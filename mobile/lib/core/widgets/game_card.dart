import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// White rounded card with a soft purple "depth" underneath.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x40250E6B), offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
