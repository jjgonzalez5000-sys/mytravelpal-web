import 'package:flutter/material.dart';

import '../api/models.dart';
import '../design/tokens.dart';

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
                child: Text('+$hiddenCount more'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _issueLine(BuildContext context, ConsistencyIssue issue) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final color = _severityColor(issue.severity, scheme);
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
            child: Text(
              issue.message,
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  String _headerLabel(List<ConsistencyIssue> issues) {
    final errors = issues.where((i) => i.isError).length;
    final warnings = issues.where((i) => i.isWarning).length;
    if (errors > 0 && warnings > 0) {
      return 'Trip plan needs review · $errors error(s), $warnings warning(s)';
    }
    if (errors > 0) {
      return errors == 1
          ? 'Trip plan needs review'
          : 'Trip plan needs review · $errors errors';
    }
    return warnings == 1
        ? 'Heads-up on your trip plan'
        : 'Heads-up on your trip plan · $warnings warnings';
  }

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
