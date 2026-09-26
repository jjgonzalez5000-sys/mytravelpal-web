import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'nav_deep_link.dart';

/// Present a bottom sheet with the three export options: open in Google
/// Maps, copy link, share via the OS share sheet. All three build the
/// same URL — a Google Maps `dir?api=1` link with origin, waypoints,
/// and destination pre-populated.
Future<void> showExportSheet(
  BuildContext context, {
  required LatLon origin,
  required LatLon destination,
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
          ],
        ),
      ),
    ),
  );
}
