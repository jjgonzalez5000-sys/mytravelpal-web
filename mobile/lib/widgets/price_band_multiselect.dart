import 'package:flutter/material.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';

/// Multi-select price-band chips (Budget / Mid / Luxury / Any).
///
/// Rules:
/// - Tapping a specific band toggles it in the selection.
/// - Tapping "Any" clears the others and selects only `{ANY}`.
/// - Selecting all three specific bands auto-collapses to `{ANY}`
///   (they're logically equivalent — the backend applies no filter).
/// - Empty selection is normalised to `{ANY}` so we always have at
///   least one visual pill highlighted.
class PriceBandMultiSelect extends StatelessWidget {
  const PriceBandMultiSelect({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<PriceBand> selected;
  final ValueChanged<Set<PriceBand>> onChanged;

  static const Set<PriceBand> _specific = {
    PriceBand.budget,
    PriceBand.mid,
    PriceBand.lux,
  };

  void _toggle(PriceBand band) {
    if (band == PriceBand.any) {
      onChanged({PriceBand.any});
      return;
    }
    final next = {...selected};
    // Selecting a specific band always removes "any" from the set.
    next.remove(PriceBand.any);
    if (next.contains(band)) {
      next.remove(band);
    } else {
      next.add(band);
    }
    // Empty → default to Any.
    if (next.isEmpty) {
      onChanged({PriceBand.any});
      return;
    }
    // All three specific bands → collapse to Any (visually and
    // semantically the same thing).
    if (_specific.every(next.contains)) {
      onChanged({PriceBand.any});
      return;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip(
          context, PriceBand.budget, l.prefBandBudget, '€',
        ),
        _chip(
          context, PriceBand.mid, l.prefBandMid, '€€',
        ),
        _chip(
          context, PriceBand.lux, l.prefBandLuxury, '€€€',
        ),
        _chip(
          context, PriceBand.any, l.prefBandAny, '∞',
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, PriceBand band, String label, String prefix,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selected.contains(band);
    return FilterChip(
      selected: isSelected,
      label: Text('$prefix  $label'),
      selectedColor: scheme.primaryContainer,
      onSelected: (_) => _toggle(band),
    );
  }
}
