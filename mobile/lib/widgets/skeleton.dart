import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// A pulsing gray placeholder. Used as a "content loading" hint that
/// preserves layout so the real content doesn't cause a jarring
/// reflow when it arrives.
///
/// Kept intentionally minimal: no color prop (theme-derived), no
/// custom animation curve. If you need something fancier build it
/// out of Skeleton primitives — don't add knobs here.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
            _ctrl.value,
          ),
          borderRadius: widget.borderRadius ??
              BorderRadius.circular(Tokens.radiusSm),
        ),
      ),
    );
  }
}

/// Full-screen "cargando resultados" placeholder — used as backdrop
/// behind the plan-loading dialog so the eventual ResultScreen
/// transition doesn't reveal a blank canvas. Also usable as a
/// stand-alone scaffold body if we ever prefer inline over dialog.
class ResultLoadingSkeleton extends StatelessWidget {
  const ResultLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space20, Tokens.space16, Tokens.space20, Tokens.space16,
      ),
      children: [
        // Big map placeholder.
        Skeleton(
          width: double.infinity, height: 200,
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
        ),
        const SizedBox(height: Tokens.space20),
        // Stats row.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            _Stat(),
            SizedBox(width: Tokens.space16),
            _Stat(),
            SizedBox(width: Tokens.space16),
            _Stat(),
          ],
        ),
        const SizedBox(height: Tokens.space24),
        // Section header + 3 tiles.
        Skeleton(
          width: 180, height: 22,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: Tokens.space12),
        for (var i = 0; i < 3; i++) ...[
          Row(
            children: [
              const Skeleton(width: 40, height: 40),
              const SizedBox(width: Tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(
                      width: 220, height: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Skeleton(
                      width: 150, height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space16),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(
            width: double.infinity, height: 12,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Skeleton(
            width: 80, height: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
