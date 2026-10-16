import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Un pack tel que le store le présente : son prix dans la monnaie du joueur.
class StoreProduct {
  const StoreProduct({required this.id, required this.price});

  final String id;

  /// Prix formaté par le store (ex. « 0,99 € », « 650 FCFA »).
  final String price;
}

enum StorePurchaseStatus { pending, purchased, canceled, error }

/// Un achat remonté par le store ; [finish] le clôt une fois les pièces
/// créditées par le serveur.
class StorePurchase {
  StorePurchase({
    required this.productId,
    required this.status,
    required this.token,
    required this.platform,
    required this.finish,
  });

  final String productId;
  final StorePurchaseStatus status;

  /// Jeton d'achat Google Play, ou identifiant de transaction App Store.
  final String token;

  /// « android » ou « ios », pour que le serveur demande au bon store.
  final String platform;
  final Future<void> Function() finish;
}

/// Accès au store du téléphone ; remplacé par un faux store dans les tests.
abstract class CoinStore {
  Future<bool> isAvailable();
  Future<List<StoreProduct>> products(Set<String> ids);
  Future<void> buy(String productId);

  /// Achats en cours ou non terminés (aussi ceux d'une session précédente).
  Stream<StorePurchase> get purchases;

  /// Redemande les achats pas encore terminés (appli fermée pendant un achat).
  Future<void> resumePending();
}

/// Store indisponible (tests, ordinateur) : la boutique l'affiche simplement.
class UnavailableCoinStore implements CoinStore {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => const [];

  @override
  Future<void> buy(String productId) async {}

  @override
  Stream<StorePurchase> get purchases => const Stream.empty();

  @override
  Future<void> resumePending() async {}
}

/// Google Play Billing et achats intégrés Apple, via `in_app_purchase`.
class DeviceCoinStore implements CoinStore {
  final InAppPurchase _iap = InAppPurchase.instance;
  final Map<String, ProductDetails> _details = {};

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (error) {
      debugPrint('Store unavailable: $error');
      return false;
    }
  }

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async {
    final response = await _iap.queryProductDetails(ids);
    for (final p in response.productDetails) {
      _details[p.id] = p;
    }
    return [
      for (final p in response.productDetails)
        StoreProduct(id: p.id, price: p.price),
    ];
  }

  @override
  Future<void> buy(String productId) async {
    final details = _details[productId];
    if (details == null) return;
    // Pas de consommation automatique : sur Android, l'achat est consommé
    // seulement après que le serveur a crédité les pièces (sinon une coupure
    // réseau ferait perdre l'achat).
    await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
      autoConsume: false,
    );
  }

  @override
  Stream<StorePurchase> get purchases =>
      _iap.purchaseStream.expand((list) => [for (final p in list) _wrap(p)]);

  StorePurchase _wrap(PurchaseDetails p) {
    final status = switch (p.status) {
      PurchaseStatus.pending => StorePurchaseStatus.pending,
      PurchaseStatus.purchased ||
      PurchaseStatus.restored => StorePurchaseStatus.purchased,
      PurchaseStatus.canceled => StorePurchaseStatus.canceled,
      PurchaseStatus.error => StorePurchaseStatus.error,
    };
    return StorePurchase(
      productId: p.productID,
      status: status,
      token: Platform.isIOS
          ? (p.purchaseID ?? '')
          : p.verificationData.serverVerificationData,
      platform: _platform,
      finish: () => _finish(p),
    );
  }

  Future<void> _finish(PurchaseDetails p) async {
    try {
      if (Platform.isAndroid && p.status != PurchaseStatus.error) {
        // Consommer le pack permet de le racheter.
        await _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .consumePurchase(p);
      } else if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    } catch (error) {
      debugPrint('Could not finish purchase: $error');
    }
  }

  @override
  Future<void> resumePending() async {
    try {
      await _iap.restorePurchases();
    } catch (error) {
      debugPrint('Could not resume purchases: $error');
    }
  }
}
