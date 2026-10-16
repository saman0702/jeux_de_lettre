import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../../animations/transitions/pop_route.dart';
import '../online/online_controller.dart';
import '../shop/shop_screen.dart';

/// Capsule du solde de pièces, avec une jauge vers la prochaine pièce. Un
/// toucher ouvre la boutique.
class CoinCounter extends StatelessWidget {
  const CoinCounter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = OnlineScope.of(context);

    return ListenableBuilder(
      listenable: online,
      builder: (context, _) {
        final wallet = online.wallet;
        final coins = wallet?.coins ?? 0;
        return Semantics(
          label: l10n.coinsCount(coins),
          button: true,
          child: GestureDetector(
            onTap: () =>
                Navigator.of(context)
                    .push(PopRoute(builder: (_) => const ShopScreen())),
            child: Container(
              key: const Key('coin_counter'),
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.9),
                  width: 2,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3A2A86), Color(0xFF221556)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIcon(GameIconKind.coin, size: 26),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: CurvedAnimation(
                                parent: animation,
                                curve: Curves.elasticOut,
                              ),
                              child: child,
                            ),
                        child: Text(
                          '$coins',
                          key: ValueKey(coins),
                          style: fredoka(
                            size: 17,
                            weight: FontWeight.w700,
                            color: AppColors.yellow,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Avancement vers la prochaine pièce.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          width: 34,
                          height: 4,
                          child: LinearProgressIndicator(
                            value: wallet?.progress ?? 0,
                            backgroundColor: AppColors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.yellow,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  // « + » : on peut acheter des pièces.
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Affiche « +N pièces » par-dessus n'importe quel écran à chaque gain.
class CoinGainOverlay extends StatefulWidget {
  const CoinGainOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<CoinGainOverlay> createState() => _CoinGainOverlayState();
}

class _CoinGainOverlayState extends State<CoinGainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  StreamSubscription<int>? _gains;
  int _amount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gains?.cancel();
    _gains = OnlineScope.of(context).coinGains.listen(_onGain);
  }

  void _onGain(int amount) {
    if (!mounted) return;
    setState(() => _amount = amount);
    GameFeedbackScope.of(context).play(Sfx.points);
    _show.forward(from: 0);
  }

  @override
  void dispose() {
    _gains?.cancel();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _show,
                builder: (context, child) {
                  final t = _show.value;
                  if (t == 0 || t == 1) return const SizedBox.shrink();
                  // Entrée rebondie, pause, puis sortie vers le haut.
                  final enter = Curves.elasticOut.transform(
                    (t / 0.3).clamp(0, 1),
                  );
                  final leave = Curves.easeIn.transform(
                    ((t - 0.75) / 0.25).clamp(0, 1),
                  );
                  return Opacity(
                    opacity: 1 - leave,
                    child: Transform.translate(
                      offset: Offset(0, 60 * enter - 40 * leave),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * enter,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Center(child: _GainBadge(amount: _amount)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GainBadge extends StatelessWidget {
  const _GainBadge({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: const Key('coin_gain'),
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
        decoration: BoxDecoration(
          color: AppColors.yellow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.depthOf(AppColors.yellow),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameIcon(GameIconKind.coin, size: 30),
            const SizedBox(width: 6),
            Text(
              l10n.coinsGained(amount),
              style: fredoka(
                size: 20,
                weight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
