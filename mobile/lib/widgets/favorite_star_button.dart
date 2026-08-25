import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';

/// One-tap toggle for adding a POI to the user's favorites. Reads its
/// selected state from [favoritesProvider] so all tiles referring to
/// the same id (star on result screen + heart on favorites screen)
/// stay in sync.
class FavoriteStarButton extends ConsumerWidget {
  const FavoriteStarButton({
    super.key,
    required this.id,
    required this.isRestaurant,
    required this.payload,
  });

  final String id;
  final bool isRestaurant;

  /// Full JSON payload to persist when adding to favorites.
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isFav = isRestaurant
        ? isFavoriteRestaurant(ref, id)
        : isFavoriteHotel(ref, id);
    return IconButton(
      tooltip: isFav ? l.favoritesTooltipRemove : l.favoritesTooltipAdd,
      icon: Icon(
        isFav ? Icons.star : Icons.star_border,
        color: isFav ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: () {
        final notifier = ref.read(favoritesProvider.notifier);
        if (isRestaurant) {
          notifier.toggleRestaurant(payload);
        } else {
          notifier.toggleHotel(payload);
        }
      },
    );
  }
}
