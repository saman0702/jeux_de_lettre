import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/game_toggle.dart';
import '../../l10n/app_localizations.dart';

/// Game-menu style settings panel sliding up from the bottom.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    isScrollControlled: true,
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.6),
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

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
                padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                  ],
                ),
              ),
            ),
          ),
          // Ribbon title over the top edge, with a close button.
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.white, width: 3),
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
                  const GameIcon(GameIconKind.settings, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    l10n.settingsTitle.toUpperCase(),
                    style: fredoka(
                      size: 20,
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
            top: 34,
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
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
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
            GameIconBadge(icon, color: color, size: 48, dimmed: !value),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: fredoka(
                  size: 18,
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
