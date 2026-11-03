import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import '../perks/perks_controller.dart';
import '../perks/perks_section.dart';
import 'shop_controller.dart';
import 'looks_section.dart';

/// Boutique : des vidéos pour gagner des pièces, l'abonnement Premium pour
/// ne plus voir de pubs, et les apparences achetées avec ses pièces.
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
    final perks = PerksScope.of(context);
    shop.load(extraProducts: perks.storeProducts);
    perks.refreshProfile();
  }

  void _onMessage(String message) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final text = switch (message) {
      _ when message.startsWith('bought:') => l10n.shopBought(
        int.parse(message.substring(7)),
      ),
      'perk:remove_ads' => l10n.perksRemoveAdsDone,
      'perk:pass_monthly' => l10n.perksPassDone,
      'pending' => l10n.shopPending,
      'invalid_purchase' || 'purchase_already_used' => l10n.shopInvalid,
      'store_error' => l10n.shopStoreError,
      // Le serveur n'a pas pu vérifier : l'achat sera repris plus tard.
      _ => l10n.shopRetryLater,
    };
    if (message.startsWith('perk:')) {
      PerksScope.of(context).refreshProfile();
    }
    if (message.startsWith('bought:') || message.startsWith('perk:')) {
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
                const PerksSection(),
                // Plus de packs de pièces à vendre : on gagne des pièces en
                // regardant des vidéos, et l'abonnement retire les pubs.
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
