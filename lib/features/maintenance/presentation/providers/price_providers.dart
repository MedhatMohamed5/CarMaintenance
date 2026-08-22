import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../domain/entities/service_milestone.dart';
import '../../domain/entities/service_price_book.dart';

class PriceBookNotifier extends Notifier<ServicePriceBook> {
  @override
  ServicePriceBook build() {
    final raw = ref.read(preferencesStoreProvider).priceBook;
    if (raw == null || raw.isEmpty) return const ServicePriceBook();
    try {
      return ServicePriceBook.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ServicePriceBook();
    }
  }

  Future<void> setMultiplier(double value) =>
      _persist(state.copyWith(multiplier: value));

  Future<void> setSpread(double value) =>
      _persist(state.copyWith(spread: value.clamp(0.0, 0.5)));

  Future<void> setOverride(String key, double? amount) =>
      _persist(state.withOverride(key, amount));

  Future<void> reset() => _persist(const ServicePriceBook());

  Future<void> _persist(ServicePriceBook next) async {
    state = next;
    await ref
        .read(preferencesStoreProvider)
        .setPriceBook(jsonEncode(next.toJson()));
  }
}

final priceBookProvider = NotifierProvider<PriceBookNotifier, ServicePriceBook>(
  PriceBookNotifier.new,
);

final serviceEstimateProvider =
    Provider.family<ServiceCostEstimate, ServiceMilestone>(
      (ref, milestone) => ref.watch(priceBookProvider).estimate(milestone),
    );
