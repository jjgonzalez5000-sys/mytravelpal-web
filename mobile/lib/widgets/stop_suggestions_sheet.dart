import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart' show ApiException;
import '../api/models.dart' show DayPlan, LatLon;
import '../design/stop_category_style.dart';
import '../design/tokens.dart';
import '../domain/my_place.dart';
import '../domain/stop_suggestion.dart';
import '../domain/trip_profile.dart' show TripProfile;
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/route_slice.dart';
import 'my_place_category.dart';
import 'poi_detail_sheet.dart' show PoiKind, showPoiDetailSheet;
import 'stop_ideas_view.dart' show StopIdeasView;

/// Opens the AI stop-suggestions sheet. [onAdd] adds a suggestion to the
/// route and reports whether it was added.
Future<void> showStopSuggestionsSheet(
  BuildContext context, {
  required List<LatLon> geometry,
  required double routeKm,
  required List<DayPlan> days,
  required TripProfile? profile,
  required Set<String> addedKeys,
  required Future<bool> Function(StopSuggestion) onAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, controller) => StopSuggestionsSheet(
        scrollController: controller,
        geometry: geometry,
        routeKm: routeKm,
        days: days,
        profile: profile,
        addedKeys: addedKeys,
        onAdd: onAdd,
      ),
    ),
  );
}

/// Stable identity of a suggestion across searches (its `c1..cN` id is
/// only unique within one answer).
String suggestionKey(StopSuggestion s) => placeKey(s.name, s.coordinate);

/// Same identity for a saved place, so "already added" matches both.
String placeKey(String name, LatLon c) =>
    '${name.toLowerCase()}|${c.lat.toStringAsFixed(3)},'
    '${c.lon.toStringAsFixed(3)}';

class StopSuggestionsSheet extends ConsumerStatefulWidget {
  const StopSuggestionsSheet({
    super.key,
    required this.scrollController,
    required this.geometry,
    required this.routeKm,
    required this.days,
    required this.profile,
    required this.addedKeys,
    required this.onAdd,
  });

  final ScrollController scrollController;
  final List<LatLon> geometry;
  final double routeKm;
  final List<DayPlan> days;
  final TripProfile? profile;
  final Set<String> addedKeys;
  final Future<bool> Function(StopSuggestion) onAdd;

  @override
  ConsumerState<StopSuggestionsSheet> createState() =>
      _StopSuggestionsSheetState();
}

class _StopSuggestionsSheetState extends ConsumerState<StopSuggestionsSheet> {
  static const _timeChoices = [30, 60, 90, 120, 180];
  static const _interestChoices = [
    MyPlaceCategory.food,
    MyPlaceCategory.viewpoint,
    MyPlaceCategory.culture,
    MyPlaceCategory.history,
    MyPlaceCategory.nature,
    MyPlaceCategory.beach,
    MyPlaceCategory.kids,
    MyPlaceCategory.shopping,
  ];

  /// Index into the driving days, or null for the whole trip.
  int? _dayIndex;
  int _freeMinutes = 90;
  final Set<MyPlaceCategory> _interests = {};
  bool _loading = false;
  String? _error;
  StopSuggestionsResult? _result;
  late final Set<String> _added = {...widget.addedKeys};
  final Set<String> _adding = {};

  List<DayPlan> get _drivingDays =>
      widget.days.where((d) => !d.isDwellDay).toList(growable: false);

  Future<void> _search() async {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final days = _drivingDays;
    final day = _dayIndex == null ? null : days[_dayIndex!];
    final stretch = sliceRoute(
      widget.geometry,
      widget.routeKm,
      fromKm: day?.fromKm ?? 0,
      toKm: day?.toKm ?? widget.routeKm,
    );
    if (stretch.length < 2) {
      setState(() => _error = l.suggestNoPlaces);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientWithPremiumProvider).suggestStops(
            route: stretch,
            freeMinutes: _freeMinutes,
            interests: [for (final i in _interests) i.name],
            travellers: widget.profile?.travellers ?? 1,
            hasKids: widget.profile?.hasKids ?? false,
            hasPets: widget.profile?.hasPets ?? false,
            limit: 10,
            extras: 25,
            locale: locale,
          );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _error = e is ApiException && e.statusCode == 429
            ? l.suggestQuota
            : l.suggestError;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(StopSuggestion s) async {
    final key = suggestionKey(s);
    if (_added.contains(key) || !_adding.add(key)) return;
    final added = await widget.onAdd(s);
    _adding.remove(key);
    if (!mounted) return;
    if (added) setState(() => _added.add(key));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final days = _drivingDays;
    final result = _result;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(
        Tokens.space20, 0, Tokens.space20, Tokens.space24,
      ),
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 20, color: scheme.primary),
            const SizedBox(width: Tokens.space8),
            Expanded(
              child: Text(
                l.suggestSheetTitle,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space12),
        if (days.length > 1) ...[
          Wrap(
            spacing: Tokens.space8,
            children: [
              ChoiceChip(
                label: Text(l.suggestWholeTrip),
                selected: _dayIndex == null,
                onSelected: (_) => setState(() => _dayIndex = null),
              ),
              for (var i = 0; i < days.length; i++)
                ChoiceChip(
                  label: Text(l.suggestDay(days[i].dayIndex)),
                  selected: _dayIndex == i,
                  onSelected: (_) => setState(() => _dayIndex = i),
                ),
            ],
          ),
          const SizedBox(height: Tokens.space12),
        ],
        Text(l.suggestFreeTime, style: t.labelLarge),
        const SizedBox(height: Tokens.space4),
        Wrap(
          spacing: Tokens.space8,
          children: [
            for (final m in _timeChoices)
              ChoiceChip(
                label: Text(l.suggestMinutes(m)),
                selected: _freeMinutes == m,
                onSelected: (_) => setState(() => _freeMinutes = m),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space12),
        Text(l.suggestInterests, style: t.labelLarge),
        const SizedBox(height: Tokens.space4),
        Wrap(
          spacing: Tokens.space8,
          children: [
            for (final c in _interestChoices)
              FilterChip(
                avatar: Icon(myPlaceCategoryIcon(c), size: 16),
                label: Text(myPlaceCategoryLabel(l, c)),
                selected: _interests.contains(c),
                onSelected: (on) => setState(() {
                  on ? _interests.add(c) : _interests.remove(c);
                }),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space16),
        FilledButton.icon(
          onPressed: _loading ? null : _search,
          icon: const Icon(Icons.search),
          label: Text(l.suggestFind),
        ),
        const SizedBox(height: Tokens.space16),
        if (_loading)
          Column(
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: Tokens.space8),
              Text(
                l.suggestSearching,
                style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          )
        else if (_error != null)
          Text(_error!, style: t.bodyMedium?.copyWith(color: scheme.error))
        else if (result != null) ...[
          if (result.suggestions.isEmpty)
            Text(
              l.suggestNoPlaces,
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else ...[
            if (!result.ai)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space8),
                child: Text(
                  l.suggestNoAiNote,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space8),
              child: Text(
                l.suggestUsed(result.usedMinutes, result.windowMinutes),
                style: t.labelMedium?.copyWith(color: scheme.primary),
              ),
            ),
            StopIdeasView(
              suggestions: result.suggestions,
              geometry: widget.geometry,
              addedKeys: _added,
              ai: result.ai,
              onAdd: (s) async {
                await _add(s);
                return _added.contains(suggestionKey(s));
              },
            ),
          ],
        ],
      ],
    );
  }
}

/// Maps link that lands on the named place (name searched near its
/// coordinate) instead of a bare pin that Maps snaps to a neighbouring one.
String suggestionMapsUrl(StopSuggestion s) {
  final name = s.name.replaceAll(RegExp(r'\s+'), ' ').trim();
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$name ${s.coordinate.lat},${s.coordinate.lon}',
  }).toString();
}

