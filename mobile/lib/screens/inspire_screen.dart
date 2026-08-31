import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/trip_sharing.dart';
import '../storage/inspiration_storage.dart';
import 'plan_screen.dart';

/// Trip Inspiration entry point. User types a free-form prompt,
/// hits "Inspire me", and the backend `/v1/trips/inspire`
/// endpoint returns a structured multi-day itinerary. Tapping
/// "Turn into a real plan" pre-fills the Plan screen with the
/// itinerary's endpoints + waypoints so the existing pipeline
/// takes over (routing, weather, hotels, fuel, toll — the works).
///
/// Premium-gated at the tap layer (free users get a preview and a
/// paywall) but the endpoint itself is not gated — the mobile
/// gate is enough for now; server-side quota comes with the real
/// Premium billing wire-up.
class InspireScreen extends ConsumerStatefulWidget {
  const InspireScreen({super.key});

  @override
  ConsumerState<InspireScreen> createState() => _InspireScreenState();
}

class _InspireScreenState extends ConsumerState<InspireScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  InspireItinerary? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.length < 8) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final locale = Localizations.localeOf(context).languageCode;
      final itinerary = await api.inspireTrip(
        prompt: prompt,
        locale: locale,
      );
      if (!mounted) return;
      setState(() => _result = itinerary);
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = AppLocalizations.of(context).inspireError);
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = AppLocalizations.of(context).inspireError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveInspiration() async {
    final it = _result;
    if (it == null) return;
    final storage = ref.read(inspirationStorageProvider);
    await storage.save(SavedInspiration(
      id: 'insp_${DateTime.now().millisecondsSinceEpoch}',
      prompt: _controller.text.trim(),
      itinerary: it,
      savedAt: DateTime.now(),
      locale: Localizations.localeOf(context).languageCode,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).inspireSavedToast)),
    );
  }

  void _convertToPlan() {
    final it = _result;
    if (it == null || it.days.isEmpty) return;
    final first = it.days.first;
    final last = it.days.last;
    // Origin = first day's from_name at first waypoint (or the
    // day's implicit start if we have one), destination = last
    // day's to_name at last waypoint. Intermediate cities are
    // handed off as waypoints so OSRM stitches the multi-leg
    // route the same way it does for manually-added stops.
    GeocodeResult? originResult;
    GeocodeResult? destResult;
    final stops = <GeocodeResult>[];
    // Walk each day. The FROM of day 1 is the origin; the TO of
    // the last day is the destination; every other TO becomes a
    // waypoint. We anchor coordinates from the day's waypoint
    // list where possible, falling back to the previous day's
    // last waypoint or the next day's first when a name lacks a
    // matching POI (LLMs sometimes omit city coords).
    LatLon? guessCoord(String cityName, InspireDay day) {
      for (final w in day.waypoints) {
        if (w.name.toLowerCase().contains(cityName.toLowerCase()) ||
            cityName.toLowerCase().contains(w.name.toLowerCase())) {
          return LatLon(lat: w.lat, lon: w.lon);
        }
      }
      return day.waypoints.isNotEmpty
          ? LatLon(
              lat: day.waypoints.first.lat,
              lon: day.waypoints.first.lon,
            )
          : null;
    }

    final originCoord = guessCoord(first.fromName, first);
    if (originCoord != null) {
      originResult = GeocodeResult(
        displayName: first.fromName,
        coordinate: originCoord,
        country: Country.fr, // best-guess; router still works.
      );
    }
    for (var i = 0; i < it.days.length - 1; i++) {
      final d = it.days[i];
      final coord = guessCoord(d.toName, d);
      if (coord == null) continue;
      stops.add(GeocodeResult(
        displayName: d.toName,
        coordinate: coord,
        country: Country.fr,
      ));
    }
    final destCoord = guessCoord(last.toName, last);
    if (destCoord != null) {
      destResult = GeocodeResult(
        displayName: last.toName,
        coordinate: destCoord,
        country: Country.fr,
      );
    }

    if (originResult == null || destResult == null) {
      // Nothing usable — fall back to just closing and letting the
      // user type manually. Rare (LLM would need to omit all
      // coords) but we shouldn't crash.
      Navigator.of(context).pop();
      return;
    }

    // Hand-off via SharedTrip so the existing plan-screen entry
    // path already knows how to pre-fill everything. Waypoints are
    // set via a small side channel — the PlanScreen already
    // supports intermediate stops.
    // Preferred: honour the LLM's timing hints from the prompt
    // ("weekend" -> next Friday, "next week" -> +7). Falls back
    // to "tomorrow 08:00" only when the prompt carried no time
    // signal at all.
    final daysOffset = it.suggestedDepartureDaysFromNow ?? 1;
    final hour = it.suggestedDepartureHour ?? 8;
    final target = DateTime.now().add(Duration(days: daysOffset));
    final departure =
        DateTime(target.year, target.month, target.day, hour);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlanScreen(
          initialShared: SharedTrip(
            origin: originResult!.coordinate,
            destination: destResult!.coordinate,
            departureAt: departure,
            originName: originResult.displayName,
            destinationName: destResult.displayName,
          ),
          initialStops: stops,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.inspireTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Tokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.inspireHero, style: t.headlineSmall),
              const SizedBox(height: Tokens.space8),
              Text(
                l.inspireSub,
                style: t.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Tokens.space16),
              TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 2,
                maxLength: 500,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: l.inspireHint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _generate(),
              ),
              const SizedBox(height: Tokens.space12),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading
                    ? l.inspireGenerating
                    : l.inspireGenerate),
              ),
              if (_error != null) ...[
                const SizedBox(height: Tokens.space12),
                Container(
                  padding: const EdgeInsets.all(Tokens.space12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(Tokens.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: scheme.onErrorContainer),
                      const SizedBox(width: Tokens.space8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Tokens.space24),
              if (_result == null) _ExamplesBlock(
                onPick: (text) {
                  _controller.text = text;
                  _generate();
                },
              ),
              if (_result != null) _ResultBlock(
                itinerary: _result!,
                onConvert: _convertToPlan,
                onSave: _saveInspiration,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamplesBlock extends StatelessWidget {
  const _ExamplesBlock({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final examples = [
      l.inspireExample1,
      l.inspireExample2,
      l.inspireExample3,
      l.inspireExample4,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.inspireExamplesTitle,
          style: t.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Tokens.space8),
        for (final ex in examples)
          Card(
            margin: const EdgeInsets.only(bottom: Tokens.space8),
            child: ListTile(
              leading: const Icon(Icons.route_outlined),
              title: Text(ex),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPick(ex),
            ),
          ),
      ],
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.itinerary,
    required this.onConvert,
    required this.onSave,
  });
  final InspireItinerary itinerary;
  final VoidCallback onConvert;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.inspireResultTitle, style: t.titleLarge),
        const SizedBox(height: Tokens.space8),
        if (itinerary.summary.isNotEmpty)
          Text(itinerary.summary,
              style: t.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              )),
        const SizedBox(height: Tokens.space12),
        Row(
          children: [
            if (itinerary.totalDistanceKmEstimate != null)
              _StatChip(
                icon: Icons.straighten,
                label: '${itinerary.totalDistanceKmEstimate!.round()} km',
              ),
            if (itinerary.estimatedBudgetEur != null) ...[
              const SizedBox(width: Tokens.space8),
              _StatChip(
                icon: Icons.euro,
                label:
                    '~${itinerary.estimatedBudgetEur!.round()} €',
              ),
            ],
          ],
        ),
        const SizedBox(height: Tokens.space16),
        for (final d in itinerary.days) _DayCard(day: d),
        const SizedBox(height: Tokens.space16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onConvert,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l.inspireConvertToPlan),
              ),
            ),
            const SizedBox(width: Tokens.space8),
            OutlinedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l.inspireSave),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: Tokens.motionBase);
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});
  final InspireDay day;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space12),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primary,
                  child: Text('${day.day}',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: Text(
                    '${day.fromName} → ${day.toName}',
                    style: t.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space8),
            Row(
              children: [
                if (day.distanceKmEstimate != null)
                  Padding(
                    padding: const EdgeInsets.only(right: Tokens.space12),
                    child: _MetaLabel(
                      icon: Icons.straighten,
                      label: '${day.distanceKmEstimate!.round()} km',
                    ),
                  ),
                if (day.drivingHoursEstimate != null)
                  _MetaLabel(
                    icon: Icons.access_time,
                    label:
                        '${day.drivingHoursEstimate!.toStringAsFixed(1)} h',
                  ),
              ],
            ),
            if (day.highlights.isNotEmpty) ...[
              const SizedBox(height: Tokens.space8),
              Text(day.highlights, style: t.bodyMedium),
            ],
            if (day.waypoints.isNotEmpty) ...[
              const SizedBox(height: Tokens.space12),
              for (final w in day.waypoints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: t.bodyMedium,
                            children: [
                              TextSpan(
                                text: w.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (w.note.isNotEmpty)
                                TextSpan(text: ' — ${w.note}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (day.hotelArea != null && day.hotelArea!.isNotEmpty) ...[
              const SizedBox(height: Tokens.space8),
              _MetaLabel(
                icon: Icons.hotel_outlined,
                label: day.hotelArea!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 6,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            )),
      ],
    );
  }
}
