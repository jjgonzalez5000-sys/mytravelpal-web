import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../api/models.dart';
import '../widgets/trip_share_card.dart';

/// Captures a [TripShareCard] offscreen and hands the resulting PNG
/// to the native share sheet so the user can post directly to
/// Instagram, X, WhatsApp, Telegram, etc.
class TripShareService {
  TripShareService._();

  // 3.0 mirrors TripShareCard._pixelRatio (1080x1350 @ 3x = 3240x4050px).
  static const double _pixelRatio = 3.0;

  /// Render the full-response share card, capture as PNG, open the
  /// native Android share sheet.
  static Future<void> shareTrip({
    required BuildContext context,
    required String originName,
    required String destinationName,
    required TripPlanResponse response,
    required DateTime departureAt,
  }) async {
    final key = GlobalKey();
    final overlayState = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -6000,
        top: 0,
        child: Material(
          child: RepaintBoundary(
            key: key,
            child: TripShareCard(
              originName: originName,
              destinationName: destinationName,
              response: response,
              desiredDepartureAt: departureAt,
            ),
          ),
        ),
      ),
    );

    overlayState.insert(entry);
    // One frame for layout + one extra for image decode.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/mtp_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Planificado con MyTravelPal — mytravelpal.io\n'
            '#roadtrip #europeroadtrip #travelplanning #mytravelpal',
        subject: '$originName → $destinationName',
      );
    } finally {
      entry.remove();
    }
  }
}
