import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Pastille bonbon « QUITTER » pour sortir d'une partie en cours (demande
/// confirmation).
class QuitButton extends StatefulWidget {
  const QuitButton({super.key, required this.onQuit});

  final VoidCallback onQuit;

  @override
  State<QuitButton> createState() => _QuitButtonState();
}

class _QuitButtonState extends State<QuitButton> {
  static const _depth = 4.0;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).quit.toUpperCase();
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: const Key('quit_button'),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          GameFeedbackScope.of(context).play(Sfx.tap);
          widget.onQuit();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          margin: EdgeInsets.only(
            top: _pressed ? _depth - 1 : 0,
            bottom: _pressed ? 1 : _depth,
          ),
          padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.white, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(AppColors.red, Colors.white, 0.3)!,
                AppColors.red,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.depthOf(AppColors.red),
                offset: Offset(0, _pressed ? 1 : _depth),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close_rounded, color: AppColors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: fredoka(
                  size: 14,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Place un [QuitButton] au-dessus des écrans qui n'ont pas d'en-tête (compte à
/// rebours, résultats, attente).
class WithQuitButton extends StatelessWidget {
  const WithQuitButton({super.key, required this.onQuit, required this.child});

  final VoidCallback onQuit;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: QuitButton(onQuit: onQuit),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
