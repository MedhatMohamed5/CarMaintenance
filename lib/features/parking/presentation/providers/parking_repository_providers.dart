import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/backend_providers.dart';
import '../../data/datasources/parking_local_datasource.dart';
import '../../data/repositories/firestore_parking_repository.dart';
import '../../data/repositories/parking_repository_impl.dart';
import '../../domain/repositories/parking_repository.dart';

final parkingLocalDataSourceProvider = Provider<ParkingLocalDataSource>(
  (ref) => ParkingLocalDataSource(),
);

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  if (ref.watch(isRemoteBackendProvider)) {
    final repository = FirestoreParkingRepository(
      ref.watch(firestorePathsProvider),
      mirror: ParkingRepositoryImpl(ref.watch(parkingLocalDataSourceProvider)),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return ParkingRepositoryImpl(ref.watch(parkingLocalDataSourceProvider));
});
