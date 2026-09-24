import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../design/components.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../widgets/skeleton.dart';
import '../services/notifications.dart';
import '../storage/saved_trip.dart';
import '../services/trip_export.dart';
import '../services/trip_sharing.dart';
import 'plan_screen.dart';
import 'result_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.onSwitchToPlan});

  /// Called when the user taps the "plan a trip" CTA from the empty state.
  final VoidCallback? onSwitchToPlan;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<SavedTrip>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAndSync();
  }

  Future<List<SavedTrip>> _loadAndSync() async {
    final storage = ref.read(tripStorageProvider);
    // Sync from server first — pulls trips saved from other
    // devices / installs into local storage before we display.
    // Cheap when there's nothing new; important when the user
    // just did "borrar datos + re-login" and expects their
    // cloud trips to reappear.
    await storage.syncFromServer();
    return storage.list();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadAndSync();
    });
  }

  Future<void> _delete(SavedTrip trip) async {
    final l = AppLocalizations.of(context);
    await NotificationService.instance.cancel(trip.notificationId);
    await ref.read(tripStorageProvider).delete(trip.id);
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l.historyDeleted(
            '${_shortName(trip.origin)} → ${_shortName(trip.destination)}',
          ),
        ),
      ),
    );
  }

  Future<void> _reopen(SavedTrip trip) async {
    final api = ref.read(apiClientWithPremiumProvider);
    // If the saved departure is already in the past, shift it to
    // the next occurrence of the same weekday + time. Testers who
    // saved a trip weeks ago tried to "reopen" and got either a
    // 4xx from the planner (past date) or a nonsense window that
    // couldn't be acted on. Same-weekday shift keeps the plan
    // useful (commutes, weekly trips) without asking the user to
    // pick a new date every time.
    final now = DateTime.now();
    var departure = trip.desiredDepartureAt;
    if (departure.isBefore(now)) {
      final target = departure;
      var candidate = DateTime(
        now.year, now.month, now.day, target.hour, target.minute,
      );
      while (
        candidate.weekday != target.weekday || candidate.isBefore(now)
      ) {
        candidate = candidate.add(const Duration(days: 1));
      }
      departure = candidate;
    }
    final request = TripPlanRequest(
      origin: trip.origin.coordinate,
      destination: trip.destination.coordinate,
      desiredDepartureAt: departure,
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
            desiredDepartureAt: departure,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          AppLocalizations.of(context).historyReplanFailed(e.statusCode),
        )),
      );
    }
  }

  /// Prefill the plan screen with the saved trip's origin +
  /// destination and hand control back to the user so they can
  /// tweak the departure / preferences before submitting. Better
  /// UX than `_reopen` when the driver wants to change something
  /// (different day, different profile, extra stops).
  Future<void> _repeat(SavedTrip trip) async {
    final now = DateTime.now();
    var departure = trip.desiredDepartureAt;
    if (departure.isBefore(now)) {
      // Same-weekday shift as `_reopen`, but here it's just a
      // sensible default the user can still override on the
      // date picker.
      final target = departure;
      var candidate = DateTime(
        now.year, now.month, now.day, target.hour, target.minute,
      );
      while (
        candidate.weekday != target.weekday || candidate.isBefore(now)
      ) {
        candidate = candidate.add(const Duration(days: 1));
      }
      departure = candidate;
    }
    final shared = SharedTrip(
      origin: trip.origin.coordinate,
      destination: trip.destination.coordinate,
      departureAt: departure,
      originName: trip.origin.displayName,
      destinationName: trip.destination.displayName,
    );
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanScreen(initialShared: shared),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.historyTitle)),
      body: FutureBuilder<List<SavedTrip>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            // Skeleton list instead of a bare spinner — the shape of
            // the eventual list is preserved so nothing jumps when
            // data lands.
            return ListView.separated(
              padding: const EdgeInsets.all(Tokens.space16),
              itemCount: 4,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: Tokens.space12),
              itemBuilder: (_, __) => Row(
                children: [
                  const Skeleton(width: 44, height: 44),
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
                          width: 140, height: 12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          final trips = snapshot.data ?? const <SavedTrip>[];
          if (trips.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_outline,
              title: l.historyEmptyTitle,
              description: l.historyEmptyBody,
              action: OutlinedButton(
                onPressed: widget.onSwitchToPlan ?? () => Navigator.of(context).maybePop(),
                child: Text(l.historyPlanCta),
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
                  onRepeat: () => _repeat(trip),
                  onDelete: () => _delete(trip),
                  onExport: () => showExportSheet(
                    context,
                    origin: trip.origin.coordinate,
                    destination: trip.destination.coordinate,
                  ),
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
    required this.onRepeat,
    required this.onDelete,
    required this.onExport,
  });

  final SavedTrip trip;
  final VoidCallback onOpen;
  final VoidCallback onRepeat;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final dateFmt = DateFormat('d MMM · HH:mm', l.localeName);
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
                icon: Icon(Icons.ios_share, color: scheme.onSurfaceVariant,
                    size: 20),
                tooltip: l.exportShareTitle,
                onPressed: onExport,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
                tooltip: l.historyDeleteTooltip,
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
                label: l.historyBestAt(
                  DateFormat.Hm(l.localeName)
                      .format(trip.recommendedDepartureAt),
                ),
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
            l.historyWantedAt(dateFmt.format(trip.desiredDepartureAt)),
            style: t.bodySmall,
          ),
          // Cost + savings summary per trip. Shown even when a
          // number is zero (fuel-only trips still show €0 saved
          // instead of hiding the row) so the layout is stable
          // across cards.
          if (trip.fuelCostEur > 0 ||
              trip.savedEurVsTolls > 0 ||
              trip.savedMinutesVsDesired > 0) ...[
            const SizedBox(height: Tokens.space12),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: Tokens.space12),
            Row(
              children: [
                if (trip.fuelCostEur > 0) ...[
                  Icon(Icons.local_gas_station, size: 14,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('€${trip.fuelCostEur.toStringAsFixed(0)}',
                      style: t.labelMedium),
                  const SizedBox(width: Tokens.space16),
                ],
                if (trip.savedEurVsTolls > 0) ...[
                  Icon(Icons.savings_outlined, size: 14,
                      color: scheme.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    '€${trip.savedEurVsTolls.toStringAsFixed(0)}',
                    style: t.labelMedium
                        ?.copyWith(color: scheme.tertiary),
                  ),
                  const SizedBox(width: Tokens.space16),
                ],
                if (trip.savedMinutesVsDesired > 0) ...[
                  Icon(Icons.timer_outlined, size: 14,
                      color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.savedMinutesVsDesired.toStringAsFixed(0)} min',
                    style: t.labelMedium
                        ?.copyWith(color: scheme.primary),
                  ),
                ],
              ],
            ),
          ],
          // Action row — explicit CTAs so the user knows how to
          // reopen the plan OR recover the trip into the plan
          // form to tweak it. The whole card is still tappable
          // (falls through to onOpen) for the common case.
          const SizedBox(height: Tokens.space12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(l.historyReopenCta),
                  onPressed: onOpen,
                ),
              ),
              const SizedBox(width: Tokens.space8),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.replay, size: 18),
                  label: Text(l.historyRepeatCta),
                  onPressed: onRepeat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _shortName(GeocodeResult r) => r.displayName.split(',').first;
