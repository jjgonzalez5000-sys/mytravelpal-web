import 'package:flutter/material.dart';

/// Pick a Material icon for a Nominatim / OpenStreetMap POI.
///
/// Coverage: ~140 (class, type) tuples across the 20 primary OSM
/// classes. When we don't recognise the specific type but do know the
/// class, we fall back to a class-wide icon (see [_classFallback]).
/// When even the class is missing we scan [displayName] for
/// language-agnostic keywords (museum / airport / hotel / station /
/// park / restaurant). Failing that, a generic pin.
///
/// Multi-language keyword scan is deliberately kept small — the OSM
/// tags are the reliable source. The scan only fires for the mock
/// catalogue and for saved [FavoritePlace]s (which don't carry OSM
/// tags), and covers our 5 launch languages.
IconData iconForPoi(String? poiClass, String? poiType, String displayName) {
  if (poiClass != null && poiType != null) {
    final key = '$poiClass:$poiType';
    final specific = _poiIcons[key];
    if (specific != null) return specific;
  }
  if (poiClass != null) {
    final fallback = _classFallback[poiClass];
    if (fallback != null) return fallback;
  }
  return _iconFromKeywords(displayName);
}

// ---------------------------------------------------------------------------
// Class-wide fallbacks
// ---------------------------------------------------------------------------

const Map<String, IconData> _classFallback = {
  'amenity': Icons.storefront,
  'tourism': Icons.tour,
  'shop': Icons.shopping_bag_outlined,
  'natural': Icons.landscape,
  'historic': Icons.museum,
  'place': Icons.place,
  'leisure': Icons.sports,
  'railway': Icons.directions_transit,
  'aeroway': Icons.flight,
  'office': Icons.business_center,
  'building': Icons.apartment,
  'highway': Icons.directions_car,
  'waterway': Icons.water,
  'man_made': Icons.construction,
  'emergency': Icons.emergency,
  'sport': Icons.sports,
  'craft': Icons.build,
  'military': Icons.shield,
  'power': Icons.bolt,
  'landuse': Icons.map,
  'barrier': Icons.horizontal_rule,
};

// ---------------------------------------------------------------------------
// Specific (class, type) → icon
// ---------------------------------------------------------------------------

