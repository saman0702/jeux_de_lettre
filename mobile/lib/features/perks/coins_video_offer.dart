import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import 'perks_controller.dart';

/// Une vidéo peut-elle être proposée maintenant (pubs récompensées actives, limite du jour non
/// atteinte) ?
bool canOfferCoinsVideo(PerksController? perks) =>
    perks != null &&
    perks.features.rewardedAds &&
    perks.adRewardsLeft > 0 &&
    !perks.watching;

/// Pas assez de pièces pour [price] : propose une vidéo récompensée sans quitter la partie.
/// Renvoie vrai si les pièces ont été créditées (on peut alors réessayer l'achat).
Future<bool> offerCoinsVideo(
  BuildContext context, {
  required PerksController perks,
  required int price,
  required int coins,
}) async {
  final l10n = AppLocalizations.of(context);
  final watch = await showGameConfirm(
    context,
    icon: GameIconKind.coin,
    title: l10n.lowCoinsTitle,
    message: l10n.lowCoinsMessage(price, coins),
    confirmLabel: l10n.lowCoinsWatch(perks.features.rewardedAdCoins),
    cancelLabel: l10n.lowCoinsLater,
    accent: AppColors.purple,
  );
  if (!watch || !context.mounted) return false;
  final feedback = GameFeedbackScope.of(context);
  final result = await perks.watchRewardedAd();
  if (!context.mounted) return false;
  if (result.startsWith('reward:')) {
    feedback.play(Sfx.victory);
    return true;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(switch (result) {
        'limit' => l10n.perksAdLimit,
        'pending' => l10n.perksAdPending,
        'no_ad' => l10n.perksNoAd,
        _ => l10n.shopRetryLater,
      }),
    ),
  );
  return false;
}
