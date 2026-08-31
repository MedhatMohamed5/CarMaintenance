import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../features/dealers/data/models/dealer_model.dart';
import '../../features/dealers/domain/entities/dealer.dart';
import '../../features/fuel/domain/entities/fuel_price_defaults.dart';
import '../firebase/crash_reporter.dart';

/// The admin-defined values, as published rather than as compiled in.
///
/// **Two things in this app go stale on a timescale the release cycle cannot
/// follow.** Egyptian pump prices move by government decision, sometimes twice
/// in a year; the workshop directory gains and loses branches continuously.
/// Both used to be baked into the binary, so correcting either meant a store
/// release and then weeks of waiting while the app confidently pre-filled a
/// fuel entry with last year's rate.
///
/// These are **defaults only, and the app never writes to them**. What a driver
/// sets for themselves lives in their own account and wins; see
/// `fuelPriceOverridesProvider` and `userWorkshopsProvider`.
class RemoteDefaults extends Equatable {
  const RemoteDefaults({
    this.fuelPrices = FuelPriceDefaults.empty,
    this.workshops = const [],
    this.hotline,
    this.isResolved = false,
  });

  static const empty = RemoteDefaults();

  /// Admin-defined pump rates, one per grade. A grade the driver has not
  /// touched resolves to whichever figure is published here.
  final FuelPriceDefaults fuelPrices;

  /// The standard directory, exactly as published. Read-only in the app: a
  /// driver can add their own workshops beside these and delete those, but they
  /// cannot edit or remove a published one.
  final List<Dealer> workshops;

  /// The authorised network's support number.
  ///
  /// A plain string parameter rather than JSON — it is one phone number, and
  /// wrapping it in a document would only add a way to get it wrong. Null when
  /// nothing is published, which is the caller's cue to fall back.
  final String? hotline;

  /// Whether a fetch has been attempted this launch, so an empty set can be
  /// read as *"there is nothing published"* rather than *"we have not asked
  /// yet"*.
  ///
  /// **The two look identical and mean opposite things.** Without this the app
  /// had to guess on a cold start, and it guessed optimistically: it showed the
  /// bundled directory immediately and swapped it out a second later when the
  /// real one landed. Holding the fallback back until this is true is what
  /// removes that flash.
  final bool isResolved;

  bool get isEmpty =>
      fuelPrices.isEmpty && workshops.isEmpty && hotline == null;

  RemoteDefaults resolved() => withResolved(true);

  RemoteDefaults withResolved(bool value) => RemoteDefaults(
    fuelPrices: fuelPrices,
    workshops: workshops,
    hotline: hotline,
    isResolved: value,
  );

  /// Compared by value so re-reading an unchanged template is a no-op for every
  /// consumer — see `RemoteDefaultsNotifier.refresh`.
  @override
  List<Object?> get props => [fuelPrices, workshops, hotline, isResolved];

  /// Parses the two Remote Config parameters.
  ///
  /// **Tolerant by construction, because nothing here is under the app's
  /// control.** These strings are typed into the Firebase console by hand. One
  /// malformed workshop must not cost the driver the other forty, and a broken
  /// workshop list must not cost them the fuel prices — so the two parameters
  /// are parsed independently and a bad row is skipped rather than thrown.
  factory RemoteDefaults.parse({
    required String fuelPricesJson,
    required String workshopsJson,
    required String hotline,
  }) => RemoteDefaults(
    fuelPrices: _parseFuelPrices(fuelPricesJson),
    workshops: _parseWorkshops(workshopsJson),
    // Digits and dialling punctuation only. `LinkLauncher.dial` strips the
    // rest anyway, but an empty or whitespace-only parameter has to read as
    // "nothing published" rather than as a number that dials nowhere.
    hotline: hotline.trim().isEmpty ? null : hotline.trim(),
  );

  static FuelPriceDefaults _parseFuelPrices(String raw) {
    if (raw.trim().isEmpty) return FuelPriceDefaults.empty;
    try {
      return FuelPriceDefaults.fromJson(jsonDecode(raw));
    } catch (error, stack) {
      CrashReporter.recordError(
        error,
        stack,
        reason: 'remote config: fuel_prices is not valid JSON',
      );
      return FuelPriceDefaults.empty;
    }
  }

  static List<Dealer> _parseWorkshops(String raw) {
    if (raw.trim().isEmpty) return const [];

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error, stack) {
      CrashReporter.recordError(
        error,
        stack,
        reason: 'remote config: workshops is not valid JSON',
      );
      return const [];
    }
    if (decoded is! List) return const [];

    final workshops = <Dealer>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      // An id is what keeps a row stable across publishes, and what a rating is
      // filed under. A row without one cannot be used for either.
      if (map['id'] is! String || (map['id'] as String).isEmpty) continue;
      try {
        // Published rows are admin-defined whatever the document claims. The
        // flag is what the UI reads to decide whether delete is offered, so it
        // is set here rather than trusted from the payload.
        workshops.add(DealerModel.fromJson(map).copyWith(isUserAdded: false));
      } on Object {
        continue;
      }
    }
    return List<Dealer>.unmodifiable(workshops);
  }
}
