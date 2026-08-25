import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/favorite_place.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../widgets/location_search_field.dart' show iconForPlaceLabel;

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.favoritesTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.favoritesTabPlaces),
              Tab(text: l.favoritesTabHotels),
              Tab(text: l.favoritesTabRestaurants),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PlacesList(
              places: ref.watch(favoritePlacesProvider),
              emptyMessage: l.favoritesEmptyPlaces,
              onRemove: (label) =>
                  ref.read(favoritePlacesProvider.notifier).remove(label),
            ),
            _FavList(
              items: favoriteHotels(ref),
              emptyMessage: l.favoritesEmptyHotels,
              onRemove: (m) =>
                  ref.read(favoritesProvider.notifier).toggleHotel(m),
              priceKey: 'price_eur_per_night',
              priceSuffix: '€/night',
            ),
            _FavList(
              items: favoriteRestaurants(ref),
              emptyMessage: l.favoritesEmptyRestaurants,
              onRemove: (m) =>
                  ref.read(favoritesProvider.notifier).toggleRestaurant(m),
              priceKey: 'price_eur_per_meal',
              priceSuffix: '€/meal',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacesList extends StatelessWidget {
  const _PlacesList({
    required this.places,
    required this.emptyMessage,
    required this.onRemove,
  });

  final List<FavoritePlace> places;
  final String emptyMessage;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = places[i];
        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(iconForPlaceLabel(p.label),
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          title: Text(p.label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            p.place.displayName,
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: l.favoritesTooltipRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onRemove(p.label),
          ),
        );
      },
    );
  }
}

class _FavList extends StatelessWidget {
  const _FavList({
    required this.items,
    required this.emptyMessage,
    required this.onRemove,
    required this.priceKey,
    required this.priceSuffix,
  });

  final List<Map<String, dynamic>> items;
  final String emptyMessage;
  final ValueChanged<Map<String, dynamic>> onRemove;
  final String priceKey;
  final String priceSuffix;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = items[i];
        final price = (m[priceKey] as num?)?.toDouble();
        return ListTile(
          leading: Icon(
            m['kind'] == 'hotel' ? Icons.hotel : Icons.restaurant,
          ),
          title: Text(m['name']?.toString() ?? '—'),
          subtitle: Text([
            m['country']?.toString(),
            if (price != null) '${price.toStringAsFixed(0)} $priceSuffix',
            (m['price_band'] as String?)?.toUpperCase(),
          ].whereType<String>().join(' · ')),
          trailing: IconButton(
            tooltip: l.favoritesTooltipRemove,
            icon: const Icon(Icons.star),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () => onRemove(m),
          ),
        );
      },
    );
  }
}
