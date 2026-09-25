import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'tokens.dart';

/// Section header used at the top of every logical block.
///
/// Small uppercase eyebrow (optional), large weighted title, optional
/// helper text underneath, and an optional trailing action slot.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space4),
                    child: Text(
                      eyebrow!.toUpperCase(),
                      style: t.labelSmall?.copyWith(
                        color: scheme.tertiary,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(title, style: t.titleLarge),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Tokens.space4),
                    child: Text(
                      description!,
                      style: t.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Card container used across the app. Flat by default (no shadow), soft
/// warm border, generous padding.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Tokens.space20),
    this.background,
    this.borderColor,
    this.elevated = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final Color? borderColor;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Subtle default drop shadow so cards read as gently elevated
    // above the scaffold surface. Dark mode gets a firmer alpha
    // because a 6% black shadow disappears against a near-black
    // surface; ~24% keeps the same perceived lift.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultShadow = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
        offset: const Offset(0, 4),
        blurRadius: 12,
        spreadRadius: -2,
      ),
    ];
    final container = DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
        boxShadow: elevated ? Tokens.shadowMd : defaultShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: container,
      ),
    );
  }
}

/// Big-number statistic tile used in a row or grid.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: t.labelSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Tokens.space4),
        Text(
          value,
          style: (emphasis ? t.headlineLarge : t.headlineMedium)?.copyWith(
            color: emphasis ? scheme.primary : scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Primary CTA button — full-width variant.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            else if (icon != null)
              Icon(icon, size: 18),
            if (icon != null || loading) const SizedBox(width: Tokens.space12),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Pill-shaped badge used for countries, categories, price bands.
class SoftBadge extends StatelessWidget {
  const SoftBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.background,
    this.borderColor,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurface;
    final bg = background ?? scheme.surfaceContainerHigh;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Empty-state block: icon + title + description + optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hero icon container — 96x96 rounded rectangle in the
            // scheme's primary container tint. Bigger + more color
            // than the previous 72x72 pill so the empty state feels
            // deliberate rather than a fallback. Subtle scale-in
            // gives it a soft entrance the first time it renders.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 56, color: scheme.onPrimaryContainer),
            )
                .animate()
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: const Duration(milliseconds: 300)),
            const SizedBox(height: Tokens.space16),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Tokens.space8),
            Text(
              description,
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: Tokens.space20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
