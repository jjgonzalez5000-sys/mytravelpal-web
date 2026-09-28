import 'package:flutter/material.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Renders backend consistency issues (impossible meal-stop speeds,
/// EV out of range, missing fuel stations, …) as a compact banner.
///
/// Priorities from the server come pre-sorted: errors first, then
/// warnings. We show up to `maxVisible` and offer expand-to-see-more
/// so the banner doesn't dominate the screen on rare multi-issue
/// trips.
class ConsistencyBanner extends StatefulWidget {
  const ConsistencyBanner({
    super.key,
    required this.issues,
    this.maxVisible = 2,
  });

  final List<ConsistencyIssue> issues;
  final int maxVisible;

  @override
  State<ConsistencyBanner> createState() => _ConsistencyBannerState();
}

class _ConsistencyBannerState extends State<ConsistencyBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Issues anchored to a specific day are rendered inside that
    // day card by `DayPlanSection.build`. The global banner only
    // shows trip-wide codes (`fuel.*`, and any meal/sleep issue the
    // backend couldn't map to a day, e.g. km outside all day ranges).
    final tripWide = widget.issues
        .where((i) => i.dayIndex == null)
        .toList(growable: false);
    if (tripWide.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final worst = tripWide.first;
    final color = _severityColor(worst.severity, scheme);
    final icon = _severityIcon(worst.severity);

    final showAll = _expanded || tripWide.length <= widget.maxVisible;
    final shown = showAll
        ? tripWide
        : tripWide.take(widget.maxVisible).toList();
    final hiddenCount = tripWide.length - shown.length;

    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.space16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space16, vertical: Tokens.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: Text(
                  _headerLabel(tripWide),
                  style: t.labelLarge?.copyWith(
                    color: color, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space8),
          for (final issue in shown) _issueLine(context, issue),
          if (hiddenCount > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppLocalizations.of(context)
                      .consistencyMoreCount(hiddenCount),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _issueLine(BuildContext context, ConsistencyIssue issue) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final color = _severityColor(issue.severity, scheme);
    final localized = _localizedMessage(l, issue);
    final hint = _hintFor(l, issue.code);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(top: 8, right: Tokens.space8),
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localized,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant
                          .withValues(alpha: 0.75),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Prefer a locale-aware message keyed on the backend `code` when
  /// we have one; fall back to the raw server text otherwise. The
  /// server ships English-only text + a structured `context` map —
  /// this method reads the codes we understand and interpolates the
  /// context values so the polished consistency banner stays
  /// intelligible in every locale.
  String _localizedMessage(AppLocalizations l, ConsistencyIssue issue) {
    final ctx = issue.context ?? const <String, dynamic>{};
    String km() => (ctx['km'] ?? '?').toString();
    String slot() => _slotLabel(l, ctx['slot']?.toString());
    String kmh() => (ctx['implied_kmh'] ?? '?').toString();
    String mins() => (ctx['remaining_min'] ?? '?').toString();
    switch (issue.code) {
      case 'fuel.no_stations_visible':
        final dk = (ctx['distance_km'] ?? _extractKm(issue.message)).toString();
        return l.consistencyFuelNoStations(dk);
      case 'fuel.range_exceeded':
        return l.consistencyFuelRangeExceeded;
      case 'meal.before_departure':
        return l.consistencyMealBeforeDeparture(slot(), km());
      case 'meal.after_arrival':
        return l.consistencyMealAfterArrival(slot(), km());
      case 'meal.impossible_speed':
        return l.consistencyMealImpossibleSpeed(slot(), km(), kmh());
      case 'meal.suspicious_speed':
        return l.consistencyMealSuspiciousSpeed(slot(), km(), kmh());
      case 'meal.too_close_to_arrival':
        return l.consistencyMealTooCloseToArrival(slot(), km(), mins());
      case 'sleep.before_departure':
        return l.consistencySleepBeforeDeparture(km());
      case 'sleep.after_arrival':
        return l.consistencySleepAfterArrival(km());
      case 'sleep.impossible_speed':
        return l.consistencySleepImpossibleSpeed(km(), kmh());
      case 'sleep.suspicious_speed':
        return l.consistencySleepSuspiciousSpeed(km(), kmh());
      default:
        return issue.message;
    }
  }

  /// Backend meal codes carry `slot` as one of "breakfast", "lunch",
  /// "dinner" (raw enum values). Map to the localized display label
  /// so the interpolated message reads naturally in every locale.
  String _slotLabel(AppLocalizations l, String? slot) {
    switch ((slot ?? '').toLowerCase()) {
      case 'breakfast':
        return l.mealSlotBreakfastCap;
      case 'lunch':
        return l.mealSlotLunchCap;
      case 'dinner':
        return l.mealSlotDinnerCap;
      default:
        return slot ?? '?';
    }
  }

  /// Optional actionable hint line rendered under the main message
  /// for codes where "here's what to do next" is more useful than
  /// silence. Returns null for codes without a hint.
  String? _hintFor(AppLocalizations l, String code) {
    switch (code) {
      case 'fuel.no_stations_visible':
        return l.consistencyFuelNoStationsHint;
      default:
        return null;
    }
  }

  /// Best-effort km extraction from the backend's English "Trip is
  /// N km but ..." string. Falls back to "?" so the localized copy
  /// still renders even if the shape changes upstream.
  String _extractKm(String message) {
    final match = RegExp(r'(\d{2,5})\s*km').firstMatch(message);
    return match?.group(1) ?? '?';
  }

  String _headerLabelStatic(
    AppLocalizations l, List<ConsistencyIssue> issues,
  ) {
    final errors = issues.where((i) => i.isError).length;
    final warnings = issues.where((i) => i.isWarning).length;
    if (errors > 0 && warnings > 0) {
      return l.consistencyNeedsReviewMixed(errors, warnings);
    }
    if (errors > 0) {
      return errors == 1
          ? l.consistencyNeedsReview
          : l.consistencyNeedsReviewErrors(errors);
    }
    return warnings == 1
        ? l.consistencyHeadsUp
        : l.consistencyHeadsUpWarnings(warnings);
  }

  String _headerLabel(List<ConsistencyIssue> issues) =>
      _headerLabelStatic(AppLocalizations.of(context), issues);

  Color _severityColor(String severity, ColorScheme scheme) {
    switch (severity) {
      case 'error':
        return scheme.error;
      case 'warning':
        return scheme.tertiary;
      default:
        return scheme.outline;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

/// Compact inline chip for a single consistency issue anchored to a
/// specific day. Rendered inside the day card by [DayPlanSection]
/// so the driver sees the warning next to the day it applies to
/// instead of hunting for a raw English message at the top of the
/// screen.
class DayConsistencyChip extends StatelessWidget {
  const DayConsistencyChip({super.key, required this.issue});
  final ConsistencyIssue issue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    // Local mini-state helper to reuse the same localization logic
    // the top-level banner uses. `_ConsistencyBannerState` owns
    // `_localizedMessage`, so we replicate its dispatch in a
    // stateless helper below to avoid coupling this widget to the
    // banner's private state class.
    final l = AppLocalizations.of(context);
    final localized = _localizeIssue(l, issue);
    final Color bg;
    final Color fg;
    final IconData icon;
    switch (issue.severity) {
      case 'error':
        bg = scheme.error.withValues(alpha: 0.10);
        fg = scheme.error;
        icon = Icons.error_outline;
        break;
      case 'warning':
        bg = scheme.tertiary.withValues(alpha: 0.10);
        fg = scheme.tertiary;
        icon = Icons.warning_amber_outlined;
        break;
      default:
        bg = scheme.outline.withValues(alpha: 0.08);
        fg = scheme.onSurfaceVariant;
        icon = Icons.info_outline;
    }
    return Container(
      margin: const EdgeInsets.only(top: Tokens.space8),
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space12, vertical: 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              localized,
              style: t.labelSmall?.copyWith(
                color: fg, fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Free-function version of `_ConsistencyBannerState._localizedMessage`
/// so [DayConsistencyChip] (a stateless widget in the same file) can
/// call it without exposing private state. Keep the two dispatches in
/// sync — adding a new backend `code` needs an entry in both.
String _localizeIssue(AppLocalizations l, ConsistencyIssue issue) {
  final ctx = issue.context ?? const <String, dynamic>{};
  String km() => (ctx['km'] ?? '?').toString();
  String kmh() => (ctx['implied_kmh'] ?? '?').toString();
  String mins() => (ctx['remaining_min'] ?? '?').toString();
  String slot() {
    final s = (ctx['slot'] ?? '').toString().toLowerCase();
    switch (s) {
      case 'breakfast':
        return l.mealSlotBreakfastCap;
      case 'lunch':
        return l.mealSlotLunchCap;
      case 'dinner':
        return l.mealSlotDinnerCap;
      default:
        return s.isEmpty ? '?' : s;
    }
  }
  switch (issue.code) {
    case 'meal.before_departure':
      return l.consistencyMealBeforeDeparture(slot(), km());
    case 'meal.after_arrival':
      return l.consistencyMealAfterArrival(slot(), km());
    case 'meal.impossible_speed':
      return l.consistencyMealImpossibleSpeed(slot(), km(), kmh());
    case 'meal.suspicious_speed':
      return l.consistencyMealSuspiciousSpeed(slot(), km(), kmh());
    case 'meal.too_close_to_arrival':
      return l.consistencyMealTooCloseToArrival(slot(), km(), mins());
    case 'sleep.before_departure':
      return l.consistencySleepBeforeDeparture(km());
    case 'sleep.after_arrival':
      return l.consistencySleepAfterArrival(km());
    case 'sleep.impossible_speed':
      return l.consistencySleepImpossibleSpeed(km(), kmh());
    case 'sleep.suspicious_speed':
      return l.consistencySleepSuspiciousSpeed(km(), kmh());
    default:
      return issue.message;
  }
}
