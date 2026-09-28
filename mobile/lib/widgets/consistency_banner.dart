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
    if (widget.issues.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final worst = widget.issues.first;
    final color = _severityColor(worst.severity, scheme);
    final icon = _severityIcon(worst.severity);

    final showAll = _expanded || widget.issues.length <= widget.maxVisible;
    final shown = showAll
        ? widget.issues
        : widget.issues.take(widget.maxVisible).toList();
    final hiddenCount = widget.issues.length - shown.length;

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
                  _headerLabel(widget.issues),
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
  /// server ships English-only text — this keeps the polished
  /// consistency banner intelligible in every locale for the codes
  /// users actually hit.
  String _localizedMessage(AppLocalizations l, ConsistencyIssue issue) {
    switch (issue.code) {
      case 'fuel.no_stations_visible':
        final km = _extractKm(issue.message);
        return l.consistencyFuelNoStations(km);
      case 'fuel.range_exceeded':
        return l.consistencyFuelRangeExceeded;
      default:
        return issue.message;
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
