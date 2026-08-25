import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../screens/plan_screen.dart';
import 'trip_sharing.dart';

/// Bootstraps `app_links` and routes any `mytravelpal://trip?...`
/// intents into a `PlanScreen` prefilled from the shared trip.
///
/// One instance is created in `main()` and kept alive by the app; the
/// stream subscription is torn down when `dispose()` is called on
/// process teardown.
class DeepLinkHandler {
  DeepLinkHandler(this._navigatorKey) : _appLinks = AppLinks();

  final GlobalKey<NavigatorState> _navigatorKey;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  Future<void> start() async {
    // Cold-start: launched from a link.
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _dispatch(initial);
    // Warm links: while the app is already running.
    _sub = _appLinks.uriLinkStream.listen(_dispatch);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _dispatch(Uri uri) {
    final shared = decodeTripLink(uri);
    if (shared == null) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => PlanScreen(initialShared: shared),
      ),
      (route) => route.isFirst,
    );
  }
}
