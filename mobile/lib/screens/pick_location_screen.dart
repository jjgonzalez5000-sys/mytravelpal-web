import 'package:flutter/material.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../widgets/location_search_field.dart';

/// Full-screen location picker. Replaces the modal-bottom-sheet
/// pickers used for "Add stop" and the "Leave now" destination
/// prompt. The bottom-sheet version had two problems: the
/// suggestion overlay was clipped by the soft keyboard, and users
/// had no visible way to cancel without a suggestion — the sheet
/// dismissed silently on backdrop tap.
///
/// This screen wraps the same [LocationSearchField] used on the
/// plan screen so autocomplete, favourites, recents and
/// "Use my location" all behave identically. Tap a suggestion →
/// pops with the [GeocodeResult]; back button → pops with null.
class PickLocationScreen extends StatelessWidget {
  const PickLocationScreen({
    super.key,
    required this.title,
    required this.geocode,
    this.label,
    this.onUseCurrentLocation,
  });

  final String title;
  final GeocodeFn geocode;
  final String? label;
  final Future<GeocodeResult?> Function()? onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LocationSearchField(
            label: label ?? l.searchPlaceholder,
            geocode: geocode,
            onUseCurrentLocation: onUseCurrentLocation,
            onSelected: (r) {
              if (r == null) return;
              Navigator.of(context).pop(r);
            },
          ),
        ),
      ),
    );
  }
}
