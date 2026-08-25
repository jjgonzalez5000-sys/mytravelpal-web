import 'package:flutter/foundation.dart';

import '../api/models.dart';

/// A user-labeled saved location — "Home", "Work", "Grandma's", etc.
///
/// Distinct from [Hotel]/[Restaurant] favorites which come pre-populated
/// from a specific POI type. These are free-form places the user picks
/// from any geocode result so they can be reused as trip endpoints.
@immutable
class FavoritePlace {
  const FavoritePlace({required this.label, required this.place});

  final String label;
  final GeocodeResult place;

  Map<String, dynamic> toJson() => {
        'label': label,
        'place': place.toJson(),
      };

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    final placeJson = json['place'];
    if (placeJson is! Map<String, dynamic>) {
      throw ArgumentError('FavoritePlace.place missing');
    }
    return FavoritePlace(
      label: json['label'] as String,
      place: GeocodeResult.fromJson(placeJson),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FavoritePlace && other.label == label && other.place == place;

  @override
  int get hashCode => Object.hash(label, place);
}
