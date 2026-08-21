import 'package:equatable/equatable.dart';

enum AlertSeverity { critical, warning, info }

enum AlertKind {
  serviceOverdue,
  serviceDueSoon,
  partOverdue,
  partDueSoon,
  licenseExpired,
  licenseExpiring,
  insuranceExpired,
  insuranceExpiring,
  odometerStale,
}

/// A single actionable warning on the home dashboard.
///
/// Carries localisation *keys* rather than finished sentences so the same alert
/// object renders correctly in Arabic and English, and can be reused verbatim
/// as a notification body.
class DashboardAlert extends Equatable {
  const DashboardAlert({
    required this.id,
    required this.kind,
    required this.severity,
    required this.titleKey,
    this.titleArgs = const {},
    this.detailKey,
    this.detailArgs = const {},
    this.colorValue,
    this.dueDate,
  });

  final String id;
  final AlertKind kind;
  final AlertSeverity severity;

  final String titleKey;
  final Map<String, Object?> titleArgs;

  final String? detailKey;
  final Map<String, Object?> detailArgs;

  final int? colorValue;

  /// When the underlying deadline falls — also the moment a reminder fires.
  final DateTime? dueDate;

  @override
  List<Object?> get props => [
    id,
    kind,
    severity,
    titleKey,
    titleArgs,
    detailKey,
    detailArgs,
    colorValue,
    dueDate,
  ];
}
