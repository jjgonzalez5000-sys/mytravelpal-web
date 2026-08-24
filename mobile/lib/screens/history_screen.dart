import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../providers.dart';
import '../storage/saved_trip.dart';
import 'result_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<SavedTrip>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(tripStorageProvider).list();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ref.read(tripStorageProvider).list();
    });
  }

  Future<void> _delete(SavedTrip trip) async {
    await ref.read(tripStorageProvider).delete(trip.id);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted ${_shortName(trip.origin)} → ${_shortName(trip.destination)}',
        ),
      ),
    );
  }

  Future<void> _reopen(SavedTrip trip) async {
    final api = ref.read(apiClientProvider);
    final request = TripPlanRequest(
      origin: trip.origin.coordinate,
      destination: trip.destination.coordinate,
      desiredDepartureAt: trip.desiredDepartureAt,
    );
    try {
      final response = await api.planTrip(request);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            request: request,
            origin: trip.origin,
            destination: trip.destination,
            response: response,
            desiredDepartureAt: trip.desiredDepartureAt,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-plan failed: ${e.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved trips')),
      body: FutureBuilder<List<SavedTrip>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? const <SavedTrip>[];
          if (trips.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_outline,
              title: 'No saved trips yet',
              description:
                  'Plan a trip and tap the bookmark to keep it here for later.',
              action: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Plan a trip'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(Tokens.space20),
              itemCount: trips.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: Tokens.space12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Tokens.space4),
                    child: Text(
                      '${trips.length} saved',
                      style: t.labelSmall?.copyWith(letterSpacing: 1.2),
                    ),
                  );
                }
                final trip = trips[i - 1];
                return _TripCard(
                  trip: trip,
                  onOpen: () => _reopen(trip),
                  onDelete: () => _delete(trip),
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 30 * (i - 1)),
                      duration: Tokens.motionBase,
                    )
                    .moveY(begin: 6, end: 0, curve: Tokens.curveOut);
              },
            ),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedTrip trip;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dateFmt = DateFormat('d MMM · HH:mm');
    return SoftCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(Tokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_shortName(trip.origin), style: t.bodySmall),
                    Text(
                      _shortName(trip.destination),
                      style: t.titleLarge,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space16),
          Wrap(
            spacing: Tokens.space8,
            runSpacing: Tokens.space8,
            children: [
              SoftBadge(
                icon: Icons.route,
                label: '${trip.distanceKm.toStringAsFixed(0)} km',
              ),
              SoftBadge(
                icon: Icons.schedule,
                label:
                    'Best ${DateFormat.Hm().format(trip.recommendedDepartureAt)}',
                color: scheme.primary,
                background: scheme.primaryContainer,
                borderColor: scheme.primary.withValues(alpha: 0.25),
              ),
              for (final c in trip.countriesCrossed)
                SoftBadge(label: c.code),
            ],
          ),
          const SizedBox(height: Tokens.space12),
          Text(
            'Wanted ${dateFmt.format(trip.desiredDepartureAt)}',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _shortName(GeocodeResult r) => r.displayName.split(',').first;
