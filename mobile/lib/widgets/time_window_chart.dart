import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../utils/duration_format.dart';

/// Horizontal bar chart for the departure-window candidates.
///
/// Rewritten in Sprint 23. The previous vertical fl_chart version took
/// half the screen height for 13 samples and rotated the time labels
/// awkwardly. This version renders one row per candidate — cleaner on
/// mobile, glanceable, and lets us tap a row to pick that departure.
///
/// Each row is:
/// `[HH:MM]   █████████████░░░░░░   14h 32m   ×1.05   [chip]`
///
/// The recommended slot gets a solid primary bar; the user's original
/// desired time gets an outlined bar so they see, at a glance, how
/// much they save by shifting.
class TimeWindowChart extends StatelessWidget {
  const TimeWindowChart({
    super.key,
    required this.windows,
    required this.desiredDepartureAt,
  });

  final List<TimeWindow> windows;
  final DateTime desiredDepartureAt;

  static const _barHeight = 8.0;
  static const _rowHeight = 30.0;
  static const _labelWidth = 52.0;
  static const _durationWidth = 68.0;

  @override
  Widget build(BuildContext context) {
    if (windows.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No time windows returned.')),
      );
    }

    final sorted = [...windows]
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fmt = DateFormat.Hm();

    final maxMinutes = sorted
        .map((w) => w.estimatedMinutes)
        .reduce((a, b) => a > b ? a : b);

    final desiredIndex = _indexClosestTo(sorted, desiredDepartureAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sorted.length; i++)
          _Row(
            window: sorted[i],
            isDesired: i == desiredIndex,
            // Non-normalized: bar width is the raw ratio to the slowest
            // slot. The recommended slot's colour + label do the
            // signalling — bar widths honestly reflect total duration
            // instead of magnifying tiny (~5 %) deltas.
            fillFraction: maxMinutes <= 0
                ? 1.0
                : sorted[i].estimatedMinutes / maxMinutes,
            barHeight: _barHeight,
            rowHeight: _rowHeight,
            labelWidth: _labelWidth,
            durationWidth: _durationWidth,
            timeFmt: fmt,
            scheme: scheme,
            textTheme: t,
          ),
      ],
    );
  }

  static int _indexClosestTo(List<TimeWindow> sorted, DateTime target) {
    var bestIndex = 0;
    var bestDelta = sorted.first.departureAt.difference(target).abs();
    for (var i = 1; i < sorted.length; i++) {
      final delta = sorted[i].departureAt.difference(target).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.window,
    required this.isDesired,
    required this.fillFraction,
    required this.barHeight,
    required this.rowHeight,
    required this.labelWidth,
    required this.durationWidth,
    required this.timeFmt,
    required this.scheme,
    required this.textTheme,
  });

  final TimeWindow window;
  final bool isDesired;
  final double fillFraction;
  final double barHeight;
  final double rowHeight;
  final double labelWidth;
  final double durationWidth;
  final DateFormat timeFmt;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final barColor = window.recommended
        ? scheme.primary
        : scheme.secondaryContainer;
    final fg = window.recommended
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    final labelStyle = textTheme.labelMedium?.copyWith(
      color: fg,
      fontWeight: isDesired || window.recommended
          ? FontWeight.w700
          : FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final durationStyle = textTheme.labelMedium?.copyWith(
      color: fg,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              timeFmt.format(window.departureAt),
              style: labelStyle,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final filled = (width * fillFraction).clamp(6.0, width);
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(barHeight / 2),
                      ),
                    ),
                    Container(
                      height: barHeight,
                      width: filled,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(barHeight / 2),
                        border: isDesired && !window.recommended
                            ? Border.all(color: scheme.primary, width: 1.5)
                            : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: durationWidth,
            child: Text(
              durationShort(window.estimatedMinutes),
              textAlign: TextAlign.right,
              style: durationStyle,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            child: Text(
              '×${window.trafficFactor.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
