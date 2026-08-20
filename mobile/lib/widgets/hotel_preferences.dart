import 'package:flutter/material.dart';

import '../api/models.dart';

/// Immutable snapshot of the user's hotel-search preferences.
@immutable
class HotelPreferences {
  const HotelPreferences({
    required this.enabled,
    required this.maxDetourMinutes,
    required this.priceBand,
  });

  final bool enabled;
  final int maxDetourMinutes;
  final PriceBand priceBand;

  static const HotelPreferences disabled = HotelPreferences(
    enabled: false,
    maxDetourMinutes: 30,
    priceBand: PriceBand.any,
  );

  HotelPreferences copyWith({
    bool? enabled,
    int? maxDetourMinutes,
    PriceBand? priceBand,
  }) =>
      HotelPreferences(
        enabled: enabled ?? this.enabled,
        maxDetourMinutes: maxDetourMinutes ?? this.maxDetourMinutes,
        priceBand: priceBand ?? this.priceBand,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Add hotels along the route'),
          subtitle: value.enabled
              ? Text(
                  'Up to ${value.maxDetourMinutes} min detour · '
                  '${value.priceBand.displayName} (${value.priceBand.symbol})',
                )
              : const Text('Off. Turn on to see hotels near your route.'),
          value: value.enabled,
          onChanged: (v) => onChanged(value.copyWith(enabled: v)),
        ),
        if (value.enabled) ...[
          const SizedBox(height: 8),
          Text('Max detour: ${value.maxDetourMinutes} min',
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
          SegmentedButton<PriceBand>(
            segments: const [
              ButtonSegment(
                value: PriceBand.budget,
                label: Text('Budget'),
                icon: Text('€'),
              ),
              ButtonSegment(
                value: PriceBand.mid,
                label: Text('Mid'),
                icon: Text('€€'),
              ),
              ButtonSegment(
                value: PriceBand.lux,
                label: Text('Luxury'),
                icon: Text('€€€'),
              ),
              ButtonSegment(
                value: PriceBand.any,
                label: Text('Any'),
                icon: Icon(Icons.all_inclusive, size: 16),
              ),
            ],
            selected: {value.priceBand},
            onSelectionChanged: (s) =>
                onChanged(value.copyWith(priceBand: s.first)),
          ),
        ],
      ],
    );
  }
}
