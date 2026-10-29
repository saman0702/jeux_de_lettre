import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/network/api_client.dart';
import '../wallet/wallet.dart';
import 'coin_store.dart';

/// Un pack de la boutique : pièces données par le serveur, prix par le store.
class CoinPack {
  const CoinPack({
    required this.productId,
    required this.coins,
    required this.price,
  });

  final String productId;
  final int coins;
  final String price;

  /// Bonus affiché par rapport au petit pack (100 pièces pour le prix le plus
  /// bas) ; correspond aux prix conseillés dans docs/BOUTIQUE.md.
  int get bonusPercent =>
      const {'coins_550': 10, 'coins_1200': 20, 'coins_2500': 25}[productId] ??
      0;
}

enum ShopStatus { loading, ready, unavailable }

/// Boutique de pièces. Écoute le store dès le lancement de l'appli : un achat
/// interrompu (appli fermée, réseau coupé) est repris et crédité plus tard.
class ShopController extends ChangeNotifier {
  ShopController({
    required this.store,
    required this.api,
    required this.clientId,
    required this.onWallet,
  }) {
    _subscription = store.purchases.listen(_onPurchase);
  }

  final CoinStore store;
  final ApiClient api;
  final String clientId;

  /// Nouveau solde après un achat crédité.
  final ValueChanged<WalletSnapshot> onWallet;

  late final StreamSubscription<StorePurchase> _subscription;
  final _messages = StreamController<String>.broadcast();

  ShopStatus _status = ShopStatus.loading;
  List<CoinPack> _packs = const [];
  Map<String, StoreProduct> _extras = const {};

  /// « Sans pub » ou Pass, avec son prix dans la monnaie du joueur (null si
  /// le store ne le vend pas).
  StoreProduct? product(String id) => _extras[id];
  String? _buying;

  ShopStatus get status => _status;
  List<CoinPack> get packs => _packs;

  /// Pack dont l'achat est en cours.
  String? get buying => _buying;

  /// Résultats à afficher : code « bought:N », « pending » ou un code d'erreur.
  Stream<String> get messages => _messages.stream;

  /// Reprend les achats non terminés d'une session précédente.
  Future<void> start() => store.resumePending();

  /// [extraProducts] : produits en plus des packs (« Sans pub », Pass), selon
  /// les options activées sur le serveur.
  Future<void> load({Set<String> extraProducts = const {}}) async {
    _status = ShopStatus.loading;
    notifyListeners();
    try {
      if (!await store.isAvailable()) {
        _status = ShopStatus.unavailable;
        notifyListeners();
        return;
      }
      final response = await api.getJsonList('/api/v1/shop/packs');
      final coins = {
        for (final p in response)
          (p as Map)['product_id'] as String: p['coins'] as int,
      };
      final products = await store.products({...coins.keys, ...extraProducts});
      _extras = {
        for (final p in products)
          if (extraProducts.contains(p.id)) p.id: p,
      };
      _packs = [
        for (final p in products)
          if (coins[p.id] != null)
            CoinPack(productId: p.id, coins: coins[p.id]!, price: p.price),
      ]..sort((a, b) => a.coins.compareTo(b.coins));
      _status = _packs.isEmpty ? ShopStatus.unavailable : ShopStatus.ready;
    } catch (_) {
      _status = ShopStatus.unavailable;
    }
    notifyListeners();
  }

  Future<void> buy(CoinPack pack) => buyProduct(pack.productId);

  Future<void> buyProduct(String productId) async {
    if (_buying != null) return;
    _buying = productId;
    notifyListeners();
    try {
      await store.buy(productId);
    } catch (_) {
      _done('store_error');
    }
  }

  Future<void> _onPurchase(StorePurchase purchase) async {
    switch (purchase.status) {
      case StorePurchaseStatus.pending:
        // Paiement en attente (espèces, opérateur…) : crédité quand le store
        // confirmera.
        _done('pending');
      case StorePurchaseStatus.canceled:
        await purchase.finish();
        _done(null);
      case StorePurchaseStatus.error:
        await purchase.finish();
        _done('store_error');
      case StorePurchaseStatus.purchased:
        await _redeem(purchase);
    }
  }

  Future<void> _redeem(StorePurchase purchase) async {
    try {
      final body = await api.postJson('/api/v1/shop/purchases', {
        'client_id': clientId,
        'platform': purchase.platform,
        'product_id': purchase.productId,
        'token': purchase.token,
      });
      final wallet = WalletSnapshot.fromJson(body);
      onWallet(wallet);
      await purchase.finish();
      _done(
        isConsumable(purchase.productId)
            ? 'bought:${wallet.coinsGained}'
            : 'perk:${purchase.productId}',
      );
    } on ApiException catch (e) {
      // Achat refusé par le store : on le clôt. Problème de réseau ou de
      // serveur : on le garde pour réessayer au prochain lancement.
      if (const {
        'invalid_purchase',
        'unknown_product',
        'purchase_already_used',
      }.contains(e.code)) {
        await purchase.finish();
      }
      _done(e.code);
    }
  }

  void _done(String? message) {
    _buying = null;
    if (message != null && !_messages.isClosed) _messages.add(message);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _messages.close();
    super.dispose();
  }
}

class ShopScope extends InheritedWidget {
  const ShopScope({super.key, required this.controller, required super.child});

  final ShopController controller;

  static ShopController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShopScope>()!.controller;

  @override
  bool updateShouldNotify(ShopScope oldWidget) =>
      controller != oldWidget.controller;
}
