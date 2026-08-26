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
  });

  final bool enabled;
  final int maxDetourMinutes;
  final Set<PriceBand> priceBands;
  final int minStars;
  final bool requireParking;
  final bool requireWifi;
  final bool requireWheelchair;
  final bool includeOtherAccommodation;

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
      );
}

class HotelPreferencesSection extends StatelessWidget {
  const HotelPreferencesSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HotelPreferences value;
  final ValueChanged<HotelPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        ],
      ],
    );
  }
}
