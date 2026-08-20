import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'storage/trip_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// Provides the [TripStorage] singleton. Must be overridden at app boot
/// (see `main.dart`) with the actual instance so the async open completes
/// before the tree is built.
final tripStorageProvider = Provider<TripStorage>(
  (ref) => throw UnimplementedError(
    'tripStorageProvider must be overridden at ProviderScope',
  ),
);
