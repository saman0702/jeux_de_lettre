import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/features/home/home_screen.dart';
import 'package:letter_battle/features/shop/coin_store.dart';
import 'package:letter_battle/features/shop/shop_controller.dart';
import 'package:letter_battle/features/shop/shop_screen.dart';

import 'online_test.dart' show Harness, me, pumpFor;
import 'widget_test.dart' show fakeApi;

/// Faux store : prix en francs CFA, achats déclenchés par le test.
class FakeStore implements CoinStore {
  FakeStore({this.available = true});

  final bool available;
  final _purchases = StreamController<StorePurchase>.broadcast();
  final List<String> bought = [];
  final List<String> finished = [];

  void emit(String productId, StorePurchaseStatus status, String token) =>
      _purchases.add(
        StorePurchase(
          productId: productId,
          status: status,
          token: token,
          platform: 'android',
          finish: () async => finished.add(token),
        ),
      );

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
    for (final (id, price) in [
      ('coins_1200', '6 500 FCFA'),
      ('coins_100', '650 FCFA'),
      ('coins_550', '3 300 FCFA'),
    ])
      if (ids.contains(id)) StoreProduct(id: id, price: price),
  ];

  @override
  Future<void> buy(String productId) async => bought.add(productId);

  @override
  Stream<StorePurchase> get purchases => _purchases.stream;

  @override
  Future<void> resumePending() async {}
}

/// Faux serveur de la boutique ; [failWith] simule une erreur.
class FakeShopServer {
  final List<Map<String, dynamic>> redeemed = [];
  String? failWith;
  int failStatus = 400;

  late final api = ApiClient(
    client: MockClient((request) async {
      if (request.url.path == '/api/v1/shop/packs') {
        return http.Response(
          jsonEncode([
            {'product_id': 'coins_100', 'coins': 100},
            {'product_id': 'coins_550', 'coins': 550},
            {'product_id': 'coins_1200', 'coins': 1200},
            {'product_id': 'coins_2500', 'coins': 2500},
          ]),
          200,
        );
      }
      if (failWith == 'network') throw Exception('offline');
      if (failWith != null) {
        return http.Response(jsonEncode({'detail': failWith}), failStatus);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      redeemed.add(body);
      return http.Response(
        jsonEncode({
          'coins': 560,
          'coins_gained': 550,
          'points_to_next_coin': 20,
        }),
        200,
      );
    }),
  );
}

Future<(Harness, FakeStore, FakeShopServer)> openShop(
  WidgetTester tester, {
  bool available = true,
}) async {
  final h = Harness();
  final store = FakeStore(available: available);
  final server = FakeShopServer();
  final shop = ShopController(
    store: store,
    api: server.api,
    clientId: me,
    onWallet: h.online.applyWallet,
  );
  await h.start(tester, const ShopScreen(), shop: shop);
  await pumpFor(tester, const Duration(seconds: 1));
  return (h, store, server);
}

void main() {
  testWidgets('packs show the store price, sorted, with their bonus', (
    tester,
  ) async {
    await openShop(tester);
    expect(find.text('650 FCFA'), findsOneWidget);
    expect(find.text('3 300 FCFA'), findsOneWidget);
    expect(find.text('+10%'), findsOneWidget);
    expect(find.text('+20%'), findsOneWidget);
    // Pas vendu dans le store (pas encore créé) : pas affiché.
    expect(find.byKey(const Key('pack_coins_2500')), findsNothing);
    final first = tester.getTopLeft(find.byKey(const Key('pack_coins_100')));
    final last = tester.getTopLeft(find.byKey(const Key('pack_coins_1200')));
    expect(first.dy <= last.dy, isTrue);
  });

  testWidgets('a purchase is verified by the server, credited, then closed', (
    tester,
  ) async {
    final (h, store, server) = await openShop(tester);
    await tester.tap(find.byKey(const Key('buy_coins_550')));
    await tester.pump();
    expect(store.bought, ['coins_550']);

    store.emit('coins_550', StorePurchaseStatus.purchased, 'tok-1');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(server.redeemed.single, {
      'client_id': me,
      'platform': 'android',
      'product_id': 'coins_550',
      'token': 'tok-1',
    });
    expect(h.online.wallet!.coins, 560);
    expect(store.finished, ['tok-1']);
    expect(find.text('+550 coins, thank you!'), findsOneWidget);
  });

  testWidgets('a purchase is kept for later when the server is unreachable', (
    tester,
  ) async {
    final (_, store, server) = await openShop(tester);
    server.failWith = 'network';
    store.emit('coins_100', StorePurchaseStatus.purchased, 'tok-2');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(store.finished, isEmpty, reason: 'retried on next launch');
    expect(find.textContaining('as soon as the server'), findsOneWidget);
  });

  testWidgets('a purchase refused by the store check is closed', (
    tester,
  ) async {
    final (_, store, server) = await openShop(tester);
    server.failWith = 'invalid_purchase';
    store.emit('coins_100', StorePurchaseStatus.purchased, 'tok-3');
    await pumpFor(tester, const Duration(seconds: 1));
    expect(store.finished, ['tok-3']);
    expect(find.text('This purchase could not be validated.'), findsOneWidget);
  });

  testWidgets('without a store the shop says so', (tester) async {
    await openShop(tester, available: false);
    expect(find.byKey(const Key('shop_unavailable')), findsOneWidget);
  });

  testWidgets('the coin counter opens the shop', (tester) async {
    final h = Harness();
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));
    await tester.tap(find.byKey(const Key('coin_counter')));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(ShopScreen), findsOneWidget);
  });
}
