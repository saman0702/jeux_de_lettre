import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../online_controller.dart';

/// "🟢 12 online" pill; the dot pulses while connected.
class OnlineCounter extends StatefulWidget {
  const OnlineCounter({super.key});

  @override
  State<OnlineCounter> createState() => _OnlineCounterState();
}

class _OnlineCounterState extends State<OnlineCounter> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = OnlineScope.of(context);

    return ListenableBuilder(
      listenable: online,
      builder: (context, _) {
        final connected = online.isOnline;
        return Container(
          key: const Key('online_counter'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: connected ? AppColors.green : AppColors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Text(
                  connected
                      ? l10n.onlineCount(online.onlineCount)
                      : l10n.offlineShort,
                  key: ValueKey('${online.onlineCount}-$connected'),
                  style: fredoka(
                    size: 15,
                    weight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
