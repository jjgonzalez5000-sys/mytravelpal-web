import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../domain/trip_emissions.dart';
import '../l10n/app_localizations.dart';

/// One line under the trip cost: estimated CO2 of the drive, total and per
/// passenger when there is more than one.
class TripCo2Row extends StatelessWidget {
  const TripCo2Row({super.key, required this.emissions, this.travellers = 1});

  final TripEmissions emissions;
  final int travellers;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.eco_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: Tokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.tripCo2Label,
                        style: t.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      l.tripCo2Total(emissions.totalKg.round()),
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (travellers > 1)
                  Text(
                    l.tripCo2PerPerson(emissions.perPassengerKg.round()),
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (emissions.electric)
                  Text(
                    l.tripCo2EvNote,
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
