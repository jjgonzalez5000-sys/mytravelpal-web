import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Inline empty-state card. Used inside result-screen sections when
/// the user asked for a category (hotels, restaurants, alerts, fuel)
/// but the backend returned nothing.
///
/// Rules of thumb for good empty-state copy:
/// - Explain WHY it's empty (not just "no results").
/// - Offer an actionable follow-up when there is one (widen the
///   detour, enable a flag).
/// - Never blame the user.
///
/// Kept as a plain container instead of a full Card so it slots
/// tidily into the same vertical rhythm as regular tiles.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String? body;

  /// When [onAction] is provided renders a text button below the body.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional accent used for the icon + border. Defaults to the
  /// scheme's `outlineVariant` — neutral / non-alarming.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final color = tint ?? scheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.all(Tokens.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: t.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: Tokens.space8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionLabel!),
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
}
