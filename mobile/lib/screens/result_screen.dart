import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../domain/trip_profile.dart' show FuelType;
import '../design/components.dart';
import '../design/tokens.dart';
import '../providers.dart';
import '../storage/saved_trip.dart';
import '../widgets/route_map.dart';
import '../widgets/time_window_chart.dart';
import 'narrative_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saved = false;
  bool _saving = false;

  TimeWindow? get _recommended {
    for (final w in widget.response.timeWindows) {
      if (w.recommended) return w;
    }
    return null;
  }

  Future<void> _save() async {
    final recommended = _recommended;
    if (recommended == null || _saving) return;
    setState(() => _saving = true);
    try {
      final storage = ref.read(tripStorageProvider);
      final trip = SavedTrip(
        id: '${widget.origin.displayName}|${widget.destination.displayName}|'
            '${widget.desiredDepartureAt.toIso8601String()}',
        origin: widget.origin,
        destination: widget.destination,
        desiredDepartureAt: widget.desiredDepartureAt,
        savedAt: DateTime.now(),
        distanceKm: widget.response.route.distanceKm,
        recommendedDepartureAt: recommended.departureAt,
        recommendedMinutes: recommended.estimatedMinutes,
        countriesCrossed: widget.response.route.countriesCrossed,
      );
      await storage.save(trip);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip saved')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openNarrative() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NarrativeScreen(
          planRequest: widget.request,
          originName: _shortName(widget.origin),
          destinationName: _shortName(widget.destination),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.response.route;
    final recommended = _recommended;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final sections = <Widget>[
      _MapCard(
        origin: widget.request.origin,
        destination: widget.request.destination,
        route: route,
        alternativeGeometry:
            widget.response.tollAlternative?.geometry ?? const [],
      ),
      const SizedBox(height: Tokens.space24),
      if (recommended != null) ...[
        _RecommendationHero(
          recommended: recommended,
          desired: widget.desiredDepartureAt,
          freeFlowMinutes: route.freeFlowMinutes,
        ),
        const SizedBox(height: Tokens.space24),
      ],
      SoftCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space20, vertical: Tokens.space20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StatTile(
              label: 'Distance',
              value: '${route.distanceKm.toStringAsFixed(0)} km',
            ),
            StatTile(
              label: 'Free flow',
              value: _hhmm(route.freeFlowMinutes),
            ),
            StatTile(
              label: 'Tolls',
              value: '€${route.tollCostEur.toStringAsFixed(0)}',
            ),
          ],
        ),
      ),
      const SizedBox(height: Tokens.space24),
      const SectionHeader(
        title: 'Departure window',
        eyebrow: 'Killer feature',
        description:
            'Total minutes at each candidate time. Tap the bars for details.',
      ),
      SoftCard(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space8, Tokens.space16, Tokens.space16, Tokens.space16,
        ),
        child: TimeWindowChart(
          windows: widget.response.timeWindows,
          desiredDepartureAt: widget.desiredDepartureAt,
        ),
      ),
      if (widget.response.optimizations != null) ...[
        const SizedBox(height: Tokens.space24),
        _OptimizationsSection(opts: widget.response.optimizations!),
      ],
      if (widget.response.tollAlternative != null) ...[
        const SizedBox(height: Tokens.space24),
        _TollAlternativeCard(alt: widget.response.tollAlternative!),
      ],
      if (widget.response.hourlyTollReport != null) ...[
        const SizedBox(height: Tokens.space16),
        _HourlyTollCard(report: widget.response.hourlyTollReport!),
      ],
      if (widget.response.adverseEvents.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        const SectionHeader(
          title: 'Alerts',
          eyebrow: 'Along your route',
          description: 'Sorted by severity, then by proximity.',
        ),
        ..._separated(
          widget.response.adverseEvents
              .map((e) => _AdverseEventTile(event: e))
              .toList(),
        ),
      ],
      if (widget.response.restStops.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        const SectionHeader(
          title: 'Rest stops',
          eyebrow: 'Safety',
          description: 'Recommended every 2 h — short breaks keep you sharp.',
        ),
        ..._separated(
          widget.response.restStops
              .map((s) => _RestStopTile(stop: s))
              .toList(),
        ),
      ],
      if (widget.response.hotels.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        const SectionHeader(title: 'Hotels', eyebrow: 'Near your route'),
        ..._separated(
          widget.response.hotels.map((h) => _HotelTile(hotel: h)).toList(),
        ),
      ],
      if (widget.response.restaurants.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        const SectionHeader(title: 'Restaurants', eyebrow: 'Near your route'),
        ..._separated(
          widget.response.restaurants
              .map((r) => _RestaurantTile(restaurant: r))
              .toList(),
        ),
      ],
      if (widget.response.fuelPrices.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        const SectionHeader(title: 'Fuel', eyebrow: 'Along the route'),
        ..._separated(
          widget.response.fuelPrices
              .map((p) => _FuelTile(price: p))
              .toList(),
        ),
      ],
      const SizedBox(height: Tokens.space32),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: BackButton(color: scheme.onSurface),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _shortName(widget.origin),
              style: t.bodySmall,
            ),
            Text(
              '→ ${_shortName(widget.destination)}',
              style: t.titleMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Explain my trip (Premium)',
            icon: Icon(Icons.auto_awesome, color: scheme.tertiary),
            onPressed: _openNarrative,
          ),
          IconButton(
            tooltip: _saved ? 'Saved' : 'Save trip',
            icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: _saved || _saving ? null : _save,
          ),
          const SizedBox(width: Tokens.space8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space20, Tokens.space16, Tokens.space20, Tokens.space16,
        ),
        children: [
          for (var i = 0; i < sections.length; i++)
            sections[i]
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 40 * i),
                  duration: Tokens.motionBase,
                )
                .moveY(begin: 4, end: 0, curve: Tokens.curveOut),
        ],
      ),
    );
  }

  static String _shortName(GeocodeResult r) => r.displayName.split(',').first;

  static String _hhmm(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  List<Widget> _separated(List<Widget> tiles) {
    final scheme = Theme.of(context).colorScheme;
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(Divider(height: 1, color: scheme.outlineVariant));
      }
    }
    return [
      SoftCard(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space16, vertical: Tokens.space4,
          ),
          child: Column(children: out),
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.origin,
    required this.destination,
    required this.route,
    this.alternativeGeometry = const [],
  });

  final LatLon origin;
  final LatLon destination;
  final RouteInfo route;
  final List<LatLon> alternativeGeometry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusLg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: RouteMap(
            origin: origin,
            destination: destination,
            geometry: route.geometry,
            alternativeGeometry: alternativeGeometry,
          ),
        ),
        Positioned(
          left: Tokens.space12,
          top: Tokens.space12,
          child: Wrap(
            spacing: Tokens.space8,
            children: [
              for (final c in route.countriesCrossed)
                SoftBadge(
                  label: c.displayName,
                  icon: Icons.public,
                  background: scheme.surface.withValues(alpha: 0.95),
                ),
            ],
          ),
        ),
        if (route.geometry.isEmpty)
          Positioned(
            right: Tokens.space12,
            bottom: Tokens.space12,
            child: SoftBadge(
              label: 'Straight-line approx.',
              icon: Icons.timeline,
              background: scheme.surface.withValues(alpha: 0.95),
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _TollAlternativeCard extends StatelessWidget {
  const _TollAlternativeCard({required this.alt});
  final TollAlternative alt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = alt.worthIt ? scheme.tertiary : scheme.onSurfaceVariant;
    final containerBg = alt.worthIt
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerLow;
    final onContainer = alt.worthIt
        ? scheme.onTertiaryContainer
        : scheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(Tokens.space20),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.toll_outlined, color: accent, size: 18),
              const SizedBox(width: Tokens.space8),
              Text(
                'TOLL-FREE ALTERNATIVE',
                style: t.labelSmall
                    ?.copyWith(color: accent, letterSpacing: 1.4),
              ),
              const Spacer(),
              SoftBadge(
                label: alt.worthIt ? 'Worth it' : 'Marginal',
                color: accent,
                background: accent.withValues(alpha: 0.10),
                borderColor: accent.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          RichText(
            text: TextSpan(
              style: t.headlineMedium?.copyWith(color: onContainer),
              children: [
                const TextSpan(text: 'Save '),
                TextSpan(
                  text: '€${alt.savingsEur.toStringAsFixed(0)}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' for '),
                TextSpan(
                  text: '+${alt.timePenaltyMinutes.toStringAsFixed(0)} min',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Text(
            '${alt.distanceKm.toStringAsFixed(0)} km · '
            '+${alt.extraDistanceKm.toStringAsFixed(0)} km vs main route · '
            'no tolls',
            style: t.bodySmall?.copyWith(color: onContainer),
          ),
          if (alt.geometry.isNotEmpty) ...[
            const SizedBox(height: Tokens.space8),
            Row(
              children: [
                Container(
                  width: 20, height: 3,
                  color: accent,
                ),
                const SizedBox(width: Tokens.space8),
                Text(
                  'Dashed on the map above',
                  style: t.bodySmall?.copyWith(color: onContainer),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationHero extends StatelessWidget {
  const _RecommendationHero({
    required this.recommended,
    required this.desired,
    required this.freeFlowMinutes,
  });

  final TimeWindow recommended;
  final DateTime desired;
  final double freeFlowMinutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final shift = recommended.departureAt.difference(desired);
    final savedVsDesired = _minutesShiftedForBetterTraffic(shift, recommended);
    final shiftLabel = _formatShift(shift);
    final dateFmt = DateFormat('EEE, d MMM · HH:mm');

    return Container(
      padding: const EdgeInsets.all(Tokens.space24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: Tokens.space8),
              Text(
                'BEST TIME TO LEAVE',
                style: t.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          Text(
            dateFmt.format(recommended.departureAt),
            style: t.displaySmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Text(
            savedVsDesired,
            style: t.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: Tokens.space16),
          Row(
            children: [
              _HeroChip(
                label: 'SHIFT',
                value: shiftLabel,
                fg: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: Tokens.space16),
              _HeroChip(
                label: 'TRAFFIC',
                value: '×${recommended.trafficFactor.toStringAsFixed(2)}',
                fg: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: Tokens.space16),
              _HeroChip(
                label: 'TOTAL',
                value: _hhmm(recommended.estimatedMinutes),
                fg: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _minutesShiftedForBetterTraffic(
    Duration shift, TimeWindow recommended,
  ) {
    final delta = recommended.estimatedMinutes - freeFlowMinutes;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(0)} min vs free flow · '
        '${shift.inMinutes.abs()} min ${shift.isNegative ? 'earlier' : 'later'} '
        'than your target';
  }

  String _formatShift(Duration d) {
    if (d.inMinutes == 0) return 'ON TIME';
    final abs = d.inMinutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    final magnitude = h > 0
        ? (m > 0 ? '${h}h ${m}m' : '${h}h')
        : '${m}m';
    return d.isNegative ? '-$magnitude' : '+$magnitude';
  }

  String _hhmm(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value, required this.fg});
  final String label;
  final String value;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.labelSmall?.copyWith(color: fg.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: t.titleMedium?.copyWith(
            color: fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _OptimizationsSection extends StatelessWidget {
  const _OptimizationsSection({required this.opts});
  final Optimizations opts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Optimized for your trip',
          eyebrow: 'Profile-aware',
          description:
              'Meal, sleep and fuel picks that match your profile.',
        ),
        SoftCard(
          padding: const EdgeInsets.all(Tokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FuelCostRow(cost: opts.fuelCost),
              if (opts.mealStops.isNotEmpty) ...[
                const SizedBox(height: Tokens.space16),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: Tokens.space16),
                for (final m in opts.mealStops)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space12),
                    child: _MealStopRow(stop: m),
                  ),
              ],
              if (opts.sleepStop != null) ...[
                const SizedBox(height: Tokens.space4),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: Tokens.space16),
                _SleepStopRow(stop: opts.sleepStop!),
              ],
              const SizedBox(height: Tokens.space8),
              if (opts.fuelCost.notes.isNotEmpty) ...[
                const SizedBox(height: Tokens.space12),
                for (final n in opts.fuelCost.notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: scheme.tertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(n,
                              style: t.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              )),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FuelCostRow extends StatelessWidget {
  const _FuelCostRow({required this.cost});
  final FuelCost cost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
          ),
          child: Icon(
            cost.fuelType == FuelType.electric
                ? Icons.electric_bolt
                : Icons.local_gas_station,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: Tokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimated fuel budget',
                  style: t.labelSmall?.copyWith(letterSpacing: 1.1)),
              const SizedBox(height: 2),
              Text(
                '€${cost.totalCostEur.toStringAsFixed(0)}',
                style: t.headlineMedium?.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${cost.fuelUnits.toStringAsFixed(1)} ${cost.unitLabel} · '
                '${cost.averageUnitPriceEur.toStringAsFixed(3)} €/${cost.unitLabel}',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MealStopRow extends StatelessWidget {
  const _MealStopRow({required this.stop});
  final MealStopOpt stop;

  IconData get _icon => switch (stop.slot) {
        'breakfast' => Icons.free_breakfast_outlined,
        'lunch' => Icons.lunch_dining_outlined,
        'dinner' => Icons.dinner_dining_outlined,
        _ => Icons.restaurant_outlined,
      };

  String get _label => switch (stop.slot) {
        'breakfast' => 'Breakfast',
        'lunch' => 'Lunch',
        'dinner' => 'Dinner',
        _ => 'Meal',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dateFmt = intl.DateFormat.Hm();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.tertiaryContainer,
          child: Icon(_icon, size: 18, color: scheme.onTertiaryContainer),
        ),
        const SizedBox(width: Tokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_label · ${dateFmt.format(stop.at.toLocal())}',
                style: t.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                stop.restaurantName != null
                    ? '${stop.restaurantName} · '
                        '${stop.restaurantPriceEurPerMeal?.toStringAsFixed(0)} €/meal · '
                        '${stop.distanceFromOriginKm.toStringAsFixed(0)} km from origin'
                    : 'Rest stop at ${stop.distanceFromOriginKm.toStringAsFixed(0)} km — no matching restaurant found.',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SleepStopRow extends StatelessWidget {
  const _SleepStopRow({required this.stop});
  final SleepStopOpt stop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dateFmt = intl.DateFormat.Hm();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.secondaryContainer,
          child: Icon(Icons.hotel_outlined, size: 18,
              color: scheme.onSecondaryContainer),
        ),
        const SizedBox(width: Tokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sleep · ${dateFmt.format(stop.at.toLocal())}',
                  style: t.titleMedium),
              const SizedBox(height: 2),
              Text(
                stop.hotelName != null
                    ? '${stop.hotelName} · '
                        '${stop.hotelPriceEurPerNight?.toStringAsFixed(0)} €/night · '
                        '${stop.distanceFromOriginKm.toStringAsFixed(0)} km from origin'
                    : 'You should stop around here (~${stop.distanceFromOriginKm.toStringAsFixed(0)} km). No matching hotel found.',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourlyTollCard extends StatelessWidget {
  const _HourlyTollCard({required this.report});
  final HourlyTollReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: scheme.tertiary),
              const SizedBox(width: Tokens.space8),
              Text('HOURLY TOLL VERDICT',
                  style: t.labelSmall?.copyWith(
                      color: scheme.tertiary, letterSpacing: 1.4)),
              const Spacer(),
              SoftBadge(
                label: 'Premium',
                color: scheme.onPrimaryContainer,
                background: scheme.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          Text(
            'Best hours to skip tolls: '
            '${report.bestHoursToSkip.map((h) => '${h.toString().padLeft(2, '0')}:00').join(' · ')}',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Worst hours: '
            '${report.worstHoursToSkip.map((h) => '${h.toString().padLeft(2, '0')}:00').join(' · ')}',
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Tokens.space16),
          _HourStrip(verdicts: report.verdicts),
        ],
      ),
    );
  }
}

class _HourStrip extends StatelessWidget {
  const _HourStrip({required this.verdicts});
  final List<HourlyTollVerdict> verdicts;

  Color _colorFor(BuildContext context, String rec) {
    final scheme = Theme.of(context).colorScheme;
    return switch (rec) {
      'skip_tolls' => scheme.tertiary,
      'keep_tolls' => scheme.primary,
      _ => scheme.outlineVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final v in verdicts)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 1),
              height: 22,
              color: _colorFor(context, v.recommendation),
              alignment: Alignment.center,
              child: v.hour % 3 == 0
                  ? Text(
                      '${v.hour}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

class _AdverseEventTile extends StatelessWidget {
  const _AdverseEventTile({required this.event});
  final AdverseEvent event;

  Color _severityColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (event.severity) {
      AdverseEventSeverity.critical => scheme.error,
      AdverseEventSeverity.warning => scheme.tertiary,
      AdverseEventSeverity.info => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(event.type.icon, color: color, size: 18),
      ),
      title: Text(event.type.displayName),
      subtitle: Text(event.description),
      isThreeLine: event.description.length > 60,
      trailing: SoftBadge(
        label: event.severity.displayName,
        color: color,
        background: color.withValues(alpha: 0.10),
        borderColor: color.withValues(alpha: 0.3),
      ),
    );
  }
}

class _RestStopTile extends StatelessWidget {
  const _RestStopTile({required this.stop});
  final RestStop stop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          Icons.pause_circle_outline,
          color: scheme.onSecondaryContainer,
          size: 18,
        ),
      ),
      title: Text(
        'After ${stop.cumulativeDrivingHours.toStringAsFixed(1)} h',
      ),
      subtitle: Text(
        '${stop.distanceFromOriginKm.toStringAsFixed(0)} km from origin · '
        '${stop.recommendedBreakMinutes} min break',
      ),
    );
  }
}

class _HotelTile extends StatelessWidget {
  const _HotelTile({required this.hotel});
  final Hotel hotel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.tertiaryContainer,
        child: Icon(Icons.hotel_outlined,
            color: scheme.onTertiaryContainer, size: 18),
      ),
      title: Text(hotel.name),
      subtitle: Text(
        '${hotel.country.displayName} · '
        '${hotel.priceEurPerNight.toStringAsFixed(0)} €/night · '
        '+${hotel.detourMinutes.toStringAsFixed(0)} min detour',
      ),
      trailing: SoftBadge(label: hotel.priceBand.symbol),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.tertiaryContainer,
        child: Icon(Icons.restaurant_outlined,
            color: scheme.onTertiaryContainer, size: 18),
      ),
      title: Text(restaurant.name),
      subtitle: Text(
        '${restaurant.country.displayName} · '
        '${restaurant.priceEurPerMeal.toStringAsFixed(0)} €/meal · '
        '+${restaurant.detourMinutes.toStringAsFixed(0)} min detour',
      ),
      trailing: SoftBadge(label: restaurant.priceBand.symbol),
    );
  }
}

class _FuelTile extends StatelessWidget {
  const _FuelTile({required this.price});
  final FuelPrice price;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.surfaceContainerHigh,
        child: Icon(Icons.local_gas_station,
            color: scheme.onSurface, size: 18),
      ),
      title: Text('${price.stationName} · ${price.country.code}'),
      subtitle: Text(
        '${price.priceEurPerL.toStringAsFixed(3)} €/L · '
        '${price.distanceFromOriginKm.toStringAsFixed(0)} km from origin',
      ),
    );
  }
}
