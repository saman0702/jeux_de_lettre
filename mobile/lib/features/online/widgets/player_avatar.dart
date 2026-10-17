import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/widgets/game_icon.dart';
import '../../avatar/drawn_avatar.dart';
import '../data/room_models.dart';
import '../../shop/look_styles.dart';

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

/// Avatar rond du joueur : sa photo dessinée, son personnage, ou à défaut son
/// initiale. Grisé quand il est déconnecté.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.nickname,
    required this.seed,
    this.size = 52,
    this.connected = true,
    this.bot = false,
    this.preset,
    this.photoUrl,
    this.frame = '',
    this.hair = '',
    this.hat = '',
  });

  /// L'avatar d'un joueur de la salle.
  PlayerAvatar.of(RoomPlayer player, {Key? key, double size = 52})
    : this(
        key: key,
        nickname: player.nickname,
        seed: player.clientId,
        size: size,
        connected: player.connected,
        bot: player.bot,
        preset: player.avatarPreset,
        photoUrl: player.avatarUrl,
        frame: player.frame,
        hair: player.hair,
        hat: player.hat,
      );

  /// Personnage dessiné choisi par le joueur.
  final int? preset;

  /// Photo transformée en dessin par le serveur (chemin relatif).
  final String? photoUrl;

  /// Cadre coloré / orné acheté (identifiant), ou vide.
  final String frame;

  /// Coiffure boutique (identifiant), ou vide.
  final String hair;

  /// Chapeau / couronne boutique (identifiant), ou vide.
  final String hat;

  final String nickname;
  final String seed;
  final double size;
  final bool connected;

  /// Les adversaires ordinateur affichent un robot au lieu de leur initiale.
  final bool bot;

  static const _botColor = Color(0xFF9DB4D6);

  @override
  Widget build(BuildContext context) {
    if (!bot && (preset != null || photoUrl != null)) {
      return _framed(_pictureContent());
    }
    final color = bot
        ? _botColor
        : (connected ? avatarColor(seed) : AppColors.grey);
    final face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: color,
      child: bot
          ? GameIcon(GameIconKind.bot, size: size * 0.58, color: AppColors.ink)
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
    return _framed(face, shadowColor: color);
  }

  Widget _framed(Widget face, {Color? shadowColor}) {
    final shadow = shadowColor ?? drawnAvatarColor(preset ?? 0);
    final content = !connected
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.33, 0.33, 0.33, 0, 0, //
              0.33, 0.33, 0.33, 0, 0, //
              0.33, 0.33, 0.33, 0, 0, //
              0, 0, 0, 0.7, 0,
            ]),
            child: face,
          )
        : face;

    final framed = frame.isEmpty
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.depthOf(shadow),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: content),
          )
        : AvatarFrameLayer(
            frameId: frame,
            size: size,
            child: content,
          );

    if (frame.isEmpty) return framed;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(shadow),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: framed,
    );
  }

  Widget _pictureContent() {
    final drawn = DrawnAvatar(
      preset: preset ?? 0,
      size: size,
      hairId: hair,
      hatId: hat,
    );
    if (photoUrl == null) return drawn;
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.network(
          photoUrl!.startsWith('http') ? photoUrl! : '$apiBaseUrl$photoUrl',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => drawn,
        ),
        if (hat.isNotEmpty) AvatarHatLayer(hatId: hat, size: size),
      ],
    );
  }
}
