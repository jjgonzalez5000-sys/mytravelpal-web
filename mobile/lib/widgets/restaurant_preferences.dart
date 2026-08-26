import 'package:flutter/material.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';
import 'price_band_multiselect.dart';

/// Immutable snapshot of the user's restaurant-search preferences.
///
/// Multi-select bands like hotels. Also carries an OSM `cuisine`
/// whitelist so the driver can filter by "italian / spanish / tapas
/// / etc." — otherwise the raw list can be huge and dominated by
/// nearby fast food.
@immutable
class RestaurantPreferences {
  const RestaurantPreferences({
    required this.enabled,
    required this.maxDetourMinutes,
    required this.priceBands,
    this.cuisines = const {},
    this.vegetarian = false,
    this.vegan = false,
    this.glutenFree = false,
    this.halal = false,
    this.kosher = false,
  });

  final bool enabled;
  final int maxDetourMinutes;
  final Set<PriceBand> priceBands;
  final Set<String> cuisines;
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final bool halal;
  final bool kosher;

  PriceBand get priceBand {
    if (priceBands.length == 1) return priceBands.first;
    return PriceBand.any;
  }

  /// Build the Geoapify `conditions` param from the diet toggles.
  String? get geoapifyConditions {
    final parts = <String>[];
    if (vegetarian) parts.add('vegetarian');
    if (vegan) parts.add('vegan');
    if (glutenFree) parts.add('gluten_free');
    if (halal) parts.add('halal');
    if (kosher) parts.add('kosher');
    return parts.isEmpty ? null : parts.join(',');
  }

  static const RestaurantPreferences disabled = RestaurantPreferences(
    enabled: false,
    maxDetourMinutes: 20,
    priceBands: {PriceBand.any},
  );

  RestaurantPreferences copyWith({
    bool? enabled,
    int? maxDetourMinutes,
    Set<PriceBand>? priceBands,
    Set<String>? cuisines,
    bool? vegetarian,
    bool? vegan,
    bool? glutenFree,
    bool? halal,
    bool? kosher,
  }) =>
      RestaurantPreferences(
        enabled: enabled ?? this.enabled,
        maxDetourMinutes: maxDetourMinutes ?? this.maxDetourMinutes,
        priceBands: priceBands ?? this.priceBands,
        cuisines: cuisines ?? this.cuisines,
        vegetarian: vegetarian ?? this.vegetarian,
        vegan: vegan ?? this.vegan,
        glutenFree: glutenFree ?? this.glutenFree,
        halal: halal ?? this.halal,
        kosher: kosher ?? this.kosher,
      );
}

class RestaurantPreferencesSection extends StatelessWidget {
  const RestaurantPreferencesSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RestaurantPreferences value;
  final ValueChanged<RestaurantPreferences> onChanged;

  static const _detourStep = 5;
  static const _detourMin = 5;
  static const _detourMax = 60;

  /// OSM `cuisine` values we surface to the user. Each option carries
  /// its own set of raw OSM tags because a "asian" chip should match
  /// stations tagged `chinese`, `japanese`, `thai`, etc. Label lookup
  /// is delegated to `_cuisineLabel(l, id)` so it localises.
  static const _cuisineOptions = <_CuisineOption>[
    _CuisineOption('italian', {'italian', 'pizza'}),
    _CuisineOption('spanish', {'spanish'}),
    _CuisineOption('tapas', {'tapas'}),
    _CuisineOption('french', {'french'}),
    _CuisineOption('mediterranean', {'mediterranean'}),
    _CuisineOption('asian', {'asian', 'chinese', 'japanese', 'thai'}),
    _CuisineOption('indian', {'indian'}),
    _CuisineOption('burger', {'burger'}),
    _CuisineOption('seafood', {'seafood', 'fish'}),
    _CuisineOption('vegetarian', {'vegetarian', 'vegan'}),
    _CuisineOption('bbq', {'barbecue', 'steak_house'}),
    _CuisineOption('regional', {'regional'}),
  ];

