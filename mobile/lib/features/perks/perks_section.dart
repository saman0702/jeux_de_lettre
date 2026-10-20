import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/option_section.dart';
import '../shop/shop_controller.dart';
import 'features.dart';
import 'perks_controller.dart';

/// Boutique : pièces gratuites (vidéo), « Sans pub » et Pass, selon les
/// options activées sur le serveur.
class PerksSection extends StatelessWidget {
  const PerksSection({super.key});

  void _toast(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _watch(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final feedback = GameFeedbackScope.of(context);
    final result = await PerksScope.of(context).watchRewardedAd();
    if (!context.mounted) return;
    if (result.startsWith('reward:')) {
      feedback.play(Sfx.victory);
      return; // « +N pièces » s'affiche déjà par-dessus l'écran.
    }
    _toast(context, switch (result) {
      'limit' => l10n.perksAdLimit,
      'pending' => l10n.perksAdPending,
      'no_ad' => l10n.perksNoAd,
      _ => l10n.shopRetryLater,
    });
  }

  Future<void> _claim(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await PerksScope.of(context).claimDailyBonus();
    if (!context.mounted || result.startsWith('reward:')) return;
    _toast(context, l10n.shopRetryLater);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final perks = PerksScope.of(context);
    final shop = ShopScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([perks, shop, perks.online]),
      builder: (context, _) {
        final features = perks.features;
        final removeAds = shop.product(PerkFeatures.removeAdsProduct);
        final pass = shop.product(PerkFeatures.passProduct);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (features.rewardedAds)
              OptionSection(
                index: 0,
                title: l10n.perksFreeCoins,
                icon: GameIconKind.coin,
                color: AppColors.yellow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.perksWatchInfo(
                        features.rewardedAdCoins,
                        perks.adRewardsLeft,
                      ),
                      textAlign: TextAlign.center,
                      style: fredoka(size: 14, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 10),
                    CandyButton(
                      key: const Key('watch_ad'),
                      label: l10n.perksWatch(features.rewardedAdCoins),
                      icon: Icons.play_circle_fill_rounded,
                      color: AppColors.green,
                      textColor: AppColors.white,
                      height: 52,
                      fontSize: 18,
                      loading: perks.watching,
                      onPressed: perks.adRewardsLeft > 0 && !perks.watching
                          ? () => _watch(context)
                          : null,
                    ),
                  ],
                ),
              ),
            if (features.subscription)
              OptionSection(
                index: 1,
                title: l10n.perksPassTitle,
                icon: GameIconKind.crown,
                color: AppColors.purpleLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in [
                      l10n.perksPassNoAds,
                      l10n.perksPassDaily(features.passDailyCoins),
                      l10n.perksPassHints(features.passBonusHints),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const GameIcon(
                              GameIconKind.check,
                              size: 18,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                line,
                                style: fredoka(
                                  size: 14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (perks.passActive) ...[
                      Text(
                        l10n.perksPassActive(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(perks.passExpiresAt!.toLocal()),
                        ),
                        key: const Key('pass_active'),
                        textAlign: TextAlign.center,
                        style: gameFont(size: 15, color: AppColors.purple),
                      ),
                      const SizedBox(height: 8),
                      CandyButton(
                        key: const Key('daily_bonus'),
                        label: perks.dailyBonusAvailable
                            ? l10n.perksClaimDaily(features.passDailyCoins)
                            : l10n.perksDailyTaken,
                        gameIcon: GameIconKind.coin,
                        color: AppColors.yellow,
                        height: 50,
                        fontSize: 17,
                        onPressed: perks.dailyBonusAvailable
                            ? () => _claim(context)
                            : null,
                      ),
                    ] else
                      CandyButton(
                        key: const Key('buy_pass'),
                        label: pass == null
                            ? l10n.shopUnavailableShort
                            : l10n.perksPassPrice(pass.price),
                        gameIcon: GameIconKind.crown,
                        color: AppColors.purpleLight,
                        textColor: AppColors.white,
                        height: 52,
                        fontSize: 18,
                        loading: shop.buying == PerkFeatures.passProduct,
                        onPressed: pass == null || shop.buying != null
                            ? null
                            : () => shop.buyProduct(PerkFeatures.passProduct),
                      ),
                  ],
                ),
              ),
            if (features.removeAds && !perks.adsFree)
              OptionSection(
                index: 2,
                title: l10n.perksRemoveAdsTitle,
                icon: GameIconKind.private,
                color: AppColors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.perksRemoveAdsInfo,
                      textAlign: TextAlign.center,
                      style: fredoka(size: 14, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 10),
                    CandyButton(
                      key: const Key('buy_remove_ads'),
                      label: removeAds?.price ?? l10n.shopUnavailableShort,
                      icon: Icons.block_rounded,
                      color: AppColors.cyan,
                      height: 52,
                      fontSize: 18,
                      loading: shop.buying == PerkFeatures.removeAdsProduct,
                      onPressed: removeAds == null || shop.buying != null
                          ? null
                          : () =>
                                shop.buyProduct(PerkFeatures.removeAdsProduct),
                    ),
                  ],
                ),
              ),
            if (features.removeAds && perks.adsRemoved)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.perksRemoveAdsOwned,
                  key: const Key('ads_removed'),
                  textAlign: TextAlign.center,
                  style: gameFont(size: 16, color: AppColors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}
