import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../domain/trip_profile.dart';
import '../l10n/app_localizations.dart';

/// A skipped toll only pays off when the money saved justifies the extra
/// driving time. Below this saving per extra hour the skip is penalised.
const double kTollSkipMinEurPerHour = 25.0;

/// Extra time up to this many minutes is ignored: leaving and rejoining
/// the motorway always costs a little.
const double kTollSkipFreeMinutes = 10.0;

/// 0-15 score for the tolls the driver chose to skip. 15 = every skipped
/// toll saves enough per extra hour (or costs almost no time). Each hour
/// lost on a skip that saves too little takes 5 points off, so e.g. 43 EUR
/// saved for 3 extra hours (14 EUR/h) scores 0.
int tollSkipTimeScore(List<({double eur, double minutes})> skipped) {
  var wastedHours = 0.0;
  for (final s in skipped) {
    if (s.minutes <= kTollSkipFreeMinutes) continue;
    final hours = s.minutes / 60.0;
    if (s.eur / hours >= kTollSkipMinEurPerHour) continue;
    wastedHours += hours;
  }
  return (15 - (wastedHours * 5).round()).clamp(0, 15);
}

/// Compact score card shown in the result screen below the hero stats.
/// Computes a 0-100 score from the trip response quality signals:
/// route completeness, fuel/hotel/weather data availability, alerts.
///
/// Factor weights and applicability adapt to the [request] profile
/// so a toll-free trip is not penalised, an EV driver is not penalised
/// for missing fuel prices, and a single-day trip is not penalised for
/// having no hotel data.
///
/// Tapping expands a per-factor breakdown.
class TripQualityScore extends StatefulWidget {
  const TripQualityScore({
    super.key,
    required this.response,
    this.request,
    this.addedStopKeys = const {},
    this.selectedHotelCount = 0,
    this.pickedFuelCount = 0,
    this.enrichPending = false,
    this.unselectedStopCount = 0,
    this.skippedTolls = const [],
  });
  final TripPlanResponse response;

  /// The tolls the driver chose to skip: money saved and extra minutes
  /// each one adds. Drives the "extra time vs savings" factor.
  final List<({double eur, double minutes})> skippedTolls;

  /// Original request that produced [response]. When provided, factor
  /// weights are adapted to the user's profile and trip options.
  final TripPlanRequest? request;

  /// Keys of stops the user has explicitly added via the + button.
  /// Used to penalise factors whose data exists but hasn't been actioned.
  final Set<String> addedStopKeys;

  /// Number of overnight hotels the user has selected (per-night).
  final int selectedHotelCount;

  /// Number of fuel stations the user has added to the route.
  final int pickedFuelCount;

  /// True while enrichment is still running — toll factor gets full score
  /// to avoid false penalties before the data is complete.
  final bool enrichPending;

  /// Same count shown in the "N stop(s) not added" badge in day bars.
  final int unselectedStopCount;

  @override
  State<TripQualityScore> createState() => _TripQualityScoreState();
}

