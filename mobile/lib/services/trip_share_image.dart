import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';

/// User-selectable output format for the trip share card.
///
/// - [story]  1080×1920 — Instagram Stories, TikTok, Snapchat, WhatsApp
/// - [feed]   1080×1080 — Instagram feed, Facebook feed
///
/// Twitter/X card 1200×675 was cut for the first cut — X's default
/// preview handles portrait fine and adding a third format doubles
/// the QA surface. If users ask for a horizontal variant later, add
/// `banner` here with a 1200×675 layout.
enum ShareFormat {
  story(1080, 1920, 'story'),
  feed(1080, 1080, 'feed');

  const ShareFormat(this.width, this.height, this.slug);
  final int width;
  final int height;

  /// UTM medium value so we can tell in Sentry / analytics which
  /// format users pick most (informs whether to invest in a
  /// third layout like the horizontal banner).
  final String slug;
}

const _kAppUrl = 'https://mytravelpal.io';

/// Hashtags stamped into every share caption. Tuned for reach in
/// road-trip and travel verticals rather than volume — smaller
/// niche tags convert better than #travel (which competes with 3B
/// posts).
const _kHashtags =
    '#roadtrip #europeroadtrip #travelplanning #mytravelpal';

/// Rendered a widget into a PNG file whose bytes are streamed to
/// the platform share sheet.
///
/// Common helper for both `shareTripCard` and `shareCompanionCard`.
/// Off-screen via an `Overlay` insertion so it never disturbs the
/// visible layout; measured at [format.width] × [format.height] px
/// so the output is publishable "as is" on the requested platform.
Future<File?> _renderCardToPng({
  required BuildContext context,
  required ShareFormat format,
  required Widget child,
}) async {
  final key = GlobalKey();
  final overlay = OverlayEntry(
    builder: (_) => Positioned(
      left: -6000,
      child: Material(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: format.width.toDouble(),
            height: format.height.toDouble(),
            child: child,
          ),
        ),
      ),
    ),
  );
  final overlayState = Overlay.of(context);
  overlayState.insert(overlay);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  try {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/mytravelpal-${format.slug}-'
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  } finally {
    overlay.remove();
  }
}

/// Ask the user which format they want before rendering. Bottom
/// sheet with two big chips (Story portrait, Feed square). Returns
/// null when the user dismisses without picking.
Future<ShareFormat?> _pickShareFormat(BuildContext context) async {
  final l = AppLocalizations.of(context);
  return showModalBottomSheet<ShareFormat>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.shareFormatTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.crop_portrait),
            title: Text(l.shareFormatStory),
            subtitle: Text(l.shareFormatStorySub),
            onTap: () => Navigator.of(context).pop(ShareFormat.story),
          ),
          ListTile(
            leading: const Icon(Icons.crop_square),
            title: Text(l.shareFormatFeed),
            subtitle: Text(l.shareFormatFeedSub),
            onTap: () => Navigator.of(context).pop(ShareFormat.feed),
          ),
        ],
      ),
    ),
  );
}

/// Deep-link stamped into the caption + watermark. Carries UTM so
/// clicks land back with attribution — informs whether IG-share is
/// worth investing more or whether TikTok is the real driver.
String _shareUrl(ShareFormat format) =>
    '$_kAppUrl?utm_source=share&utm_medium=${format.slug}&utm_campaign=trip_card';

Future<void> shareTripCard(
  BuildContext context, {
  required String originName,
  required String destinationName,
  required RouteInfo route,
  double? savedEur,
  double? savedMinutes,
}) async {
  final format = await _pickShareFormat(context);
  if (format == null || !context.mounted) return;
  final l = AppLocalizations.of(context);
  final file = await _renderCardToPng(
    context: context,
    format: format,
    child: _ShareCard(
      originName: originName,
      destinationName: destinationName,
      route: route,
      savedEur: savedEur,
      savedMinutes: savedMinutes,
      appTagline: l.appTagline,
      format: format,
    ),
  );
  if (file == null || !context.mounted) return;
  await Share.shareXFiles(
    [XFile(file.path)],
    text: _shareCaption(l, originName, destinationName, route, format),
    subject: '$originName → $destinationName',
  );
}

String _shareCaption(
  AppLocalizations l,
  String origin,
  String destination,
  RouteInfo route,
  ShareFormat format,
) {
  final km = route.distanceKm.toStringAsFixed(0);
  final hours = (route.freeFlowMinutes / 60).toStringAsFixed(1);
  return '$origin → $destination · $km km · $hours h\n'
      '${l.shareTitle}\n'
      '${_shareUrl(format)}\n'
      '$_kHashtags';
}

