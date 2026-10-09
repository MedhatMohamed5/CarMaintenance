import 'package:equatable/equatable.dart';

import 'consumable_part.dart';

/// What kind of work a maintenance record is.
///
/// **Three classes, not one scale.** The first four are the preventive
/// roadmap: stops the schedule plans, in ascending weight, each one closing a
/// phase and moving the next target. [routine] is upkeep between those stops —
/// topping up coolant, setting tyre pressure — maintenance, not a repair, but
/// nothing the roadmap plans. [corrective] is work the car demanded rather than
/// work the calendar did. Both of the last two belong here rather than in
/// expenses because they do what a service does: they happen at an odometer
/// reading, often at a workshop, and can fit parts whose wear has to be reset.
///
/// The split runs through the whole app from this one enum: what the schedule
/// may anchor on ([isScheduled]), what "maintenance spend" means on a chart
/// ([isMaintenance]), and which bucket a figure lands in.
enum ServiceTier {
  firstCheck(
    l10nKey: 'firstCheckService',
    colorValue: 0xFF818CF8,
    iconKey: 'service',
  ),
  minor(l10nKey: 'minorService', colorValue: 0xFF34D399, iconKey: 'service'),
  important(
    l10nKey: 'importantService',
    colorValue: 0xFFF59E0B,
    iconKey: 'service',
  ),
  major(l10nKey: 'majorService', colorValue: 0xFF22D3EE, iconKey: 'service'),

  /// Small upkeep between scheduled services — water, air, a top-up, a bulb.
  ///
  /// Like [corrective], **never produced by [ServiceCatalog]** and never part
  /// of the roadmap: topping up coolant is not the 10,000 km service arriving
  /// early. Unlike it, its money is maintenance, not repairs.
  routine(
    l10nKey: 'routineCare',
    colorValue: 0xFF2DD4BF,
    iconKey: 'serviceRoutine',
  ),

  /// An unscheduled repair — a breakdown, a fault, anything the car asked for
  /// out of turn.
  ///
  /// **Never produced by [ServiceCatalog].** The roadmap is built from the four
  /// above; this one only ever arrives from a driver choosing it on the form,
  /// which is why nothing that walks the schedule has to special-case it beyond
  /// refusing to anchor on it.
  corrective(
    l10nKey: 'correctiveService',
    colorValue: 0xFFF87171,
    iconKey: 'serviceRepair',
  );

  const ServiceTier({
    required this.l10nKey,
    required this.colorValue,
    required this.iconKey,
  });

  final String l10nKey;
  final int colorValue;

  /// Resolved through `AppIcons.of`, the same way [ConsumablePart] and
  /// `ExpenseCategory` do it — this enum was the only one drawing records with
  /// an icon hard-coded at each call site, which is why a repair looked
  /// identical to a scheduled service everywhere except the one place the
  /// exception had been written out by hand.
  ///
  /// The four preventive tiers deliberately share one key. They are the same
  /// kind of event at different weights, already separated by colour and label;
  /// four icons would be decoration competing with the one distinction that
  /// matters here.
  final String iconKey;

  bool get isCorrective => this == ServiceTier.corrective;

  bool get isRoutine => this == ServiceTier.routine;

  /// Part of the preventive roadmap: plannable, phase-closing, and a valid
  /// anchor for projecting the next stop.
  ///
  /// **Named, not "everything but repairs".** It used to be `!isCorrective`,
  /// which was the same thing while repairs were the only other class. With
  /// [routine] added that would have let a coolant top-up close a roadmap
  /// stop and move the next service's target.
  bool get isScheduled => scheduled.contains(this);

  /// Counts as maintenance money rather than repairs: the roadmap and the
  /// routine upkeep between its stops.
  bool get isMaintenance => !isCorrective;

  /// The tiers the periodic schedule is built from, in ascending weight.
  ///
  /// Anywhere that means "the roadmap" must iterate this rather than [values],
  /// which also carries the routine and repair classes.
  static const List<ServiceTier> scheduled = [
    firstCheck,
    minor,
    important,
    major,
  ];
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