const Map<String, IconData> _poiIcons = {
  // ─── AMENITY · food & drink ────────────────────────────────────────────
  'amenity:restaurant': Icons.restaurant,
  'amenity:cafe': Icons.local_cafe,
  'amenity:fast_food': Icons.fastfood,
  'amenity:bar': Icons.local_bar,
  'amenity:pub': Icons.sports_bar,
  'amenity:biergarten': Icons.sports_bar,
  'amenity:food_court': Icons.restaurant_menu,
  'amenity:ice_cream': Icons.icecream,

  // ─── AMENITY · fuel & vehicles ─────────────────────────────────────────
  'amenity:fuel': Icons.local_gas_station,
  'amenity:charging_station': Icons.ev_station,
  'amenity:parking': Icons.local_parking,
  'amenity:parking_entrance': Icons.local_parking,
  'amenity:bicycle_parking': Icons.directions_bike,
  'amenity:motorcycle_parking': Icons.two_wheeler,
  'amenity:bicycle_rental': Icons.pedal_bike,
  'amenity:car_rental': Icons.directions_car,
  'amenity:car_sharing': Icons.car_rental,
  'amenity:car_wash': Icons.local_car_wash,
  'amenity:taxi': Icons.local_taxi,

  // ─── AMENITY · health ──────────────────────────────────────────────────
  'amenity:hospital': Icons.local_hospital,
  'amenity:clinic': Icons.medical_services,
  'amenity:doctors': Icons.medical_services,
  'amenity:dentist': Icons.medical_services,
  'amenity:pharmacy': Icons.local_pharmacy,
  'amenity:veterinary': Icons.pets,

  // ─── AMENITY · money ───────────────────────────────────────────────────
  'amenity:atm': Icons.atm,
  'amenity:bank': Icons.account_balance,
  'amenity:bureau_de_change': Icons.currency_exchange,
  'amenity:payment_terminal': Icons.payments,

  // ─── AMENITY · civic / education ───────────────────────────────────────
  'amenity:school': Icons.school,
  'amenity:kindergarten': Icons.child_care,
  'amenity:college': Icons.school,
  'amenity:university': Icons.cast_for_education,
  'amenity:library': Icons.local_library,
  'amenity:public_bookcase': Icons.menu_book,
  'amenity:townhall': Icons.account_balance,
  'amenity:courthouse': Icons.gavel,
  'amenity:embassy': Icons.flag,
  'amenity:post_office': Icons.local_post_office,
  'amenity:post_box': Icons.mail_outline,
  'amenity:community_centre': Icons.groups,
  'amenity:social_facility': Icons.groups,

  // ─── AMENITY · emergency / safety ──────────────────────────────────────
  'amenity:police': Icons.local_police,
  'amenity:fire_station': Icons.local_fire_department,
  'amenity:prison': Icons.security,

  // ─── AMENITY · religion (also used with `building:*`) ──────────────────
  'amenity:place_of_worship': Icons.church,

  // ─── AMENITY · leisure / culture ───────────────────────────────────────
  'amenity:cinema': Icons.local_movies,
  'amenity:theatre': Icons.theater_comedy,
  'amenity:nightclub': Icons.nightlife,
  'amenity:arts_centre': Icons.palette,
  'amenity:events_venue': Icons.event,
  'amenity:conference_centre': Icons.co_present,
  'amenity:exhibition_centre': Icons.museum,
  'amenity:fountain': Icons.water_drop,

  // ─── AMENITY · misc ────────────────────────────────────────────────────
  'amenity:toilets': Icons.wc,
  'amenity:shower': Icons.shower,
  'amenity:drinking_water': Icons.water_drop,
  'amenity:bench': Icons.chair_outlined,
  'amenity:waste_basket': Icons.delete_outline,
  'amenity:recycling': Icons.recycling,
  'amenity:vending_machine': Icons.local_convenience_store,
  'amenity:marketplace': Icons.storefront,
  'amenity:internet_cafe': Icons.wifi,
  'amenity:telephone': Icons.phone,

  // ─── TOURISM ───────────────────────────────────────────────────────────
  'tourism:hotel': Icons.hotel,
  'tourism:motel': Icons.hotel,
  'tourism:hostel': Icons.airline_seat_flat,
  'tourism:guest_house': Icons.house,
  'tourism:apartment': Icons.apartment,
  'tourism:chalet': Icons.cabin,
  'tourism:camp_site': Icons.forest,
  'tourism:caravan_site': Icons.rv_hookup,
  'tourism:museum': Icons.museum,
  'tourism:gallery': Icons.palette,
  'tourism:attraction': Icons.attractions,
  'tourism:theme_park': Icons.attractions,
  'tourism:zoo': Icons.pets,
  'tourism:aquarium': Icons.set_meal,
  'tourism:viewpoint': Icons.landscape,
  'tourism:artwork': Icons.brush,
  'tourism:picnic_site': Icons.deck,
  'tourism:information': Icons.info_outline,

  // ─── SHOP ──────────────────────────────────────────────────────────────
  'shop:supermarket': Icons.local_grocery_store,
  'shop:convenience': Icons.local_convenience_store,
  'shop:mall': Icons.local_mall,
  'shop:department_store': Icons.local_mall,
  'shop:kiosk': Icons.storefront,
  'shop:bakery': Icons.bakery_dining,
  'shop:pastry': Icons.cake,
  'shop:butcher': Icons.kebab_dining,
  'shop:seafood': Icons.set_meal,
  'shop:deli': Icons.lunch_dining,
  'shop:cheese': Icons.tapas,
  'shop:wine': Icons.wine_bar,
  'shop:alcohol': Icons.liquor,
  'shop:beverages': Icons.local_drink,
  'shop:coffee': Icons.coffee,
  'shop:greengrocer': Icons.eco,
  'shop:farm': Icons.agriculture,
  'shop:clothes': Icons.checkroom,
  'shop:shoes': Icons.snowshoeing,
  'shop:jewelry': Icons.diamond,
  'shop:watches': Icons.watch,
  'shop:bag': Icons.shopping_bag,
  'shop:sports': Icons.sports_basketball,
  'shop:outdoor': Icons.hiking,
  'shop:bicycle': Icons.directions_bike,
  'shop:motorcycle': Icons.two_wheeler,
  'shop:car': Icons.directions_car,
  'shop:car_parts': Icons.build,
  'shop:car_repair': Icons.car_repair,
  'shop:hardware': Icons.handyman,
  'shop:doityourself': Icons.home_repair_service,
  'shop:garden_centre': Icons.grass,
  'shop:florist': Icons.local_florist,
  'shop:electronics': Icons.devices,
  'shop:computer': Icons.computer,
  'shop:mobile_phone': Icons.smartphone,
  'shop:books': Icons.menu_book,
  'shop:stationery': Icons.edit_note,
  'shop:toys': Icons.toys,
  'shop:gift': Icons.card_giftcard,
  'shop:art': Icons.palette,
  'shop:beauty': Icons.face_retouching_natural,
  'shop:hairdresser': Icons.content_cut,
  'shop:optician': Icons.remove_red_eye,
  'shop:cosmetics': Icons.brush,
  'shop:perfumery': Icons.spa,
  'shop:pet': Icons.pets,
  'shop:laundry': Icons.local_laundry_service,
  'shop:dry_cleaning': Icons.dry_cleaning,
  'shop:travel_agency': Icons.luggage,
  'shop:tobacco': Icons.smoking_rooms,

  // ─── LEISURE ───────────────────────────────────────────────────────────
  'leisure:park': Icons.park,
  'leisure:garden': Icons.local_florist,
  'leisure:playground': Icons.child_friendly,
  'leisure:pitch': Icons.sports_soccer,
  'leisure:sports_centre': Icons.fitness_center,
  'leisure:stadium': Icons.stadium,
  'leisure:swimming_pool': Icons.pool,
  'leisure:water_park': Icons.pool,
  'leisure:fitness_centre': Icons.fitness_center,
  'leisure:fitness_station': Icons.fitness_center,
  'leisure:track': Icons.directions_run,
  'leisure:golf_course': Icons.golf_course,
  'leisure:marina': Icons.sailing,
  'leisure:beach_resort': Icons.beach_access,
  'leisure:nature_reserve': Icons.forest,
  'leisure:sauna': Icons.spa,
  'leisure:dog_park': Icons.pets,

  // ─── NATURAL ───────────────────────────────────────────────────────────
  'natural:peak': Icons.terrain,
  'natural:volcano': Icons.local_fire_department,
  'natural:beach': Icons.beach_access,
  'natural:water': Icons.water,
  'natural:bay': Icons.water,
  'natural:strait': Icons.waves,
  'natural:coastline': Icons.beach_access,
  'natural:cave_entrance': Icons.landscape,
  'natural:glacier': Icons.ac_unit,
  'natural:wood': Icons.forest,
  'natural:tree': Icons.park,
  'natural:cliff': Icons.landscape,
  'natural:spring': Icons.water_drop,
  'natural:hot_spring': Icons.hot_tub,
  'natural:wetland': Icons.water,
  'natural:desert': Icons.wb_sunny,
  'natural:island': Icons.landscape,

  // ─── HISTORIC ──────────────────────────────────────────────────────────
  'historic:castle': Icons.castle,
  'historic:fort': Icons.castle,
  'historic:ruins': Icons.museum,
  'historic:monument': Icons.push_pin,
  'historic:memorial': Icons.push_pin,
  'historic:archaeological_site': Icons.museum,
  'historic:tomb': Icons.museum,
  'historic:wayside_cross': Icons.church,
  'historic:wayside_shrine': Icons.church,
  'historic:battlefield': Icons.shield,

  // ─── PLACE (populated) ─────────────────────────────────────────────────
  'place:city': Icons.location_city,
  'place:town': Icons.location_city,
  'place:village': Icons.holiday_village,
  'place:hamlet': Icons.holiday_village,
  'place:suburb': Icons.location_city,
  'place:neighbourhood': Icons.location_city,
  'place:borough': Icons.location_city,
  'place:isolated_dwelling': Icons.house,
  'place:farm': Icons.agriculture,
  'place:island': Icons.landscape,
  'place:islet': Icons.landscape,
  'place:region': Icons.map,
  'place:state': Icons.map,
  'place:country': Icons.public,

  // ─── TRANSPORT · railway ───────────────────────────────────────────────
  'railway:station': Icons.train,
  'railway:halt': Icons.train,
  'railway:tram_stop': Icons.tram,
  'railway:subway_entrance': Icons.subway,
  'railway:platform': Icons.directions_transit,

  // ─── TRANSPORT · aeroway ───────────────────────────────────────────────
  'aeroway:aerodrome': Icons.local_airport,
  'aeroway:terminal': Icons.local_airport,
  'aeroway:helipad': Icons.airplanemode_active,
  'aeroway:heliport': Icons.airplanemode_active,

  // ─── TRANSPORT · highway ───────────────────────────────────────────────
  'highway:bus_stop': Icons.directions_bus,
  'highway:services': Icons.local_gas_station,
  'highway:rest_area': Icons.pause_circle_outline,
  'highway:motorway_junction': Icons.merge_type,

  // ─── WATERWAY ──────────────────────────────────────────────────────────
  'waterway:river': Icons.water,
  'waterway:stream': Icons.water,
  'waterway:canal': Icons.water,
  'waterway:waterfall': Icons.water,
  'waterway:dock': Icons.anchor,
  'waterway:lock_gate': Icons.anchor,

  // ─── OFFICE ────────────────────────────────────────────────────────────
  'office:company': Icons.business_center,
  'office:government': Icons.account_balance,
  'office:diplomatic': Icons.flag,
  'office:lawyer': Icons.gavel,
  'office:insurance': Icons.security,
  'office:it': Icons.computer,
  'office:coworking': Icons.co_present,

  // ─── BUILDING (religion + landmark shortcuts) ──────────────────────────
  'building:church': Icons.church,
  'building:cathedral': Icons.church,
  'building:chapel': Icons.church,
  'building:mosque': Icons.mosque,
  'building:synagogue': Icons.synagogue,
  'building:temple': Icons.temple_buddhist,

  // ─── EMERGENCY ─────────────────────────────────────────────────────────
  'emergency:phone': Icons.phone_in_talk,
  'emergency:defibrillator': Icons.medical_services,
  'emergency:fire_hydrant': Icons.local_fire_department,

  // ─── SPORT (when the tag is on a way rather than a leisure feature) ────
  'sport:soccer': Icons.sports_soccer,
  'sport:basketball': Icons.sports_basketball,
  'sport:tennis': Icons.sports_tennis,
  'sport:swimming': Icons.pool,
  'sport:running': Icons.directions_run,
  'sport:cycling': Icons.directions_bike,
  'sport:golf': Icons.golf_course,
  'sport:skiing': Icons.downhill_skiing,
  'sport:snowboarding': Icons.snowboarding,
  'sport:climbing': Icons.hiking,
  'sport:surfing': Icons.surfing,
  'sport:sailing': Icons.sailing,
  'sport:baseball': Icons.sports_baseball,
  'sport:volleyball': Icons.sports_volleyball,
  'sport:handball': Icons.sports_handball,
  'sport:rugby': Icons.sports_rugby,
  'sport:hockey': Icons.sports_hockey,
  'sport:motorsport': Icons.sports_motorsports,
  'sport:equestrian': Icons.pets,

  // ─── MAN_MADE ──────────────────────────────────────────────────────────
  'man_made:tower': Icons.cell_tower,
  'man_made:lighthouse': Icons.wb_sunny,
  'man_made:water_tower': Icons.water,
  'man_made:pier': Icons.anchor,
  'man_made:bridge': Icons.linear_scale,
  'man_made:windmill': Icons.wind_power,
  'man_made:antenna': Icons.cell_tower,
};

