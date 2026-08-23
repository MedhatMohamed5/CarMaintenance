import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vehicle_catalog.dart';

/// The catalogue is a compile-time constant. The provider exists so the
/// add-vehicle sheet never constructs or copies the map inside `build` —
/// that allocation on every keystroke is what made the web form hitch.
final vehicleCatalogProvider = Provider<VehicleCatalog>(
  (ref) => const VehicleCatalog(),
);

final vehicleMakesProvider = Provider<List<CatalogName>>(
  (ref) => ref.watch(vehicleCatalogProvider).makes,
);

/// Models for [make], or an empty list when the make is unknown / "Other".
/// Family-keyed so switching make does not rebuild the make picker.
final vehicleModelsProvider = Provider.family<List<CatalogName>, String?>((
  ref,
  make,
) {
  if (make == null || make == VehicleCatalog.otherKey) {
    return const <CatalogName>[];
  }
  return ref.watch(vehicleCatalogProvider).modelsFor(make);
});
