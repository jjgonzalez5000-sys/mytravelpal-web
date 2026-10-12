import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart' show LatLon;
import '../design/stop_category_style.dart';
import '../design/tokens.dart';
import '../domain/my_place.dart';
import '../domain/stop_suggestion.dart';
import '../l10n/app_localizations.dart';
import 'my_place_category.dart';
import 'osm_attribution.dart';
import 'stop_suggestions_sheet.dart'
    show SuggestionCard, showSuggestionDetail, suggestionKey;

/// Kinds present in [list], in the fixed display order.
List<MyPlaceCategory> kindsPresent(Iterable<StopSuggestion> list) {
  final present = {for (final s in list) s.placeCategory};
  return [
    for (final k in MyPlaceCategory.values)
      if (present.contains(k)) k,
  ];
}

Map<MyPlaceCategory, int> kindCounts(Iterable<StopSuggestion> list) {
  final out = <MyPlaceCategory, int>{};
  for (final s in list) {
    out[s.placeCategory] = (out[s.placeCategory] ?? 0) + 1;
  }
  return out;
}

/// [list] narrowed to the chosen [kinds]; no kinds chosen means everything.
List<StopSuggestion> filterByKinds(
  List<StopSuggestion> list,
  Set<MyPlaceCategory> kinds,
) =>
    kinds.isEmpty
        ? list
        : [
            for (final s in list)
              if (kinds.contains(s.placeCategory)) s,
          ];

/// At most [max] points of [points], evenly spread, both ends kept.
List<LatLng> thinPolyline(List<LatLon> points, {int max = 500}) {
  if (points.length <= max) {
    return [for (final p in points) LatLng(p.lat, p.lon)];
  }
  final step = (points.length - 1) / (max - 1);
  return [
    for (var i = 0; i < max; i++)
      LatLng(
        points[(i * step).round()].lat,
        points[(i * step).round()].lon,
      ),
  ];
}

class _IdeasModel extends ChangeNotifier {
  final Set<MyPlaceCategory> filters = {};
  String? selected;

  /// Added from the full-screen map, until the parent reports it.
  final Set<String> locallyAdded = {};
  bool showAllExtras = false;

  void toggle(MyPlaceCategory k) {
    filters.contains(k) ? filters.remove(k) : filters.add(k);
    notifyListeners();
  }

  void clearFilters() {
    filters.clear();
    notifyListeners();
  }

  void select(String? key) {
    selected = key;
    notifyListeners();
  }

  void markAdded(String key) {
    locallyAdded.add(key);
    notifyListeners();
  }

  void expandExtras() {
    showAllExtras = true;
    notifyListeners();
  }

  void refresh() {
    locallyAdded.clear();
    notifyListeners();
  }
}

/// AI stop ideas on a map with their type: filter chips with counts, a map
/// with the route and one pin per stop coloured by type, the selected stop
/// as a full card with its Add button, and the list underneath. Filtering is
/// done here on the list already fetched, so it costs no request.
class StopIdeasView extends StatefulWidget {
  const StopIdeasView({
    super.key,
    required this.suggestions,
    required this.geometry,
    required this.addedKeys,
    required this.onAdd,
    this.ai = true,
  });

  final List<StopSuggestion> suggestions;
  final List<LatLon> geometry;

  /// [suggestionKey] of the ones already on the route.
  final Set<String> addedKeys;
  final Future<bool> Function(StopSuggestion) onAdd;

  /// False when the model did not take part: nothing is marked as its pick.
  final bool ai;

  /// Replaces the network tiles; tests only.
  @visibleForTesting
  static TileProvider? debugTileProvider;

  @override
  State<StopIdeasView> createState() => _StopIdeasViewState();
}

class _StopIdeasViewState extends State<StopIdeasView> {
  static const _collapsedExtras = 5;

  final _model = _IdeasModel();
  final _mapKey = GlobalKey();

  @override
  void didUpdateWidget(StopIdeasView old) {
    super.didUpdateWidget(old);
    if (old.addedKeys != widget.addedKeys && _model.locallyAdded.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _model.refresh();
      });
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  bool _isAdded(StopSuggestion s) {
    final k = suggestionKey(s);
    return widget.addedKeys.contains(k) || _model.locallyAdded.contains(k);
  }

