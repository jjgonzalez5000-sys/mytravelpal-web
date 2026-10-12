import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../api/api_client.dart';
import '../config/beta_access.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../widgets/purchase_sheet.dart';

/// SKU identifiers — must match the product IDs configured in Play Console.
const _kEssentialYearly = 'mytravelpal_essential_yearly';
const _kPremiumMonthly = 'mytravelpal_premium_monthly';
const _kPremiumYearly = 'mytravelpal_premium_yearly';

const Set<String> _kAllSkus = {
  _kEssentialYearly,
  _kPremiumMonthly,
  _kPremiumYearly,
};

/// Thin wrapper around the `in_app_purchase` plugin.
///
/// Call [initialize] once at app startup from AppShell. The service
/// subscribes to the Play Billing purchase stream; every completed
/// purchase goes through [_onPurchaseUpdated] which validates with the
/// backend and persists the resolved tier.
///
/// [showPurchaseSheet] is the entry point for all in-app upsell UI.
/// [restorePurchases] satisfies the Play Store policy requirement to
/// let users restore without re-paying.
class BillingService {
  BillingService._();

  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static ApiClient? _api;
  static WidgetRef? _ref;

  // Cache the product details so the sheet can display Play Store prices.
  static List<ProductDetails> _productDetails = const [];
  static List<ProductDetails> get productDetails => List.unmodifiable(_productDetails);

  /// Boot the billing client. Must be called before any purchase flow.
  ///
  /// Idempotent: calling twice cancels the old stream subscription first.
  static Future<void> initialize({
    required ApiClient api,
    required WidgetRef ref,
  }) async {
    _api = api;
    _ref = ref;

    final iap = InAppPurchase.instance;
    final available = await iap.isAvailable();
    if (!available) return;

    await _subscription?.cancel();
    _subscription = iap.purchaseStream.listen(
      (purchases) {
        for (final p in purchases) {
          _onPurchaseUpdated(p);
        }
      },
      onError: (_) {},
    );

    // Pre-fetch product metadata so the sheet can display real prices.
    try {
      final resp = await iap.queryProductDetails(_kAllSkus);
      _productDetails = resp.productDetails;
    } catch (_) {}
  }

  /// Dispose the billing stream. Call from AppShell dispose if needed.
  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _api = null;
    _ref = null;
  }

  /// Open the subscription picker bottom-sheet.
  static Future<void> showPurchaseSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PurchaseSheet(
        productDetails: _productDetails,
        simulated: kBetaAccess,
        // Closed beta: a price tap grants the plan. Production builds
        // (BETA_ACCESS=false) always go through Play Billing.
        onBuyEssential: () => kBetaAccess
            ? _simulate(context, sheetContext, ref, 'essential')
            : _launchPurchase(_kEssentialYearly, ref),
        onBuyPremiumMonthly: () => kBetaAccess
            ? _simulate(context, sheetContext, ref, 'premium')
            : _launchPurchase(_kPremiumMonthly, ref),
        onBuyPremiumYearly: () => kBetaAccess
            ? _simulate(context, sheetContext, ref, 'premium')
            : _launchPurchase(_kPremiumYearly, ref),
        onRestore: () => restorePurchases(_api),
      ),
    );
  }

  /// Closed beta only: grants [tier] as if it had been bought, closes the
  /// sheet and says so. No Play Billing involved and nothing is charged.
  static Future<void> _simulate(
    BuildContext outer,
    BuildContext sheet,
    WidgetRef ref,
    String tier,
  ) async {
    await applySubscriptionTier(ref, tier);
    if (sheet.mounted) Navigator.of(sheet).pop();
    if (outer.mounted) {
      final l = AppLocalizations.of(outer);
      ScaffoldMessenger.of(outer).showSnackBar(
        SnackBar(
          content: Text(
            l.purchaseBetaApplied(tier == 'premium' ? 'Premium' : 'Essential'),
          ),
        ),
      );
    }
  }

  /// Trigger the Play Billing purchase flow for a single SKU.
  static Future<void> _launchPurchase(String sku, WidgetRef ref) async {
    final iap = InAppPurchase.instance;
    if (_productDetails.isEmpty) {
      // Fallback: query now if the pre-fetch failed at init.
      try {
        final resp = await iap.queryProductDetails({sku});
        _productDetails = resp.productDetails;
      } catch (_) {
        return;
      }
    }
    final detail = _productDetails.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == sku,
          orElse: () => null,
        );
    if (detail == null) return;
    final params = PurchaseParam(productDetails: detail);
    await iap.buyNonConsumable(purchaseParam: params);
  }

  /// Restore previous purchases — Play Store policy requirement.
  static Future<void> restorePurchases(ApiClient? api) async {
    await InAppPurchase.instance.restorePurchases();
  }

  /// Handle each purchase update from the stream.
  static Future<void> _onPurchaseUpdated(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) return;

    final iap = InAppPurchase.instance;
    final api = _api;
    final ref = _ref;

    if (purchase.status == PurchaseStatus.error) {
      if (purchase.pendingCompletePurchase) {
        await iap.completePurchase(purchase);
      }
      return;
    }

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      final token =
          purchase.verificationData.serverVerificationData;
      final productId = purchase.productID;

      // Validate with backend; fall back to tier derived from SKU if
      // the backend is unreachable (validation will retry next session).
      String tier = _tierFromSku(productId);
      if (api != null && token.isNotEmpty) {
        try {
          tier = await api.validatePurchase(
            purchaseToken: token,
            productId: productId,
          );
        } catch (_) {
          // Offline or backend error — grant tier locally; backend
          // will re-verify on next launch via restorePurchases.
        }
      }

      // Persisting the tier also drives the derived premium flag so all
      // gates stay consistent.
      if (ref != null) {
        await applySubscriptionTier(ref, tier);
      }

      if (purchase.pendingCompletePurchase) {
        await iap.completePurchase(purchase);
      }
    }
  }

  static String _tierFromSku(String sku) {
    if (sku == _kEssentialYearly) return 'essential';
    if (sku == _kPremiumMonthly || sku == _kPremiumYearly) return 'premium';
    return 'free';
  }
}
