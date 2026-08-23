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
///
/// [phaseIndex] is the stop's position in the sequence (0 = the complimentary
/// break-in check, 1 = the first 10,000 km interval, 2 = the second, …). It is
/// the stable identity of a stop — [targetOdometer] is not: it is recomputed
/// relative to when the *previous* stop actually closed, so it drifts away
/// from the nominal `phaseIndex * intervalKm` grid the moment a service is
/// logged early or late.
class ServiceMilestone extends Equatable {
  const ServiceMilestone({
    required this.phaseIndex,
    required this.targetOdometer,
    required this.tier,
    required this.replaceParts,
    required this.inspectKeys,
    required this.recommendedMonths,
    this.conditionalParts = const [],
    this.isComplimentary = false,
  });

  final int phaseIndex;

  /// The odometer this stop is currently projected or known to fall due at.
  /// Dynamic: derived from the last completed phase's real odometer plus one
  /// interval, not a fixed multiple of 10,000.
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

  /// Free-of-charge stop: excluded from every cost estimate.
  final bool isComplimentary;

  /// Stable across every recalculation — unlike [targetOdometer], which
  /// moves whenever an earlier phase closes off-grid.
  String get id => 'ms_p$phaseIndex';

  @override
  List<Object?> get props => [
    phaseIndex,
    targetOdometer,
    tier,
    replaceParts,
    conditionalParts,
    inspectKeys,
    recommendedMonths,
    isComplimentary,
  ];
}
