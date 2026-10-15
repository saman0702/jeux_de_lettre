import 'package:flutter/material.dart';

import '../../../core/widgets/candy_button.dart';
import '../../../l10n/app_localizations.dart';

/// ✕ button to leave a game in progress (asks for confirmation).
class QuitButton extends StatelessWidget {
  const QuitButton({super.key, required this.onQuit});

  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) => RoundIconButton(
    key: const Key('quit_button'),
    icon: Icons.close_rounded,
    tooltip: AppLocalizations.of(context).quit,
    onPressed: onQuit,
  );
}

/// Puts a [QuitButton] above screens that have no header of their own
/// (countdown, results, waiting).
class WithQuitButton extends StatelessWidget {
  const WithQuitButton({super.key, required this.onQuit, required this.child});

  final VoidCallback onQuit;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: QuitButton(onQuit: onQuit),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