class _TripQualityScoreState extends State<TripQualityScore> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    // Only include applicable factors (max > 0).
    final allFactors = _computeFactors(
      widget.response,
      widget.request,
      l,
      addedStopKeys: widget.addedStopKeys,
      selectedHotelCount: widget.selectedHotelCount,
      pickedFuelCount: widget.pickedFuelCount,
      enrichPending: widget.enrichPending,
      unselectedStopCount: widget.unselectedStopCount,
      skippedTolls: widget.skippedTolls,
    );
    final factors = allFactors.where((f) => f.max > 0).toList();

    final rawScore = factors.fold<int>(0, (s, f) => s + f.score);
    final rawMax = factors.fold<int>(0, (s, f) => s + f.max);
    // Normalise to 0-100 regardless of how many factors are active.
    final score = rawMax > 0 ? (rawScore * 100 ~/ rawMax) : 100;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color(score, isDark);
    final label = _label(score, l);

    // During enrichment show an indeterminate pulsing bar.
    if (widget.enrichPending) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space12, vertical: Tokens.space12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.star_rounded, color: scheme.onSurfaceVariant, size: 18),
            const SizedBox(width: Tokens.space8),
            Expanded(
              child: Text(
                l.tripQualityTitle,
                style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      scheme.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space12, vertical: Tokens.space12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.06 : 0.1),
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.4)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, color: color, size: 18),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: Text(
                    l.tripQualityTitle,
                    style: t.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700),
                  ),
                ),
                // Score pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.15 : 0.16),
                    borderRadius:
                        BorderRadius.circular(Tokens.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: t.labelLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800),
                      ),
                      Text('/100 · $label',
                          style: t.labelSmall?.copyWith(color: color)),
                    ],
                  ),
                ),
                const SizedBox(width: Tokens.space4),
                Icon(
                  _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            // Progress bar
            const SizedBox(height: Tokens.space8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: 800.ms,
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 5,
                  backgroundColor:
                      scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            // Expanded breakdown
            if (_expanded) ...[
              const SizedBox(height: Tokens.space12),
              Wrap(
                spacing: Tokens.space8,
                runSpacing: Tokens.space8,
                children: [
                  for (final (i, f) in factors.indexed)
                    _ScoreChip(factor: f, scheme: scheme, t: t)
                        .animate(delay: (i * 50).ms)
                        .fadeIn(duration: 200.ms)
                        .scale(
                            begin: const Offset(0.85, 0.85),
                            end: const Offset(1, 1)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _color(int score, bool isDark) =>
      qualityTierColor(score >= 75 ? 2 : (score >= 50 ? 1 : 0), isDark);

  String _label(int score, AppLocalizations l) {
    if (score >= 75) return l.tripQualityExcellent;
    if (score >= 60) return l.tripQualityGood;
    if (score >= 40) return l.tripQualityFair;
    return l.tripQualityPoor;
  }

  List<_QFactor> _computeFactors(
    TripPlanResponse r,
    TripPlanRequest? req,
    AppLocalizations l, {
    Set<String> addedStopKeys = const {},
    int selectedHotelCount = 0,
    int pickedFuelCount = 0,
    bool enrichPending = false,
    int unselectedStopCount = 0,
    List<({double eur, double minutes})> skippedTolls = const [],
  }) {
    final profile = req?.tripProfile;
    final tollTimeScore = tollSkipTimeScore(skippedTolls);

    // ---- Route geometry (max 20) ----------------------------------------
    final hasGeometry = r.route.geometry.length > 10;
    // Same source as the "N stop(s) not added" badge in day bars.
    final hasMealStops = r.optimizations?.mealStops.isNotEmpty == true;
    final pace = profile?.travelPace;
    final stopsNeeded = unselectedStopCount > 0 ||
        (hasMealStops && pace != TravelPace.push);
    final stopsPlanned = !stopsNeeded;

    // ---- Fuel prices (max 15 — EV: auto full-score, not applicable) ------
    final isElectric =
        profile?.vehicle.fuelType == FuelType.electric;
    final hasFuelPrices = r.fuelPrices.any((f) => f.priceAvailable);

    // ---- Hotels (max 15) -------------------------------------------------
    // N/A when user said neverOvernight or backend flagged showHotels=false.
    final hotelExpected =
        profile?.overnightPolicy != OvernightPolicy.never &&
            (r.recommendationScope?.showHotels ?? true);
    final hasHotels = r.hotels.isNotEmpty;

    // ---- Weather (max 15) ------------------------------------------------
    // Compute severity from segment icons. Empty = no data = no problem.
    final weatherScore = _weatherScore(r.weatherSegments);
    final weatherOk = weatherScore >= 10; // 10/15+ = decent conditions

    // ---- Adverse events (max 15) -----------------------------------------
    final adverseCount = r.adverseEvents.length;

    // ---- Tolls (max 10) --------------------------------------------------
    // A toll-FREE route is the best outcome — do not penalise.
    // Only penalise when there are actual tolls but no per-booth detail.
    final routeHasTolls =
        (r.route.tollCostEur + r.route.vignetteCostEur) > 0 ||
            r.route.vignetteCountries.isNotEmpty;
    final hasTollDetail = r.partialTollSkips.isNotEmpty;

    // ---- Meal / rest stops (max varies by pace) --------------------------
    // push   → driver wants no stops → factor excluded (max 0).
    // savour → stops are important  → max 15.
    // no kids/pets, steady           → max 5.
    // kids or pets present, steady   → max 10.
    final hasKids = profile?.hasKids ?? false;
    final hasPets = profile?.hasPets ?? false;
    final stopsMax = pace == TravelPace.push
        ? 0
        : pace == TravelPace.savour
            ? 15
            : (hasKids || hasPets)
                ? 10
                : 5;

    return [
      // Route geometry — max 20
      _QFactor(
        icon: Icons.route,
        label: l.tripQualityFactorRoute,
        score: hasGeometry
            ? (stopsPlanned ? 20 : 14) // 14 if stops suggested but none added
            : 10,
        max: 20,
        ok: hasGeometry && stopsPlanned,
        explanation: l.tripQualityExplainRoute,
      ),

      // Fuel prices — max 15 (EV: auto full-score, not applicable)
      _QFactor(
        icon: Icons.local_gas_station_outlined,
        label: l.tripQualityFactorFuel,
        score: isElectric
            ? 15
            : hasFuelPrices
                ? (pickedFuelCount == 0 ? 8 : 15)
                : r.fuelPrices.isNotEmpty
                    ? 8
                    : 0,
        max: 15,
        ok: isElectric || (hasFuelPrices && pickedFuelCount > 0),
        explanation: l.tripQualityExplainFuel,
      ),

      // Hotels — max 15, excluded (max=0) when hotels not applicable.
      _QFactor(
        icon: Icons.hotel_outlined,
        label: l.tripQualityFactorHotels,
        score: !hotelExpected
            ? 0
            : hasHotels
                ? (selectedHotelCount == 0 ? 8 : 15)
                : 0,
        max: !hotelExpected ? 0 : 15,
        ok: !hotelExpected || (hasHotels && selectedHotelCount > 0),
        explanation: l.tripQualityExplainHotels,
      ),

      // Weather — max 15 (computed from segment severity; empty = perfect)
      _QFactor(
        icon: Icons.wb_cloudy_outlined,
        label: l.tripQualityFactorWeather,
        score: weatherScore,
        max: 15,
        ok: weatherOk,
        explanation: l.tripQualityExplainWeather,
      ),

      // Alerts / adverse events — max 15
      _QFactor(
        icon: Icons.warning_amber_outlined,
        label: l.tripQualityFactorAlerts,
        score: adverseCount == 0 ? 15 : adverseCount <= 2 ? 8 : 3,
        max: 15,
        ok: adverseCount == 0,
        explanation: l.tripQualityExplainAlerts,
      ),

      // Tolls — max 10
      // No tolls on route → full score (clean trip).
      // Has tolls + bypass detail → full (data available to optimise).
      // Has tolls, no detail → partial (data missing).
      // enrichPending → full score (toll data not yet complete).
      _QFactor(
        icon: Icons.toll_outlined,
        label: l.tripQualityFactorTolls,
        score: (enrichPending || !routeHasTolls || hasTollDetail) ? 10 : 5,
        max: 10,
        ok: enrichPending || !routeHasTolls || hasTollDetail,
        explanation: l.tripQualityExplainTolls,
      ),

      // Extra time vs money saved by the tolls the driver chose to skip.
      // Only present once at least one toll is skipped.
      if (skippedTolls.isNotEmpty)
        _QFactor(
          icon: Icons.timer_outlined,
          label: l.tripQualityFactorTollTime,
          score: tollTimeScore,
          max: 15,
          ok: tollTimeScore == 15,
          explanation: l.tripQualityExplainTollTime,
        ),

      // Rest / meal stops — max varies by pace (max 0 = factor excluded)
      _QFactor(
        icon: Icons.restaurant_outlined,
        label: l.tripQualityFactorStops,
        score: pace == TravelPace.push
            ? 0
            : hasMealStops
                ? (addedStopKeys.isEmpty ? stopsMax ~/ 2 : stopsMax)
                : 0,
        max: stopsMax,
        ok: pace == TravelPace.push || (hasMealStops && addedStopKeys.isNotEmpty),
        explanation: l.tripQualityExplainStops,
      ),
    ];
  }

  /// Compute a 0-15 weather score from the segment icons.
  /// Empty segment list (= no weather data from backend) returns 15
  /// because absence of data means no known problems on this route.
  /// Each segment is weighted by its km span.
  int _weatherScore(List<WeatherSegment> segs) {
    if (segs.isEmpty) return 15;
    double totalKm = 0;
    double weighted = 0;
    for (final seg in segs) {
      final km = (seg.toKm - seg.fromKm).abs().clamp(1.0, double.infinity);
      weighted += _iconSeverity(seg.icon) * km;
      totalKm += km;
    }
    if (totalKm == 0) return 15;
    final avg = weighted / totalKm; // 0-100 scale
    return (avg * 15 / 100).round().clamp(0, 15);
  }

  /// Maps a weather icon code to a 0-100 severity score
  /// (100 = best / clear sky, 0 = worst / thunderstorm).
  int _iconSeverity(String icon) => switch (icon) {
        'sunny' => 100,
        'partly_cloudy' => 90,
        'cloudy' => 85,
        'drizzle' => 65,
        'fog' => 50,
        'rain' => 60,
        'heavy_rain' => 30,
        'snow' => 20,
        'heavy_snow' => 10,
        'thunderstorm' => 0,
        _ => 80,
      };
}

class _QFactor {
  const _QFactor({
    required this.icon,
    required this.label,
    required this.score,
    required this.max,
    required this.ok,
    required this.explanation,
  });
  final IconData icon;
  final String label;
  final int score;
  final int max;
  final bool ok;
  final String explanation;
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip(
      {required this.factor, required this.scheme, required this.t});
  final _QFactor factor;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = qualityTierColor(
      factor.ok ? 2 : (factor.score > 0 ? 1 : 0),
      isDark,
    );

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Row(
            children: [
              Icon(factor.icon, size: 18),
              const SizedBox(width: 8),
              Text(factor.label),
            ],
          ),
          content: Text(factor.explanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.1 : 0.12),
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              factor.ok ? Icons.check : Icons.remove,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 4),
            Icon(factor.icon, size: 12, color: color.withValues(alpha: isDark ? 0.8 : 1.0)),
            const SizedBox(width: 4),
            Text(
              factor.label,
              style: t.labelSmall?.copyWith(
                  color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tier colour for the quality score: 2 = good, 1 = partial, 0 = poor.
/// The neon shades read well on the dark surface; on the light surface
/// they sit around 1.7:1, so the light theme gets darker shades that
/// clear 4.5:1 as text.
Color qualityTierColor(int tier, bool isDark) => switch (tier) {
      2 => isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      1 => isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      _ => isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
    };