  Future<bool> _add(StopSuggestion s) async {
    final ok = await widget.onAdd(s);
    if (ok && mounted) _model.markAdded(suggestionKey(s));
    return ok;
  }

  void _openDetail(StopSuggestion s) {
    showSuggestionDetail(
      context,
      suggestion: s,
      geometry: widget.geometry,
      added: _isAdded(s),
      onAdd: _add,
    );
  }

  void _selectFromList(StopSuggestion s) {
    _model.select(suggestionKey(s));
    final ctx = _mapKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: Tokens.motionBase,
        curve: Tokens.curveOut,
        alignment: 0.05,
      );
    }
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _IdeasFullscreen(
          model: _model,
          suggestions: widget.suggestions,
          geometry: widget.geometry,
          ai: widget.ai,
          isAdded: _isAdded,
          onAdd: _add,
          onOpenDetail: _openDetail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final visible = filterByKinds(widget.suggestions, _model.filters);
        StopSuggestion? selected;
        for (final s in visible) {
          if (suggestionKey(s) == _model.selected) selected = s;
        }
        final picked = [for (final s in visible) if (s.picked) s];
        final extras = [for (final s in visible) if (!s.picked) s];
        final shownExtras = _model.showAllExtras
            ? extras
            : extras.take(_collapsedExtras).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KindChips(model: _model, suggestions: widget.suggestions),
            const SizedBox(height: Tokens.space8),
            KeyedSubtree(
              key: _mapKey,
              child: SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Tokens.radiusMd),
                  child: Stack(
                    children: [
                      _IdeasMap(
                        suggestions: visible,
                        geometry: widget.geometry,
                        selectedKey: selected == null
                            ? null
                            : suggestionKey(selected),
                        ai: widget.ai,
                        isAdded: _isAdded,
                        onSelect: _model.select,
                      ),
                      Positioned(
                        top: Tokens.space8,
                        right: Tokens.space8,
                        child: _MapButton(
                          icon: Icons.fullscreen,
                          tooltip: l.suggestMapFullscreen,
                          onPressed: _openFullscreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Tokens.space8),
            if (selected != null)
              SuggestionCard(
                suggestion: selected,
                added: _isAdded(selected),
                aiPick: widget.ai && selected.picked,
                onAdd: () => _add(selected!),
                onTap: () => _openDetail(selected!),
              ),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.space12),
                child: Text(
                  l.suggestNoneForFilter,
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            for (final s in picked)
              _IdeaRow(
                suggestion: s,
                selected: suggestionKey(s) == _model.selected,
                added: _isAdded(s),
                aiPick: widget.ai,
                onTap: () => _selectFromList(s),
                onAdd: () => _add(s),
              ),
            if (shownExtras.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: Tokens.space8,
                  bottom: Tokens.space4,
                ),
                child: Text(
                  l.suggestMoreNearby,
                  style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              for (final s in shownExtras)
                _IdeaRow(
                  suggestion: s,
                  selected: suggestionKey(s) == _model.selected,
                  added: _isAdded(s),
                  aiPick: false,
                  onTap: () => _selectFromList(s),
                  onAdd: () => _add(s),
                ),
              if (shownExtras.length < extras.length)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('ideas-show-more'),
                    onPressed: _model.expandExtras,
                    child: Text(
                      l.suggestShowMore(extras.length - shownExtras.length),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _KindChips extends StatelessWidget {
  const _KindChips({required this.model, required this.suggestions});

  final _IdeasModel model;
  final List<StopSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final counts = kindCounts(suggestions);
    final kinds = kindsPresent(suggestions);
    if (kinds.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            key: const ValueKey('ideas-chip-all'),
            label: Text(
              l.suggestFilterCount(l.suggestFilterAll, suggestions.length),
            ),
            selected: model.filters.isEmpty,
            onSelected: (_) => model.clearFilters(),
          ),
          for (final k in kinds) ...[
            const SizedBox(width: Tokens.space8),
            FilterChip(
              key: ValueKey('ideas-chip-${k.name}'),
              avatar: Icon(
                myPlaceCategoryIcon(k),
                size: 16,
                color: stopCategoryStyle(k).onSurface(brightness),
              ),
              label: Text(
                l.suggestFilterCount(myPlaceCategoryLabel(l, k), counts[k]!),
              ),
              selected: model.filters.contains(k),
              onSelected: (_) => model.toggle(k),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: scheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class _IdeasMap extends StatefulWidget {
  const _IdeasMap({
    required this.suggestions,
    required this.geometry,
    required this.selectedKey,
    required this.ai,
    required this.isAdded,
    required this.onSelect,
    this.fullInteraction = false,
  });

  final List<StopSuggestion> suggestions;
  final List<LatLon> geometry;
  final String? selectedKey;
  final bool ai;
  final bool Function(StopSuggestion) isAdded;
  final void Function(String?) onSelect;
  final bool fullInteraction;

  @override
  State<_IdeasMap> createState() => _IdeasMapState();
}

class _IdeasMapState extends State<_IdeasMap> {
  final _controller = MapController();
  bool _ready = false;
  late List<LatLng> _route = thinPolyline(widget.geometry);

  LatLng _at(StopSuggestion s) =>
      LatLng(s.coordinate.lat, s.coordinate.lon);

  List<LatLng> _anchors() => widget.suggestions.isNotEmpty
      ? [for (final s in widget.suggestions) _at(s)]
      : _route;

  CameraFit _fit() => CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          _anchors().length >= 2
              ? _anchors()
              : [..._anchors(), ..._route.take(1)],
        ),
        padding: const EdgeInsets.all(36),
        maxZoom: 13,
      );

  @override
  void didUpdateWidget(_IdeasMap old) {
    super.didUpdateWidget(old);
    if (!identical(old.geometry, widget.geometry)) {
      _route = thinPolyline(widget.geometry);
    }
    if (!_ready) return;
    final oldKeys = {for (final s in old.suggestions) suggestionKey(s)};
    final newKeys = {for (final s in widget.suggestions) suggestionKey(s)};
    if (oldKeys.length != newKeys.length || !oldKeys.containsAll(newKeys)) {
      if (widget.suggestions.isNotEmpty) _controller.fitCamera(_fit());
      return;
    }
    if (old.selectedKey != widget.selectedKey && widget.selectedKey != null) {
      for (final s in widget.suggestions) {
        if (suggestionKey(s) == widget.selectedKey) {
          _controller.move(_at(s), _controller.camera.zoom);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Marker _pin(StopSuggestion s, ColorScheme scheme) {
    final key = suggestionKey(s);
    final selected = key == widget.selectedKey;
    final style = stopCategoryStyle(s.placeCategory);
    final added = widget.isAdded(s);
    return Marker(
      key: ValueKey('ideas-pin-$key'),
      point: _at(s),
      width: 48,
      height: 48,
      child: Semantics(
        button: true,
        label: s.name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelect(key),
          child: AnimatedScale(
            scale: selected ? 1.3 : 1,
            duration: Tokens.motionFast,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: style.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(style.icon, color: Colors.white, size: 18),
                  ),
                ),
                if (added)
                  const Positioned(
                    right: 4,
                    bottom: 4,
                    child: _PinBadge(icon: Icons.check, color: Color(0xFF2E7D32)),
                  )
                else if (widget.ai && s.picked)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: _PinBadge(
                      icon: Icons.auto_awesome,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Marker _endpoint(LatLon p, String label, Color color) => Marker(
        point: LatLng(p.lat, p.lon),
        width: 24,
        height: 24,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The selected pin goes last so it is drawn above its neighbours.
    final ordered = [
      for (final s in widget.suggestions)
        if (suggestionKey(s) != widget.selectedKey) s,
      for (final s in widget.suggestions)
        if (suggestionKey(s) == widget.selectedKey) s,
    ];
    return FlutterMap(
      key: const ValueKey('ideas-map'),
      mapController: _controller,
      options: MapOptions(
        initialCameraFit: _fit(),
        onMapReady: () => _ready = true,
        interactionOptions: InteractionOptions(
          flags: widget.fullInteraction
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
        onTap: (_, __) => widget.onSelect(null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mytravelpal.app',
          maxZoom: 19,
          tileProvider: StopIdeasView.debugTileProvider,
        ),
        if (_route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _route,
                strokeWidth: 4,
                color: scheme.primary,
                borderStrokeWidth: 1.5,
                borderColor: Colors.white,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.geometry.length >= 2) ...[
              _endpoint(widget.geometry.first, 'A', scheme.primary),
              _endpoint(widget.geometry.last, 'B', scheme.primary),
            ],
            for (final s in ordered) _pin(s, scheme),
          ],
        ),
        const OsmAttribution(),
      ],
    );
  }
}

class _PinBadge extends StatelessWidget {
  const _PinBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: SizedBox(
        width: 16,
        height: 16,
        child: Icon(icon, color: Colors.white, size: 10),
      ),
    );
  }
}

class _IdeaRow extends StatelessWidget {
  const _IdeaRow({
    required this.suggestion,
    required this.selected,
    required this.added,
    required this.aiPick,
    required this.onTap,
    required this.onAdd,
  });

  final StopSuggestion suggestion;
  final bool selected;
  final bool added;
  final bool aiPick;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final s = suggestion;
    final style = stopCategoryStyle(s.placeCategory);
    final tint = style.onSurface(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space4),
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        child: InkWell(
          key: ValueKey('ideas-row-${suggestionKey(s)}'),
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space8,
              vertical: Tokens.space8,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: style.color,
                  foregroundColor: Colors.white,
                  child: Icon(style.icon, size: 16),
                ),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          if (aiPick && s.picked) ...[
                            Icon(Icons.auto_awesome,
                                size: 12, color: scheme.primary),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              '${myPlaceCategoryLabel(l, s.placeCategory)}'
                              ' · ${l.suggestMinutes(s.totalMinutes)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelSmall?.copyWith(color: tint),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                added
                    ? Padding(
                        padding: const EdgeInsets.all(Tokens.space8),
                        child: Icon(Icons.check_circle,
                            color: scheme.primary, semanticLabel: l.suggestAdded),
                      )
                    : IconButton(
                        key: ValueKey('ideas-add-${suggestionKey(s)}'),
                        tooltip: l.suggestAdd,
                        icon: Icon(Icons.add_circle_outline,
                            color: scheme.primary),
                        onPressed: onAdd,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdeasFullscreen extends StatelessWidget {
  const _IdeasFullscreen({
    required this.model,
    required this.suggestions,
    required this.geometry,
    required this.ai,
    required this.isAdded,
    required this.onAdd,
    required this.onOpenDetail,
  });

  final _IdeasModel model;
  final List<StopSuggestion> suggestions;
  final List<LatLon> geometry;
  final bool ai;
  final bool Function(StopSuggestion) isAdded;
  final Future<bool> Function(StopSuggestion) onAdd;
  final void Function(StopSuggestion) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.suggestMapClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l.suggestEntryTitle),
      ),
      body: ListenableBuilder(
        listenable: model,
        builder: (context, _) {
          final visible = filterByKinds(suggestions, model.filters);
          StopSuggestion? selected;
          for (final s in visible) {
            if (suggestionKey(s) == model.selected) selected = s;
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.space12, Tokens.space8, Tokens.space12, Tokens.space8,
                ),
                child: _KindChips(model: model, suggestions: suggestions),
              ),
              Expanded(
                child: Stack(
                  children: [
                    _IdeasMap(
                      suggestions: visible,
                      geometry: geometry,
                      selectedKey:
                          selected == null ? null : suggestionKey(selected),
                      ai: ai,
                      isAdded: isAdded,
                      onSelect: model.select,
                      fullInteraction: true,
                    ),
                    if (selected != null)
                      Positioned(
                        left: Tokens.space12,
                        right: Tokens.space12,
                        bottom: Tokens.space12,
                        child: SafeArea(
                          top: false,
                          child: SuggestionCard(
                            suggestion: selected,
                            added: isAdded(selected),
                            aiPick: ai && selected.picked,
                            onAdd: () => onAdd(selected!),
                            onTap: () => onOpenDetail(selected!),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
