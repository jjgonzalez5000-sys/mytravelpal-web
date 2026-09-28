import 'package:flutter/material.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'price_band_multiselect.dart';

@immutable
class HotelPreferences {
  const HotelPreferences({
    required this.enabled,
    this.maxDetourMinutes = 45,
    this.priceBands = const {PriceBand.any},
    this.minStars = 0,
    this.requireParking = false,
    this.requireWifi = false,
    this.requireWheelchair = false,
    this.includeOtherAccommodation = false,
    this.destinationRadiusKm = 40,
  });

  final bool enabled;
  final int maxDetourMinutes;
  final Set<PriceBand> priceBands;
  final int minStars;
  final bool requireParking;
  final bool requireWifi;
  final bool requireWheelchair;
  final bool includeOtherAccommodation;
  /// Extra hotel-search radius around the destination. 5–100 km.
  /// Default 40 matches the backend default; users can push it
  /// higher for rural destinations where the corridor pass
  /// returns a thin pool.
  final int destinationRadiusKm;

  PriceBand get priceBand {
    if (priceBands.length == 1) return priceBands.first;
    return PriceBand.any;
  }

  static const HotelPreferences disabled = HotelPreferences(
    enabled: false,
  );

  static const HotelPreferences enabledDefault = HotelPreferences(
    enabled: true,
  );

  HotelPreferences copyWith({
    bool? enabled,
    int? maxDetourMinutes,
    Set<PriceBand>? priceBands,
    int? minStars,
    bool? requireParking,
    bool? requireWifi,
    bool? requireWheelchair,
    bool? includeOtherAccommodation,
    int? destinationRadiusKm,
  }) =>
      HotelPreferences(
        enabled: enabled ?? this.enabled,
        maxDetourMinutes: maxDetourMinutes ?? this.maxDetourMinutes,
        priceBands: priceBands ?? this.priceBands,
        minStars: minStars ?? this.minStars,
        requireParking: requireParking ?? this.requireParking,
        requireWifi: requireWifi ?? this.requireWifi,
        requireWheelchair: requireWheelchair ?? this.requireWheelchair,
        includeOtherAccommodation:
            includeOtherAccommodation ?? this.includeOtherAccommodation,
        destinationRadiusKm:
            destinationRadiusKm ?? this.destinationRadiusKm,
      );

  /// Serialise for SharedPreferences persistence. PriceBand set is
  /// stored as a list of `slug` values (backend-compatible enum names)
  /// so a future schema change in the enum doesn't break stored prefs.
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'max_detour_minutes': maxDetourMinutes,
        'price_bands':
            priceBands.map((b) => b.name).toList(growable: false),
        'min_stars': minStars,
        'require_parking': requireParking,
        'require_wifi': requireWifi,
        'require_wheelchair': requireWheelchair,
        'include_other_accommodation': includeOtherAccommodation,
        'destination_radius_km': destinationRadiusKm,
      };

  factory HotelPreferences.fromJson(Map<String, dynamic> j) {
    Set<PriceBand> bands = const {PriceBand.any};
    final raw = j['price_bands'];
    if (raw is List) {
      final parsed = raw
          .whereType<String>()
          .map((s) =>
              PriceBand.values.firstWhere(
                (b) => b.name == s,
                orElse: () => PriceBand.any,
              ))
          .toSet();
      if (parsed.isNotEmpty) bands = parsed;
    }
    return HotelPreferences(
      enabled: j['enabled'] as bool? ?? true,
      maxDetourMinutes: (j['max_detour_minutes'] as num?)?.toInt() ?? 45,
      priceBands: bands,
      minStars: (j['min_stars'] as num?)?.toInt() ?? 0,
      requireParking: j['require_parking'] as bool? ?? false,
      requireWifi: j['require_wifi'] as bool? ?? false,
      requireWheelchair: j['require_wheelchair'] as bool? ?? false,
      includeOtherAccommodation:
          j['include_other_accommodation'] as bool? ?? false,
      destinationRadiusKm:
          (j['destination_radius_km'] as num?)?.toInt() ?? 40,
    );
  }
}

class HotelPreferencesSection extends StatelessWidget {
  const HotelPreferencesSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.hideMainSwitch = false,
  });

  /// When true, don't render the top "Enable hotels" SwitchListTile.
  /// Used by the compact prefs layout where the parent already owns
  /// the enable/disable switch and this widget only shows the
  /// nested options (detour slider, stars, filters).
  final bool hideMainSwitch;

  final HotelPreferences value;
  final ValueChanged<HotelPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hideMainSwitch)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.hotelPrefTitle),
            subtitle: Text(
              value.enabled ? l.hotelPrefSubOn : l.hotelPrefSubOff,
              style: t.bodySmall,
            ),
            value: value.enabled,
            onChanged: (v) => onChanged(value.copyWith(enabled: v)),
          ),
        if (value.enabled) ...[
          const SizedBox(height: 4),
          PriceBandMultiSelect(
            selected: value.priceBands,
            onChanged: (bands) =>
                onChanged(value.copyWith(priceBands: bands)),
          ),
          const SizedBox(height: Tokens.space12),
          Row(
            children: [
              Text(l.hotelPrefStarsLabel, style: t.bodyMedium),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 0, label: Text(l.hotelPrefStarsAny)),
                    const ButtonSegment(value: 3, label: Text('3+')),
                    const ButtonSegment(value: 4, label: Text('4+')),
                    const ButtonSegment(value: 5, label: Text('5')),
                  ],
                  selected: {value.minStars},
                  onSelectionChanged: (s) =>
                      onChanged(value.copyWith(minStars: s.first)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                selected: value.requireParking,
                label: Text(l.hotelFilterParking),
                onSelected: (v) =>
                    onChanged(value.copyWith(requireParking: v)),
              ),
              FilterChip(
                selected: value.requireWifi,
                label: Text(l.hotelFilterWifi),
                onSelected: (v) =>
                    onChanged(value.copyWith(requireWifi: v)),
              ),
              FilterChip(
                selected: value.requireWheelchair,
                label: Text(l.hotelFilterAccessible),
                onSelected: (v) =>
                    onChanged(value.copyWith(requireWheelchair: v)),
              ),
              FilterChip(
                selected: value.includeOtherAccommodation,
                label: Text(l.hotelFilterOtherTypes),
                onSelected: (v) =>
                    onChanged(value.copyWith(includeOtherAccommodation: v)),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          // Destination radius — how far from the final stop we
          // scan for hotels. Rural destinations benefit from
          // pushing it up; city centres are fine at 40 km.
          Row(
            children: [
              Text(l.hotelPrefDestRadiusLabel, style: t.bodyMedium),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: Slider(
                  min: 10, max: 100, divisions: 9,
                  value: value.destinationRadiusKm.toDouble(),
                  label: '${value.destinationRadiusKm} km',
                  onChanged: (v) => onChanged(
                    value.copyWith(destinationRadiusKm: v.round()),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${value.destinationRadiusKm} km',
                  textAlign: TextAlign.end,
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
