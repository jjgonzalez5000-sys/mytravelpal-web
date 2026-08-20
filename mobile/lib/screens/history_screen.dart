import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
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
      SnackBar(content: Text('Deleted ${_shortName(trip.origin)} → ${_shortName(trip.destination)}.')),
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
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _TripTile(
                trip: trips[i],
                onOpen: () => _reopen(trips[i]),
                onDelete: () => _delete(trips[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({
    required this.trip,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedTrip trip;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM y — HH:mm');
    return ListTile(
      onTap: onOpen,
      leading: const Icon(Icons.route),
      title: Text(
        '${_shortName(trip.origin)} → ${_shortName(trip.destination)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${trip.distanceKm.toStringAsFixed(0)} km · '
              'best at ${DateFormat.Hm().format(trip.recommendedDepartureAt)}'),
          Text('Wanted ${dateFmt.format(trip.desiredDepartureAt)}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: true,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: onDelete,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('No saved trips yet.',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Plan a trip and hit the bookmark to keep it here.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _shortName(GeocodeResult r) => r.displayName.split(',').first;
