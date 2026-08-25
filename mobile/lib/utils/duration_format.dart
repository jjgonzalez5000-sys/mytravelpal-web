/// Human-readable duration formatting.
///
/// Trip durations that are "872 min" or "1450 min" force the reader to
/// divide in their head. These helpers convert to `Nd Xh Ym` /
/// `Xh Ym` / `Ym` so the chart tick labels and tooltip lines are
/// glanceable.
///
/// Compact vs. spelled-out variants:
/// - [durationCompact] returns `1d 2h 30m` — for chart labels & chips.
/// - [durationShort] returns just the largest two units — for the
///   axis where space is tight (`14h`, `1d 2h`, `45m`).
library;

String durationCompact(num minutes) {
  final total = minutes.round().abs();
  final days = total ~/ (24 * 60);
  final hours = (total ~/ 60) % 24;
  final mins = total % 60;
  final parts = <String>[
    if (days > 0) '${days}d',
    if (hours > 0) '${hours}h',
    if (mins > 0 || (days == 0 && hours == 0)) '${mins}m',
  ];
  final sign = minutes < 0 ? '-' : '';
  return '$sign${parts.join(' ')}';
}

/// Two-largest-units variant for tight spaces (axis ticks).
///
///     45     → "45m"
///     150    → "2h 30m"
///     900    → "15h"      (drop 0m when hours are round)
///     1500   → "1d 1h"
String durationShort(num minutes) {
  final total = minutes.round().abs();
  if (total < 60) return '${total}m';
  final days = total ~/ (24 * 60);
  final hours = (total ~/ 60) % 24;
  final mins = total % 60;
  if (days > 0) {
    return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  }
  return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
}
