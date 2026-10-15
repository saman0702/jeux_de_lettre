import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

const _avatarColors = [
  AppColors.yellow,
  AppColors.pink,
  AppColors.cyan,
  AppColors.green,
  AppColors.orange,
  AppColors.purpleLight,
];

Color avatarColor(String seed) =>
    _avatarColors[seed.codeUnits.fold<int>(0, (a, b) => a + b) %
        _avatarColors.length];

/// Round avatar with the player's initial; greyed out when disconnected.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.nickname,
    required this.seed,
    this.size = 52,
    this.connected = true,
    this.bot = false,
  });

  final String nickname;
  final String seed;
  final double size;
  final bool connected;

  /// Computer opponents show a robot instead of their initial.
  final bool bot;

  static const _botColor = Color(0xFF9DB4D6);

  @override
  Widget build(BuildContext context) {
    final color = bot
        ? _botColor
        : (connected ? avatarColor(seed) : AppColors.grey);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(color),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: bot
          ? Text('🤖', style: TextStyle(fontSize: size * 0.5, height: 1))
          : Text(
              nickname.isEmpty ? '?' : nickname.characters.first.toUpperCase(),
              style: fredoka(
                size: size * 0.45,
                weight: FontWeight.w700,
                color: AppColors.ink,
                height: 1,
              ),
            ),
    );
  }
}
