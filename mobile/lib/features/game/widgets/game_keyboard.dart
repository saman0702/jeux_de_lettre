import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Dispositions des lettres. Pas d'accents : les réponses sont comparées sans
/// eux.
const _layouts = {
  'fr': ['AZERTYUIOP', 'QSDFGHJKLM', "WXCVBN'-"],
  'en': ['QWERTYUIOP', 'ASDFGHJKL', "ZXCVBNM'-"],
};

/// Clavier du jeu : grosses touches bonbon qui s'enfoncent et ressortent quand
/// on appuie. La lettre de la manche est mise en valeur pour trouver tout de
/// suite la première touche.
class GameKeyboard extends StatelessWidget {
  const GameKeyboard({
    super.key,
    required this.letter,
    required this.onKey,
    required this.onBackspace,
    required this.onNext,
    required this.onFinish,
    this.enabled = true,
    this.loading = false,
  });

  final String letter;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onNext;
  final VoidCallback onFinish;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final rows = _layouts[language] ?? _layouts['fr']!;

    Widget letters(String row, {Widget? trailing}) => Row(
      children: [
        for (final char in row.split(''))
          Expanded(
            child: _Key(
              key: Key('key_$char'),
              label: char,
              color: char == letter ? AppColors.yellow : AppColors.white,
              enabled: enabled,
              onTap: () => onKey(char),
            ),
          ),
        ?trailing,
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.purpleDeep.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            letters(rows[0]),
            letters(rows[1]),
            letters(
              rows[2],
              trailing: Expanded(
                flex: 2,
                child: _Key(
                  key: const Key('key_backspace'),
                  icon: Icons.backspace_rounded,
                  color: AppColors.red,
                  textColor: AppColors.white,
                  enabled: enabled,
                  repeat: true,
                  onTap: onBackspace,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _Key(
                    key: const Key('key_next'),
                    label: l10n.keyNext,
                    icon: Icons.play_arrow_rounded,
                    iconFirst: false,
                    fontSize: 15,
                    color: AppColors.cyan,
                    enabled: enabled,
                    onTap: onNext,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _Key(
                    key: const Key('key_space'),
                    label: l10n.keySpace,
                    fontSize: 14,
                    color: AppColors.purpleLight,
                    textColor: AppColors.white,
                    enabled: enabled,
                    onTap: () => onKey(' '),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _Key(
                    key: const Key('key_finish'),
                    label: l10n.finish,
                    icon: Icons.check_rounded,
                    fontSize: 15,
                    color: AppColors.green,
                    textColor: AppColors.white,
                    enabled: enabled && !loading,
                    sound: Sfx.finish,
                    onTap: onFinish,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    super.key,
    required this.color,
    required this.onTap,
    this.label,
    this.icon,
    this.textColor = AppColors.ink,
    this.fontSize = 20,
    this.enabled = true,
    this.repeat = false,
    this.sound,
    this.iconFirst = true,
  });

  final String? label;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final double fontSize;
  final bool enabled;

  /// Continue de se déclencher tant qu'on appuie (effacement).
  final bool repeat;

  /// Joué par la touche elle-même ; le son des lettres vient du champ de
  /// réponse.
  final Sfx? sound;

  /// Avec un libellé et une icône : icône avant (true) ou après le libellé.
  final bool iconFirst;
  final VoidCallback onTap;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  static const _height = 48.0;
  static const _depth = 4.0;
  bool _pressed = false;
  Timer? _repeat;

  void _down() {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
    _fire();
    if (widget.repeat) {
      _repeat = Timer(const Duration(milliseconds: 400), () {
        _repeat = Timer.periodic(
          const Duration(milliseconds: 70),
          (_) => _fire(),
        );
      });
    }
  }

  void _up() {
    _repeat?.cancel();
    _repeat = null;
    if (_pressed) setState(() => _pressed = false);
  }

  void _fire() {
    final sound = widget.sound;
    if (sound != null) GameFeedbackScope.of(context).play(sound);
    widget.onTap();
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? widget.color : AppColors.grey;
    final icon = widget.icon == null
        ? null
        : Icon(
            widget.icon,
            color: widget.textColor,
            size: widget.label == null ? 22 : 20,
          );
    final text = widget.label == null
        ? null
        : Text(
            widget.label!,
            style: fredoka(
              size: widget.fontSize,
              weight: FontWeight.w700,
              color: widget.textColor,
            ),
          );
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.iconFirst) ?icon,
          if (icon != null && text != null) const SizedBox(width: 4),
          ?text,
          if (!widget.iconFirst) ?icon,
        ],
      ),
    );

    return Semantics(
      button: true,
      label: widget.label,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
          child: SizedBox(
            height: _height + _depth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: _depth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.depthOf(color),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 60),
                  left: 0,
                  right: 0,
                  top: _pressed ? _depth - 1 : 0,
                  height: _height,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 90),
                    // La touche grossit un peu sous le doigt, comme dans un
                    // jeu.
                    scale:
                        _pressed &&
                            widget.label != null &&
                            widget.label!.length == 1
                        ? 1.18
                        : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.lerp(color, Colors.white, 0.35)!,
                            color,
                          ],
                        ),
                      ),
                      child: Center(child: content),
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
