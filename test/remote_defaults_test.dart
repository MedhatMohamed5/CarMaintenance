import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_care/core/remote/remote_defaults.dart';
import 'package:vehicle_care/features/fuel/domain/entities/fuel_price_defaults.dart';
import 'package:vehicle_care/features/fuel/domain/entities/fuel_type.dart';

FuelPriceDefaults pricesOf(Map<String, double> raw) =>
    FuelPriceDefaults.fromJson(raw);

void main() {
  group('published defaults', () {
    test('a driver price wins for its grade and leaves the others alone', () {
      final published = pricesOf({
        'octane92': 13.75,
        'octane95': 15.5,
        'diesel': 11.0,
      });
      final own = pricesOf({'octane92': 14.0});

      final resolved = published.mergedWith(own);

      expect(resolved.priceOf(FuelType.octane92), 14.0);
      expect(resolved.priceOf(FuelType.octane95), 15.5);
      expect(resolved.priceOf(FuelType.diesel), 11.0);
    });

    test('an empty override set changes nothing', () {
      final published = pricesOf({'octane92': 13.75});
      expect(published.mergedWith(FuelPriceDefaults.empty), published);
    });

    test('published rates apply where the driver has set nothing', () {
      final resolved = FuelPriceDefaults.empty.mergedWith(
        pricesOf({'diesel': 11.0}),
      );
      expect(resolved.priceOf(FuelType.diesel), 11.0);
    });

    test('one malformed workshop does not cost the rest of the document', () {
      final defaults = RemoteDefaults.fromJson({
        'version': 4,
        'fuelPrices': {'octane92': 13.75},
        'workshops': [
          {'id': 'a', 'name': 'Good', 'city': 'Cairo', 'kind': 'towing'},
          // No id at all — unusable, and must not take the others with it.
          {'name': 'Nameless'},
          'not a map',
          {'id': 'b', 'name': 'Also good', 'city': 'Giza'},
        ],
      });

      expect(defaults.version, 4);
      expect(defaults.fuelPrices.priceOf(FuelType.octane92), 13.75);
      expect(defaults.workshops.map((w) => w.id), ['a', 'b']);
    });

    test('a published row is never marked as the driver own work', () {
      final defaults = RemoteDefaults.fromJson({
        'workshops': [
          // Even when the document claims otherwise: the flags are what protect
          // a local edit from the next publish, so the publish cannot set them.
          {'id': 'a', 'name': 'X', 'isUserAdded': true, 'isUserEdited': true},
        ],
      });

      expect(defaults.workshops.single.isUserOwned, isFalse);
    });

    test('a document with nothing usable reads as empty', () {
      expect(RemoteDefaults.fromJson(const {}).isEmpty, isTrue);
    });

    test('survives a round trip through JSON', () {
      final original = RemoteDefaults.fromJson({
        'version': 2,
        'fuelPrices': {'octane95': 15.5},
        'workshops': [
          {'id': 'a', 'name': 'X', 'city': 'Cairo', 'kind': 'tireShop'},
        ],
      });

      final restored = RemoteDefaults.fromJson(original.toJson());

      expect(restored.version, 2);
      expect(restored.fuelPrices.priceOf(FuelType.octane95), 15.5);
      expect(restored.workshops.single.id, 'a');
    });
  });
}
