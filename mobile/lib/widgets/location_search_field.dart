import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';

typedef GeocodeFn = Future<List<GeocodeResult>> Function(String query);

/// Autocomplete field: user types a city name, backend returns candidates,
/// user picks one → coordinate + country are locked in and shown as a chip.
class LocationSearchField extends StatefulWidget {
  const LocationSearchField({
    super.key,
    required this.label,
    required this.geocode,
    required this.onSelected,
    this.initial,
  });

  final String label;
  final GeocodeFn geocode;
  final ValueChanged<GeocodeResult?> onSelected;
  final GeocodeResult? initial;

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final _controller = SearchController();
  GeocodeResult? _picked;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    if (widget.initial != null) {
      _controller.text = widget.initial!.displayName;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<List<GeocodeResult>> _debouncedSearch(String query) async {
    _debounce?.cancel();
    final completer = Completer<List<GeocodeResult>>();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        completer.complete(await widget.geocode(query));
      } on ApiException {
        completer.complete(const []);
      } catch (_) {
        completer.complete(const []);
      }
    });
    return completer.future;
  }

  void _clear() {
    setState(() {
      _picked = null;
      _controller.text = '';
    });
    widget.onSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _controller,
      builder: (context, controller) => InkWell(
        onTap: controller.openView,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: _picked == null
                ? const Icon(Icons.search)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clear,
                    tooltip: 'Clear',
                  ),
          ),
          child: Text(
            _picked?.displayName ?? 'Search a city…',
            style: _picked == null
                ? TextStyle(color: Theme.of(context).hintColor)
                : null,
          ),
        ),
      ),
      suggestionsBuilder: (context, controller) async {
        final query = controller.text.trim();
        if (query.length < 2) {
          return const <Widget>[
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('Type at least 2 characters.'),
            ),
          ];
        }
        final results = await _debouncedSearch(query);
        if (results.isEmpty) {
          return const <Widget>[
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('No matches.'),
            ),
          ];
        }
        return results.map(
          (r) => ListTile(
            leading: const Icon(Icons.place),
            title: Text(r.displayName),
            subtitle: Text(r.country.displayName),
            onTap: () {
              setState(() {
                _picked = r;
                _controller.closeView(r.displayName);
              });
              widget.onSelected(r);
            },
          ),
        );
      },
    );
  }
}
