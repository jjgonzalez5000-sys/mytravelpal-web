import 'package:flutter/material.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'price_band_multiselect.dart';

/// Immutable snapshot of the user's hotel-search preferences.
///
/// `priceBands` is a set: users can pick any combination of Budget /
/// Mid / Luxury. Empty set OR all three selected → treated as ANY
/// (the backend applies no filter). Exposing the raw `priceBand`
/// getter keeps a few legacy callers happy — it collapses the set
/// to a single value.
@immutable
class HotelPreferences {
  const HotelPreferences({
    required this.enabled,
    required this.maxDetourMinutes,
    required this.priceBands,
    this.minStars = 0,
    this.requireParking = false,
  });

  final bool enabled;
  final int maxDetourMinutes;
  final Set<PriceBand> priceBands;

  /// Minimum star rating. 0 = no filter, 3-5 = filter by
  /// `attributes['stars']` post-response. OSM data is spotty
  /// on stars, so a "3+" filter with strict enforcement would
  /// hide most hotels — see the tolerant client-side filter in
  /// ResultScreen where hotels lacking the tag pass through.
  final int minStars;

  /// Only surface hotels tagged with parking. Falls back to
  /// showing everything when the tag is missing (same tolerance
  /// as [minStars]).
  final bool requireParking;

  /// Legacy single-band view. Returns the sole selected band, or
  /// `any` when the set is empty or represents "everything".
  PriceBand get priceBand {
    if (priceBands.length == 1) return priceBands.first;
    return PriceBand.any;
  }

  static const HotelPreferences disabled = HotelPreferences(
    enabled: false,
    maxDetourMinutes: 30,
    priceBands: {PriceBand.any},
  );

  /// Sensible on-by-default. Chosen 30 min detour so overnight
  /// candidates surface without the user having to opt in first —
  /// multi-day trips are useless without hotel context. Users who
  /// want to hide the section can toggle it off.
  static const HotelPreferences enabledDefault = HotelPreferences(
    enabled: true,
    maxDetourMinutes: 30,
    priceBands: {PriceBand.any},
  );

  HotelPreferences copyWith({
    bool? enabled,
    int? maxDetourMinutes,
    Set<PriceBand>? priceBands,
    int? minStars,
    bool? requireParking,
  }) =>
      HotelPreferences(
        enabled: enabled ?? this.enabled,
        maxDetourMinutes: maxDetourMinutes ?? this.maxDetourMinutes,
        priceBands: priceBands ?? this.priceBands,
        minStars: minStars ?? this.minStars,
        requireParking: requireParking ?? this.requireParking,
      );
}

/// Collapsible section: switch to enable, then a detour slider and price
/// band picker underneath.
class HotelPreferencesSection extends StatelessWidget {
  const HotelPreferencesSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HotelPreferences value;
  final ValueChanged<HotelPreferences> onChanged;

  static const _detourStep = 15;
  static const _detourMin = 15;
  static const _detourMax = 120;

  String _bandsLabel(AppLocalizations l, Set<PriceBand> bands) {
    if (bands.isEmpty || bands.contains(PriceBand.any)) {
      return l.prefBandAny;
    }
    // Preserve visual order Budget → Mid → Luxury.
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
          title: Text(l.hotelPrefTitle),
          subtitle: value.enabled
              ? Text(l.hotelPrefSubEnabled(
                  value.maxDetourMinutes,
                  _bandsLabel(l, value.priceBands),
                ))
              : Text(l.hotelPrefSubOff),
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
          // Multi-select. Picking 2 filters by both; picking all 3
          // collapses to "any" (the backend treats it the same).
          PriceBandMultiSelect(
            selected: value.priceBands,
            onChanged: (bands) =>
                onChanged(value.copyWith(priceBands: bands)),
          ),
          const SizedBox(height: Tokens.space12),
          // Star filter — 0 (any), 3+, 4+, 5. Kept as an inline
          // segmented button rather than a slider so the driver
          // reads it at a glance.
          Row(
            children: [
              Text(l.hotelPrefStarsLabel,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 0, label: Text(l.hotelPrefStarsAny)),
                    const ButtonSegment(value: 3, label: Text('3★+')),
                    const ButtonSegment(value: 4, label: Text('4★+')),
                    const ButtonSegment(value: 5, label: Text('5★')),
                  ],
                  selected: {value.minStars},
                  onSelectionChanged: (s) =>
                      onChanged(value.copyWith(minStars: s.first)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.hotelPrefParkingTitle),
            subtitle: Text(l.hotelPrefParkingSub,
                style: Theme.of(context).textTheme.bodySmall),
            value: value.requireParking,
            onChanged: (v) =>
                onChanged(value.copyWith(requireParking: v)),
          ),
        ],
      ],
    );
  }
}
