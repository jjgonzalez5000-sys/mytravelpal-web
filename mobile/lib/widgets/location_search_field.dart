import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'poi_icons.dart';
import 'save_place_dialog.dart';

typedef GeocodeFn = Future<List<GeocodeResult>> Function(String query);

/// City + POI search field with paste support (rewritten in Sprint 19).
///
/// Uses a plain [TextField] + an [OverlayPortal] for the suggestions
/// panel. The previous [SearchAnchor]-based implementation:
///
/// - showed a read-only placeholder in the closed state, so users could
///   not right-click / long-press to paste;
/// - opened a fullscreen search view whose internal `SearchBar` context
///   menu was inconsistent across Chrome vs. mobile.
///
/// This version:
///
/// - keeps a real editable [TextField] visible → paste works everywhere;
/// - shows suggestions in an overlay under the field, following its
///   position with [CompositedTransformFollower];
/// - surfaces saved [FavoritePlace]s + recent picks + "Use my location"
///   in the idle state;
/// - lets the user save any result as a labeled place (Home/Work/…) via
///   the star icon on each tile.
class LocationSearchField extends ConsumerStatefulWidget {
  const LocationSearchField({
    super.key,
    required this.label,
    required this.geocode,
    required this.onSelected,
    this.initial,
    this.onUseCurrentLocation,
  });

  final String label;
  final GeocodeFn geocode;
  final ValueChanged<GeocodeResult?> onSelected;
  final GeocodeResult? initial;

  /// Callback resolving the device location. When null, hides the
  /// "Use my location" affordance. Wire only on the origin field.
  final Future<GeocodeResult?> Function()? onUseCurrentLocation;

  @override
  ConsumerState<LocationSearchField> createState() =>
      _LocationSearchFieldState();
}

