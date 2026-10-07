import '../api/api_client.dart';

/// Lightweight fire-and-forget service that bumps implicit counters
/// in the user's learning blob on the server.
///
/// All methods swallow errors — caller behaviour must never depend on
/// these writes landing. They inform the AI context progressively;
/// missing a write just means slightly less context, not a crash.
class UserLearningTracker {
  UserLearningTracker._();

  /// Call after every successful plan. Increments the trip counter
  /// and records which country/region the user tends to route through.
  static Future<void> onTripPlanned({
    required String? country,
    required bool isMultiDay,
    required ApiClient api,
  }) async {
    try {
      final existing = await api.getUserLearning();
      final updated = Map<String, dynamic>.from(existing);

      // Increment total trips planned counter.
      final trips = (updated['trips_planned'] as int? ?? 0) + 1;
      updated['trips_planned'] = trips;

      // Track multi-day usage.
      if (isMultiDay) {
        final md = (updated['multi_day_trips'] as int? ?? 0) + 1;
        updated['multi_day_trips'] = md;
      }

      // Record country visits (up to 20 unique entries).
      if (country != null && country.isNotEmpty) {
        final countries =
            List<String>.from(updated['visited_countries'] as List? ?? []);
        if (!countries.contains(country)) {
          if (countries.length < 20) countries.add(country);
          updated['visited_countries'] = countries;
        }
      }

      await api.putUserLearning(updated);
    } catch (_) {
      // Fire-and-forget.
    }
  }

  /// Call when the user invokes a specific Companion feature.
  /// Increments a per-feature use counter in the learning blob.
  static Future<void> onFeatureUsed(
    String feature,
    ApiClient api,
  ) async {
    try {
      final existing = await api.getUserLearning();
      final updated = Map<String, dynamic>.from(existing);
      final features =
          Map<String, dynamic>.from(updated['feature_uses'] as Map? ?? {});
      features[feature] = ((features[feature] as int?) ?? 0) + 1;
      updated['feature_uses'] = features;
      await api.putUserLearning(updated);
    } catch (_) {
      // Fire-and-forget.
    }
  }
}
