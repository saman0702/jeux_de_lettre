import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../online_controller.dart';

/// Capsule d'affichage de jeu : un voyant lumineux qui pulse quand on est
/// connecté, et le nombre de joueurs en ligne en gros chiffres.
class OnlineCounter extends StatefulWidget {
  const OnlineCounter({super.key});

  @override
  State<OnlineCounter> createState() => _OnlineCounterState();
}

class _OnlineCounterState extends State<OnlineCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GameFeedbackScope.of(context).ambientMotion && !_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = OnlineScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([online, _pulse]),
      builder: (context, _) {
        final connected = online.isOnline;
        final led = connected ? const Color(0xFF39FF88) : AppColors.red;
        final glow = connected
            ? 0.45 + 0.4 * (0.5 + 0.5 * sin(_pulse.value * 2 * pi))
            : 0.5;

        return Semantics(
          label: connected
              ? l10n.onlineCount(online.onlineCount)
              : l10n.offlineShort,
          child: Container(
            key: const Key('online_counter'),
            padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: connected
                    ? const [Color(0xFF3A2A86), Color(0xFF221556)]
                    : const [Color(0xFF4A3A6E), Color(0xFF2E2448)],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Voyant avec un halo.
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white, led],
                      stops: const [0.05, 0.6],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: led.withValues(alpha: glow),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (connected) ...[
                  const Icon(
                    Icons.people_alt_rounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 5),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.elasticOut,
                      ),
                      child: child,
                    ),
                    child: Text(
                      '${online.onlineCount}',
                      key: ValueKey(online.onlineCount),
                      style: fredoka(
                        size: 18,
                        weight: FontWeight.w700,
                        color: AppColors.yellow,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    l10n.onlineLabel,
                    style: fredoka(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ] else
                  Text(
                    l10n.offlineShort.toUpperCase(),
                    style: fredoka(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.white.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
