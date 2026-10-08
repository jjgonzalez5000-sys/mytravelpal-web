import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Gantt-style day timeline bars.
///
/// Each day shows proportional segments for driving, meal stops (breakfast /
/// lunch / dinner), and rest stops. Unselected rest stops are ghost bars
/// (low-alpha fill + dashed border). A vertical marker shows the daily cap.
/// Tapping the header expands each row to show an unselected-stops hint.
class TripDayBars extends StatefulWidget {
  const TripDayBars({
    super.key,
    required this.days,
    required this.dayOverrides,
    required this.profileCapHours,
    required this.addedStopKeys,
    this.onDayTap,
    this.loading = false,
    this.avgKmh = 90.0,
  });

  final List<DayPlan> days;

  /// Per-day overrides currently active in the result screen.
  final Map<int, dynamic> dayOverrides; // DayOverride — dynamic to avoid import

  /// Default cap from the user's profile (fallback when no override).
  final int profileCapHours;

  /// Stop keys currently added by the user (_addedStops.keys.toSet()).
  /// Drives ghost vs solid rendering for rest stops.
  final Set<String> addedStopKeys;

  /// Route average speed (km/h).
  // TODO(day-plan-v2): use avgKmh to derive km-based driving time estimate
  // when wall-clock data is unavailable. Currently unused — wall-clock
  // (endAt - startAt) is the correct input for the Gantt timeline.
  final double avgKmh;

  /// Called with the day's index when a bar row is tapped.
  /// Null while replanning to prevent concurrent edits.
  final void Function(int dayIndex)? onDayTap;

  /// When true, shows animated shimmer bars instead of real data.
  final bool loading;

  @override
  State<TripDayBars> createState() => _TripDayBarsState();
}

// ── Segment model ─────────────────────────────────────────────────────────────

enum _SegType { driving, breakfast, lunch, dinner, rest }

class _Seg {
  const _Seg({
    required this.startFrac,
    required this.endFrac,
    required this.type,
    this.selected = true,
  });
  final double startFrac; // 0..1 of total bar width
  final double endFrac;   // 0..1 of total bar width
  final _SegType type;
  final bool selected; // false → ghost bar (rest stops only)
}

Color _baseColor(_SegType type, ColorScheme scheme) => switch (type) {
      _SegType.driving   => scheme.primary,
      _SegType.breakfast => const Color(0xFFF59E0B),
      _SegType.lunch     => const Color(0xFF22C55E),
      _SegType.dinner    => const Color(0xFF818CF8),
      _SegType.rest      => const Color(0xFFFB923C),
    };

// ── State ─────────────────────────────────────────────────────────────────────

class _TripDayBarsState extends State<TripDayBars> {
  bool _expanded = false;

  String _restKey(RestStop r) =>
      'reststop:${r.name ?? "noname"}:'
      '${r.coordinate.lat.toStringAsFixed(4)},'
      '${r.coordinate.lon.toStringAsFixed(4)}';

  bool _isSelected(RestStop r) =>
      widget.addedStopKeys.contains(_restKey(r));

  /// Build an ordered list of Gantt segments for one day.
  List<_Seg> _buildSegments(DayPlan d) {
    final startLocal = d.startAt.toLocal();
    final totalMin   = d.endAt.toLocal().difference(startLocal).inMinutes;
    if (totalMin <= 0) {
      return [const _Seg(startFrac: 0, endFrac: 1, type: _SegType.driving)];
    }

    // (startMin, durationMin, type, selected)
    final events = <(int, int, _SegType, bool)>[];

    // Meal stops — always selected, 30-min slots
    for (final m in d.mealStops) {
      final offset = m.at
          .toLocal()
          .difference(startLocal)
          .inMinutes
          .clamp(0, totalMin - 1);
      final type = switch (m.slot.toLowerCase()) {
        'breakfast' => _SegType.breakfast,
        'dinner'    => _SegType.dinner,
        _           => _SegType.lunch,
      };
      events.add((offset, 30, type, true));
    }

    // Rest stops — selected iff key is in addedStopKeys
    final dayRange = d.toKm - d.fromKm;
    for (final r in d.restStops) {
      final frac = dayRange > 0
          ? ((r.distanceFromOriginKm - d.fromKm) / dayRange).clamp(0.0, 1.0)
          : 0.5;
      final offset = (totalMin * frac).round().clamp(0, totalMin - 1);
      events.add((
        offset,
        r.recommendedBreakMinutes.clamp(1, 120),
        _SegType.rest,
        _isSelected(r),
      ));
    }

    // Sort events by start offset
    events.sort((a, b) => a.$1.compareTo(b.$1));

    final segs = <_Seg>[];
    var cursor = 0;
    for (final (s, dur, type, sel) in events) {
      final cs = s.clamp(cursor, totalMin);
      if (cs > cursor) {
        // Driving gap before this event
        segs.add(_Seg(
          startFrac: cursor / totalMin,
          endFrac: cs / totalMin,
          type: _SegType.driving,
        ));
      }
      final e = (cs + dur).clamp(0, totalMin);
      if (e > cs) {
        segs.add(_Seg(
          startFrac: cs / totalMin,
          endFrac: e / totalMin,
          type: type,
          selected: sel,
        ));
      }
      cursor = e;
    }
    // Trailing driving segment
    if (cursor < totalMin) {
      segs.add(_Seg(
        startFrac: cursor / totalMin,
        endFrac: 1.0,
        type: _SegType.driving,
      ));
    }
    return segs;
  }

