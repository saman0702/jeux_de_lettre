import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../online/online_controller.dart';
import '../wallet/wallet.dart';
import 'ads_service.dart';
import 'features.dart';

/// Mémoire des options sur le téléphone : dernières options connues (pour
/// l'hors ligne) et parties jouées depuis la dernière pub.
abstract class PerksStorage {
  String? readFeatures();
  void writeFeatures(String json);
  int readGamesSinceAd();
  void writeGamesSinceAd(int value);
}

class MemoryPerksStorage implements PerksStorage {
  String? _features;
  int _games = 0;

  @override
  String? readFeatures() => _features;
  @override
  void writeFeatures(String json) => _features = json;
  @override
  int readGamesSinceAd() => _games;
  @override
  void writeGamesSinceAd(int value) => _games = value;
}

class PrefsPerksStorage implements PerksStorage {
  PrefsPerksStorage(this._prefs);

  static Future<PrefsPerksStorage> load() async =>
      PrefsPerksStorage(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  @override
  String? readFeatures() => _prefs.getString('perks.features');
  @override
  void writeFeatures(String json) => _prefs.setString('perks.features', json);
  @override
  int readGamesSinceAd() => _prefs.getInt('perks.games_since_ad') ?? 0;
  @override
  void writeGamesSinceAd(int value) =>
      _prefs.setInt('perks.games_since_ad', value);
}

/// Pubs récompensées, pub entre les parties, « Sans pub » et Pass : chaque
/// option n'apparaît que si elle est activée sur le serveur.
class PerksController extends ChangeNotifier {
  PerksController({
    required this.api,
    required this.online,
    AdsService? ads,
    PerksStorage? storage,
    this.pollDelay = const Duration(milliseconds: 1500),
  }) : ads = ads ?? NoAdsService(),
       storage = storage ?? MemoryPerksStorage() {
    final cached = this.storage.readFeatures();
    if (cached != null) {
      try {
        _features = PerkFeatures.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
  }

  final ApiClient api;
  final OnlineController online;
  final AdsService ads;
  final PerksStorage storage;

  /// Attente entre deux vérifications du solde après une vidéo (AdMob
  /// prévient le serveur quelques secondes après).
  final Duration pollDelay;

  PerkFeatures _features = const PerkFeatures();
  int _adRewardsLeft = 0;
  bool _dailyBonusAvailable = false;
  bool _watching = false;

  PerkFeatures get features => _features;
  int get adRewardsLeft => _adRewardsLeft;
  bool get dailyBonusAvailable => _dailyBonusAvailable;

  /// Vidéo récompensée en cours.
  bool get watching => _watching;

  bool get adsRemoved => online.wallet?.adsRemoved ?? false;
  bool get passActive => online.wallet?.passActive() ?? false;
  DateTime? get passExpiresAt => online.wallet?.passExpiresAt;

  /// Plus de pub entre les parties (achat « Sans pub » ou Pass actif).
  bool get adsFree => adsRemoved || passActive;

  /// Produits des stores à proposer dans la boutique.
  Set<String> get storeProducts => {
    if (_features.removeAds) PerkFeatures.removeAdsProduct,
    if (_features.subscription) PerkFeatures.passProduct,
  };

  String get _clientId => online.clientId;

  /// Lit les options du serveur, puis l'état du joueur.
  Future<void> load() async {
    try {
      final config = await api.getJson('/api/v1/config');
      final json = config['features'];
      if (json is Map<String, dynamic>) {
        _features = PerkFeatures.fromJson(json);
        storage.writeFeatures(jsonEncode(_features.toJson()));
      }
    } on ApiException {
      // Hors ligne : on garde les dernières options connues.
    }
    notifyListeners();
    if (_features.anyAds) unawaited(ads.initialize());
    await refreshProfile();
  }

  Future<Map<String, dynamic>?> _profile() async {
    try {
      return await api.getJson('/api/v1/profiles/$_clientId');
    } on ApiException {
      return null;
    }
  }

  Future<void> refreshProfile() async {
    final profile = await _profile();
    if (profile == null) return;
    _adRewardsLeft = profile['ad_rewards_left'] as int? ?? 0;
    _dailyBonusAvailable = profile['daily_bonus_available'] as bool? ?? false;
    final wallet =
        online.wallet ?? WalletSnapshot(coins: profile['coins'] as int? ?? 0);
    online.applyWallet(
      wallet.copyWith(
        coins: profile['coins'] as int?,
        adsRemoved: profile['ads_removed'] as bool? ?? false,
        passExpiresAt: profile['pass_expires_at'] == null
            ? null
            : DateTime.parse(profile['pass_expires_at'] as String),
      ),
    );
    notifyListeners();
  }

  /// Vidéo récompensée. Renvoie « reward:N », « pending » (le serveur n'a pas
  /// encore été prévenu par AdMob), « no_ad », « limit » ou un code d'erreur.
  Future<String> watchRewardedAd() async {
    if (_watching || !_features.rewardedAds) return 'no_ad';
    _watching = true;
    notifyListeners();
    try {
      final before = online.wallet?.coins ?? 0;
      final reward = await ads.showRewarded(userId: _clientId);
      if (reward == null) return 'no_ad';
      try {
        final body = await api.postJson('/api/v1/ads/reward', {
          'client_id': _clientId,
          'reward_id': reward,
        });
        final wallet = WalletSnapshot.fromJson(body);
        online.applyWallet(wallet);
        _adRewardsLeft = (_adRewardsLeft - 1).clamp(0, 1 << 30);
        return 'reward:${wallet.coinsGained}';
      } on ApiException catch (e) {
        if (e.code == 'daily_limit_reached') return 'limit';
        if (e.code != 'server_verification_only') return e.code;
      }
      // En prod, AdMob prévient le serveur lui-même : on attend le crédit.
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(pollDelay);
        final profile = await _profile();
        final coins = profile?['coins'] as int?;
        if (coins != null && coins > before) {
          final wallet = online.wallet ?? WalletSnapshot(coins: coins);
          online.applyWallet(
            wallet.copyWith(coins: coins, coinsGained: coins - before),
          );
          _adRewardsLeft = profile?['ad_rewards_left'] as int? ?? 0;
          return 'reward:${coins - before}';
        }
      }
      return 'pending';
    } finally {
      _watching = false;
      notifyListeners();
    }
  }

  /// Bonus de pièces du jour, pour les abonnés au Pass.
  Future<String> claimDailyBonus() async {
    try {
      final body = await api.postJson(
        '/api/v1/profiles/$_clientId/daily-bonus',
      );
      final wallet = WalletSnapshot.fromJson(body);
      online.applyWallet(wallet);
      _dailyBonusAvailable = false;
      notifyListeners();
      return 'reward:${wallet.coinsGained}';
    } on ApiException catch (e) {
      if (e.code == 'already_claimed') {
        _dailyBonusAvailable = false;
        notifyListeners();
      }
      return e.code;
    }
  }

  /// À appeler à la fin de chaque partie : une pub toutes les N parties, sauf
  /// pour les joueurs « Sans pub » ou abonnés.
  Future<void> onGameFinished() async {
    if (!_features.interstitialAds || adsFree) return;
    final games = storage.readGamesSinceAd() + 1;
    if (games < _features.interstitialEveryGames) {
      storage.writeGamesSinceAd(games);
      return;
    }
    storage.writeGamesSinceAd(0);
    await ads.showInterstitial();
  }
}

class PerksScope extends InheritedWidget {
  const PerksScope({super.key, required this.controller, required super.child});

  final PerksController controller;

  static PerksController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PerksScope>()!.controller;

  /// Pour les écrans qui peuvent exister sans boutique (tests anciens).
  static PerksController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PerksScope>()?.controller;

  @override
  bool updateShouldNotify(PerksScope oldWidget) =>
      controller != oldWidget.controller;
}
