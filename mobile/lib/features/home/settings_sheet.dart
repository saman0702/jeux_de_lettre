import 'package:flutter/material.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = GameFeedbackScope.of(context).settings;

    Widget toggle(
      String emoji,
      String label,
      bool value,
      ValueChanged<bool> onChanged,
    ) => SwitchListTile(
      key: Key('setting_$label'),
      value: value,
      onChanged: onChanged,
      secondary: Text(emoji, style: const TextStyle(fontSize: 26)),
      title: Text(label, style: fredoka(size: 18, weight: FontWeight.w600)),
    );

    return SafeArea(
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.settingsTitle,
                style: fredoka(size: 24, weight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              toggle(
                '🔊',
                l10n.settingsSound,
                settings.sound,
                (v) => settings.sound = v,
              ),
              toggle(
                '🎵',
                l10n.settingsMusic,
                settings.music,
                (v) => settings.music = v,
              ),
              toggle(
                '📳',
                l10n.settingsVibration,
                settings.vibration,
                (v) => settings.vibration = v,
              ),
              toggle(
                '⌨️',
                l10n.settingsGameKeyboard,
                settings.gameKeyboard,
                (v) => settings.gameKeyboard = v,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
