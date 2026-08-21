import '../entities/dealer.dart';

abstract interface class DealerRepository {
  Stream<List<Dealer>> watchAll();

  List<Dealer> getAll();

  /// Case-insensitive match across name, brand, city and address.
  List<Dealer> search(String query, {DealerKind? kind, String? city});

  Future<void> upsert(Dealer dealer);

  Future<void> delete(String id);

  Future<void> rate(String id, double rating);

  Future<void> syncSeedData();
}
