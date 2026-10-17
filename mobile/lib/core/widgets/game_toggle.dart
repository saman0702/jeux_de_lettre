import 'package:flutter/material.dart';

import '../audio/game_audio.dart';
import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';

/// Gros interrupteur ON/OFF : le bouton glisse en rebondissant et affiche ✓ ou
/// ✕.
class GameToggle extends StatelessWidget {
  const GameToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const _width = 66.0;
  static const _height = 36.0;
  static const _depth = 4.0;

  @override
  Widget build(BuildContext context) {
    final track = value ? AppColors.green : AppColors.grey;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () {
          final feedback = GameFeedbackScope.of(context);
          feedback.play(Sfx.tap);
          feedback.haptic(Haptic.light);
          onChanged(!value);
        },
        child: SizedBox(
          width: _width,
          height: _height + _depth,
          child: Stack(
            children: [
              Positioned(
                top: _depth,
                left: 0,
                right: 0,
                height: _height,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: AppColors.depthOf(track),
                    borderRadius: BorderRadius.circular(_height / 2),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_height / 2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(track, Colors.white, 0.3)!, track],
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 380),
                curve: Curves.elasticOut,
                alignment: value ? Alignment.topRight : Alignment.topLeft,
                child: Container(
                  width: _height - 6,
                  height: _height - 6,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.depthOf(track),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    value ? Icons.check_rounded : Icons.close_rounded,
                    size: 18,
                    color: track,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
