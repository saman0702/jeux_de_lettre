import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_card.dart';

/// Carte de réglages compacte : un titre et ses options.
class OptionSection extends StatelessWidget {
  const OptionSection({
    super.key,
    required this.index,
    required this.title,
    required this.child,
  });

  /// Position dans la liste, pour l'apparition décalée.
  final int index;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BounceIn(
        delay: Duration(milliseconds: 60 * index),
        from: 0.85,
        slideY: 0.3,
        child: GameCard(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: fredoka(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
