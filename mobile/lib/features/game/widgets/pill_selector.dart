import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_icon.dart';

/// Rangée de grosses pastilles à choisir ; celles sélectionnées sont en relief
/// et jaunes.
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.options,
    required this.isSelected,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  final List<T> options;
  final bool Function(T option) isSelected;
  final String Function(T option) label;
  final ValueChanged<T> onTap;

  /// Icône animée facultative avant le libellé.
  final GameIconKind? Function(T option)? icon;
  final Color Function(T option)? iconColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final option in options)
          _Pill(
            label: label(option),
            icon: icon?.call(option),
            iconColor: iconColor?.call(option) ?? AppColors.purple,
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
    this.icon,
    this.iconColor = AppColors.purple,
  });

  final String label;
  final GameIconKind? icon;
  final Color iconColor;
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        transform: Matrix4.translationValues(0, selected ? 0 : 3, 0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.depthOf(AppColors.yellow)
                  : const Color(0xFFDCD3F2),
              offset: Offset(0, selected ? 4 : 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              GameIcon(
                icon!,
                size: 20,
                color: selected ? iconColor : iconColor.withValues(alpha: 0.6),
                motion: selected ? null : IconMotion.none,
              ),
              if (label.isNotEmpty) const SizedBox(width: 6),
            ],
            if (label.isNotEmpty)
              Text(
                label,
                style: fredoka(
                  size: 15,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
