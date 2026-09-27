import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Compact progress card shown between the map/hero and the day plan
/// while the `/plan/enrich` request is in flight. Replaces per-section
/// skeletons + the wrong "activa hoteles..." empty-state that used to
/// flash for a request that IS going to bring hotels a few seconds
/// later.
///
/// Rendering rules:
/// - Only shows chips for categories the user actually requested
///   (hotel prefs on / restaurant prefs on / etc). If a category isn't
///   requested, it doesn't add noise.
/// - Each chip transitions from spinner → check when its data lands.
/// - The whole card auto-fades and slides out when `pending` flips
///   false (all categories done).
class EnrichmentProgress extends StatelessWidget {
  const EnrichmentProgress({
    super.key,
    required this.pending,
    required this.hotelsRequested,
    required this.restaurantsRequested,
    required this.adverseRequested,
    required this.hasHotels,
    required this.hasRestaurants,
    required this.hasFuel,
    required this.hasWeather,
    required this.hasAdverse,
  });

  /// True while the enrich future is still in flight. When false the
  /// card fades out over 300 ms then removes itself from the tree.
  final bool pending;

  final bool hotelsRequested;
  final bool restaurantsRequested;
  final bool adverseRequested;

  final bool hasHotels;
  final bool hasRestaurants;
  final bool hasFuel;
  final bool hasWeather;
  final bool hasAdverse;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    // Build the chip list dynamically — only for requested categories.
    // Fuel + weather are always requested (they always appear in the
    // response when the backend has data; there's no per-user opt-out
    // in the plan form yet). Adverse is gated by an explicit flag.
    final chips = <_EnrichChipData>[
      if (hotelsRequested)
        _EnrichChipData(
          icon: Icons.hotel_outlined,
          label: l.enrichmentChipHotels,
          done: hasHotels,
        ),
      if (restaurantsRequested)
        _EnrichChipData(
          icon: Icons.restaurant_outlined,
          label: l.enrichmentChipRestaurants,
          done: hasRestaurants,
        ),
      _EnrichChipData(
        icon: Icons.local_gas_station_outlined,
        label: l.enrichmentChipFuel,
        done: hasFuel,
      ),
      _EnrichChipData(
        icon: Icons.wb_cloudy_outlined,
        label: l.enrichmentChipWeather,
        done: hasWeather,
      ),
      if (adverseRequested)
        _EnrichChipData(
          icon: Icons.warning_amber_outlined,
          label: l.enrichmentChipAdverse,
          done: hasAdverse,
        ),
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: pending ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: pending
            ? Card(
                elevation: 0,
                color: scheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusLg),
                  side: BorderSide(color: scheme.outlineVariant, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.space16,
                    Tokens.space12,
                    Tokens.space16,
                    Tokens.space12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: Tokens.space12),
                          Expanded(
                            child: Text(
                              l.enrichmentLoadingTitle,
                              style: t.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Tokens.space8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: Tokens.space12),
                      Wrap(
                        spacing: Tokens.space8,
                        runSpacing: Tokens.space8,
                        children: [
                          for (final c in chips) _EnrichChip(data: c),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _EnrichChipData {
  const _EnrichChipData({
    required this.icon,
    required this.label,
    required this.done,
  });
  final IconData icon;
  final String label;
  final bool done;
}

class _EnrichChip extends StatelessWidget {
  const _EnrichChip({required this.data});
  final _EnrichChipData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = data.done;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(
          color: done ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : data.icon,
            size: 14,
            color: done ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: done ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
