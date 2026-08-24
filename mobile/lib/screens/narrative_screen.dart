import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../providers.dart';

class NarrativeScreen extends ConsumerStatefulWidget {
  const NarrativeScreen({
    super.key,
    required this.planRequest,
    required this.originName,
    required this.destinationName,
  });

  final TripPlanRequest planRequest;
  final String originName;
  final String destinationName;

  @override
  ConsumerState<NarrativeScreen> createState() => _NarrativeScreenState();
}

class _NarrativeScreenState extends ConsumerState<NarrativeScreen> {
  late Future<NarrativeResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<NarrativeResponse> _load() =>
      ref.read(apiClientProvider).tripNarrative(
            planRequest: widget.planRequest,
            originName: widget.originName,
            destinationName: widget.destinationName,
          );

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip briefing'),
      ),
      body: FutureBuilder<NarrativeResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState();
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error!, onRetry: _retry);
          }
          return _NarrativeBody(
            data: snapshot.data!,
            origin: widget.originName,
            destination: widget.destinationName,
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
            ),
            child: Icon(Icons.auto_awesome,
                color: scheme.onPrimaryContainer, size: 28),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.06, 1.06),
                duration: 800.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .scale(
                begin: const Offset(1.06, 1.06),
                end: const Offset(1, 1),
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: Tokens.space16),
          Text('Composing your trip briefing…', style: t.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Could not fetch the briefing',
      description: '$error',
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Retry'),
      ),
    );
  }
}

class _NarrativeBody extends StatelessWidget {
  const _NarrativeBody({
    required this.data,
    required this.origin,
    required this.destination,
  });

  final NarrativeResponse data;
  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space24, Tokens.space16, Tokens.space24, Tokens.space32,
      ),
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: scheme.tertiary),
            const SizedBox(width: Tokens.space8),
            Text(
              'AI BRIEFING',
              style: t.labelSmall?.copyWith(
                color: scheme.tertiary, letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            SoftBadge(
              label: 'Premium',
              color: scheme.onPrimaryContainer,
              background: scheme.primaryContainer,
              borderColor: scheme.primary.withValues(alpha: 0.3),
            ),
          ],
        ).animate().fadeIn(duration: Tokens.motionBase),
        const SizedBox(height: Tokens.space12),
        Text(origin, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
            .animate()
            .fadeIn(delay: 60.ms, duration: Tokens.motionBase),
        Text('→ $destination', style: t.displaySmall)
            .animate()
            .fadeIn(delay: 100.ms, duration: Tokens.motionBase)
            .moveY(begin: 6, end: 0, curve: Tokens.curveOut),
        const SizedBox(height: Tokens.space8),
        Text(
          'Generated ${DateFormat('d MMM y · HH:mm').format(data.generatedAt.toLocal())}',
          style: t.bodySmall,
        ),
        const SizedBox(height: Tokens.space24),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: Tokens.space16),
        SelectableText(
          data.narrative,
          style: t.bodyLarge?.copyWith(height: 1.6),
        )
            .animate()
            .fadeIn(delay: 160.ms, duration: Tokens.motionSlow),
      ],
    );
  }
}
