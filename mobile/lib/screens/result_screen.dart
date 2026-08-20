import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../widgets/route_map.dart';
import '../widgets/time_window_chart.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.request,
    required this.origin,
    required this.destination,
    required this.response,
    required this.desiredDepartureAt,
  });

  final TripPlanRequest request;
  final GeocodeResult origin;
  final GeocodeResult destination;
  final TripPlanResponse response;
  final DateTime desiredDepartureAt;

  TimeWindow? get _recommended {
    for (final w in response.timeWindows) {
      if (w.recommended) return w;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final route = response.route;
    final recommended = _recommended;
    final dateFmt = DateFormat('EEE, d MMM — HH:mm');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_shortName(origin)} → ${_shortName(destination)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RouteMap(
                origin: request.origin,
                destination: request.destination,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in route.countriesCrossed)
                Chip(
                  label: Text(c.displayName),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _summaryRow(context, route),
          const SizedBox(height: 24),
          if (recommended != null)
            _RecommendationCard(
              recommended: recommended,
              desiredDepartureAt: desiredDepartureAt,
              freeFlowMinutes: route.freeFlowMinutes,
              scheme: scheme,
              dateFmt: dateFmt,
            ),
          const SizedBox(height: 24),
          Text('Departure window',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Bars show total minutes at each candidate departure time. '
            'The recommended slot is highlighted; a marker shows your '
            'desired time for comparison.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TimeWindowChart(
            windows: response.timeWindows,
            desiredDepartureAt: desiredDepartureAt,
          ),
          const SizedBox(height: 24),
          Text('Fuel along the route',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...response.fuelPrices.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_gas_station),
              title: Text('${p.stationName} · ${p.country.code}'),
              subtitle: Text(
                '${p.priceEurPerL.toStringAsFixed(3)} €/L · '
                '${p.distanceFromOriginKm.toStringAsFixed(0)} km from origin',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortName(GeocodeResult r) => r.displayName.split(',').first;

  Widget _summaryRow(BuildContext context, RouteInfo r) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _stat(context, style, 'Distance', '${r.distanceKm.toStringAsFixed(0)} km'),
        _stat(context, style, 'Free flow',
            '${r.freeFlowMinutes.toStringAsFixed(0)} min'),
        _stat(context, style, 'Tolls', '${r.tollCostEur.toStringAsFixed(0)} €'),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    TextStyle? style,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Text(label, style: style),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommended,
    required this.desiredDepartureAt,
    required this.freeFlowMinutes,
    required this.scheme,
    required this.dateFmt,
  });

  final TimeWindow recommended;
  final DateTime desiredDepartureAt;
  final double freeFlowMinutes;
  final ColorScheme scheme;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final shift = recommended.departureAt.difference(desiredDepartureAt);
    final shiftLabel = _formatShift(shift);
    final losing = recommended.estimatedMinutes - freeFlowMinutes;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.schedule, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Best time to leave',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFmt.format(recommended.departureAt),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$shiftLabel from your desired time · '
                    '${recommended.estimatedMinutes.toStringAsFixed(0)} min total '
                    '(${losing >= 0 ? '+' : ''}${losing.toStringAsFixed(0)} vs free flow)',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShift(Duration d) {
    if (d.inMinutes == 0) return 'On time';
    final absMin = d.inMinutes.abs();
    final hours = absMin ~/ 60;
    final mins = absMin % 60;
    final magnitude = hours > 0
        ? (mins > 0 ? '${hours}h ${mins}m' : '${hours}h')
        : '${mins}m';
    return d.isNegative ? '$magnitude earlier' : '$magnitude later';
  }
}
