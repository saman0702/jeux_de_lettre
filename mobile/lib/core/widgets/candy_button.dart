import 'package:flutter/material.dart';

import '../audio/game_audio.dart';
import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Chunky 3D button that sinks when pressed, with a click sound and a tap haptic.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.yellow,
    this.textColor = AppColors.ink,
    this.icon,
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
    if (widget.icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, color: widget.textColor, size: widget.fontSize + 4),
        const SizedBox(width: 10),
        text,
      ],
    );
  }
}

/// Round white icon button used for back / settings.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppColors.white.withValues(alpha: 0.2),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            GameFeedbackScope.of(context).play(Sfx.tap);
            onPressed();
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppColors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
