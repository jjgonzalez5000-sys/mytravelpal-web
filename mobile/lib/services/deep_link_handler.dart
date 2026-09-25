import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/plan_screen.dart';
import 'maps_url_parser.dart';
import 'trip_sharing.dart';

/// Bootstraps `app_links` and routes any `mytravelpal://trip?...`
/// intents into a `PlanScreen` prefilled from the shared trip.
///
/// Also listens on the `mytravelpal/share` MethodChannel for
/// Android-share-sheet payloads (see `MainActivity.kt`). When a
/// shared text looks like a Google Maps URL we parse it via
/// [parseGoogleMapsUrl] and open PlanScreen the same way as the
/// deep-link path.
///
/// One instance is created in `main()` and kept alive by the app; the
/// stream subscription is torn down when `dispose()` is called on
/// process teardown.
class DeepLinkHandler {
  DeepLinkHandler(
    this._navigatorKey, {
    this.geocodeResolver,
  })  : _appLinks = AppLinks(),
        _shareChannel = const MethodChannel('mytravelpal/share');

  final GlobalKey<NavigatorState> _navigatorKey;
  final AppLinks _appLinks;
  final MethodChannel _shareChannel;
  StreamSubscription<Uri>? _sub;

  /// Lazy accessor for the app's geocode function — resolved on demand
  /// so we don't need Riverpod set up at construction time (this
  /// handler is built in `main()` before `runApp`). Kept nullable to
  /// keep tests trivial; when null we skip the share-sheet path.
  final GeocodeFn Function()? geocodeResolver;

  Future<void> start() async {
    // Cold-start: launched from a link.
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _dispatch(initial);
    // Warm links: while the app is already running.
    _sub = _appLinks.uriLinkStream.listen(_dispatch);

    // Register the share-sheet channel. Kotlin buffers a cold-start
    // share; ask for it now and process it if any.
    _shareChannel.setMethodCallHandler(_onShareChannelCall);
    try {
      final initialShared =
          await _shareChannel.invokeMethod<String>('getInitialSharedText');
      if (initialShared != null && initialShared.isNotEmpty) {
        // Fire-and-forget — no one awaits `start()` for shared-text
        // parsing, and network round-trips shouldn't block launch.
        // ignore: unawaited_futures
        _handleSharedText(initialShared);
      }
    } catch (_) {
      // Channel missing (e.g. hot-reload without a restart) — nothing
      // to grab; warm-share events will still flow once the channel
      // is up.
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _shareChannel.setMethodCallHandler(null);
  }

  Future<dynamic> _onShareChannelCall(MethodCall call) async {
    if (call.method == 'onSharedText') {
      final text = call.arguments as String?;
      if (text != null && text.isNotEmpty) {
        await _handleSharedText(text);
      }
    }
    return null;
  }

  void _dispatch(Uri uri) {
    final shared = decodeTripLink(uri);
    if (shared == null) return;
    _openPlan(shared);
  }

  Future<void> _handleSharedText(String text) async {
    // The share sheet may hand us anything — a plain message, a
    // WhatsApp forward, a random webpage. Quick shape check so we
    // don't kick off a geocode round-trip for arbitrary strings.
    final lower = text.toLowerCase();
    final looksLikeMaps = lower.contains('google.') ||
        lower.contains('goo.gl') ||
        lower.contains('g.co');
    if (!looksLikeMaps) return;

    final resolver = geocodeResolver;
    if (resolver == null) return;

    // Some sharers prefix the URL with a title / newline / label —
    // pull out the first http(s) URL from the payload.
    final url = _extractFirstUrl(text);
    if (url == null) return;

    SharedTrip? trip;
    try {
      trip = await parseGoogleMapsUrl(url, geocode: resolver());
    } catch (_) {
      trip = null;
    }
    if (trip == null) return;
    _openPlan(trip);
  }

  void _openPlan(SharedTrip shared) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => PlanScreen(initialShared: shared),
      ),
      (route) => route.isFirst,
    );
  }

  static final _urlPattern = RegExp(r'https?://\S+');

  static String? _extractFirstUrl(String text) {
    final match = _urlPattern.firstMatch(text);
    return match?.group(0);
  }
}
