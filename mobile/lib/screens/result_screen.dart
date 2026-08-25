import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../domain/trip_profile.dart' show FuelType;
import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../utils/duration_format.dart';
import '../services/notifications.dart';
import '../services/trip_sharing.dart';
import '../storage/saved_trip.dart';
import '../widgets/adverse_event_sheet.dart';
import '../widgets/favorite_star_button.dart';
import '../widgets/poi_detail_sheet.dart';
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
      final profile = ref.read(tripProfileProvider);
      final l = AppLocalizations.of(context);
      final reminderMinutes = profile?.meals.reminderMinutesBefore ?? 0;
      final id = '${widget.origin.displayName}|${widget.destination.displayName}|'
          '${widget.desiredDepartureAt.toIso8601String()}';
      final notificationId = reminderMinutes > 0
          ? await NotificationService.instance.scheduleDepartureReminder(
              tripId: id,
              departureLocal: recommended.departureAt.toLocal(),
              minutesBefore: reminderMinutes,
              title: l.notificationsLeaveSoonTitle,
              body:
                  '${_shortName(widget.origin)} → ${_shortName(widget.destination)}'
                  ' · leave in $reminderMinutes min',
            )
          : null;
      final trip = SavedTrip(
        id: id,
        origin: widget.origin,
        destination: widget.destination,
        desiredDepartureAt: widget.desiredDepartureAt,
        savedAt: DateTime.now(),
        distanceKm: widget.response.route.distanceKm,
        recommendedDepartureAt: recommended.departureAt,
        recommendedMinutes: recommended.estimatedMinutes,
        countriesCrossed: widget.response.route.countriesCrossed,
        savedMinutesVsDesired:
            widget.response.savings.timeSavedMinutesVsDesired,
        savedEurVsTolls: widget.response.savings.moneySavedEurVsTolls,
        fuelCostEur:
            widget.response.optimizations?.fuelCost.totalCostEur ?? 0,
        reminderMinutesBefore: reminderMinutes,
        notificationId: notificationId,
      );
      await storage.save(trip);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.resultTripSaved)),
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
    final l = AppLocalizations.of(context);

    // Scope tells the client which sections to surface. When absent
    // (request had no TripProfile), fall through to a permissive default.
    final scope = widget.response.recommendationScope;
    final showHotels = scope?.showHotels ?? true;
    final showRestaurants = scope?.showRestaurants ?? true;
    final bedtimeHour = widget.request.tripProfile?.bedtimeHour ?? 22;

    final sections = <Widget>[
      _MapCard(
        origin: widget.request.origin,
        destination: widget.request.destination,
        route: route,
        alternativeGeometry:
            widget.response.tollAlternative?.geometry ?? const [],
      ),
      const SizedBox(height: Tokens.space24),
      if (scope != null && scope.arrivalAfterBedtime) ...[
        _ArrivalHintCard(
          arrivalHour: scope.arrivalLocalHour,
          bedtimeHour: bedtimeHour,
          requiresOvernight: scope.requiresOvernight,
        ),
        const SizedBox(height: Tokens.space16),
      ],
      if (widget.response.savings.timeSavedMinutesVsDesired > 0 ||
          widget.response.savings.moneySavedEurVsTolls > 0) ...[
        _SavingsSummaryCard(savings: widget.response.savings),
        const SizedBox(height: Tokens.space16),
      ],
      if (recommended != null) ...[
        _RecommendationHero(
          recommended: recommended,
          desired: widget.desiredDepartureAt,
          freeFlowMinutes: route.freeFlowMinutes,
          savedMinutesVsDesired:
              widget.response.savings.timeSavedMinutesVsDesired,
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
            Builder(builder: (context) {
              final fmt = ref.watch(unitFormatterProvider);
              return StatTile(
                label: l.resultStatDistance,
                value: fmt.distance(route.distanceKm),
              );
            }),
            StatTile(
              label: l.resultStatFreeFlow,
              value: _hhmm(route.freeFlowMinutes),
            ),
            StatTile(
              label: l.resultStatTolls,
              value: '€${route.tollCostEur.toStringAsFixed(0)}',
            ),
          ],
        ),
      ),
      const SizedBox(height: Tokens.space24),
      SectionHeader(
        title: l.resultDepartureWindowTitle,
        eyebrow: l.onboardEyebrowKiller,
        description: l.resultDepartureWindowDesc,
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
      if (widget.response.routeVariants.length >= 2) ...[
        const SizedBox(height: Tokens.space24),
        _RouteVariantsSection(variants: widget.response.routeVariants),
      ],
      if (widget.response.optimizations != null) ...[
        const SizedBox(height: Tokens.space24),
        _OptimizationsSection(opts: widget.response.optimizations!),
      ],
      if (widget.response.tollAlternative != null) ...[
        const SizedBox(height: Tokens.space24),
        _TollAlternativeCard(alt: widget.response.tollAlternative!),
      ],
      if (widget.response.partialTollSkips.isNotEmpty) ...[
        const SizedBox(height: Tokens.space16),
        _PartialTollSkipsCard(skips: widget.response.partialTollSkips),
      ],
      if (widget.response.hourlyTollReport != null) ...[
        const SizedBox(height: Tokens.space16),
        _HourlyTollCard(report: widget.response.hourlyTollReport!),
      ],
      if (widget.response.adverseEvents.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultAlerts,
          eyebrow: l.resultEyebrowAlongRoute,
          description: l.alertsAlongYourRouteDesc,
        ),
        ..._separated(
          widget.response.adverseEvents
              .map((e) => _AdverseEventTile(
                    event: e,
                    onTap: () => showAdverseEventSheet(
                      context,
                      event: e,
                      origin: widget.request.origin,
                      destination: widget.request.destination,
                      routeGeometry: widget.response.route.geometry,
                    ),
                  ))
              .toList(),
        ),
      ],
      // Rest stops: hidden by default (Sprint 21). Re-shown when the
      // server-derived scope opts in — currently only for
      // `travel_pace=savour` — and capped at `restStopsCountTarget`.
      if (scope != null &&
          scope.showRestStops &&
          widget.response.restStops.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultRestStops,
          eyebrow: l.resultEyebrowAlongRoute,
          description: l.restStopsHint,
        ),
        ..._separated(
          widget.response.restStops
              .take(scope.restStopsCountTarget)
              .map(_RestStopTile.new)
              .toList(),
        ),
      ],
      if (showHotels && widget.response.hotels.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(title: l.resultHotels, eyebrow: l.resultEyebrowNearRoute),
        ..._separated(
          widget.response.hotels
              .map((h) => _HotelTile(
                    hotel: h,
                    onTap: () => showPoiDetailSheet(
                      context,
                      kind: PoiKind.hotel,
                      name: h.name,
                      subtitle: '${h.country.displayName} · '
                          '${h.priceEurPerNight.toStringAsFixed(0)} €/night · '
                          '+${h.detourMinutes.toStringAsFixed(0)} min',
                      poi: h.coordinate,
                      origin: widget.request.origin,
                      destination: widget.request.destination,
                      routeGeometry: widget.response.route.geometry,
                      attributes: h.attributes,
                      icon: Icons.hotel_outlined,
                      accent: Theme.of(context).colorScheme.tertiary,
                    ),
                  ))
              .toList(),
        ),
      ],
      if (showRestaurants && widget.response.restaurants.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultRestaurants, eyebrow: l.resultEyebrowNearRoute,
        ),
        ..._separated(
          widget.response.restaurants
              .map((r) => _RestaurantTile(
                    restaurant: r,
                    onTap: () => showPoiDetailSheet(
                      context,
                      kind: PoiKind.restaurant,
                      name: r.name,
                      subtitle: '${r.country.displayName} · '
                          '${r.priceEurPerMeal.toStringAsFixed(0)} €/meal · '
                          '+${r.detourMinutes.toStringAsFixed(0)} min',
                      poi: r.coordinate,
                      origin: widget.request.origin,
                      destination: widget.request.destination,
                      routeGeometry: widget.response.route.geometry,
                      attributes: r.attributes,
                      icon: Icons.restaurant_outlined,
                      accent: Theme.of(context).colorScheme.tertiary,
                    ),
                  ))
              .toList(),
        ),
      ],
      if (widget.response.fuelPrices.isNotEmpty) ...[
        const SizedBox(height: Tokens.space24),
        SectionHeader(
          title: l.resultFuel, eyebrow: l.resultEyebrowAlongRoute,
        ),
        ..._separated(
          widget.response.fuelPrices
              .map((p) => _FuelTile(
                    price: p,
                    onTap: p.coordinate == null
                        ? null
                        : () => showPoiDetailSheet(
                              context,
                              kind: PoiKind.fuel,
                              name: p.stationName,
                              subtitle:
                                  '${p.country.displayName} · '
                                  '${p.priceEurPerL.toStringAsFixed(3)} €/L · '
                                  '${p.distanceFromOriginKm.toStringAsFixed(0)} km',
                              poi: p.coordinate!,
                              origin: widget.request.origin,
                              destination: widget.request.destination,
                              routeGeometry: widget.response.route.geometry,
                              attributes: p.attributes,
                              icon: Icons.local_gas_station,
                              accent:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                  ))
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
            tooltip: l.resultShareTooltip,
            icon: const Icon(Icons.ios_share),
            onPressed: () => shareTrip(
              originName: _shortName(widget.origin),
              destinationName: _shortName(widget.destination),
              route: widget.response.route,
              origin: widget.request.origin,
              destination: widget.request.destination,
              departureAt: widget.desiredDepartureAt,
              recommended: _recommended,
              tollAlt: widget.response.tollAlternative,
            ),
          ),
          IconButton(
            tooltip: l.resultExplainTooltip,
            icon: Icon(Icons.auto_awesome, color: scheme.tertiary),
            onPressed: _openNarrative,
          ),
          IconButton(
            tooltip: _saved ? l.resultSavedTooltip : l.resultSaveTooltip,
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

  // Kept as an alias so callsites don't churn; delegates to the shared
  // formatter which handles day rollover (long EV trips, ferry legs).
  static String _hhmm(double minutes) => durationCompact(minutes);

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
              label: AppLocalizations.of(context).resultCompareStraightApprox,
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
    final l = AppLocalizations.of(context);
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
                l.resultTollAlternativeEyebrow,
                style: t.labelSmall
                    ?.copyWith(color: accent, letterSpacing: 1.4),
              ),
              const Spacer(),
              SoftBadge(
                label: alt.worthIt
                    ? l.resultTollAlternativeWorthIt
                    : l.resultTollAlternativeMarginal,
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
                TextSpan(text: l.resultSaveExactly),
                TextSpan(
                  text: '€${alt.savingsEur.toStringAsFixed(0)}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' · '),
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
            '+${alt.extraDistanceKm.toStringAsFixed(0)} km · '
            '${l.resultStatTolls.toLowerCase()}: 0',
            style: t.bodySmall?.copyWith(color: onContainer),
          ),
          if (alt.geometry.isNotEmpty) ...[
            const SizedBox(height: Tokens.space8),
            Row(
              children: [
                Container(width: 20, height: 3, color: accent),
                const SizedBox(width: Tokens.space8),
                Text(
                  l.resultVariantDashed,
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

class _RouteVariantsSection extends StatelessWidget {
  const _RouteVariantsSection({required this.variants});
  final List<RouteVariant> variants;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(builder: (context) {
          final l = AppLocalizations.of(context);
          return SectionHeader(
            title: l.resultCompareTitle,
            eyebrow: l.resultCompareEyebrow,
            description: l.resultCompareDescription,
          );
        }),
        SoftCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space16, vertical: Tokens.space8,
          ),
          child: Column(
            children: [
              for (var i = 0; i < variants.length; i++) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                _RouteVariantRow(
                  variant: variants[i],
                  isPrimary: variants[i].key == 'fastest',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteVariantRow extends StatelessWidget {
  const _RouteVariantRow({required this.variant, required this.isPrimary});
  final RouteVariant variant;
  final bool isPrimary;

  IconData get _icon => switch (variant.key) {
        'fastest' => Icons.speed,
        'toll_free' => Icons.savings_outlined,
        'scenic' => Icons.landscape_outlined,
        _ => Icons.alt_route,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = isPrimary ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isPrimary
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            child: Icon(_icon, size: 18, color: accent),
          ),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(variant.label, style: t.titleSmall),
                    if (isPrimary) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· PRIMARY',
                        style: t.labelSmall?.copyWith(
                          color: scheme.primary, letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${variant.distanceKm.toStringAsFixed(0)} km · '
                  '${_hhmm(variant.freeFlowMinutes)} · '
                  'tolls €${variant.tollCostEur.toStringAsFixed(0)}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hhmm(double minutes) => durationCompact(minutes);
}

class _SavingsSummaryCard extends StatelessWidget {
  const _SavingsSummaryCard({required this.savings});
  final TripSavings savings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final savedTime = savings.timeSavedMinutesVsDesired;
    final savedEur = savings.moneySavedEurVsTolls;
    return Container(
      padding: const EdgeInsets.all(Tokens.space20),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, size: 18, color: scheme.tertiary),
              const SizedBox(width: Tokens.space8),
              Text(
                l.resultTripSavings,
                style: t.labelSmall?.copyWith(
                  color: scheme.tertiary, letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SavingsStat(
                icon: Icons.access_time,
                value: durationCompact(savedTime.abs()),
                label: savedTime >= 0
                    ? l.resultTimeSavedLabel
                    : l.resultExtraTimeLabel,
                positive: savedTime > 0,
                foreground: scheme.onTertiaryContainer,
              ),
              _SavingsStat(
                icon: Icons.euro,
                value: savedEur.toStringAsFixed(0),
                label: l.resultMoneySavedLabel,
                positive: savedEur > 0,
                foreground: scheme.onTertiaryContainer,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          Text(
            savedTime > 0 && savedEur > 0
                ? l.resultSavingsShiftAndSkip
                : savedTime > 0
                    ? l.resultSavingsShift
                    : savedEur > 0
                        ? l.resultSavingsSkip
                        : l.resultSavingsNone,
            style: t.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
          ),
        ],
      ),
    );
  }
}

class _SavingsStat extends StatelessWidget {
  const _SavingsStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.positive,
    required this.foreground,
  });
  final IconData icon;
  final String value;
  final String label;
  final bool positive;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 4),
            Text(
              value,
              style: t.headlineMedium?.copyWith(
                color: foreground,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: t.labelSmall?.copyWith(
            color: foreground,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _RecommendationHero extends StatelessWidget {
  const _RecommendationHero({
    required this.recommended,
    required this.desired,
    required this.freeFlowMinutes,
    required this.savedMinutesVsDesired,
  });

  final TimeWindow recommended;
  final DateTime desired;
  final double freeFlowMinutes;
  final double savedMinutesVsDesired;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

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
                l.resultBestTimeToLeave,
                style: t.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (savedMinutesVsDesired > 0)
                _HeroSavingsBadge(
                  minutes: savedMinutesVsDesired,
                  fg: scheme.onPrimaryContainer,
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
                label: l.resultShift,
                value: shiftLabel,
                fg: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: Tokens.space16),
              _HeroChip(
                label: l.resultTraffic,
                value: '×${recommended.trafficFactor.toStringAsFixed(2)}',
                fg: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: Tokens.space16),
              _HeroChip(
                label: l.resultTotal,
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

  String _hhmm(double minutes) => durationCompact(minutes);
}

class _HeroSavingsBadge extends StatelessWidget {
  const _HeroSavingsBadge({required this.minutes, required this.fg});
  final double minutes;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final abs = minutes.abs();
    final hours = abs ~/ 60;
    final mins = (abs % 60).round();
    final magnitude = hours > 0
        ? (mins > 0 ? '${hours}h ${mins}m' : '${hours}h')
        : '${mins}m';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space12, vertical: 6,
      ),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_down, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            '$magnitude saved',
            style: t.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
        Builder(builder: (context) {
          final l = AppLocalizations.of(context);
          return SectionHeader(
            title: l.resultOptimized,
            eyebrow: l.resultOptimizedEyebrow,
            description: l.resultOptimizedDescription,
          );
        }),
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
              Text(AppLocalizations.of(context).resultOptimizedFuelBudget,
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

  String _label(AppLocalizations l) => switch (stop.slot) {
        'breakfast' => l.profileBreakfast,
        'lunch' => l.profileLunch,
        'dinner' => l.profileDinner,
        _ => l.resultMealFallback,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
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
                '${_label(l)} · ${dateFmt.format(stop.at.toLocal())}',
                style: t.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                stop.restaurantName != null
                    ? '${stop.restaurantName} · '
                        '${stop.restaurantPriceEurPerMeal?.toStringAsFixed(0)} €/meal · '
                        '${stop.distanceFromOriginKm.toStringAsFixed(0)} km'
                    : l.resultRestStopNoRestaurant(
                        stop.distanceFromOriginKm.toStringAsFixed(0),
                      ),
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
              Builder(builder: (context) {
                final l = AppLocalizations.of(context);
                return Text(
                  l.resultSleepAt(dateFmt.format(stop.at.toLocal())),
                  style: t.titleMedium,
                );
              }),
              const SizedBox(height: 2),
              Text(
                stop.hotelName != null
                    ? '${stop.hotelName} · '
                        '${stop.hotelPriceEurPerNight?.toStringAsFixed(0)} €/night · '
                        '${stop.distanceFromOriginKm.toStringAsFixed(0)} km'
                    : AppLocalizations.of(context).resultNoHotelHere(
                        stop.distanceFromOriginKm.toStringAsFixed(0),
                      ),
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
    final l = AppLocalizations.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: scheme.tertiary),
              const SizedBox(width: Tokens.space8),
              Text(l.resultHourlyTollEyebrow,
                  style: t.labelSmall?.copyWith(
                      color: scheme.tertiary, letterSpacing: 1.4)),
              const Spacer(),
              SoftBadge(
                label: l.narrativePremiumBadge,
                color: scheme.onPrimaryContainer,
                background: scheme.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          Text(
            '${l.hourlyBestHours}: '
            '${report.bestHoursToSkip.map((h) => '${h.toString().padLeft(2, '0')}:00').join(' · ')}',
            style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${l.hourlyWorstHours}: '
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

class _PartialTollSkipsCard extends StatelessWidget {
  const _PartialTollSkipsCard({required this.skips});
  final List<PartialTollSkip> skips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(Tokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, size: 18, color: scheme.tertiary),
              const SizedBox(width: Tokens.space8),
              Text(
                l.partialTollSkipsTitle.toUpperCase(),
                style: t.labelSmall?.copyWith(
                  color: scheme.tertiary, letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.resultHourlyExplainer, style: t.bodySmall),
          const SizedBox(height: Tokens.space12),
          for (final s in skips) _PartialTollSkipRow(skip: s),
        ],
      ),
    );
  }
}

class _PartialTollSkipRow extends StatelessWidget {
  const _PartialTollSkipRow({required this.skip});
  final PartialTollSkip skip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = skip.worthIt ? scheme.tertiary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.12),
            child: Icon(
              skip.worthIt ? Icons.check : Icons.remove,
              color: accent, size: 18,
            ),
          ),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(skip.label, style: t.titleSmall),
                Text(
                  'km ${skip.distanceFromOriginKm.toStringAsFixed(0)} · '
                  '€${skip.savingsEur.toStringAsFixed(0)} saved · '
                  '+${skip.timePenaltyMinutes.toStringAsFixed(0)} min · '
                  '+${skip.extraDistanceKm.toStringAsFixed(0)} km',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          SoftBadge(
            label: skip.worthIt
                ? AppLocalizations.of(context).resultSkipLabel
                : AppLocalizations.of(context).resultKeepLabel,
            color: accent,
            background: accent.withValues(alpha: 0.10),
            borderColor: accent.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _AdverseEventTile extends StatelessWidget {
  const _AdverseEventTile({required this.event, this.onTap});
  final AdverseEvent event;
  final VoidCallback? onTap;

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
      onTap: onTap,
    );
  }
}

class _HotelTile extends StatelessWidget {
  const _HotelTile({required this.hotel, this.onTap});
  final Hotel hotel;
  final VoidCallback? onTap;

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SoftBadge(label: hotel.priceBand.symbol),
          const SizedBox(width: 4),
          FavoriteStarButton(
            id: hotel.favoriteId,
            isRestaurant: false,
            payload: hotel.toFavoriteJson(),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({required this.restaurant, this.onTap});
  final Restaurant restaurant;
  final VoidCallback? onTap;

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SoftBadge(label: restaurant.priceBand.symbol),
          const SizedBox(width: 4),
          FavoriteStarButton(
            id: restaurant.favoriteId,
            isRestaurant: true,
            payload: restaurant.toFavoriteJson(),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _FuelTile extends StatelessWidget {
  const _FuelTile({required this.price, this.onTap});
  final FuelPrice price;
  final VoidCallback? onTap;

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
      onTap: onTap,
    );
  }
}

/// Rest-stop tile: shown for `travel_pace=savour` trips (see
/// `scope.showRestStops`). Times are cumulative from origin, formatted
/// in whole hours so a 3.5 h stop renders "After 3h 30m".
class _RestStopTile extends StatelessWidget {
  const _RestStopTile(this.stop);
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
          color: scheme.onSecondaryContainer, size: 18,
        ),
      ),
      title: Text(
        durationCompact(stop.cumulativeDrivingHours * 60),
      ),
      subtitle: Text(
        '${stop.distanceFromOriginKm.toStringAsFixed(0)} km · '
        '${stop.recommendedBreakMinutes} min',
      ),
    );
  }
}

/// Hint card that fires when the projected arrival lands after the
/// user's configured bedtime. Suggests an overnight stop with a link
/// down to the hotels section.
class _ArrivalHintCard extends StatelessWidget {
  const _ArrivalHintCard({
    required this.arrivalHour,
    required this.bedtimeHour,
    required this.requiresOvernight,
  });

  final int arrivalHour;
  final int bedtimeHour;
  final bool requiresOvernight;

  String _fmt(int hour) => hour.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.nights_stay_outlined,
              color: scheme.onTertiaryContainer, size: 24),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.arrivalHintTitle(_fmt(arrivalHour)),
                  style: t.titleMedium?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.arrivalHintBody(_fmt(bedtimeHour)),
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
          if (requiresOvernight) ...[
            const SizedBox(width: Tokens.space8),
            Icon(Icons.priority_high, color: scheme.error, size: 20),
          ],
        ],
      ),
    );
  }
}