  int _unselectedCount(DayPlan d) =>
      d.restStops.where((r) => !_isSelected(r)).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final days = widget.days.where((d) => !d.isDwellDay).toList();
    if (days.isEmpty && !widget.loading) return const SizedBox.shrink();

    // ── Loading shimmer ──────────────────────────────────────────────────────
    if (widget.loading) {
      return Container(
        padding: const EdgeInsets.all(Tokens.space12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart_rounded, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(l.tripDayBarsTitle,
                  style: t.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: scheme.primary)),
              const Spacer(),
              Icon(Icons.sync_rounded, size: 13, color: scheme.primary)
                  .animate(onPlay: (c) => c.repeat())
                  .rotate(duration: 900.ms, curve: Curves.linear),
            ]),
            const SizedBox(height: Tokens.space8),
            for (var i = 0; i < (days.isEmpty ? 3 : days.length); i++) ...[
              if (i > 0) const SizedBox(height: Tokens.space8),
              _ShimmerBar(scheme: scheme, widthFraction: 0.45 + i * 0.15),
            ],
          ],
        ),
      );
    }

    final totalUnselected =
        days.fold(0, (sum, d) => sum + _unselectedCount(d));

    // Opaque hit-test so taps on spacers between rows don't fall through
    // to the parent InkWell (heroStatsCard).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
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
            // ── Card header ─────────────────────────────────────────────────
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
                  if (totalUnselected > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB923C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l.tripDayBarsUnselected(totalUnselected),
                        style: t.labelSmall?.copyWith(
                          color: const Color(0xFFFB923C),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    l.tripDayBarsCap(widget.profileCapHours),
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
            // ── Day rows ────────────────────────────────────────────────────
            for (final (i, day) in days.indexed) ...[
              if (i > 0) const SizedBox(height: Tokens.space8),
              GestureDetector(
                onTap: widget.onDayTap != null
                    ? () => widget.onDayTap!(day.dayIndex)
                    : null,
                child: _GanttDayRow(
                  day: day,
                  segments: _buildSegments(day),
                  profileCapHours: widget.profileCapHours,
                  unselectedCount: _unselectedCount(day),
                  expanded: _expanded,
                  tappable: widget.onDayTap != null,
                  scheme: scheme,
                  t: t,
                ),
              ).animate(delay: (i * 60).ms).fadeIn(duration: 250.ms),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Gantt row per day ─────────────────────────────────────────────────────────

class _GanttDayRow extends StatelessWidget {
  const _GanttDayRow({
    required this.day,
    required this.segments,
    required this.profileCapHours,
    required this.unselectedCount,
    required this.expanded,
    required this.tappable,
    required this.scheme,
    required this.t,
  });

  final DayPlan day;
  final List<_Seg> segments;
  final int profileCapHours;
  final int unselectedCount;
  final bool expanded;
  final bool tappable;
  final ColorScheme scheme;
  final TextTheme t;

  static const double _barH = 14.0;

  @override
  Widget build(BuildContext context) {
    final startLocal = day.startAt.toLocal();
    final totalMin =
        day.endAt.toLocal().difference(startLocal).inMinutes;
    final dayKm = (day.toKm - day.fromKm).toStringAsFixed(0);

    final dateLabel = DateFormat(
      'EEE d',
      Localizations.localeOf(context).toString(),
    ).format(startLocal);

    final hh = totalMin ~/ 60;
    final mm = totalMin % 60;
    final durLabel = mm > 0 ? '${hh}h ${mm}m' : '${hh}h';

    // Cap marker: fraction of wall-clock bar where driving cap falls.
    // Only draw when the cap is strictly inside the bar (not at edges).
    final capFrac = totalMin > 0
        ? (profileCapHours * 60.0 / totalMin).clamp(0.0, 1.0)
        : 1.0;
    final showCap = capFrac > 0.02 && capFrac < 0.99;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35), width: 1),
              ),
              child: Center(
                child: Text(
                  '${day.dayIndex}',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$dateLabel · $dayKm km · $durLabel',
              style: t.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10),
            ),
            const Spacer(),
            if (tappable)
              Icon(Icons.tune_rounded,
                  size: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
          ],
        ),
        const SizedBox(height: 4),
        // Gantt bar
        LayoutBuilder(builder: (ctx, constraints) {
          final W = constraints.maxWidth;
          return SizedBox(
            height: _barH,
            child: Stack(
              children: [
                // Segments clipped to rounded track shape
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      // Track background
                      Container(
                        width: W,
                        height: _barH,
                        color: scheme.surfaceContainerHighest,
                      ),
                      // Gantt segments
                      for (final seg in segments)
                        _SegBar(seg: seg, W: W, h: _barH, scheme: scheme),
                    ],
                  ),
                ),
                // Cap marker — drawn outside ClipRRect so it's always visible
                if (showCap)
                  Positioned(
                    left: (W * capFrac - 1.0).clamp(0.0, W - 2.0),
                    top: 0,
                    child: Container(
                      width: 2,
                      height: _barH,
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        // Ghost hint — shown when expanded and this day has unselected stops
        if (expanded && unselectedCount > 0) ...[
          const SizedBox(height: 3),
          Builder(builder: (ctx) {
            final l = AppLocalizations.of(ctx);
            return Text(
              '${l.tripDayBarsUnselected(unselectedCount)} · ${l.tripDayBarsHint}',
              style: t.labelSmall?.copyWith(
                color: const Color(0xFFFB923C).withValues(alpha: 0.8),
                fontSize: 9,
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ── Single Gantt segment ──────────────────────────────────────────────────────

class _SegBar extends StatelessWidget {
  const _SegBar({
    required this.seg,
    required this.W,
    required this.h,
    required this.scheme,
  });

  final _Seg seg;
  final double W;
  final double h;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final base  = _baseColor(seg.type, scheme);
    final left  = W * seg.startFrac;
    final width = W * (seg.endFrac - seg.startFrac);
    if (width <= 0) return const SizedBox.shrink();

    if (!seg.selected) {
      // Ghost: low-alpha fill + dashed border
      return Positioned(
        left: left,
        top: 0,
        child: SizedBox(
          width: width,
          height: h,
          child: CustomPaint(
            painter: _DashedBorderPainter(base.withValues(alpha: 0.5)),
            child: Container(color: base.withValues(alpha: 0.15)),
          ),
        ),
      );
    }

    return Positioned(
      left: left,
      top: 0,
      child: Container(width: width, height: h, color: base),
    );
  }
}

// ── Dashed border painter ─────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter(this.color);
  final Color color;

  static const double _dash = 3.0;
  static const double _gap  = 2.0;

  void _dashedLine(Canvas c, Paint p, Offset a, Offset b) {
    final dx  = b.dx - a.dx;
    final dy  = b.dy - a.dy;
    final len = (b - a).distance;
    if (len == 0) return;
    var t = 0.0;
    while (t < len) {
      final t1 = t / len;
      final t2 = ((t + _dash) / len).clamp(0.0, 1.0);
      c.drawLine(
        Offset(a.dx + dx * t1, a.dy + dy * t1),
        Offset(a.dx + dx * t2, a.dy + dy * t2),
        p,
      );
      t += _dash + _gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    // Top and bottom edges
    _dashedLine(canvas, p, Offset.zero, Offset(size.width, 0));
    _dashedLine(
        canvas, p, Offset(0, size.height), Offset(size.width, size.height));
    // Left and right edges (only for segments wide enough to matter)
    if (size.width > 5) {
      _dashedLine(canvas, p, Offset.zero, Offset(0, size.height));
      _dashedLine(
          canvas, p, Offset(size.width, 0), Offset(size.width, size.height));
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// ── Shimmer placeholder bar for loading state ─────────────────────────────────

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({required this.scheme, required this.widthFraction});

  final ColorScheme scheme;
  final double widthFraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
          const SizedBox(width: 6),
          Container(
            width: 40,
            height: 10,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
          const Spacer(),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
        ]),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (ctx, constraints) {
          return Stack(children: [
            Container(
              width: constraints.maxWidth,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            Container(
              width: constraints.maxWidth * widthFraction.clamp(0.0, 1.0),
              height: 14,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(7),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fadeIn(duration: 700.ms)
                .then()
                .fadeOut(duration: 700.ms),
          ]);
        }),
      ],
    );
  }
}
