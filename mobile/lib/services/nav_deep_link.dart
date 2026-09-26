import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

/// Which external navigation app the user picked. Kept enum-shaped so
/// analytics can measure preference over time.
enum NavApp { googleMaps, waze, appleMaps }

/// URL builders for each supported target. We use https deep-links
/// where possible so a missing app degrades to the browser + web nav,
/// rather than a hard "app not installed" error.
String buildNavUrl(
  NavApp app, {
  required LatLon destination,
  LatLon? origin,
  List<LatLon> waypoints = const [],
  bool avoidTolls = false,
  bool avoidHighways = false,
  bool avoidFerries = false,
}) {
  final d = '${destination.lat},${destination.lon}';
  switch (app) {
    case NavApp.googleMaps:
      // The universal `dir?api=1` URL opens the app when installed,
      // otherwise the web app. `travelmode=driving` skips the mode
      // picker Google would otherwise show. Google caps waypoints
      // at 9 (10 total with destination); we hard-cap to 9 to match
      // — extras are silently dropped rather than 400'd.
      final origPart =
          origin == null ? '' : '&origin=${origin.lat},${origin.lon}';
      final wpPart = waypoints.isEmpty
          ? ''
          : '&waypoints=${waypoints
              .take(9)
              .map((w) => '${w.lat},${w.lon}')
              .join('|')}';
      // Google Maps `avoid` param accepts a comma-separated combo
      // of `tolls`, `highways`, `ferries`. Only emit when at least
      // one is on so URLs stay clean when nothing is asked for.
      final avoidParts = <String>[
        if (avoidTolls) 'tolls',
        if (avoidHighways) 'highways',
        if (avoidFerries) 'ferries',
      ];
      final avoidPart = avoidParts.isEmpty
          ? ''
          : '&avoid=${avoidParts.join(',')}';
      return 'https://www.google.com/maps/dir/?api=1'
          '&destination=$d$origPart$wpPart$avoidPart&travelmode=driving';
    case NavApp.waze:
      // Waze URL supports `avoid_toll_roads=yes` and
      // `avoid_ferries=yes`. No route waypoints — waze only accepts a
      // single destination + current position as origin.
      final avoidWazeParts = <String>[
        if (avoidTolls) '&avoid_toll_roads=yes',
        if (avoidFerries) '&avoid_ferries=yes',
      ];
      return 'https://waze.com/ul?ll=$d&navigate=yes'
          '${avoidWazeParts.join()}';
    case NavApp.appleMaps:
      // Apple Maps universal link — opens the native app on iOS and
      // shows the web equivalent everywhere else. `dirflg=d` = drive.
      // No stable waypoint syntax in the universal URL, so we ignore
      // them for Apple Maps.
      final origPart = origin == null ? '' : '&saddr=${origin.lat},${origin.lon}';
      return 'https://maps.apple.com/?daddr=$d&dirflg=d$origPart';
  }
}

/// Open the picked nav app in the OS. Uses `externalApplication` mode
/// so the launch escapes the WebView-style in-app browser and hits
/// the native app when installed.
Future<bool> openInNav(
  NavApp app, {
  required LatLon destination,
  LatLon? origin,
  List<LatLon> waypoints = const [],
  bool avoidTolls = false,
  bool avoidHighways = false,
  bool avoidFerries = false,
}) {
  return launchUrl(
    Uri.parse(buildNavUrl(
      app,
      destination: destination,
      origin: origin,
      waypoints: waypoints,
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
      avoidFerries: avoidFerries,
    )),
    mode: LaunchMode.externalApplication,
  );
}

/// Present the "Continue in…" picker with every supported nav app.
/// Deliberately shows all three even when we don't know which are
/// installed — Google's URL degrades to browser, Waze/Apple Maps
/// URLs deep-link to the app when present.
Future<void> showNavAppPicker(
  BuildContext context, {
  required LatLon destination,
  LatLon? origin,
}) {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space16, vertical: Tokens.space12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: Tokens.space8,
                right: Tokens.space8,
                bottom: Tokens.space8,
              ),
              child: Text(
                l.navPickerTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _navRow(
              context,
              icon: Icons.map_outlined,
              label: 'Google Maps',
              onTap: () async {
                Navigator.of(context).pop();
                await openInNav(
                  NavApp.googleMaps,
                  destination: destination,
                  origin: origin,
                );
              },
            ),
            _navRow(
              context,
              icon: Icons.near_me_outlined,
              label: 'Waze',
              onTap: () async {
                Navigator.of(context).pop();
                await openInNav(
                  NavApp.waze,
                  destination: destination,
                  origin: origin,
                );
              },
            ),
            _navRow(
              context,
              icon: Icons.apple,
              label: 'Apple Maps',
              onTap: () async {
                Navigator.of(context).pop();
                await openInNav(
                  NavApp.appleMaps,
                  destination: destination,
                  origin: origin,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _navRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return ListTile(
    leading: Icon(icon, size: 24),
    title: Text(label,
        style: Theme.of(context).textTheme.titleMedium),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: onTap,
  );
}
