import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom-right "© OpenStreetMap contributors" chip required by ODbL
/// 1.0 whenever OSM data is rendered visually. Pulled into its own
/// widget so every map in the app carries the exact same wording and
/// tap-through — legally the mention has to be present, not just the
/// awareness of it.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  static const _copyrightUrl = 'https://www.openstreetmap.org/copyright';

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      showFlutterMapAttribution: false,
      attributions: [
        TextSourceAttribution(
          '© OpenStreetMap contributors',
          onTap: () => launchUrl(
            Uri.parse(_copyrightUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}