// ---------------------------------------------------------------------------
// Keyword-based fallback (mock catalogue + saved places)
// ---------------------------------------------------------------------------

IconData _iconFromKeywords(String displayName) {
  final n = displayName.toLowerCase();
  for (final entry in _keywordIcons) {
    if (entry.pattern.hasMatch(n)) return entry.icon;
  }
  return Icons.place;
}

class _KeywordIcon {
  const _KeywordIcon(this.pattern, this.icon);
  final RegExp pattern;
  final IconData icon;
}

final List<_KeywordIcon> _keywordIcons = [
  _KeywordIcon(
    RegExp(r'\b(museum|museo|musée|musee)\b'),
    Icons.museum,
  ),
  _KeywordIcon(
    RegExp(r'\b(airport|aéroport|aeroport|aeropuerto|aeroporto|flughafen)\b'),
    Icons.local_airport,
  ),
  _KeywordIcon(
    RegExp(r'\b(station|gare|estación|estacion|bahnhof|stazione)\b'),
    Icons.directions_transit,
  ),
  _KeywordIcon(
    RegExp(r'\b(hotel|hôtel|hostel|hostal|guest\s?house|posada|pensione)\b'),
    Icons.hotel,
  ),
  _KeywordIcon(
    RegExp(r'\b(park|parque|parc|parco)\b'),
    Icons.park,
  ),
  _KeywordIcon(
    RegExp(r'\b(restaurant|restaurante|ristorante)\b'),
    Icons.restaurant,
  ),
  _KeywordIcon(
    RegExp(r'\b(cafe|café|caffè)\b'),
    Icons.local_cafe,
  ),
  _KeywordIcon(
    RegExp(r'\b(hospital|hôpital|krankenhaus|ospedale)\b'),
    Icons.local_hospital,
  ),
  _KeywordIcon(
    RegExp(r'\b(school|colegio|escuela|école|ecole|scuola|schule)\b'),
    Icons.school,
  ),
  _KeywordIcon(
    RegExp(r'\b(university|universidad|université|università|universität)\b'),
    Icons.cast_for_education,
  ),
  _KeywordIcon(
    RegExp(r'\b(church|iglesia|église|eglise|chiesa|kirche|cathedral|catedral|cathédrale|cattedrale|dom)\b'),
    Icons.church,
  ),
  _KeywordIcon(
    RegExp(r'\b(mosque|mezquita|mosquée|moschea|moschee)\b'),
    Icons.mosque,
  ),
  _KeywordIcon(
    RegExp(r'\b(castle|castillo|château|castello|schloss|burg)\b'),
    Icons.castle,
  ),
  _KeywordIcon(
    RegExp(r'\b(beach|playa|plage|spiaggia|strand)\b'),
    Icons.beach_access,
  ),
  _KeywordIcon(
    RegExp(r'\b(mountain|montaña|montagne|montagna|berg|peak|pico|cima|gipfel)\b'),
    Icons.terrain,
  ),
];
