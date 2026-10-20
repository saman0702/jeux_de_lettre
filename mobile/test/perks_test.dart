import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/features/perks/ads_service.dart';
import 'package:letter_battle/features/perks/perks_controller.dart';
import 'package:letter_battle/features/shop/coin_store.dart';
import 'package:letter_battle/features/shop/shop_controller.dart';
import 'package:letter_battle/features/shop/shop_screen.dart';

import 'online_test.dart' show Harness, me, pumpFor;

/// Pubs de test : la vidéo est « regardée » aussitôt.
class FakeAds implements AdsService {
  int rewarded = 0;
  int interstitials = 0;
  String? lastUserId;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> showRewarded({required String userId}) async {
    lastUserId = userId;
    return 'video-${++rewarded}';
  }

  @override
  Future<void> showInterstitial() async => interstitials++;
}

/// Faux serveur : options du .env, profil et récompenses.
class FakePerksServer {
  FakePerksServer({this.features = const {}, this.trustClient = true});

  Map<String, dynamic> features;
  bool trustClient;
  int coins = 10;
  int adsLeft = 3;
  bool adsRemoved = false;
  final List<Map<String, dynamic>> rewards = [];

  Map<String, dynamic> wallet(int gained) => {
    'coins': coins,
    'coins_gained': gained,
    'points_to_next_coin': 20,
    'ads_removed': adsRemoved,
    'pass_expires_at': null,
  };

  late final api = ApiClient(
    client: MockClient((request) async {
      final path = request.url.path;
      http.Response json(Object body, [int status = 200]) =>
          http.Response(jsonEncode(body), status);
      if (path == '/api/v1/config') return json({'features': features});
      if (path == '/api/v1/profiles/$me') {
        return json({
          'coins': coins,
          'ad_rewards_left': adsLeft,
          'ads_removed': adsRemoved,
          'pass_expires_at': null,
          'daily_bonus_available': false,
        });
      }
      if (path == '/api/v1/ads/reward') {
        if (!trustClient) {
          // En prod, c'est AdMob qui prévient le serveur : il crédite ici.
          coins += 5;
          adsLeft--;
          return json({'detail': 'server_verification_only'}, 403);
        }
        rewards.add(jsonDecode(request.body) as Map<String, dynamic>);
        coins += 5;
        adsLeft--;
        return json(wallet(5));
      }
      if (path == '/api/v1/shop/packs') return json([]);
      if (path == '/api/v1/shop/purchases') {
        adsRemoved = true;
        return json(wallet(0));
      }
      return json({'detail': 'not_found'}, 404);
    }),
  );
}

/// Store qui vend « Sans pub » ; l'achat est accepté tout de suite.
class PerkStore extends UnavailableCoinStore {
  final bought = <String>[];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
    for (final id in ids)
      if (id == 'remove_ads')
        const StoreProduct(id: 'remove_ads', price: '2,99 €'),
  ];

  @override
  Future<void> buy(String productId) async => bought.add(productId);
}

Future<(Harness, PerksController, FakeAds, FakePerksServer)> open(
  WidgetTester tester, {
  Map<String, dynamic> features = const {},
  bool trustClient = true,
  ShopController Function(Harness, FakePerksServer)? shop,
}) async {
  final h = Harness();
  final server = FakePerksServer(features: features, trustClient: trustClient);
  final ads = FakeAds();
  final perks = PerksController(
    api: server.api,
    online: h.online,
    ads: ads,
    pollDelay: const Duration(milliseconds: 10),
  );
  await perks.load();
  await h.start(
    tester,
    const ShopScreen(),
    perks: perks,
    shop: shop?.call(h, server),
  );
  await pumpFor(tester, const Duration(seconds: 1));
  return (h, perks, ads, server);
}

void main() {
  testWidgets('with everything off, the shop shows no ads nor pass', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('watch_ad')), findsNothing);
    expect(find.byKey(const Key('buy_pass')), findsNothing);
    expect(find.byKey(const Key('buy_remove_ads')), findsNothing);
  });

  testWidgets('a rewarded video gives coins', (tester) async {
    final (h, perks, ads, server) = await open(
      tester,
      features: {'rewarded_ads': true, 'rewarded_ad_coins': 5},
    );
    expect(
      find.text('Watch a short video and earn 5 coins. 3 left today.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('watch_ad')));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(ads.lastUserId, me, reason: 'AdMob is told who to reward');
    expect(server.rewards.single['client_id'], me);
    expect(h.online.wallet!.coins, 15);
    expect(perks.adRewardsLeft, 2);
    await pumpFor(tester, const Duration(seconds: 3));
  });

  testWidgets('in production, the coins come from AdMob via the server', (
    tester,
  ) async {
    final (h, _, _, _) = await open(
      tester,
      features: {'rewarded_ads': true},
      trustClient: false,
    );
    await tester.tap(find.byKey(const Key('watch_ad')));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(h.online.wallet!.coins, 15);
    await pumpFor(tester, const Duration(seconds: 3));
  });

  testWidgets('remove ads can be bought and hides itself', (tester) async {
    late PerkStore store;
    await open(
      tester,
      features: {'remove_ads': true},
      shop: (h, server) {
        store = PerkStore();
        return ShopController(
          store: store,
          api: server.api,
          clientId: me,
          onWallet: h.online.applyWallet,
        );
      },
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('buy_remove_ads')),
        matching: find.text('2,99 €'),
      ),
      findsWidgets,
    );
    await tester.ensureVisible(find.byKey(const Key('buy_remove_ads')));
    await tester.tap(find.byKey(const Key('buy_remove_ads')));
    await tester.pump();
    expect(store.bought, ['remove_ads']);
  });

  test('a full-screen ad every N games, never for ad-free players', () async {
    final h = Harness();
    final server = FakePerksServer(
      features: {'interstitial_ads': true, 'interstitial_every_games': 3},
    );
    final ads = FakeAds();
    final perks = PerksController(api: server.api, online: h.online, ads: ads);
    await perks.load();
    for (var i = 0; i < 6; i++) {
      await perks.onGameFinished();
    }
    expect(ads.interstitials, 2);

    server.adsRemoved = true;
    await perks.refreshProfile();
    for (var i = 0; i < 6; i++) {
      await perks.onGameFinished();
    }
    expect(ads.interstitials, 2, reason: 'bought "No ads"');
  });
}
