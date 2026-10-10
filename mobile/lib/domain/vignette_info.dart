/// What a driver needs to know about a country's vignette (a road permit
/// bought per country, not per toll booth). Prices come from the server;
/// this is the part that does not change with them.
class VignetteInfo {
  const VignetteInfo({required this.officialUrl, this.sticker = false});

  /// Official seller. Third-party resellers add fees, so link the state one.
  final String officialUrl;

  /// True when the usual form is a windscreen sticker (an e-version may also
  /// exist); false for a digital permit tied to the number plate.
  final bool sticker;
}

const Map<String, VignetteInfo> kVignetteInfo = {
  'AT': VignetteInfo(officialUrl: 'https://www.asfinag.at/'),
  'CH': VignetteInfo(officialUrl: 'https://www.e-vignette.ch/', sticker: true),
  'CZ': VignetteInfo(officialUrl: 'https://edalnice.cz/'),
  'SK': VignetteInfo(officialUrl: 'https://eznamka.sk/'),
  'HU': VignetteInfo(officialUrl: 'https://nemzetiutdij.hu/'),
  'SI': VignetteInfo(officialUrl: 'https://evinjeta.dars.si/'),
  'RO': VignetteInfo(officialUrl: 'https://www.roviniete.ro/'),
  'BG': VignetteInfo(officialUrl: 'https://web.bgtoll.bg/'),
};

VignetteInfo? vignetteInfoFor(String countryCode) =>
    kVignetteInfo[countryCode.toUpperCase()];
