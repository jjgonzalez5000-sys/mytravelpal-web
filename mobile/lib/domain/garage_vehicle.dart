import 'package:flutter/foundation.dart';

/// One entry in the user's "garage" — a saved vehicle they can pick
/// per-trip.
///
/// The `id` is server-generated (UUID). `modelId` points at an entry
/// in the curated catalogue served by `/v1/vehicles`; the client
/// resolves it via `vehicleCatalogueProvider` to render the make /
/// model / tank stats on the row.
///
/// Persisted server-side inside the same `profile` JSONB blob under
/// a `garage` array key. The mobile side keeps a Riverpod cache of
/// the last-fetched list and pushes mutations to the backend on
/// every edit.
@immutable
class GarageVehicle {
  const GarageVehicle({
    required this.id,
    required this.name,
    required this.modelId,
    required this.defaultTankPercent,
    this.notes,
  });

  final String id;
  final String name;
  final String modelId;
  final int defaultTankPercent;
  final String? notes;

  GarageVehicle copyWith({
    String? name,
    String? modelId,
    int? defaultTankPercent,
    Object? notes = _sentinel,
  }) =>
      GarageVehicle(
        id: id,
        name: name ?? this.name,
        modelId: modelId ?? this.modelId,
        defaultTankPercent: defaultTankPercent ?? this.defaultTankPercent,
        notes: notes == _sentinel ? this.notes : notes as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model_id': modelId,
        'default_tank_percent': defaultTankPercent,
        if (notes != null) 'notes': notes,
      };

  factory GarageVehicle.fromJson(Map<String, dynamic> j) => GarageVehicle(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        modelId: (j['model_id'] as String?) ?? '',
        defaultTankPercent:
            (j['default_tank_percent'] as num?)?.toInt() ?? 100,
        notes: j['notes'] as String?,
      );
}

const Object _sentinel = Object();
