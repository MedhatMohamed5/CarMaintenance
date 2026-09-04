import 'package:equatable/equatable.dart';

import 'consumable_part.dart';
import 'service_catalog.dart';
import 'service_milestone.dart';

/// Where a service entry sits between being booked and being done.
///
/// Two states, not three. A draft would be a fourth thing to render, migrate
/// and reason about, and nothing in the app produces one: a sheet that is
/// abandoned is never saved, so an unfinished entry does not exist to have a
/// status.
enum ServiceStatus {
  /// An appointment. Nothing has been fitted, nothing has been paid, and the
  /// figures on it are intentions rather than facts.
  scheduled,

  /// Work that actually happened. The only state history is built from.
  completed,
}

/// A service — booked, or done.
///
/// **[status] decides what this record is allowed to affect.** A completed
/// record resets part health, closes its milestone phase and counts towards
/// spend; a scheduled one does none of those things, because none of it has
/// happened yet. Every consumer that means "history" reads
/// `completedRecordsProvider` rather than the raw list, and the repository
/// derives a `PartReplacement` only once the status says the work is real.
class MaintenanceRecord extends Equatable {
  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.title,
    required this.tier,
    this.status = ServiceStatus.completed,
    this.scheduledDate,
    this.completedDate,
    this.replacedParts = const [],
    this.inspectedKeys = const [],
    this.customItems = const [],
    this.cost = 0,
    this.workshopName,
    this.notes,
    this.milestoneOdometer,
    this.milestonePhase,
    this.invoiceAttachments = const [],
  });

  final String id;
  final String vehicleId;
  final DateTime date;
  final int odometer;
  final String title;
  final ServiceTier tier;

  /// Booked, or done. Defaults to [ServiceStatus.completed] so every record
  /// written before bookings existed keeps counting as history.
  final ServiceStatus status;

  /// When the appointment is, or was. Set on a booking and kept afterwards, so
  /// a completed entry can still say whether it was carried out on the day.
  final DateTime? scheduledDate;

  /// When the work was actually carried out. Null while the entry is only
  /// booked.
  final DateTime? completedDate;

  bool get isScheduled => status == ServiceStatus.scheduled;

  bool get isCompleted => status == ServiceStatus.completed;

  /// Whole days from today until the appointment: negative once it has passed,
  /// zero on the day itself. Null for anything that is not booked.
  int? get daysUntilScheduled {
    final target = scheduledDate;
    if (target == null || !isScheduled) return null;
    final today = DateTime.now();
    return DateTime(
      target.year,
      target.month,
      target.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  /// A booking whose appointment is behind us and that nobody has confirmed.
  bool get isMissedBooking => (daysUntilScheduled ?? 0) < 0;

  /// Parts fitted new during this service. Each one also produces a
  /// [PartReplacement] so the health bars reset.
  final List<ConsumablePart> replacedParts;

  final List<String> inspectedKeys;

  /// Free-text line items the catalogue does not cover.
  final List<String> customItems;

  final double cost;
  final String? workshopName;
  final String? notes;

  /// Invoices or receipts photographed for this entry, base64-encoded.
  ///
  /// A list rather than one string because a service is regularly billed on
  /// more than one document — parts on one, labour on another — and the driver
  /// who has both should not have to choose.
  ///
  /// Inline rather than a file path or a bucket URL, matching the vehicle
  /// photo: a record stays one self-contained thing that exports, syncs and
  /// deletes without leaving an orphan behind. That is also why the count and
  /// the per-file size are capped where they are picked — see
  /// `InvoiceAttachmentField` — because the whole record has to fit inside
  /// Firestore's 1 MB document limit.
  final List<String> invoiceAttachments;

  /// Suggested odometer this service was logged against, at the time it was
  /// logged. Historical/informational only — the schedule no longer matches
  /// records against this value because it does not move once the schedule
  /// ahead of it drifts. Kept for display and for inferring [milestonePhase]
  /// on records saved before that field existed.
  final int? milestoneOdometer;

  /// The periodic phase this service closes (0 = break-in check, 1, 2, 3 … =
  /// successive 10,000 km intervals). Stable — this, not [milestoneOdometer],
  /// is what the schedule matches on, and what makes re-logging the same
  /// phase an edit rather than a duplicate even after the target it was
  /// originally offered against has moved.
  final int? milestonePhase;

  /// [milestonePhase] when set; otherwise inferred from a pre-phase record's
  /// grid-aligned [milestoneOdometer].
  int? get resolvedMilestonePhase =>
      milestonePhase ?? ServiceCatalog.legacyPhaseFor(milestoneOdometer);

  /// The same entry, marked as carried out on [on].
  ///
  /// **[date] moves with it deliberately.** Every list, chart and projection in
  /// the app sorts and windows on `date`, and a service that happened in March
  /// but was booked in January belongs in March. The appointment is not lost —
  /// [scheduledDate] still holds it.
  MaintenanceRecord completedOn(DateTime on) =>
      copyWith(status: ServiceStatus.completed, completedDate: on, date: on);

  MaintenanceRecord copyWith({
    DateTime? date,
    ServiceStatus? status,
    DateTime? scheduledDate,
    DateTime? completedDate,
    int? odometer,
    String? title,
    ServiceTier? tier,
    List<ConsumablePart>? replacedParts,
    List<String>? inspectedKeys,
    List<String>? customItems,
    double? cost,
    String? workshopName,
    String? notes,
    int? milestoneOdometer,
    int? milestonePhase,
    List<String>? invoiceAttachments,
  }) => MaintenanceRecord(
    id: id,
    vehicleId: vehicleId,
    date: date ?? this.date,
    status: status ?? this.status,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    completedDate: completedDate ?? this.completedDate,
    odometer: odometer ?? this.odometer,
    title: title ?? this.title,
    tier: tier ?? this.tier,
    replacedParts: replacedParts ?? this.replacedParts,
    inspectedKeys: inspectedKeys ?? this.inspectedKeys,
    customItems: customItems ?? this.customItems,
    cost: cost ?? this.cost,
    workshopName: workshopName ?? this.workshopName,
    notes: notes ?? this.notes,
    milestoneOdometer: milestoneOdometer ?? this.milestoneOdometer,
    milestonePhase: milestonePhase ?? this.milestonePhase,
    invoiceAttachments: invoiceAttachments ?? this.invoiceAttachments,
  );

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    date,
    status,
    scheduledDate,
    completedDate,
    odometer,
    title,
    tier,
    replacedParts,
    inspectedKeys,
    customItems,
    cost,
    workshopName,
    notes,
    milestoneOdometer,
    milestonePhase,
    invoiceAttachments,
  ];
}
