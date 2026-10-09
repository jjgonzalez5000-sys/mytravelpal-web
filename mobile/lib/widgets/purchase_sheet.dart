import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../l10n/app_localizations.dart';

/// Three-tier subscription picker bottom-sheet.
///
/// Shows Free / Essential / Premium cards. Prices come from Play Console
/// via [productDetails] when available; otherwise falls back to the
/// hard-coded display prices below.
class PurchaseSheet extends StatefulWidget {
  const PurchaseSheet({
    super.key,
    required this.productDetails,
    required this.onBuyEssential,
    required this.onBuyPremiumMonthly,
    required this.onBuyPremiumYearly,
    required this.onRestore,
    this.simulated = false,
  });

  /// True in closed-beta builds: a plan tap grants the plan without
  /// charging, and the sheet says so.
  final bool simulated;

  final List<ProductDetails> productDetails;
  final VoidCallback onBuyEssential;
  final VoidCallback onBuyPremiumMonthly;
  final VoidCallback onBuyPremiumYearly;
  final VoidCallback onRestore;

  @override
  State<PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<PurchaseSheet> {
  // true = yearly, false = monthly (only applies to Premium tier).
  bool _yearlyPremium = true;
  bool _buying = false;

  String _priceFor(String sku, String fallback) {
    final match = widget.productDetails.cast<ProductDetails?>().firstWhere(
          (p) => p?.id == sku,
          orElse: () => null,
        );
    return match?.price ?? fallback;
  }

  Future<void> _tap(VoidCallback cb) async {
    if (_buying) return;
    setState(() => _buying = true);
    try {
      cb();
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final l = AppLocalizations.of(context);
    // Real prices come from Play (already localised); these only show when
    // the store did not answer.
    final essentialPrice = _priceFor(
        'mytravelpal_essential_yearly', l.paywallPerYear('19.99 EUR'));
    final premiumMonthlyPrice = _priceFor(
        'mytravelpal_premium_monthly', l.paywallPerMonth('4.99 EUR'));
    final premiumYearlyPrice = _priceFor(
        'mytravelpal_premium_yearly', l.paywallPerYear('39.99 EUR'));

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'MyTravelPal Premium',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                l.paywallSubtitle,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (widget.simulated) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context).purchaseBetaNote,
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Free tier
              _TierCard(
                title: l.settingsTierFreeName,
                price: l.paywallFreePrice,
                subtitle: l.paywallFreeSubtitle,
                features: [
                  l.paywallFreeF1,
                  l.paywallFreeF2,
                  l.paywallFreeF3,
                  l.paywallFreeF4,
                ],
                accent: scheme.outline,
                isCurrent: true,
                cta: l.paywallCurrentPlan,
                onTap: null,
              ),
              const SizedBox(height: 12),

              // Essential tier
              _TierCard(
                title: 'Essential',
                price: essentialPrice,
                subtitle: l.paywallEssentialSubtitle,
                features: [
                  l.paywallEssentialF1,
                  l.paywallEssentialF2,
                  l.paywallEssentialF3,
                  l.paywallEssentialF4,
                  l.paywallEssentialF5,
                  l.paywallEssentialF6,
                ],
                accent: scheme.primary,
                isCurrent: false,
                cta: _buying ? l.paywallOpening : l.paywallStartTrial,
                onTap: _buying ? null : () => _tap(widget.onBuyEssential),
              ),
              const SizedBox(height: 12),

              // Premium — monthly / yearly toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.paywallMonthly),
                      const SizedBox(width: 8),
                      Switch(
                        value: _yearlyPremium,
                        onChanged: (v) => setState(() => _yearlyPremium = v),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.paywallYearly),
                          Text(
                            l.paywallSave33,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _TierCard(
                    title: 'Premium',
                    price: _yearlyPremium ? premiumYearlyPrice : premiumMonthlyPrice,
                    subtitle: l.paywallPremiumSubtitle,
                    features: [
                      l.paywallPremiumF1,
                      l.paywallPremiumF2,
                      l.paywallPremiumF3,
                      l.paywallPremiumF4,
                      l.paywallPremiumF5,
                      l.paywallPremiumF6,
                    ],
                    accent: const Color(0xFFD4A017), // gold
                    isCurrent: false,
                    cta: _buying ? l.paywallOpening : l.paywallGetPremium,
                    onTap: _buying
                        ? null
                        : () => _tap(
                              _yearlyPremium
                                  ? widget.onBuyPremiumYearly
                                  : widget.onBuyPremiumMonthly,
                            ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: widget.onRestore,
                  child: Text(l.paywallRestore),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.paywallLegal,
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.features,
    required this.accent,
    required this.isCurrent,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String price;
  final String subtitle;
  final List<String> features;
  final Color accent;
  final bool isCurrent;
  final String cta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final disabled = onTap == null && !isCurrent;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isCurrent ? scheme.outline : accent,
          width: isCurrent ? 1 : 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              Text(
                price,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: text.bodySmall)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: isCurrent ? null : onTap,
            style: FilledButton.styleFrom(
              backgroundColor: isCurrent ? null : accent,
              foregroundColor: isCurrent ? null : Colors.white,
              disabledBackgroundColor:
                  isCurrent ? scheme.surfaceContainerHighest : null,
            ),
            child: Text(cta),
          ),
        ],
      ),
    );
  }
}
