import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Carte blanche arrondie avec un léger relief violet en dessous.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(11),
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x40250E6B), offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}