  static String _cuisineLabel(AppLocalizations l, String id) => switch (id) {
        'italian' => l.cuisineItalian,
        'spanish' => l.cuisineSpanish,
        'tapas' => l.cuisineTapas,
        'french' => l.cuisineFrench,
        'mediterranean' => l.cuisineMediterranean,
        'asian' => l.cuisineAsian,
        'indian' => l.cuisineIndian,
        'burger' => l.cuisineBurger,
        'seafood' => l.cuisineSeafood,
        'vegetarian' => l.cuisineVegetarian,
        'bbq' => l.cuisineBbq,
        'regional' => l.cuisineRegional,
        _ => id,
      };

  String _bandsLabel(AppLocalizations l, Set<PriceBand> bands) {
    if (bands.isEmpty || bands.contains(PriceBand.any)) {
      return l.prefBandAny;
    }
    const order = [PriceBand.budget, PriceBand.mid, PriceBand.lux];
    return order
        .where(bands.contains)
        .map((b) => b.symbol)
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l.restaurantPrefTitle),
          subtitle: value.enabled
              ? Text(l.restaurantPrefSubEnabled(
                  value.maxDetourMinutes,
                  _bandsLabel(l, value.priceBands),
                ))
              : Text(l.restaurantPrefSubOff),
          value: value.enabled,
          onChanged: (v) => onChanged(value.copyWith(enabled: v)),
        ),
        if (value.enabled) ...[
          const SizedBox(height: 8),
          Text(l.prefMaxDetour(value.maxDetourMinutes),
              style: Theme.of(context).textTheme.bodyMedium),
          Slider(
            value: value.maxDetourMinutes.toDouble(),
            min: _detourMin.toDouble(),
            max: _detourMax.toDouble(),
            divisions: (_detourMax - _detourMin) ~/ _detourStep,
            label: '${value.maxDetourMinutes} min',
            onChanged: (v) => onChanged(
              value.copyWith(maxDetourMinutes: v.round()),
            ),
          ),
          const SizedBox(height: 4),
          PriceBandMultiSelect(
            selected: value.priceBands,
            onChanged: (bands) =>
                onChanged(value.copyWith(priceBands: bands)),
          ),
          const SizedBox(height: 12),
          Text(
            l.restaurantPrefCuisinesLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final opt in _cuisineOptions)
                FilterChip(
                  selected: value.cuisines.contains(opt.id),
                  label: Text(_cuisineLabel(l, opt.id)),
                  onSelected: (sel) {
                    final next = {...value.cuisines};
                    if (sel) {
                      next.add(opt.id);
                    } else {
                      next.remove(opt.id);
                    }
                    onChanged(value.copyWith(cuisines: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.restaurantDietaryLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                selected: value.vegetarian,
                label: Text(l.restaurantFilterVegetarian),
                onSelected: (v) =>
                    onChanged(value.copyWith(vegetarian: v)),
              ),
              FilterChip(
                selected: value.vegan,
                label: Text(l.restaurantFilterVegan),
                onSelected: (v) =>
                    onChanged(value.copyWith(vegan: v)),
              ),
              FilterChip(
                selected: value.glutenFree,
                label: Text(l.restaurantFilterGlutenFree),
                onSelected: (v) =>
                    onChanged(value.copyWith(glutenFree: v)),
              ),
              FilterChip(
                selected: value.halal,
                label: Text(l.restaurantFilterHalal),
                onSelected: (v) =>
                    onChanged(value.copyWith(halal: v)),
              ),
              FilterChip(
                selected: value.kosher,
                label: Text(l.restaurantFilterKosher),
                onSelected: (v) =>
                    onChanged(value.copyWith(kosher: v)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CuisineOption {
  const _CuisineOption(this.id, this.osmTags);
  final String id;
  final Set<String> osmTags;
}

/// Collapse the visible cuisine IDs into the raw OSM tags the
/// backend expects. Exposed as a top-level helper so `plan_screen`
/// can build the payload without importing internals.
Set<String> cuisineOsmTagsFor(Set<String> selectedIds) {
  final out = <String>{};
  for (final opt in RestaurantPreferencesSection._cuisineOptions) {
    if (selectedIds.contains(opt.id)) {
      out.addAll(opt.osmTags);
    }
  }
  return out;
}
