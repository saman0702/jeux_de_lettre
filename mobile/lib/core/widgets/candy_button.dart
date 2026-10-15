import 'package:flutter/material.dart';

import '../audio/game_audio.dart';
import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'game_icon.dart';

/// Chunky 3D button that sinks when pressed, with a click sound and a tap haptic.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.yellow,
    this.textColor = AppColors.ink,
    this.icon,
    this.gameIcon,
    this.badge,
    this.loading = false,
    this.fontSize = 22,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;

  /// Animated game icon shown instead of [icon].
  final GameIconKind? gameIcon;

  /// Small sticker in the corner, e.g. "Bientôt".
  final String? badge;
  final bool loading;
  final double fontSize;
  final double height;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  static const _depth = 6.0;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (_enabled && _pressed != value) setState(() => _pressed = value);
  }

  void _tap() {
    if (!_enabled) return;
    final feedback = GameFeedbackScope.of(context);
    feedback.play(Sfx.tap);
    feedback.haptic(Haptic.light);
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final color = _enabled ? widget.color : AppColors.grey;
    final offset = _pressed ? _depth - 2 : 0.0;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _tap,
        child: SizedBox(
          height: widget.height + _depth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: _depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.depthOf(color),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: offset,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                    ),
                  ),
                  child: Center(child: _content()),
                ),
              ),
              if (widget.badge != null)
                Positioned(
                  top: -8 + offset,
                  right: 14,
                  child: Transform.rotate(
                    angle: 0.08,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pink,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: Text(
                        widget.badge!,
                        style: fredoka(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (widget.loading) {
      return SizedBox.square(
        dimension: 26,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: widget.textColor,
        ),
      );
    }
    final text = Text(
      widget.label,
      style: fredoka(
        size: widget.fontSize,
        weight: FontWeight.w700,
        color: widget.textColor,
      ),
    );
    final gameIcon = widget.gameIcon;
    if (widget.icon == null && gameIcon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gameIcon != null)
          GameIcon(gameIcon, color: widget.textColor, size: widget.fontSize + 6)
        else
          Icon(widget.icon, color: widget.textColor, size: widget.fontSize + 4),
        const SizedBox(width: 10),
        text,
      ],
    );
  }
}

/// Round candy button (back, settings...): it sinks when pressed and its
/// icon can spin, like a game menu button.
class RoundIconButton extends StatefulWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AppColors.white,
    this.iconColor = AppColors.purple,
    this.spinOnTap = false,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color color;
  final Color iconColor;

  /// Gives the icon a full turn on tap (settings gear).
  final bool spinOnTap;
  final double size;

  @override
  State<RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<RoundIconButton>
    with SingleTickerProviderStateMixin {
  static const _depth = 5.0;
  bool _pressed = false;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _tap() {
    final feedback = GameFeedbackScope.of(context);
    feedback.play(Sfx.tap);
    feedback.haptic(Haptic.light);
    if (widget.spinOnTap) _spin.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = widget.color;
    final offset = _pressed ? _depth - 1 : 0.0;
    return Tooltip(
      message: widget.tooltip ?? '',
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _tap,
          child: SizedBox(
            width: size,
            height: size + _depth,
            child: Stack(
              children: [
                Positioned(
                  top: _depth,
                  left: 0,
                  right: 0,
                  height: size,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.depthOf(color),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 70),
                  top: offset,
                  left: 0,
                  right: 0,
                  height: size,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2.5),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                      ),
                    ),
                    child: Center(
                      child: RotationTransition(
                        turns: CurvedAnimation(
                          parent: _spin,
                          curve: Curves.easeOutBack,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.iconColor,
                          size: size * 0.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
