import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'ads_providers.dart';

/// The store, or null where the "remove ads" purchase is not offered.
final inAppPurchaseProvider = Provider<InAppPurchase?>(
  (ref) => ref.watch(adsConfigProvider).removeAdsEnabled && isAdsPlatform
      ? InAppPurchase.instance
      : null,
);

enum RemoveAdsNotice { purchased, failed }

class RemoveAdsState {
  const RemoveAdsState({this.product, this.busy = false, this.notice});

  /// The store's listing, with its localized price; null until loaded or
  /// when the store does not have it.
  final ProductDetails? product;

  /// A purchase is under way.
  final bool busy;

  /// The latest outcome to tell the user about.
  final RemoveAdsNotice? notice;
}

/// Buys and restores "remove ads". It listens from app start, because the
/// stores redeliver unfinished and restored purchases on that stream.
class RemoveAdsNotifier extends Notifier<RemoveAdsState> {
  InAppPurchase? get _store => ref.read(inAppPurchaseProvider);
  String get _productId => ref.read(adsConfigProvider).removeAdsProductId;

  @override
  RemoveAdsState build() {
    final store = ref.watch(inAppPurchaseProvider);
    if (store == null) return const RemoveAdsState();
    final subscription = store.purchaseStream.listen(_onPurchases);
    ref.onDispose(subscription.cancel);
    unawaited(_loadProduct(store));
    return const RemoveAdsState();
  }

  Future<void> _loadProduct(InAppPurchase store) async {
    try {
      if (!await store.isAvailable()) return;
      final response = await store.queryProductDetails({_productId});
      final product = response.productDetails
          .where((p) => p.id == _productId)
          .firstOrNull;
      if (ref.mounted && product != null) {
        state = RemoveAdsState(product: product, busy: state.busy);
      }
    } catch (_) {
      // No listing means no buy button; nothing else depends on it.
    }
  }

  Future<void> buy() async {
    final store = _store;
    final product = state.product;
    if (store == null || product == null || state.busy) return;
    state = RemoveAdsState(product: product, busy: true);
    try {
      final started = await store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) _finish(RemoveAdsNotice.failed);
    } catch (_) {
      _finish(RemoveAdsNotice.failed);
    }
  }

  /// Restored purchases arrive on the purchase stream like new ones.
  Future<void> restore() async => _store?.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _productId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = RemoveAdsState(product: state.product, busy: true);
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          await ref.read(adsRemovedProvider.notifier).markRemoved();
          _finish(RemoveAdsNotice.purchased);
        case PurchaseStatus.error:
          _finish(RemoveAdsNotice.failed);
        case PurchaseStatus.canceled:
          _finish(null);
      }
      if (purchase.pendingCompletePurchase) {
        await _store?.completePurchase(purchase);
      }
    }
  }

  void _finish(RemoveAdsNotice? notice) {
    if (!ref.mounted) return;
    state = RemoveAdsState(product: state.product, notice: notice);
  }
}

final removeAdsProvider = NotifierProvider<RemoveAdsNotifier, RemoveAdsState>(
  RemoveAdsNotifier.new,
);