class _LocationSearchFieldState extends ConsumerState<LocationSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _link = LayerLink();
  final _overlayController = OverlayPortalController();
  Timer? _debounce;

  List<GeocodeResult> _results = const [];
  bool _loading = false;
  bool _resolvingLocation = false;
  GeocodeResult? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    if (widget.initial != null) {
      _controller.text = widget.initial!.displayName;
    }
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant LocationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent handed us a new prefill (e.g. "Recent trips" dropdown). The
    // TextEditingController is owned by this state, so a change on
    // widget.initial after mount is otherwise invisible.
    if (widget.initial != oldWidget.initial) {
      _picked = widget.initial;
      final newText = widget.initial?.displayName ?? '';
      if (_controller.text != newText) {
        _controller.text = newText;
        _controller.selection =
            TextSelection.collapsed(offset: newText.length);
      }
      // Clear any stale search state and dismiss the suggestions panel so
      // the user sees a clean, prefilled field.
      _debounce?.cancel();
      _results = const [];
      _loading = false;
      if (_overlayController.isShowing) _overlayController.hide();
      if (_focusNode.hasFocus) _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _overlayController.show();
    } else {
      // Delay hide so tap on a suggestion still fires.
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!_focusNode.hasFocus && mounted) _overlayController.hide();
      });
    }
  }

  void _onTextChanged() {
    // Any manual edit clears the picked state; the caller learns via
    // onSelected(null) so it can gate the "Plan trip" CTA.
    if (_picked != null && _controller.text != _picked!.displayName) {
      _picked = null;
      widget.onSelected(null);
    }
    // A result is already locked in — don't re-search.
    if (_picked != null) return;
    final query = _controller.text.trim();
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _loading = true);
      try {
        final res = await widget.geocode(query);
        if (!mounted) return;
        setState(() {
          _results = res;
          _loading = false;
        });
      } on ApiException {
        if (mounted) {
          setState(() {
            _results = const [];
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _results = const [];
            _loading = false;
          });
        }
      }
    });
  }

  void _accept(GeocodeResult r) {
    setState(() {
      _picked = r;
      _results = const [];
    });
    _controller.text = r.displayName;
    _controller.selection = TextSelection.collapsed(offset: r.displayName.length);
    widget.onSelected(r);
    _focusNode.unfocus();
    _overlayController.hide();
  }

  void _clear() {
    setState(() {
      _picked = null;
      _controller.text = '';
      _results = const [];
    });
    widget.onSelected(null);
    _focusNode.requestFocus();
  }

  Future<void> _useCurrentLocation() async {
    final onUse = widget.onUseCurrentLocation;
    if (onUse == null || _resolvingLocation) return;
    setState(() => _resolvingLocation = true);
    try {
      final r = await onUse();
      if (!mounted) return;
      if (r != null) _accept(r);
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  Future<void> _saveAsPlace(GeocodeResult r) async {
    final label = await showSavePlaceDialog(context, suggested: r.displayName);
    if (label == null || !mounted) return;
    await ref.read(favoritePlacesProvider.notifier).upsert(label: label, place: r);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        AppLocalizations.of(context).placeSavedAs(label),
      )),
    );
  }

  IconData _iconFor(GeocodeResult r) =>
      iconForPoi(r.poiClass, r.poiType, r.displayName);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: _buildOverlay,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: l.searchPlaceholder,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l.commonClear,
                    onPressed: _clear,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      width: (context.findRenderObject() as RenderBox?)?.size.width,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        offset: Offset(0, _measuredHeight() + 4),
        targetAnchor: Alignment.bottomLeft,
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: scheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: SizedBox(
                width: _measuredWidth(),
                child: _buildSuggestions(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _measuredHeight() {
    final rb = context.findRenderObject() as RenderBox?;
    return rb?.size.height ?? 56;
  }

  double? _measuredWidth() {
    final rb = context.findRenderObject() as RenderBox?;
    return rb?.size.width;
  }

  Widget _buildSuggestions() {
    final l = AppLocalizations.of(context);
    final query = _controller.text.trim();

    // Idle state — recent picks + saved places + optional current-location.
    if (query.length < 2) {
      return _buildIdle(l);
    }

    // Typing state.
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (!_loading && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.searchNoMatches),
          ),
        ..._results.map(_buildResultTile),
      ],
    );
  }

  Widget _buildIdle(AppLocalizations l) {
    final places = ref.watch(favoritePlacesProvider);
    final recent = ref.watch(recentSearchesProvider);
    final children = <Widget>[];

    if (widget.onUseCurrentLocation != null) {
      children.add(
        ListTile(
          leading: _resolvingLocation
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          title: Text(l.searchUseMyLocation),
          onTap: _useCurrentLocation,
        ),
      );
    }

    if (places.isNotEmpty) {
      children.add(_sectionHeader(l.placesSectionTitle));
      children.addAll(
        places.map((p) => ListTile(
              leading: Icon(iconForPlaceLabel(p.label)),
              title: Text(p.label),
              subtitle: Text(
                p.place.displayName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _accept(p.place),
            )),
      );
    }

    if (recent.isNotEmpty) {
      children.add(_sectionHeader(l.searchRecent));
      children.addAll(recent.map(_buildResultTile));
    }

    if (children.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l.searchStartTyping),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: children,
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );

  Widget _buildResultTile(GeocodeResult r) => ListTile(
        leading: Icon(_iconFor(r)),
        title: Text(
          r.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(r.country.displayName),
        trailing: IconButton(
          icon: const Icon(Icons.star_border, size: 20),
          tooltip: AppLocalizations.of(context).placeSaveAsTooltip,
          onPressed: () => _saveAsPlace(r),
        ),
        onTap: () => _accept(r),
      );
}

/// Icon for a saved-place label. Simple keyword match — falls back to a
/// pin. Kept as a top-level helper so [FavoritesScreen] can reuse it.
IconData iconForPlaceLabel(String label) {
  final l = label.toLowerCase();
  if (RegExp(r'\b(home|casa|maison|zuhause|hogar)\b').hasMatch(l)) {
    return Icons.home_outlined;
  }
  if (RegExp(r'\b(work|trabajo|travail|arbeit|lavoro|office|oficina|ufficio)\b')
      .hasMatch(l)) {
    return Icons.work_outline;
  }
  if (RegExp(r'\b(school|colegio|escuela|école|ecole|scuola|schule)\b')
      .hasMatch(l)) {
    return Icons.school_outlined;
  }
  if (RegExp(r'\b(gym|gimnasio|palestra|fitness)\b').hasMatch(l)) {
    return Icons.fitness_center;
  }
  if (RegExp(r'\b(family|familia|famille|famiglia|familie)\b').hasMatch(l)) {
    return Icons.family_restroom;
  }
  return Icons.bookmark_border;
}
