import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../services/my_places_match.dart' show PlaceOnRoute;
import 'my_place_category.dart';

/// The driver's saved places that lie near the current route, in the order
/// the route meets them, each with how far off the road it is and a button
/// to add it as a stop (or take it back out).
class MyPlacesOnRoute extends StatelessWidget {
  const MyPlacesOnRoute({
    super.key,
    required this.matches,
    required this.addedIds,
    required this.onToggle,
  });

  final List<PlaceOnRoute> matches;

  /// Ids of the saved places already added to this route.
  final Set<String> addedIds;

  final ValueChanged<PlaceOnRoute> onToggle;

  /// More than this and the card becomes a wall; the nearest-to-route ones
  /// by position along it are the useful ones.
  static const int _maxShown = 6;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(Tokens.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: Text(
                  l.myPlacesOnRouteTitle,
                  style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          for (final m in matches.take(_maxShown))
            _Row(
              match: m,
              added: addedIds.contains(m.place.id),
              onToggle: () => onToggle(m),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.match,
    required this.added,
    required this.onToggle,
  });

  final PlaceOnRoute match;
  final bool added;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final p = match.place;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Icon(myPlaceCategoryIcon(p.category), size: 18),
          ),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  l.myPlacesOffRoute(
                    match.distanceKm.toStringAsFixed(1),
                    match.detourMinutes.round(),
                  ),
                  style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: Tokens.space8),
          added
              ? FilledButton.tonalIcon(
                  onPressed: onToggle,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(l.myPlacesRemoveFromRoute),
                )
              : OutlinedButton(
                  onPressed: onToggle,
                  child: Text(l.myPlacesAddToRoute),
                ),
        ],
      ),
    );
  }
}
