import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/fuel_local_datasource.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../data/repositories/firestore_fuel_repository.dart';
import '../../data/repositories/fuel_repository_impl.dart';
import '../../domain/repositories/fuel_repository.dart';
import '../../domain/usecases/calculate_fuel_stats.dart';

/// Kept free of any dependency on the vehicles feature so other features can
/// reach the repository without creating an import cycle.
final fuelLocalDataSourceProvider = Provider<FuelLocalDataSource>(
  (ref) => FuelLocalDataSource(),
);

final fuelRepositoryProvider = Provider<FuelRepository>((ref) {
  if (ref.watch(isRemoteBackendProvider)) {
    final repository = FirestoreFuelRepository(
      ref.watch(firestorePathsProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return FuelRepositoryImpl(ref.watch(fuelLocalDataSourceProvider));
});

final calculateFuelStatsProvider = Provider<CalculateFuelStats>(
  (ref) => const CalculateFuelStats(),
);
