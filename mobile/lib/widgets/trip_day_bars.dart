import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Day-by-day timeline bars showing actual driving hours vs the user's
/// configured cap per day. Bar width = cap; fill = actual hours used.
///
/// - Green  : actual ≤ 75 % of cap (comfortable)
/// - Amber  : 75–100 % of cap (near limit)
/// - Red    : actual > cap (over limit — backend may have split the day)
///
/// The cap marker (`│`) shows the user's configured limit per day.
/// Tapping the card toggles expanded mode (adds km, time range, date).
class TripDayBars extends StatefulWidget {
  const TripDayBars({
    super.key,
    required this.days,
    required this.dayOverrides,
    required this.profileCapHours,
    this.onDayTap,
  });

  final List<DayPlan> days;

  /// Per-day overrides currently active in the result screen.
  final Map<int, dynamic> dayOverrides; // DayOverride — using dynamic to avoid import

  /// Default cap from the user's profile (fallback when no override).
  final int profileCapHours;

  /// Called with the day's index when a bar row is tapped.
  /// Null while replanning to prevent concurrent edits.
  final void Function(int dayIndex)? onDayTap;

  @override
  State<TripDayBars> createState() => _TripDayBarsState();
}

class _TripDayBarsState extends State<TripDayBars> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final days = widget.days.where((d) => !d.isDwellDay).toList();
    if (days.isEmpty) return const SizedBox.shrink();

    // For each day compute [actualHours, capHours]
    final data = days.map((d) {
      final actual = d.endAt.toLocal()
          .difference(d.startAt.toLocal()).inMinutes / 60.0;
      final override = widget.dayOverrides[d.dayIndex];
      final cap = (override?.dailyDrivingCapHours as int?) ??
          widget.profileCapHours;
      return (d, actual, cap.toDouble());
    }).toList();

    // Bar x-axis scale: max cap across all days (so all bars fit)
    final maxCap = data
        .map((e) => e.$3)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, 16.0);

    return Container(
        padding: const EdgeInsets.all(Tokens.space12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — tap to expand/collapse detail
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(l.tripDayBarsTitle,
                      style: t.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                  const Spacer(),
                  Text(
                    'Cap: ${widget.profileCapHours}h',
                    style: t.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space8),
            for (final (i, (day, actual, cap)) in data.indexed) ...[
              if (i > 0) const SizedBox(height: Tokens.space8),
              GestureDetector(
                onTap: widget.onDayTap != null
                    ? () => widget.onDayTap!(day.dayIndex)
                    : null,
                child: _DayBar(
                  day: day,
                  actualHours: actual,
                  capHours: cap,
                  maxCap: maxCap,
                  expanded: _expanded,
                  tappable: widget.onDayTap != null,
                  scheme: scheme,
                  t: t,
                ),
              ).animate(delay: (i * 60).ms).fadeIn(duration: 250.ms),
            ],
          ],
        ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.actualHours,
    required this.capHours,
    required this.maxCap,
    required this.expanded,
    required this.tappable,
    required this.scheme,
    required this.t,
  });

  final DayPlan day;
  final double actualHours;
  final double capHours;
  final double maxCap;
  final bool expanded;
  final bool tappable;
  final ColorScheme scheme;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    final dayKm = (day.toKm - day.fromKm);
    final startLocal = day.startAt.toLocal();
    final endLocal = (day.sleepAt ?? day.endAt).toLocal();

    // How full is the bar (clamped to 100% — over-cap shown red)
    final fillFraction = (actualHours / capHours).clamp(0.0, 1.0);
    // Cap marker position within the bar (cap/maxCap of total width)
    final capFraction = (capHours / maxCap).clamp(0.0, 1.0);
    // Over cap?
    final overCap = actualHours > capHours + 0.25;
    final nearCap = !overCap && actualHours > capHours * 0.75;

    final barColor = overCap
        ? const Color(0xFFF87171)  // red
        : nearCap
            ? const Color(0xFFFBBF24) // amber
            : const Color(0xFF4ADE80); // green

    final statusEmoji = overCap ? '🔴' : nearCap ? '⚠️' : '✓';

    final timeFmt = DateFormat('HH:mm');
    final dateLabel = DateFormat('EEE d',
            Localizations.localeOf(context).toString())
        .format(startLocal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            // Day badge
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: barColor.withValues(alpha: 0.5), width: 1),
              ),
              child: Center(
                child: Text('${day.dayIndex}',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: barColor)),
              ),
            ),
            const SizedBox(width: 6),
            Text(dateLabel,
                style: t.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10)),
            const Spacer(),
            if (expanded) ...[
              Text(
                '${timeFmt.format(startLocal)} → ${timeFmt.format(endLocal)}',
                style: t.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant, fontSize: 10),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '${actualHours.toStringAsFixed(1)}h / ${capHours.toStringAsFixed(0)}h',
              style: t.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: overCap ? const Color(0xFFF87171) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(statusEmoji, style: const TextStyle(fontSize: 10)),
            if (expanded) ...[
              const SizedBox(width: 8),
              Text('${dayKm.toStringAsFixed(0)} km',
                  style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant, fontSize: 10)),
            ],
            if (tappable) ...[
              const SizedBox(width: 6),
              Icon(Icons.tune_rounded, size: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Bar
        LayoutBuilder(builder: (ctx, constraints) {
          final W = constraints.maxWidth;
          return SizedBox(
            height: 10,
            child: Stack(
              children: [
                // Track (full width = maxCap)
                Container(
                  width: W,
                  height: 10,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                // Cap zone (shaded area = this day's cap)
                Positioned(
                  left: 0,
                  child: Container(
                    width: W * capFraction,
                    height: 10,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                // Fill (actual hours)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fillFraction * capFraction),
                  duration: 700.ms,
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Container(
                    width: W * v,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        barColor,
                        barColor.withValues(alpha: 0.75),
                      ]),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // Cap marker line (user's limit)
                Positioned(
                  left: W * capFraction - 1.5,
                  top: 0,
                  child: Container(
                    width: 3,
                    height: 10,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
