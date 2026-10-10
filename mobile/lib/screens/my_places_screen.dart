import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart' show GeocodeResult, LatLon;
import '../design/tokens.dart';
import '../domain/my_place.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/my_places_match.dart' show parseCoordinates;
import '../widgets/my_place_category.dart';

/// The driver's saved stops: places worth pulling over for. A route that
/// passes near one offers it (see `MyPlacesOnRoute`).
class MyPlacesScreen extends ConsumerWidget {
  const MyPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final places = ref.watch(myPlacesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.myPlacesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l.myPlacesAdd),
      ),
      body: places.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_outlined,
                        size: 48, color: scheme.onSurfaceVariant),
                    const SizedBox(height: Tokens.space12),
                    Text(
                      l.myPlacesEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: places.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = places[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Icon(myPlaceCategoryIcon(p.category), size: 20),
                  ),
                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    p.note.isEmpty
                        ? myPlaceCategoryLabel(l, p.category)
                        : '${myPlaceCategoryLabel(l, p.category)} · ${p.note}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(context, ref, p),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, MyPlace p) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(myPlacesProvider.notifier);
    await notifier.remove(p.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.myPlacesRemoved(p.name)),
        action: SnackBarAction(
          label: l.myPlacesUndo,
          onPressed: () => notifier.add(p),
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showAddPlaceSheet(context);
  }
}

/// Search (or paste a map link for) a place, name it and save it to the
/// driver's places. Resolves to the saved place, or null when dismissed.
Future<MyPlace?> showAddPlaceSheet(BuildContext context) {
  return showModalBottomSheet<MyPlace>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AddPlaceSheet(),
  );
}

class _AddPlaceSheet extends ConsumerStatefulWidget {
  const _AddPlaceSheet();

  @override
  ConsumerState<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends ConsumerState<_AddPlaceSheet> {
  final _query = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();

  List<GeocodeResult> _results = const [];
  bool _searching = false;
  bool _searched = false;
  LatLon? _picked;
  MyPlaceCategory _category = MyPlaceCategory.other;

  @override
  void dispose() {
    _query.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final l = AppLocalizations.of(context);
    // A pasted map link with explicit coordinates needs no lookup.
    final coords = parseCoordinates(q);
    if (coords != null) {
      setState(() {
        _picked = coords;
        _name.text = l.myPlacesFromLink;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searched = false;
    });
    try {
      final res = await ref.read(apiClientProvider).geocode(
            q,
            locale: Localizations.localeOf(context).languageCode,
          );
      if (!mounted) return;
      setState(() {
        _results = res;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searched = true;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(GeocodeResult r) {
    setState(() {
      _picked = r.coordinate;
      // "Alcázar de Toledo, Toledo, Spain" -> "Alcázar de Toledo"
      _name.text = r.displayName.split(',').first.trim();
    });
  }

  Future<void> _save() async {
    final coord = _picked;
    final name = _name.text.trim();
    if (coord == null || name.isEmpty) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final place = MyPlace(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      coordinate: coord,
      category: _category,
      note: _note.text.trim(),
      createdAt: DateTime.now(),
    );
    final ok = await ref.read(myPlacesProvider.notifier).add(place);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.myPlacesLimit(MyPlacesNotifier.maxPlaces))),
      );
      return;
    }
    navigator.pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          Tokens.space16, 0, Tokens.space16, inset + Tokens.space16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.myPlacesAdd, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Tokens.space12),
            if (_picked == null) ...[
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: l.myPlacesSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: l.myPlacesSearch,
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _searching ? null : _search,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Tokens.space8),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(Tokens.space16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_searched && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Tokens.space12),
                  child: Text(
                    l.myPlacesNoResults,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                for (final r in _results)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(r.displayName,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _pick(r),
                  ),
            ] else ...[
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l.myPlacesNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Tokens.space12),
              Text(l.myPlacesCategoryLabel,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: Tokens.space8),
              Wrap(
                spacing: Tokens.space8,
                runSpacing: Tokens.space8,
                children: [
                  for (final c in MyPlaceCategory.values)
                    ChoiceChip(
                      avatar: Icon(myPlaceCategoryIcon(c), size: 16),
                      label: Text(myPlaceCategoryLabel(l, c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: Tokens.space12),
              TextField(
                controller: _note,
                maxLength: 140,
                decoration: InputDecoration(
                  labelText: l.myPlacesNoteLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Tokens.space8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(l.myPlacesSave),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
