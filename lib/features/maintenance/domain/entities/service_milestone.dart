import 'package:equatable/equatable.dart';

import 'consumable_part.dart';

/// How heavy a periodic service is — drives both the copy and the accent
/// colour of its card.
enum ServiceTier {
  firstCheck(l10nKey: 'firstCheckService', colorValue: 0xFF818CF8),
  minor(l10nKey: 'minorService', colorValue: 0xFF34D399),
  important(l10nKey: 'importantService', colorValue: 0xFFF59E0B),
  major(l10nKey: 'majorService', colorValue: 0xFF22D3EE);

  const ServiceTier({required this.l10nKey, required this.colorValue});

  final String l10nKey;
  final int colorValue;
}

/// One stop on the periodic-service roadmap (10k, 20k, 30k …), expressed as
/// what gets *replaced* and what merely gets *inspected*.
class ServiceMilestone extends Equatable {
  const ServiceMilestone({
    required this.targetOdometer,
    required this.tier,
    required this.replaceParts,
    required this.inspectKeys,
    required this.recommendedMonths,
    this.conditionalParts = const [],
  });

  final int targetOdometer;
  final ServiceTier tier;

  /// Parts always changed at this milestone. Logging the service resets each
  /// of their health bars.
  final List<ConsumablePart> replaceParts;

  /// Parts changed only when worn — shown with an "if needed" qualifier and
  /// not auto-reset.
  final List<ConsumablePart> conditionalParts;

  /// Localisation keys of the visual/mechanical checks (suspension, tightening,
  /// cooling circuit …).
  final List<String> inspectKeys;

  /// Calendar equivalent of the distance target, for drivers who cover little
  /// ground: the service is due at whichever comes first.
  final int recommendedMonths;

  String get id => 'ms_$targetOdometer';

  @override
  List<Object?> get props => [
    targetOdometer,
    tier,
    replaceParts,
    conditionalParts,
    inspectKeys,
    recommendedMonths,
  ];
}
