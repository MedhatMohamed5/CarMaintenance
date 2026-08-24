import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../data/datasources/maintenance_local_datasource.dart';
import '../../../../core/providers/backend_providers.dart';
import '../../data/repositories/firestore_maintenance_repository.dart';
import '../../data/repositories/maintenance_repository_impl.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/usecases/calculate_parts_health.dart';
import '../../domain/usecases/predict_services.dart';

final maintenanceLocalDataSourceProvider = Provider<MaintenanceLocalDataSource>(
  (ref) => MaintenanceLocalDataSource(),
);

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  if (ref.watch(isRemoteBackendProvider)) {
    final repository = FirestoreMaintenanceRepository(
      ref.watch(firestorePathsProvider),
      uuid: ref.watch(uuidProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  return MaintenanceRepositoryImpl(
    ref.watch(maintenanceLocalDataSourceProvider),
    uuid: ref.watch(uuidProvider),
  );
});

final calculatePartsHealthProvider = Provider<CalculatePartsHealth>(
  (ref) => const CalculatePartsHealth(),
);

final predictServicesProvider = Provider<PredictServices>(
  (ref) => const PredictServices(),
);
