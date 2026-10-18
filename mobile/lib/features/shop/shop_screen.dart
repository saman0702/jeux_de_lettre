import 'dart:async';

import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import 'shop_controller.dart';
import 'looks_section.dart';

/// Boutique : packs de pièces payés par le store du téléphone.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  ShopController? _shop;
  StreamSubscription<String>? _messages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shop != null) return;
    final shop = _shop = ShopScope.of(context);
    _messages = shop.messages.listen(_onMessage);
    shop.load();
  }

  void _onMessage(String message) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final text = switch (message) {
      _ when message.startsWith('bought:') => l10n.shopBought(
        int.parse(message.substring(7)),
      ),
      'pending' => l10n.shopPending,
      'invalid_purchase' || 'purchase_already_used' => l10n.shopInvalid,
      'store_error' => l10n.shopStoreError,
      // Le serveur n'a pas pu vérifier : l'achat sera repris plus tard.
      _ => l10n.shopRetryLater,
    };
    if (message.startsWith('bought:')) {
      GameFeedbackScope.of(context).play(Sfx.victory);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shop = ShopScope.of(context);
    final online = OnlineScope.of(context);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([shop, online]),
            builder: (context, _) => FloatingBarsLayout(
              header: OnlineHeader(
                title: l10n.shopTitle,
                onBack: () => Navigator.of(context).pop(),
              ),
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon(GameIconKind.coin, size: 34),
                      const SizedBox(width: 8),
                      Text(
                        l10n.yourCoins(online.wallet?.coins ?? 0),
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
                const SizedBox(height: 14),
                switch (shop.status) {
                  ShopStatus.loading => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.yellow),
                    ),
                  ),
                  ShopStatus.unavailable => GameCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const GameIcon(
                          GameIconKind.offline,
                          size: 40,
                          color: AppColors.purple,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.shopUnavailable,
                          key: const Key('shop_unavailable'),
                          textAlign: TextAlign.center,
                          style: fredoka(size: 16, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  ShopStatus.ready => GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                    children: [
                      for (final (i, pack) in shop.packs.indexed)
                        BounceIn(
                          delay: Duration(milliseconds: 80 * i),
                          from: 0.7,
                          child: _PackCard(
                            pack: pack,
                            busy: shop.buying == pack.productId,
                            onBuy: shop.buying == null
                                ? () => shop.buy(pack)
                                : null,
                          ),
                        ),
                    ],
                  ),
                },
                const SizedBox(height: 18),
                LooksSection(api: shop.api, clientId: shop.clientId),
                const SizedBox(height: 14),
                Text(
                  l10n.shopLegal,
                  textAlign: TextAlign.center,
                  style: fredoka(
                    size: 12,
                    weight: FontWeight.w500,
                    color: AppColors.white.withValues(alpha: 0.8),
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

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack, required this.busy, this.onBuy});

  final CoinPack pack;
  final bool busy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Plus le pack est gros, plus la pile de pièces est haute.
    final stack = switch (pack.coins) {
      < 500 => 1,
      < 1000 => 3,
      < 2000 => 5,
      _ => 7,
    };
    return GameCard(
      key: Key('pack_${pack.productId}'),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        children: [
          if (pack.bonusPercent > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.pink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.shopBonus(pack.bonusPercent),
                style: fredoka(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            )
          else
            const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < stack; i++)
                      Positioned(
                        bottom: 4.0 + i * 6,
                        left: 14.0 + (i.isEven ? 0 : 6) - (stack > 4 ? 6 : 0),
                        child: const GameIcon(
                          GameIconKind.coin,
                          size: 40,
                          motion: IconMotion.none,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            '${pack.coins}',
            style: fredoka(
              size: 26,
              weight: FontWeight.w700,
              color: AppColors.purple,
            ),
          ),
          Text(
            l10n.shopCoinsLabel,
            style: fredoka(size: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          CandyButton(
            key: Key('buy_${pack.productId}'),
            label: pack.price,
            color: AppColors.green,
            textColor: AppColors.white,
            loading: busy,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}
