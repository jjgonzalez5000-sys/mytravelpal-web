import 'dart:async';

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
  final _refineController = TextEditingController();
  bool _loading = false;
  bool _refining = false;
  bool _converting = false;
  String? _error;
  InspireItinerary? _result;
  /// Conversation persisted alongside the itinerary. Each
  /// generate/refine turn appends here so the LLM's next call
  /// has full context.
  final List<InspireChatTurn> _chat = [];

  @override
  void dispose() {
    _controller.dispose();
    _refineController.dispose();
    super.dispose();
  }

  Future<void> _refine() async {
    final prompt = _refineController.text.trim();
    final prev = _result;
    if (prompt.isEmpty || prev == null) return;
    setState(() {
      _refining = true;
      _error = null;
      _chat.add(InspireChatTurn(role: 'user', content: prompt));
    });
    _refineController.clear();
    try {
      final api = ref.read(apiClientWithPremiumProvider);
      final locale = Localizations.localeOf(context).languageCode;
      final updated = await api.refineTrip(
        prompt: prompt,
        previous: prev,
        history: List.of(_chat),
        locale: locale,
      );
      if (!mounted) return;
      setState(() {
        _result = updated;
        if (updated.assistantNote != null &&
            updated.assistantNote!.isNotEmpty) {
          _chat.add(InspireChatTurn(
            role: 'assistant', content: updated.assistantNote!,
          ));
        }
      });
      unawaited(_autoSaveInspiration(updated, _controller.text.trim()));
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = AppLocalizations.of(context).inspireError);
    } finally {
      if (mounted) setState(() => _refining = false);
    }
  }

  Future<void> _generate() async {
    final prompt = _controller.text.trim();
    if (prompt.length < 8) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      // Fresh conversation whenever the user regenerates from
      // the initial prompt. Refinements append; regens reset.
      _chat.clear();
      _chat.add(InspireChatTurn(role: 'user', content: prompt));
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
      // Auto-save every generation. Cheaper than losing an
      // itinerary the driver liked but didn't tap "save" for.
      // Dedup by prompt inside InspirationStorage prevents
      // duplicates from same-prompt regenerations.
      unawaited(_autoSaveInspiration(itinerary, prompt));
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

  /// Compute a departure DateTime from a days-from-today offset.
  /// Used only when the response carries no ISO date (older
  /// backend build) or when the ISO is invalid.
  DateTime _fallbackDeparture(int daysOffset, int hour) {
    final target = DateTime.now().add(Duration(days: daysOffset));
    return DateTime(target.year, target.month, target.day, hour);
  }

  Future<void> _autoSaveInspiration(
    InspireItinerary it, String prompt,
  ) async {
    try {
      final storage = ref.read(inspirationStorageProvider);
      await storage.save(SavedInspiration(
        id: 'insp_${DateTime.now().millisecondsSinceEpoch}',
        prompt: prompt,
        itinerary: it,
        savedAt: DateTime.now(),
        locale: Localizations.localeOf(context).languageCode,
      ));
    } catch (_) {
      // Auto-save is best-effort — a persistence failure must
      // not break the generation UX. User can still tap the
      // manual save button on the result screen.
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

  Future<void> _convertToPlan() async {
    final it = _result;
    if (it == null || it.days.isEmpty || _converting) return;
    setState(() => _converting = true);
    final first = it.days.first;
    final last = it.days.last;
    // Origin = first day's from_name; destination = last day's
    // to_name; every other to_name becomes an intermediate
    // waypoint. For each city we try three sources in order:
    //   1) LLM waypoint whose name substring-matches the city
    //   2) Backend geocode of the city name (authoritative)
    //   3) Skip (previously silently fell back to the first
    //      day.waypoints entry — that produced the "destination
    //      says Monza but map shows Rome" bug when the LLM
    //      threw sightseeing POIs from another city into the
    //      day's waypoint list).
    GeocodeResult? originResult;
    GeocodeResult? destResult;
    final stops = <PlannedStop>[];
    final api = ref.read(apiClientWithPremiumProvider);

    LatLon? matchInDay(String cityName, InspireDay day) {
      final needle = cityName.toLowerCase().trim();
      if (needle.isEmpty) return null;
      for (final w in day.waypoints) {
        final hay = w.name.toLowerCase();
        // Require BOTH substrings only when neither name is
        // a real subset of the other — avoids catching "Roma"
        // when the target is "Monza".
        if (hay.contains(needle) || needle.contains(hay)) {
          return LatLon(lat: w.lat, lon: w.lon);
        }
      }
      return null;
    }

    Future<LatLon?> resolveCoord(
      String cityName, InspireDay day,
    ) async {
      final direct = matchInDay(cityName, day);
      if (direct != null) return direct;
      // Fallback: geocode via backend. Cheap, cached upstream,
      // avoids the "waypoints.first" trap that silently rewrote
      // Monza -> Roma when the LLM stuffed extra POIs into the
      // day list.
      try {
        final results = await api.geocode(cityName.trim());
        if (results.isNotEmpty) return results.first.coordinate;
      } catch (_) {
        // Network / backend hiccup — skip this stop rather than
        // guess a coord.
      }
      return null;
    }

    final originCoord = await resolveCoord(first.fromName, first);
    if (originCoord != null) {
      originResult = GeocodeResult(
        displayName: first.fromName,
        coordinate: originCoord,
        country: Country.fr,
      );
    }
    // Count how many days end in each city → that becomes the
    // dwell_nights for that waypoint. Example: for a "Milan → Como
    // (2 nights) → Bergamo → Milan" itinerary the LLM emits, Como
    // ends day 1 AND day 2 as to_name → dwell_nights = 2. Bergamo
    // ends day 3 → dwell_nights = 1.
    final overnightCount = <String, int>{};
    for (var i = 0; i < it.days.length - 1; i++) {
      final key = it.days[i].toName.trim().toLowerCase();
      overnightCount[key] = (overnightCount[key] ?? 0) + 1;
    }
    // Emit intermediate stops in first-occurrence order so the
    // resulting waypoint list matches the LLM's day ordering. A
    // city that appears twice as to_name (multi-night stay) shows
    // up ONCE as a waypoint with the aggregated dwell.
    final emittedStopKeys = <String>{};
    for (var i = 0; i < it.days.length - 1; i++) {
      final d = it.days[i];
      final key = d.toName.trim().toLowerCase();
      if (emittedStopKeys.contains(key)) continue;
      final coord = await resolveCoord(d.toName, d);
      if (coord == null) continue;
      emittedStopKeys.add(key);
      final nights = overnightCount[key] ?? 1;
      stops.add(PlannedStop(
        place: GeocodeResult(
          displayName: d.toName,
          coordinate: coord,
          country: Country.fr,
        ),
        dwellNights: nights,
      ));
    }
    final destCoord = await resolveCoord(last.toName, last);
    if (destCoord != null) {
      destResult = GeocodeResult(
        displayName: last.toName,
        coordinate: destCoord,
        country: Country.fr,
      );
    }

    // Also emit "significant" per-day waypoints as pass-through
    // stops so items the user asked the AI to add (a restaurant
    // near Como, a specific viewpoint, a museum) actually reach
    // the real router instead of only living in the itinerary
    // preview. Cap total stops at 8 (backend limit — origin +
    // 8 waypoints + destination = 10, OSRM's soft cap).
    const significantKinds = {
      'restaurant', 'landmark', 'museum', 'viewpoint',
      'nature', 'beach', 'village',
    };
    const maxTotalStops = 8;
    final knownStopKeys = <String>{
      for (final s in stops) s.place.displayName.trim().toLowerCase(),
    };
    for (final d in it.days) {
      if (stops.length >= maxTotalStops) break;
      for (final w in d.waypoints) {
        if (stops.length >= maxTotalStops) break;
        if (!significantKinds.contains(w.kind.toLowerCase())) continue;
        final key = w.name.trim().toLowerCase();
        if (key.isEmpty || knownStopKeys.contains(key)) continue;
        knownStopKeys.add(key);
        stops.add(PlannedStop(
          place: GeocodeResult(
            displayName: w.name,
            coordinate: LatLon(lat: w.lat, lon: w.lon),
            country: Country.fr,
          ),
          dwellNights: 0,   // pass-through: visit + continue
        ));
      }
    }

    if (!mounted) {
      setState(() => _converting = false);
      return;
    }
    if (originResult == null || destResult == null) {
      // Nothing usable — fall back to just closing and letting the
      // user type manually. Rare (LLM would need to omit all
      // coords) but we shouldn't crash.
      setState(() => _converting = false);
      Navigator.of(context).pop();
      return;
    }

    // Hand-off via SharedTrip so the existing plan-screen entry
    // path already knows how to pre-fill everything. Waypoints are
    // set via a small side channel — the PlanScreen already
    // supports intermediate stops.
    // Prefer the ISO date directly — the LLM was historically
    // off-by-one on weekday arithmetic when we asked for an
    // offset instead. Falls back to the offset field (older
    // backends) and finally to "tomorrow 08:00".
    final hour = it.suggestedDepartureHour ?? 8;
    late DateTime departure;
    final iso = it.suggestedDepartureIso;
    if (iso != null) {
      try {
        final d = DateTime.parse(iso);
        departure = DateTime(d.year, d.month, d.day, hour);
      } catch (_) {
        departure = _fallbackDeparture(
          it.suggestedDepartureDaysFromNow ?? 1, hour,
        );
      }
    } else {
      departure = _fallbackDeparture(
        it.suggestedDepartureDaysFromNow ?? 1, hour,
      );
    }
    // _converting stays true — the route replacement makes this
    // widget unmount so setState after would no-op anyway.
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
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_loading
                    ? l.inspireGenerating
                    : l.inspireGenerate),
              ),
              if (_loading) ...[
                const SizedBox(height: Tokens.space12),
                const LinearProgressIndicator(),
                const SizedBox(height: Tokens.space8),
                Text(
                  l.planLoadingHelper,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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
              if (_result == null) ...[
                // Recent inspirations (auto-saved on each generate).
                // Tapping one restores the itinerary immediately —
                // no re-call to Anthropic → free.
                Consumer(builder: (context, ref, _) {
                  final storage = ref.read(inspirationStorageProvider);
                  final recent = storage.list().take(3).toList();
                  if (recent.isEmpty) return const SizedBox.shrink();
                  final l = AppLocalizations.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.inspireRecentTitle,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: Tokens.space8),
                      for (final e in recent)
                        Card(
                          margin: const EdgeInsets.only(bottom: Tokens.space8),
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(
                              e.prompt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${e.itinerary.days.length} ${l.inspireDayLabel(e.itinerary.days.length)}',
                            ),
                            onTap: () {
                              _controller.text = e.prompt;
                              setState(() => _result = e.itinerary);
                            },
                          ),
                        ),
                      const SizedBox(height: Tokens.space16),
                    ],
                  );
                }),
                _ExamplesBlock(
                  onPick: (text) {
                    _controller.text = text;
                    _generate();
                  },
                ),
              ],
              if (_result != null) ...[
                _ResultBlock(
                  itinerary: _result!,
                  onConvert: _converting ? null : _convertToPlan,
                  converting: _converting,
                  onSave: _saveInspiration,
                ),
                const SizedBox(height: Tokens.space20),
                _ChatConversation(chat: _chat),
                const SizedBox(height: Tokens.space8),
                _RefineComposer(
                  controller: _refineController,
                  busy: _refining,
                  onSend: _refine,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Conversation trail of user/assistant bubbles. Rendered only
/// once the refinement chat has at least one assistant reply —
/// keeps the initial-generation view clean.
class _ChatConversation extends StatelessWidget {
  const _ChatConversation({required this.chat});
  final List<InspireChatTurn> chat;

  @override
  Widget build(BuildContext context) {
    // Skip when only the seed user message is present (no
    // assistant turn yet → don't render a lonely bubble).
    final assistantTurns =
        chat.where((m) => m.role == 'assistant').length;
    if (assistantTurns == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.inspireChatTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: Tokens.space8),
        for (final m in chat.skip(1)) // drop the initial prompt
          Align(
            alignment: m.role == 'user'
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8,
              ),
              constraints:
                  const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: m.role == 'user'
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(m.role == 'user' ? 14 : 4),
                  bottomRight: Radius.circular(m.role == 'user' ? 4 : 14),
                ),
              ),
              child: Text(
                m.content,
                style: TextStyle(
                  color: m.role == 'user'
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Composer row: text input + send button for refinement turns.
class _RefineComposer extends StatelessWidget {
  const _RefineComposer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !busy,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              hintText: l.inspireChatHint,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12,
              ),
            ),
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: busy ? null : onSend,
          style: FilledButton.styleFrom(
            minimumSize: const Size(52, 52),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: busy
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimary,
                  ),
                )
              : const Icon(Icons.send),
        ),
      ],
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
    required this.onSave,
    this.onConvert,
    this.converting = false,
  });
  final InspireItinerary itinerary;
  final VoidCallback? onConvert;
  final VoidCallback onSave;
  final bool converting;

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
                onPressed: converting ? null : onConvert,
                icon: converting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded),
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
