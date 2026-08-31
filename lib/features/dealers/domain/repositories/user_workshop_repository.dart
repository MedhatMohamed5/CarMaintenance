import '../entities/dealer.dart';
import '../entities/dealer_ratings.dart';

/// The workshops the driver added themselves — and nothing else.
///
/// **This used to be `DealerRepository` and used to hold the whole
/// directory.** The standard list was written into the same store as the
/// driver's own rows and the two were told apart by a flag, which meant the
/// published directory was duplicated onto every device, a stale copy could
/// outlive a publish, and the merge happened in storage where nobody could see
/// it. The standard list now comes from Remote Config and is never persisted;
/// this holds only what the driver created, which is the only part that is
/// genuinely theirs to keep.
abstract interface class UserWorkshopRepository {
  /// Newest first is not meaningful here — the merged list is sorted for
  /// display in one place, so this returns them as stored.
  List<Dealer> getAll();

  Future<void> upsert(Dealer workshop);

  Future<void> delete(String id);

  /// Drops rows left behind by the version that stored the standard directory
  /// locally, and hands back any ratings those rows were carrying.
  ///
  /// **The salvage is the point, not the delete.** Ratings used to live as two
  /// fields on the stored workshop, so deleting the stale rows would take every
  /// score the driver had given with them — silently, on upgrade, with nothing
  /// on screen to suggest anything had been lost. The caller writes what comes
  /// back into the device's ratings map.
  ///
  /// Runs once per launch and is cheap when there is nothing to do. Not gated
  /// on a stored "done" flag: a device that upgrades, downgrades and upgrades
  /// again would set the flag on the first pass and then keep the second batch
  /// of stale rows forever.
  Future<Map<String, DealerRating>> purgeLegacyStandardRows();
}
