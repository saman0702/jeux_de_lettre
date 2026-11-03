import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'country_picker.dart';
import 'onboarding_screen.dart';

import '../../animations/bounce_in.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/game_toggle.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/pill_selector.dart';
import '../../l10n/app_localizations.dart';
import '../online/online_controller.dart';

/// Panneau de réglages façon menu de jeu qui monte depuis le bas.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    isScrollControlled: true,
    // Le titre et la croix restaient sous l'heure et les icônes du téléphone.
    useSafeArea: true,
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.6),
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _nickname;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final name = GameFeedbackScope.of(context).settings.nickname ?? '';
      if (_nickname.text != name) _nickname.text = name;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _saveNickname(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    final settings = GameFeedbackScope.of(context).settings;
    if (settings.nickname == name) return;
    settings.nickname = name;
    await OnlineScope.of(context).client.updateNickname(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = GameFeedbackScope.of(context).settings;

    final options = [
      (
        GameIconKind.sound,
        AppColors.cyan,
        l10n.settingsSound,
        () => settings.sound,
        (bool v) => settings.sound = v,
      ),
      (
        GameIconKind.music,
        AppColors.pink,
        l10n.settingsMusic,
        () => settings.music,
        (bool v) => settings.music = v,
      ),
      (
        GameIconKind.vibration,
        AppColors.orange,
        l10n.settingsVibration,
        () => settings.vibration,
        (bool v) => settings.vibration = v,
      ),
      (
        GameIconKind.keyboard,
        AppColors.green,
        l10n.settingsGameKeyboard,
        () => settings.gameKeyboard,
        (bool v) => settings.gameKeyboard = v,
      ),
      (
        GameIconKind.voice,
        AppColors.purpleLight,
        l10n.settingsVoice,
        () => settings.voice,
        (bool v) => settings.voice = v,
      ),
    ];

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 26),
            decoration: const BoxDecoration(
              color: AppColors.cloud,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(color: AppColors.yellow, width: 5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BounceIn(
                      from: 0.85,
                      slideY: 0.3,
                      child: _NicknameRow(
                        controller: _nickname,
                        onSubmitted: _saveNickname,
                      ),
                    ),
                    const SizedBox(height: 10),
                    BounceIn(
                      from: 0.85,
                      slideY: 0.3,
                      child: _LanguageRow(
                        value: settings.languageCode,
                        onChanged: (code) => settings.languageCode = code,
                      ),
                    ),
                    const SizedBox(height: 10),
                    BounceIn(
                      from: 0.85,
                      slideY: 0.3,
                      child: _GenderRow(
                        value: settings.gender,
                        onChanged: (g) => settings.gender = g,
                      ),
                    ),
                    const SizedBox(height: 10),
                    BounceIn(
                      from: 0.85,
                      slideY: 0.3,
                      child: _CountryRow(
                        value: settings.country,
                        onChanged: (c) => settings.country = c,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final (i, (icon, color, label, read, write))
                        in options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BounceIn(
                          delay: Duration(milliseconds: 60 * i),
                          from: 0.85,
                          slideY: 0.3,
                          child: _SettingRow(
                            key: Key('setting_$label'),
                            icon: icon,
                            color: color,
                            label: label,
                            value: read(),
                            onChanged: write,
                          ),
                        ),
                      ),
                    BounceIn(
                      delay: Duration(milliseconds: 60 * options.length),
                      from: 0.85,
                      slideY: 0.3,
                      child: _MusicVolumeRow(
                        enabled: settings.music,
                        value: settings.musicVolume,
                        onChanged: (v) => settings.musicVolume = v,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Suppression du compte (exigée par les stores).
                    TextButton.icon(
                      key: const Key('delete_account'),
                      onPressed: () => deleteMyAccount(context),
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: AppColors.red,
                        size: 18,
                      ),
                      label: Text(
                        l10n.deleteAccountButton,
                        style: fredoka(
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                    // Lien discret : la licence CC BY des musiques demande de
                    // citer l'auteur quelque part dans l'appli.
                    TextButton(
                      key: const Key('credits_button'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            l10n.credits,
                            style: fredoka(size: 20, weight: FontWeight.w700),
                          ),
                          content: Text(
                            l10n.musicCredits,
                            style: fredoka(size: 14),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      ),
                      child: Text(
                        l10n.credits,
                        style: fredoka(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Titre en bandeau sur le bord supérieur, avec un bouton de
          // fermeture.
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.white, width: 2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.purpleLight, AppColors.purple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.depthOf(AppColors.purple),
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon(GameIconKind.settings, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    l10n.settingsTitle.toUpperCase(),
                    style: fredoka(
                      size: 16,
                      weight: FontWeight.w700,
                      color: AppColors.white,
                      shadows: textShadow,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 14,
            child: RoundIconButton(
              key: const Key('settings_close'),
              icon: Icons.close_rounded,
              size: 40,
              color: AppColors.red,
              iconColor: AppColors.white,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final GameIconKind icon;
  final Color color;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? color : const Color(0xFFDCD3F2),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.depthOf(value ? color : AppColors.grey),
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            GameIconBadge(icon, color: color, size: 36, dimmed: !value),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: fredoka(
                  size: 15,
                  weight: FontWeight.w700,
                  color: value ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
            ),
            GameToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _NicknameRow extends StatelessWidget {
  const _NicknameRow({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('setting_nickname'),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.yellow, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(AppColors.yellow),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GameIconBadge(
                GameIconKind.smile,
                color: AppColors.yellow,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.settingsNickname,
                  style: fredoka(size: 15, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.nicknameHelp,
            style: fredoka(size: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('settings_nickname_field'),
            controller: controller,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            style: fredoka(size: 18, weight: FontWeight.w600),
            textAlign: TextAlign.center,
            onEditingComplete: () => onSubmitted(controller.text),
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: l10n.nicknameHint,
              fillColor: AppColors.cloud,
              counterText: '',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Langue de l'appli : suivre le téléphone, ou forcer le français / l'anglais.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('setting_language'),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(AppColors.cyan),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const GameIconBadge(
            GameIconKind.language,
            color: AppColors.cyan,
            size: 36,
          ),
          const SizedBox(width: 10),
          // Libellé au-dessus, choix en dessous : rien ne se chevauche.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsLanguage,
                  style: fredoka(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
          PillSelector<String?>(
            options: const [null, 'fr', 'en'],
            isSelected: (code) => code == value,
            label: (code) => switch (code) {
              'fr' => 'FR',
              'en' => 'EN',
              _ => l10n.languageAuto,
            },
            onTap: onChanged,
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pays d'origine, à côté du sexe.
class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('setting_country'),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(AppColors.green),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const GameIconBadge(
            GameIconKind.country,
            color: AppColors.green,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.settingsCountry,
              style: fredoka(size: 15, weight: FontWeight.w700),
            ),
          ),
          Flexible(child: CountryButton(value: value, onChanged: onChanged)),
        ],
      ),
    );
  }
}

class _GenderRow extends StatelessWidget {
  const _GenderRow({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('setting_gender'),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pink, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(AppColors.pink),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const GameIconBadge(
            GameIconKind.person,
            color: AppColors.pink,
            size: 36,
          ),
          const SizedBox(width: 10),
          // Libellé au-dessus, choix en dessous : rien ne se chevauche.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsGender,
                  style: fredoka(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
          PillSelector<String?>(
            options: const ['male', 'female', 'other'],
            isSelected: (code) => code == value,
            label: (code) => switch (code) {
              'male' => l10n.genderMale,
              'female' => l10n.genderFemale,
              _ => l10n.genderOther,
            },
            onTap: onChanged,
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicVolumeRow extends StatelessWidget {
  const _MusicVolumeRow({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        key: const Key('setting_music_volume'),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.pink, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.depthOf(AppColors.pink),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const GameIconBadge(
                  GameIconKind.music,
                  color: AppColors.pink,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l10n.settingsMusicVolume,
                    style: fredoka(size: 15, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.pink,
                inactiveTrackColor: const Color(0xFFDCD3F2),
                thumbColor: AppColors.pink,
              ),
              child: Slider(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Réglages > Supprimer mon compte : après confirmation, le serveur efface le
/// profil et tout ce qui lui appartient, puis l'appli efface ses données de
/// joueur et se ferme (au prochain lancement : nouveau joueur).
Future<void> deleteMyAccount(BuildContext context, {ApiClient? api}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final online = OnlineScope.of(context);
  final settings = GameFeedbackScope.of(context).settings;
  final ok = await showGameConfirm(
    context,
    icon: GameIconKind.door,
    title: l10n.deleteAccountTitle,
    message: l10n.deleteAccountMessage,
    confirmLabel: l10n.deleteAccountConfirm,
    cancelLabel: l10n.cancel,
  );
  if (!ok || !context.mounted) return;
  try {
    await (api ?? ApiClient()).deleteJson('/api/v1/profiles/${online.clientId}');
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e.code))));
    return;
  }
  await settings.eraseAccountData();
  if (!context.mounted) return;
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Text(l10n.deleteAccountDone, style: fredoka(size: 15)),
      actions: [
        TextButton(
          key: const Key('delete_account_close'),
          // Android : l'appli se ferme. iPhone ne permet pas à une appli de se
          // fermer : retour à l'écran de bienvenue, comme un nouveau joueur.
          onPressed: ios
              ? () => Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const OnboardingScreen(),
                  ),
                  (_) => false,
                )
              : () => SystemNavigator.pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

