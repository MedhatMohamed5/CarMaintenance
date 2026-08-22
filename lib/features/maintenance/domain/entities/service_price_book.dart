import 'consumable_part.dart';
import 'service_catalog.dart';
import 'service_milestone.dart';

/// Relative price index. Values are unit costs at a multiplier of 1.0 and are
/// deliberately neutral reference points, not quoted market prices — users
/// scale them with [ServicePriceBook.multiplier] or replace any single line
/// through [ServicePriceBook.overrides].
class BasePriceIndex {
  const BasePriceIndex._();

  static const Map<String, double> parts = {
    'engineOil': 900,
    'oilFilter': 180,
    'drainPlugGasket': 40,
    'airFilter': 260,
    'cabinFilter': 240,
    'fuelFilter': 420,
    'sparkPlugs': 700,
    'brakePads': 1200,
    'brakeFluid': 350,
    'coolant': 400,
    'powerSteeringFluid': 320,
    'transmissionOil': 1400,
    'transmissionFilter': 600,
    'tires': 6000,
    'battery': 3200,
    'timingBelt': 3500,
    'driveBelt': 800,
  };

  static const Map<String, double> supplies = {
    ServiceCatalog.supplyCleaners: 150,
  };

  static const Map<ServiceTier, double> labour = {
    ServiceTier.firstCheck: 0,
    ServiceTier.minor: 300,
    ServiceTier.important: 550,
    ServiceTier.major: 900,
  };

  static double unit(String key) => parts[key] ?? supplies[key] ?? 0;
}

class ServicePriceLine {
  const ServicePriceLine({
    required this.key,
    required this.l10nKey,
    required this.amount,
    required this.isCustom,
    this.optional = false,
  });

  final String key;
  final String l10nKey;
  final double amount;
  final bool isCustom;
  final bool optional;
}

class ServiceCostEstimate {
  const ServiceCostEstimate({
    required this.lines,
    required this.optionalLines,
    required this.labour,
    required this.spread,
    required this.isComplimentary,
  });

  const ServiceCostEstimate.free()
    : lines = const [],
      optionalLines = const [],
      labour = 0,
      spread = 0,
      isComplimentary = true;

  final List<ServicePriceLine> lines;

  /// Offered but never billed into the headline figure.
  final List<ServicePriceLine> optionalLines;

  final double labour;

  /// Fractional band applied either side of the midpoint, so the UI shows a
  /// range instead of a false-precision figure.
  final double spread;

  final bool isComplimentary;

  double get parts => lines.fold<double>(0, (s, l) => s + l.amount);

  double get midpoint => isComplimentary ? 0 : parts + labour;

  double get low => midpoint * (1 - spread);

  double get high => midpoint * (1 + spread);

  double get optionalTotal =>
      optionalLines.fold<double>(0, (s, l) => s + l.amount);
}

class ServicePriceBook {
  const ServicePriceBook({
    this.multiplier = 1.0,
    this.overrides = const {},
    this.spread = 0.15,
  });

  /// Scales the whole index to local market rates.
  final double multiplier;

  /// Per-key user prices that bypass the index entirely.
  final Map<String, double> overrides;

  final double spread;

  static const double minMultiplier = 0.25;
  static const double maxMultiplier = 5.0;

  bool isCustom(String key) => overrides.containsKey(key);

  double priceFor(String key) =>
      overrides[key] ?? BasePriceIndex.unit(key) * multiplier;

  double labourFor(ServiceTier tier) =>
      overrides['labour_${tier.name}'] ??
      (BasePriceIndex.labour[tier] ?? 0) * multiplier;

  ServicePriceBook copyWith({
    double? multiplier,
    Map<String, double>? overrides,
    double? spread,
  }) => ServicePriceBook(
    multiplier: (multiplier ?? this.multiplier).clamp(
      minMultiplier,
      maxMultiplier,
    ),
    overrides: overrides ?? this.overrides,
    spread: spread ?? this.spread,
  );

  ServicePriceBook withOverride(String key, double? amount) {
    final next = Map<String, double>.from(overrides);
    if (amount == null || amount <= 0) {
      next.remove(key);
    } else {
      next[key] = amount;
    }
    return copyWith(overrides: next);
  }

  ServiceCostEstimate estimate(ServiceMilestone milestone) {
    if (milestone.isComplimentary) {
      return ServiceCostEstimate(
        lines: const [],
        optionalLines: _linesFor(milestone.conditionalParts, optional: true),
        labour: 0,
        spread: spread,
        isComplimentary: true,
      );
    }

    final lines = <ServicePriceLine>[
      ..._linesFor(milestone.replaceParts),
      for (final supply in milestone.inspectKeys)
        if (BasePriceIndex.supplies.containsKey(supply))
          ServicePriceLine(
            key: supply,
            l10nKey: supply,
            amount: priceFor(supply),
            isCustom: isCustom(supply),
          ),
    ];

    return ServiceCostEstimate(
      lines: lines,
      optionalLines: _linesFor(milestone.conditionalParts, optional: true),
      labour: labourFor(milestone.tier),
      spread: spread,
      isComplimentary: false,
    );
  }

  List<ServicePriceLine> _linesFor(
    List<ConsumablePart> parts, {
    bool optional = false,
  }) => [
    for (final part in parts)
      ServicePriceLine(
        key: part.id,
        l10nKey: part.l10nKey,
        amount: priceFor(part.id),
        isCustom: isCustom(part.id),
        optional: optional,
      ),
  ];

  Map<String, dynamic> toJson() => {
    'multiplier': multiplier,
    'spread': spread,
    'overrides': overrides,
  };

  factory ServicePriceBook.fromJson(Map<String, dynamic> json) =>
      ServicePriceBook(
        multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
        spread: (json['spread'] as num?)?.toDouble() ?? 0.15,
        overrides:
            (json['overrides'] as Map?)?.map(
              (k, v) => MapEntry('$k', (v as num).toDouble()),
            ) ??
            const {},
      );
}
