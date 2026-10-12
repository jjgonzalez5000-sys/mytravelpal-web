import '../api/models.dart' show LatLon;

/// What kind of stop a saved place is. Drives the icon and, later, the
/// kind of suggestion the AI layer pairs it with.
enum MyPlaceCategory {
  food,
  viewpoint,
  culture,
  history,
  nature,
  beach,
  kids,
  shopping,
  other,
}

/// A place the driver likes to stop at, saved once and offered whenever a
/// route passes near it. Unlike [FavoritePlace] (Home / Work shortcuts for
/// picking an origin or destination) this is a stop worth making.
class MyPlace {
  const MyPlace({
    required this.id,
    required this.name,
    required this.coordinate,
    required this.createdAt,
    this.category = MyPlaceCategory.other,
    this.note = '',
  });

  final String id;
  final String name;
  final LatLon coordinate;
  final DateTime createdAt;
  final MyPlaceCategory category;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': coordinate.lat,
        'lon': coordinate.lon,
        'category': category.name,
        'note': note,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  /// Throws [FormatException] when the entry cannot describe a place
  /// (missing id / name / position), so callers can skip corrupt rows.
  factory MyPlace.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final lat = json['lat'];
    final lon = json['lon'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw const FormatException('MyPlace: missing id or name');
    }
    if (lat is! num || lon is! num) {
      throw const FormatException('MyPlace: missing position');
    }
    final categoryName = json['category'];
    return MyPlace(
      id: id,
      name: name,
      coordinate: LatLon(lat: lat.toDouble(), lon: lon.toDouble()),
      category: MyPlaceCategory.values.firstWhere(
        (c) => c.name == categoryName,
        orElse: () => MyPlaceCategory.other,
      ),
      note: json['note'] is String ? json['note'] as String : '',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }

  MyPlace copyWith({
    String? name,
    MyPlaceCategory? category,
    String? note,
  }) =>
      MyPlace(
        id: id,
        name: name ?? this.name,
        coordinate: coordinate,
        createdAt: createdAt,
        category: category ?? this.category,
        note: note ?? this.note,
      );
}
