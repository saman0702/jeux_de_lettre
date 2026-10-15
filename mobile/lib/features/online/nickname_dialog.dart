import 'package:flutter/material.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../l10n/app_localizations.dart';
import 'online_controller.dart';
import '../../core/widgets/game_icon.dart';

/// Makes sure the player has a nickname before going online.
/// Returns false if they dismissed the dialog.
Future<bool> ensureNickname(BuildContext context) async {
  final settings = GameFeedbackScope.of(context).settings;
  final online = OnlineScope.of(context);
  if (settings.nickname != null) return true;

  final nickname = await showDialog<String>(
    context: context,
    builder: (_) => const _NicknameDialog(),
  );
  if (nickname == null || nickname.isEmpty) return false;
  settings.nickname = nickname;
  await online.client.updateNickname(nickname);
  return true;
}

class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog();

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameIconBadge(
              GameIconKind.smile,
              color: AppColors.yellow,
              size: 64,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.nicknameTitle,
              style: fredoka(size: 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('nickname_field'),
              controller: _controller,
              autofocus: true,
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              textAlign: TextAlign.center,
              style: fredoka(size: 20, weight: FontWeight.w600),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: l10n.nicknameHint,
                fillColor: AppColors.cloud,
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            CandyButton(
              label: l10n.nicknameConfirm,
              onPressed: _submit,
              color: AppColors.green,
              textColor: AppColors.white,
              height: 56,
              fontSize: 19,
            ),
          ],
        ),
      ),
    );
  }
}