/// Live "I'm on the road" card generated during Companion Drive.
Future<void> shareCompanionCard(
  BuildContext context, {
  required String currentCity,
  double? drivingHours,
  double? kmSoFar,
}) async {
  final format = await _pickShareFormat(context);
  if (format == null || !context.mounted) return;
  final l = AppLocalizations.of(context);
  final file = await _renderCardToPng(
    context: context,
    format: format,
    child: _LiveCard(
      city: currentCity,
      drivingHours: drivingHours,
      kmSoFar: kmSoFar,
      tagline: l.appTagline,
      headline: l.shareLiveHeadline(currentCity),
      format: format,
    ),
  );
  if (file == null || !context.mounted) return;
  await Share.shareXFiles(
    [XFile(file.path)],
    text: '${l.shareLiveCaption(currentCity)}\n'
        '${_shareUrl(format)}\n'
        '$_kHashtags',
    subject: currentCity,
  );
}

// ---------------------------------------------------------------
// Cards
// ---------------------------------------------------------------

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.originName,
    required this.destinationName,
    required this.route,
    required this.appTagline,
    required this.format,
    this.savedEur,
    this.savedMinutes,
  });

  final String originName;
  final String destinationName;
  final RouteInfo route;
  final double? savedEur;
  final double? savedMinutes;
  final String appTagline;
  final ShareFormat format;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Feed is square (1:1) so the arrow + tagline row need less
    // vertical breathing; scale down the destination hero one
    // notch so it fits without truncating.
    final destinationSize = format == ShareFormat.feed ? 72.0 : 88.0;
    final padding = format == ShareFormat.feed ? 60.0 : 72.0;
    return Container(
      width: format.width.toDouble(),
      height: format.height.toDouble(),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Brand(),
          const Spacer(),
          Text(
            originName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 44,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Icon(Icons.arrow_downward, color: Colors.white, size: 52),
          Text(
            destinationName,
            style: TextStyle(
              color: Colors.white,
              fontSize: destinationSize,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              for (final c in route.countriesCrossed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    c.code.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 40, runSpacing: 20,
            children: [
              _Stat(
                value: '${route.distanceKm.toStringAsFixed(0)} km',
                label: 'Distancia',
              ),
              _Stat(
                value: '${(route.freeFlowMinutes / 60).toStringAsFixed(1)} h',
                label: 'Tiempo',
              ),
              if (savedEur != null && savedEur! > 0)
                _Stat(
                  value: '€${savedEur!.toStringAsFixed(0)}',
                  label: 'Ahorrados',
                ),
            ],
          ),
          const SizedBox(height: 32),
          _Watermark(tagline: appTagline),
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.city,
    required this.tagline,
    required this.headline,
    required this.format,
    this.drivingHours,
    this.kmSoFar,
  });
  final String city;
  final double? drivingHours;
  final double? kmSoFar;
  final String tagline;
  final String headline;
  final ShareFormat format;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headlineSize = format == ShareFormat.feed ? 60.0 : 72.0;
    final padding = format == ShareFormat.feed ? 60.0 : 72.0;
    return Container(
      width: format.width.toDouble(),
      height: format.height.toDouble(),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.tertiary, scheme.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Brand(),
          const Spacer(),
          const Text('🚗', style: TextStyle(fontSize: 96)),
          const SizedBox(height: 24),
          Text(
            headline,
            style: TextStyle(
              color: Colors.white,
              fontSize: headlineSize,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const Spacer(),
          if (drivingHours != null || kmSoFar != null) ...[
            Wrap(
              spacing: 40, runSpacing: 20,
              children: [
                if (drivingHours != null)
                  _Stat(
                    value: '${drivingHours!.toStringAsFixed(1)} h',
                    label: 'CONDUCIENDO',
                  ),
                if (kmSoFar != null)
                  _Stat(
                    value: '${kmSoFar!.toStringAsFixed(0)} km',
                    label: 'RECORRIDOS',
                  ),
              ],
            ),
            const SizedBox(height: 32),
          ],
          _Watermark(tagline: tagline),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Shared card fragments
// ---------------------------------------------------------------

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        children: const [
          Icon(Icons.explore, color: Colors.white, size: 48),
          SizedBox(width: 16),
          Text(
            'MyTravelPal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _Watermark extends StatelessWidget {
  const _Watermark({required this.tagline});
  final String tagline;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tagline,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 24,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          // Explicit URL watermark: whoever reposts / screenshots
          // the card still ends up pointing back to us. Free
          // acquisition loop worth every pixel.
          const Text(
            'mytravelpal.io',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 20,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
