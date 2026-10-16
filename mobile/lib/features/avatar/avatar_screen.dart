import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/labels.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import '../online/widgets/player_avatar.dart';
import 'drawn_avatar.dart';
import 'profile_api.dart';

/// Photo choisie : contenu et nom du fichier.
typedef PickedPhoto = ({List<int> bytes, String name});

/// Ouvre l'appareil photo ou la galerie ; remplaçable dans les tests.
typedef PhotoPicker = Future<PickedPhoto?> Function(ImageSource source);

Future<PickedPhoto?> pickWithImagePicker(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    // Le serveur recadre en 256 px : inutile d'envoyer plus.
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
    preferredCameraDevice: CameraDevice.front,
  );
  if (file == null) return null;
  return (bytes: await file.readAsBytes(), name: file.name);
}

/// Choix de l'avatar : un personnage dessiné, ou une photo que le serveur
/// transforme en dessin.
class AvatarScreen extends StatefulWidget {
  const AvatarScreen({
    super.key,
    required this.apiClient,
    this.pickPhoto = pickWithImagePicker,
  });

  final ApiClient apiClient;
  final PhotoPicker pickPhoto;

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  bool _busy = false;

  ProfileApi get _profile =>
      ProfileApi(widget.apiClient, OnlineScope.of(context).clientId);

  Future<void> _apply(Future<AvatarChoice> Function() change) async {
    final l10n = AppLocalizations.of(context);
    final online = OnlineScope.of(context);
    final feedback = GameFeedbackScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final avatar = await change();
      online.setAvatar(avatar.preset, avatar.url);
      feedback.play(Sfx.valid);
      messenger.showSnackBar(SnackBar(content: Text(l10n.avatarUpdated)));
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(avatarErrorMessage(l10n, e.code))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photo(ImageSource source) async {
    final picked = await widget.pickPhoto(source);
    if (picked == null || !mounted) return;
    await _apply(() => _profile.uploadPhoto(picked.bytes, picked.name));
  }

  void _preset(int preset) {
    GameFeedbackScope.of(context).play(Sfx.tap);
    _apply(() => _profile.choosePreset(preset));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = OnlineScope.of(context);
    final nickname =
        GameFeedbackScope.of(context).settings.nickname ?? l10n.defaultNickname;

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: online,
            builder: (context, _) => FloatingBarsLayout(
              header: OnlineHeader(
                title: l10n.avatarTitle,
                onBack: () => Navigator.of(context).pop(),
              ),
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PlayerAvatar(
                        key: const Key('my_avatar'),
                        nickname: nickname,
                        seed: online.clientId,
                        size: 128,
                        preset: online.avatarPreset,
                        photoUrl: online.avatarUrl,
                      ),
                      if (_busy)
                        const SizedBox(
                          width: 128,
                          height: 128,
                          child: CircularProgressIndicator(
                            strokeWidth: 6,
                            color: AppColors.yellow,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final (i, (source, label, kind, color)) in [
                      (
                        ImageSource.camera,
                        l10n.avatarCamera,
                        GameIconKind.camera,
                        AppColors.pink,
                      ),
                      (
                        ImageSource.gallery,
                        l10n.avatarGallery,
                        GameIconKind.gallery,
                        AppColors.cyan,
                      ),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: CandyButton(
                          key: Key('avatar_${source.name}'),
                          label: label,
                          gameIcon: kind,
                          color: color,
                          height: 52,
                          fontSize: 17,
                          onPressed: _busy || !online.isOnline
                              ? null
                              : () => _photo(source),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.avatarPhotoInfo,
                  textAlign: TextAlign.center,
                  style: fredoka(
                    size: 13,
                    weight: FontWeight.w500,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 14),
                GameCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.avatarCharacters,
                        style: fredoka(size: 17, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < drawnAvatarCount; i++)
                            _PresetTile(
                              preset: i,
                              selected:
                                  online.avatarUrl == null &&
                                  online.avatarPreset == i,
                              onTap: _busy || !online.isOnline
                                  ? null
                                  : () => _preset(i),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final int preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('preset_$preset'),
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.12 : 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.elasticOut,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.green : const Color(0xFFE9E2FA),
          ),
          child: DrawnAvatar(preset: preset, size: 56),
        ),
      ),
    );
  }
}

String avatarErrorMessage(AppLocalizations l10n, String code) => switch (code) {
  'invalid_image' => l10n.errorInvalidImage,
  'file_too_large' => l10n.errorFileTooLarge,
  _ => errorMessage(l10n, code),
};
