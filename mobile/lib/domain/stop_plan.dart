import '../api/models.dart' show LatLon;
import 'my_place.dart';

/// Where an extra stop came from. Drives the "IA" tag in the day plan.
enum StopSource { ai, myPlace, custom }

/// An extra stop the driver chose to make: an AI suggestion, a saved place
/// or a place picked by hand. [key] is the same `place:<id>` key the added
/// stops maps already use, so totals and the replan request keep working.
class StopPlan {
  const StopPlan({
    required this.key,
    required this.name,
    required this.coordinate,
    required this.source,
    required this.visitMinutes,
    required this.detourMinutes,
    required this.alongKm,
    this.category = MyPlaceCategory.other,
    this.plannedAt,
    this.why = '',
    this.userEdited = false,
  });

  final String key;
  final String name;
  final LatLon coordinate;
  final StopSource source;
  final int visitMinutes;
  final int detourMinutes;

  /// Km from the origin measured along the route where the stop hangs off.
  final double alongKm;
  final MyPlaceCategory category;

  /// Approximate local time the driver wants to be there.
  final DateTime? plannedAt;
  final String why;

  /// The driver moved the time by hand: a replan keeps it while it still
  /// falls inside the stop's day instead of picking a new slot.
  final bool userEdited;

  bool get isAi => source == StopSource.ai;
  int get totalMinutes => visitMinutes + detourMinutes;

  StopPlan copyWith({
    DateTime? plannedAt,
    int? visitMinutes,
    double? alongKm,
    bool? userEdited,
  }) =>
      StopPlan(
        key: key,
        name: name,
        coordinate: coordinate,
        source: source,
        visitMinutes: visitMinutes ?? this.visitMinutes,
        detourMinutes: detourMinutes,
        alongKm: alongKm ?? this.alongKm,
        category: category,
        plannedAt: plannedAt ?? this.plannedAt,
        why: why,
        userEdited: userEdited ?? this.userEdited,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'lat': coordinate.lat,
        'lon': coordinate.lon,
        'source': source.name,
        'visit_minutes': visitMinutes,
        'detour_minutes': detourMinutes,
        'along_km': alongKm,
        'category': category.name,
        if (plannedAt != null) 'planned_at': plannedAt!.toIso8601String(),
        if (why.isNotEmpty) 'why': why,
        if (userEdited) 'user_edited': true,
      };

  /// Throws [FormatException] for an entry that cannot describe a stop, so a
  /// corrupt saved trip skips the row instead of failing to open.
  factory StopPlan.fromJson(Map<String, dynamic> j) {
    final key = j['key'];
    final name = j['name'];
    final lat = j['lat'];
    final lon = j['lon'];
    if (key is! String || key.isEmpty || name is! String || name.isEmpty) {
      throw const FormatException('StopPlan: missing key or name');
    }
    if (lat is! num || lon is! num) {
      throw const FormatException('StopPlan: missing position');
    }
    return StopPlan(
      key: key,
      name: name,
      coordinate: LatLon(lat: lat.toDouble(), lon: lon.toDouble()),
      source: StopSource.values.firstWhere(
        (s) => s.name == j['source'],
        orElse: () => StopSource.custom,
      ),
      visitMinutes: (j['visit_minutes'] as num?)?.toInt() ?? 30,
      detourMinutes: (j['detour_minutes'] as num?)?.toInt() ?? 0,
      alongKm: (j['along_km'] as num?)?.toDouble() ?? 0,
      category: MyPlaceCategory.values.firstWhere(
        (c) => c.name == j['category'],
        orElse: () => MyPlaceCategory.other,
      ),
      plannedAt: DateTime.tryParse('${j['planned_at']}'),
      why: j['why'] is String ? j['why'] as String : '',
      userEdited: j['user_edited'] == true,
    );
  }
}