/// Opens the place's detail sheet: the route and the stop on a map, the
/// address, phone, website and opening hours the place lists, a Google Maps
/// link and, if it is not on the route yet, the add button.
Future<void> showSuggestionDetail(
  BuildContext context, {
  required StopSuggestion suggestion,
  required List<LatLon> geometry,
  required bool added,
  required Future<bool> Function(StopSuggestion) onAdd,
}) {
  final l = AppLocalizations.of(context);
  final s = suggestion;
  final where = l.suggestWhere(
    s.alongKm.round(), s.distanceFromRouteKm.toStringAsFixed(1),
  );
  final subtitle = [
    if (s.why.isNotEmpty) s.why,
    where,
    l.suggestCost(s.detourMinutes, s.visitMinutes),
  ].join('\n');
  return showPoiDetailSheet(
    context,
    kind: PoiKind.rest,
    name: s.name,
    subtitle: subtitle,
    poi: s.coordinate,
    origin: geometry.isNotEmpty ? geometry.first : s.coordinate,
    destination: geometry.isNotEmpty ? geometry.last : s.coordinate,
    routeGeometry: geometry,
    attributes: {
      if (!s.attributes.containsKey('google_maps_url'))
        'google_maps_url': suggestionMapsUrl(s),
      ...s.attributes,
    },
    icon: myPlaceCategoryIcon(s.placeCategory),
    accent: stopCategoryStyle(s.placeCategory).color,
    isAdded: added,
    // Add only: the detail's button would flip to "remove" and this does not
    // remove, so it closes once the stop is on the route.
    onAddToRoute: added
        ? null
        : () {
            onAdd(s);
            Navigator.of(context).pop();
          },
  );
}

class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    required this.suggestion,
    required this.added,
    required this.onAdd,
    this.onTap,
    this.aiPick = false,
  });

  final StopSuggestion suggestion;
  final bool added;
  final VoidCallback onAdd;

  /// Marks the card as chosen by the model (not just a place nearby).
  final bool aiPick;

  /// Tapping the card (anywhere but the button) opens the place's details.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final s = suggestion;
    final style = stopCategoryStyle(s.placeCategory);
    final tint = style.onSurface(Theme.of(context).brightness);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: Tokens.space8),
      padding: const EdgeInsets.all(Tokens.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: style.color,
            foregroundColor: Colors.white,
            child: Icon(style.icon, size: 18),
          ),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Tokens.space8,
                  children: [
                    Text(
                      myPlaceCategoryLabel(l, s.placeCategory),
                      style: t.labelSmall?.copyWith(
                        color: tint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (aiPick)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 12, color: scheme.primary),
                          const SizedBox(width: 3),
                          Text(
                            l.suggestAiPick,
                            style: t.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Text(
                  s.name,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (s.why.isNotEmpty) ...[
                  const SizedBox(height: Tokens.space4),
                  Text(s.why, style: t.bodySmall),
                ],
                const SizedBox(height: Tokens.space4),
                Text(
                  l.suggestCost(s.detourMinutes, s.visitMinutes),
                  style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  s.fitsWindow ? l.suggestFits : l.suggestTooLong,
                  style: t.labelSmall?.copyWith(
                    color: s.fitsWindow ? scheme.primary : scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: Tokens.space4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        l.suggestSeeDetails,
                        style: t.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 16, color: scheme.primary),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Tokens.space8),
          added
              ? FilledButton.tonalIcon(
                  onPressed: null,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(l.suggestAdded),
                )
              : OutlinedButton(
                  onPressed: onAdd,
                  child: Text(l.suggestAdd),
                ),
        ],
      ),
      ),
    );
  }
}
