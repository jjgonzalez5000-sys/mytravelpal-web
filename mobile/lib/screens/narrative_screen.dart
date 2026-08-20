import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
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
        title: Text('${widget.originName} → ${widget.destinationName}'),
      ),
      body: FutureBuilder<NarrativeResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState();
          }
          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error!,
              onRetry: _retry,
            );
          }
          final data = snapshot.data!;
          return _NarrativeBody(data: data);
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Composing your trip briefing…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text('Could not fetch the narrative.',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$error', textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NarrativeBody extends StatelessWidget {
  const _NarrativeBody({required this.data});

  final NarrativeResponse data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: scheme.primary),
            const SizedBox(width: 8),
            Text('AI trip briefing',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Chip(
              label: const Text('Premium'),
              backgroundColor: scheme.primaryContainer,
              labelStyle: TextStyle(color: scheme.onPrimaryContainer),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Generated ${DateFormat('d MMM y — HH:mm').format(data.generatedAt.toLocal())}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SelectableText(
          data.narrative,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
