import 'package:flutter/material.dart';

import '../audio/game_audio.dart';
import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'game_icon.dart';

/// Bouton plat avec un léger relief : s'enfonce un peu à l'appui, clic sonore
/// et vibration légère.
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
    // Aligné sur les boutons salon (podium / freeze / lobby).
    this.fontSize = 16,
    this.height = 44,
    /// Si défini : texte multiligne (pas de FittedBox qui rapetisse trop).
    this.maxLines,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;

  /// Icône de jeu animée affichée à la place de [icon].
  final GameIconKind? gameIcon;

  /// Petite pastille dans le coin, ex. « Bientôt ».
  final String? badge;
  final bool loading;
  final double fontSize;
  final double height;
  final int? maxLines;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  /// Relief discret : assez pour sentir l'appui, sans look « bonbon » 3D.
  static const _depth = 2.0;
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
    final offset = _pressed ? _depth : 0.0;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _tap,
        // Enfant non positionné pour donner une largeur intrinsèque (Row sans
        // Expanded). Sous contraintes serrées (Expanded), le Stack s'étire.
        child: SizedBox(
          height: widget.height + _depth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(top: _depth),
                child: Opacity(
                  opacity: 0,
                  child: _face(color: color, child: _labelChild()),
                ),
              ),
              Positioned.fill(
                top: _depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.depthOf(color),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: offset,
                height: widget.height,
                child: _face(color: color, child: _labelChild()),
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

  Widget _face({required Color color, required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grey, width: 1.5),
      ),
      child: SizedBox(
        height: widget.height,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _labelChild() {
    if (widget.maxLines != null) return _content();
    return FittedBox(fit: BoxFit.scaleDown, child: _content());
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
      textAlign: TextAlign.center,
      maxLines: widget.maxLines,
      softWrap: widget.maxLines != null,
      overflow: widget.maxLines != null
          ? TextOverflow.ellipsis
          : TextOverflow.visible,
      style: fredoka(
        size: widget.fontSize,
        weight: FontWeight.w700,
        color: widget.textColor,
        height: widget.maxLines != null ? 1.15 : null,
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
        if (widget.maxLines != null) Flexible(child: text) else text,
      ],
    );
  }
}

/// Bouton rond plat (retour, réglages…) : léger enfoncement à l'appui ; l'icône
/// peut tourner (réglages).
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

  /// Fait faire un tour complet à l'icône au toucher (engrenage des réglages).
  final bool spinOnTap;
  final double size;

  @override
  State<RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<RoundIconButton>
    with SingleTickerProviderStateMixin {
  static const _depth = 2.0;
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
    final offset = _pressed ? _depth : 0.0;
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
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.grey, width: 1.5),
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
