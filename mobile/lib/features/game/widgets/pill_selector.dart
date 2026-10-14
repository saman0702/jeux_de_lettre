import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Row of chunky toggle pills; selected pills are raised and yellow.
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.options,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  final List<T> options;
  final bool Function(T option) isSelected;
  final String Function(T option) label;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final option in options)
          _Pill(
            label: label(option),
            selected: isSelected(option),
            onTap: () {
              final feedback = GameFeedbackScope.of(context);
              feedback.play(Sfx.tap);
              feedback.haptic(Haptic.light);
              onTap(option);
            },
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.yellow : AppColors.cloud;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        transform: Matrix4.translationValues(0, selected ? 0 : 3, 0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.depthOf(AppColors.yellow)
                  : const Color(0xFFDCD3F2),
              offset: Offset(0, selected ? 4 : 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: fredoka(
            size: 16,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
