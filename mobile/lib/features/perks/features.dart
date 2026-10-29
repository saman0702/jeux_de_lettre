/// Options de revenus activées sur le serveur (fichier .env), reçues au
/// démarrage. Tout est coupé tant que le serveur n'a rien dit.
class PerkFeatures {
  const PerkFeatures({
    this.rewardedAds = false,
    this.rewardedAdCoins = 5,
    this.rewardedAdsPerDay = 10,
    this.interstitialAds = false,
    this.interstitialEveryGames = 3,
    this.removeAds = false,
    this.subscription = false,
    this.passDailyCoins = 20,
    this.passBonusHints = 2,
  });

  factory PerkFeatures.fromJson(Map<String, dynamic> json) => PerkFeatures(
    rewardedAds: json['rewarded_ads'] as bool? ?? false,
    rewardedAdCoins: json['rewarded_ad_coins'] as int? ?? 5,
    rewardedAdsPerDay: json['rewarded_ads_per_day'] as int? ?? 10,
    interstitialAds: json['interstitial_ads'] as bool? ?? false,
    interstitialEveryGames: json['interstitial_every_games'] as int? ?? 3,
    removeAds: json['remove_ads'] as bool? ?? false,
    subscription: json['subscription'] as bool? ?? false,
    passDailyCoins: json['pass_daily_coins'] as int? ?? 20,
    passBonusHints: json['pass_bonus_hints'] as int? ?? 2,
  );

  /// Produits des stores, à créer avec ces identifiants.
  static const removeAdsProduct = 'remove_ads';
  static const passProduct = 'pass_monthly';

  final bool rewardedAds;
  final int rewardedAdCoins;
  final int rewardedAdsPerDay;
  final bool interstitialAds;
  final int interstitialEveryGames;
  final bool removeAds;
  final bool subscription;
  final int passDailyCoins;
  final int passBonusHints;

  bool get anyAds => rewardedAds || interstitialAds;

  Map<String, dynamic> toJson() => {
    'rewarded_ads': rewardedAds,
    'rewarded_ad_coins': rewardedAdCoins,
    'rewarded_ads_per_day': rewardedAdsPerDay,
    'interstitial_ads': interstitialAds,
    'interstitial_every_games': interstitialEveryGames,
    'remove_ads': removeAds,
    'subscription': subscription,
    'pass_daily_coins': passDailyCoins,
    'pass_bonus_hints': passBonusHints,
  };
}
