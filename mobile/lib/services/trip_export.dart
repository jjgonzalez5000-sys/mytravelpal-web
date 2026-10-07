import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'nav_deep_link.dart';

/// Builds the shareable MyTravelPal "trip template" deep-link.
///
/// Format: https://mytravelpal.io/join?
///   from=<originName>:<lat>,<lon>
///   &to=<destName>:<lat>,<lon>
///   &at=<ISO8601_departure>  (optional)
///
/// When tapped on Android with the app installed → deep link opens
/// the plan form pre-filled. On other platforms → opens the web
/// landing page with a QR to install the app.
String buildMtpShareUrl({
  required LatLon origin,
  required LatLon destination,
  required String originName,
  required String destinationName,
  DateTime? departureAt,
}) {
  final encodedFrom = Uri.encodeComponent(
    '$originName:${origin.lat.toStringAsFixed(5)},${origin.lon.toStringAsFixed(5)}',
  );
  final encodedTo = Uri.encodeComponent(
    '$destinationName:${destination.lat.toStringAsFixed(5)},${destination.lon.toStringAsFixed(5)}',
  );
  var url = 'https://www.mytravelpal.io/join?from=$encodedFrom&to=$encodedTo';
  if (departureAt != null) {
    url += '&at=${Uri.encodeComponent(departureAt.toUtc().toIso8601String())}';
  }
  return url;
}

/// Present a bottom sheet with export options: open in Google Maps,
/// copy Maps link, share OS sheet, AND share with MyTravelPal users
/// (deep link that pre-fills the plan form in the app).
Future<void> showExportSheet(
  BuildContext context, {
  required LatLon origin,
  required LatLon destination,
  String originName = '',
  String destinationName = '',
  DateTime? departureAt,
  List<LatLon> waypoints = const [],
  bool avoidTolls = false,
  bool avoidHighways = false,
  bool avoidFerries = false,
}) {
  final l = AppLocalizations.of(context);
  final url = buildNavUrl(
    NavApp.googleMaps,
    destination: destination,
    origin: origin,
    waypoints: waypoints,
    avoidTolls: avoidTolls,
    avoidHighways: avoidHighways,
    avoidFerries: avoidFerries,
  );
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space16,
          vertical: Tokens.space12,
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
                l.exportShareTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(l.exportOpenInMaps),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await openInNav(
                  NavApp.googleMaps,
                  destination: destination,
                  origin: origin,
                  waypoints: waypoints,
                  avoidTolls: avoidTolls,
                  avoidHighways: avoidHighways,
                  avoidFerries: avoidFerries,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l.exportCopyLink),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!sheetCtx.mounted) return;
                Navigator.of(sheetCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.exportLinkCopied)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l.exportShareOs),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await Share.share(url, subject: l.exportShareSubject);
              },
            ),
            const Divider(height: Tokens.space16),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(l.exportShareMtp),
              subtitle: Text(l.exportShareMtpSubtitle),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final mtpUrl = buildMtpShareUrl(
                  origin: origin,
                  destination: destination,
                  originName: originName,
                  destinationName: destinationName,
                  departureAt: departureAt,
                );
                await Share.share(
                  mtpUrl,
                  subject: l.exportShareMtpSubject(
                    originName.isNotEmpty ? originName : 'origin',
                    destinationName.isNotEmpty ? destinationName : 'destination',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
