import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Blocs d'annonces AdMob. Par défaut, les blocs de test de Google (aucun
/// revenu, aucun risque de bannissement) ; les vrais se donnent à la
/// compilation : --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-…/…
const _rewardedAndroid = String.fromEnvironment(
  'ADMOB_REWARDED_ANDROID',
  defaultValue: 'ca-app-pub-3940256099942544/5224354917',
);
const _rewardedIos = String.fromEnvironment(
  'ADMOB_REWARDED_IOS',
  defaultValue: 'ca-app-pub-3940256099942544/1712485313',
);
const _interstitialAndroid = String.fromEnvironment(
  'ADMOB_INTERSTITIAL_ANDROID',
  defaultValue: 'ca-app-pub-3940256099942544/1033173712',
);
const _interstitialIos = String.fromEnvironment(
  'ADMOB_INTERSTITIAL_IOS',
  defaultValue: 'ca-app-pub-3940256099942544/4411468910',
);

/// Affiche les publicités ; remplacé par [NoAdsService] dans les tests.
abstract class AdsService {
  /// Demande le consentement (RGPD) si besoin, puis prépare le SDK.
  Future<void> initialize();

  /// Vidéo récompensée. [userId] part au serveur via la vérification AdMob.
  /// Renvoie l'identifiant de la vidéo si elle a été regardée jusqu'au bout.
  Future<String?> showRewarded({required String userId});

  /// Pub plein écran entre deux parties.
  Future<void> showInterstitial();
}

/// Aucune pub (tests, plateformes sans AdMob).
class NoAdsService implements AdsService {
  @override
  Future<void> initialize() async {}

  @override
  Future<String?> showRewarded({required String userId}) async => null;

  @override
  Future<void> showInterstitial() async {}
}

/// Google AdMob, avec le formulaire de consentement de Google (UMP).
class AdMobAdsService implements AdsService {
  bool _ready = false;
  Future<void>? _initializing;

  String get _rewardedUnit => Platform.isIOS ? _rewardedIos : _rewardedAndroid;
  String get _interstitialUnit =>
      Platform.isIOS ? _interstitialIos : _interstitialAndroid;

  @override
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      final consent = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => ConsentForm.loadAndShowConsentFormIfRequired(
          (_) => consent.complete(),
        ),
        (_) => consent.complete(),
      );
      await consent.future;
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      _ready = true;
    } catch (error) {
      debugPrint('Ads unavailable: $error');
    }
  }

  @override
  Future<String?> showRewarded({required String userId}) async {
    await initialize();
    if (!_ready) return null;
    final loaded = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: _rewardedUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    final ad = await loaded.future;
    if (ad == null) return null;
    await ad.setServerSideOptions(
      ServerSideVerificationOptions(userId: userId),
    );
    final done = Completer<String?>();
    String? reward;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(reward);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!done.isCompleted) done.complete(null);
      },
    );
    await ad.show(
      onUserEarnedReward: (_, _) {
        reward = '${userId.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
      },
    );
    return done.future;
  }

  @override
  Future<void> showInterstitial() async {
    await initialize();
    if (!_ready) return;
    final loaded = Completer<InterstitialAd?>();
    await InterstitialAd.load(
      adUnitId: _interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    final ad = await loaded.future;
    if (ad == null) return;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        done.complete();
      },
    );
    await ad.show();
    return done.future;
  }
}
