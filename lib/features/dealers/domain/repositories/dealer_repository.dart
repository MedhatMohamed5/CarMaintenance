import '../entities/dealer.dart';

abstract interface class DealerRepository {
  Stream<List<Dealer>> watchAll();

  List<Dealer> getAll();

  /// Case-insensitive match across name, brand, city and address.
  List<Dealer> search(String query, {DealerKind? kind, String? city});

  Future<void> upsert(Dealer dealer);

  Future<void> delete(String id);

  Future<void> rate(String id, double rating);

  /// Replaces the published rows with [defaults], leaving everything the
  /// driver owns untouched.
  ///
  /// Takes the list rather than reaching for a bundled constant, because where
  /// the directory comes from is not the repository's decision any more: it is
  /// the published document when one has arrived, and the bundled seed when
  /// none has.
  Future<void> syncDefaults(List<Dealer> defaults);

  /// Directory support number, independent of any one workshop row.
  String get authorizedHotline;
}
