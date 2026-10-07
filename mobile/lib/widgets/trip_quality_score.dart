import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Compact score card shown in the result screen below the hero stats.
/// Computes a 0-100 score from the trip response quality signals:
/// route completeness, fuel/hotel/weather data availability, alerts.
///
/// Tapping expands a per-factor breakdown.
class TripQualityScore extends StatefulWidget {
  const TripQualityScore({super.key, required this.response});
  final TripPlanResponse response;

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

    final factors = _computeFactors(widget.response, l);
    final score = factors.fold<int>(0, (s, f) => s + f.score);
    final color = _color(score);
    final label = _label(score, l);

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space12, vertical: Tokens.space12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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
                    color: color.withValues(alpha: 0.15),
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

  Color _color(int score) {
    if (score >= 75) return const Color(0xFF4ADE80);
    if (score >= 50) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }

  String _label(int score, AppLocalizations l) {
    if (score >= 75) return l.tripQualityExcellent;
    if (score >= 60) return l.tripQualityGood;
    if (score >= 40) return l.tripQualityFair;
    return l.tripQualityPoor;
  }

  List<_QFactor> _computeFactors(
      TripPlanResponse r, AppLocalizations l) {
    final hasGeometry = r.route.geometry.length > 10;
    final hasFuelPrices = r.fuelPrices.any((f) => f.priceAvailable);
    final hasHotels = r.hotels.isNotEmpty;
    final hasWeather = r.weatherSegments.isNotEmpty;
    final adverseCount = r.adverseEvents.length;
    final hasTollData = r.partialTollSkips.isNotEmpty;
    final hasMealStops = r.optimizations?.mealStops.isNotEmpty == true;

    return [
      _QFactor(
        icon: Icons.route,
        label: l.tripQualityFactorRoute,
        score: hasGeometry ? 20 : 10,
        max: 20,
        ok: hasGeometry,
      ),
      _QFactor(
        icon: Icons.local_gas_station_outlined,
        label: l.tripQualityFactorFuel,
        score: hasFuelPrices ? 15 : r.fuelPrices.isNotEmpty ? 8 : 0,
        max: 15,
        ok: hasFuelPrices,
      ),
      _QFactor(
        icon: Icons.hotel_outlined,
        label: l.tripQualityFactorHotels,
        score: hasHotels ? 15 : 0,
        max: 15,
        ok: hasHotels,
      ),
      _QFactor(
        icon: Icons.wb_cloudy_outlined,
        label: l.tripQualityFactorWeather,
        score: hasWeather ? 15 : 0,
        max: 15,
        ok: hasWeather,
      ),
      _QFactor(
        icon: Icons.warning_amber_outlined,
        label: l.tripQualityFactorAlerts,
        // Penalise for adverse events (max 15 pts when none)
        score: adverseCount == 0 ? 15 : adverseCount <= 2 ? 8 : 3,
        max: 15,
        ok: adverseCount == 0,
      ),
      _QFactor(
        icon: Icons.toll_outlined,
        label: l.tripQualityFactorTolls,
        score: hasTollData ? 10 : 5,
        max: 10,
        ok: hasTollData,
      ),
      _QFactor(
        icon: Icons.restaurant_outlined,
        label: l.tripQualityFactorStops,
        score: hasMealStops ? 10 : 0,
        max: 10,
        ok: hasMealStops,
      ),
    ];
  }
}

class _QFactor {
  const _QFactor({
    required this.icon,
    required this.label,
    required this.score,
    required this.max,
    required this.ok,
  });
  final IconData icon;
  final String label;
  final int score;
  final int max;
  final bool ok;
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip(
      {required this.factor, required this.scheme, required this.t});
  final _QFactor factor;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    final color = factor.ok
        ? const Color(0xFF4ADE80)
        : factor.score > 0
            ? const Color(0xFFFBBF24)
            : const Color(0xFFF87171);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
          Icon(factor.icon, size: 12, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            factor.label,
            style: t.labelSmall?.copyWith(
                color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Text(
            '${factor.score}',
            style: t.labelSmall
                ?.copyWith(color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
