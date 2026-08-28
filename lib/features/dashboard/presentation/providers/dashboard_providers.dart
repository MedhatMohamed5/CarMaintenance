import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../maintenance/domain/entities/part_health.dart';
import '../../../maintenance/presentation/providers/maintenance_providers.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/presentation/providers/vehicle_providers.dart';
import '../../domain/entities/dashboard_alert.dart';

/// How far ahead a deadline starts nagging.
const int _kDocumentWarningDays = 30;
const int _kOdometerStaleDays = 21;

/// Every warning the dashboard shows, most urgent first.
///
/// Deliberately assembled in one place: overdue services, worn parts and
/// expiring documents are the same kind of problem to a driver, and ranking
/// them together is what stops the important one hiding under a minor one.
final dashboardAlertsProvider = Provider<List<DashboardAlert>>((ref) {
  final vehicle = ref.watch(selectedVehicleProvider);
  if (vehicle == null) return const [];

  final alerts = <DashboardAlert>[
    ..._serviceAlerts(ref),
    ..._partAlerts(ref),
    ..._documentAlerts(vehicle),
    ..._odometerAlerts(vehicle),
  ];

  alerts.sort((a, b) {
    final bySeverity = a.severity.index.compareTo(b.severity.index);
    if (bySeverity != 0) return bySeverity;
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue == null || bDue == null) return 0;
    return aDue.compareTo(bDue);
  });

  return List.unmodifiable(alerts);
});

/// True when something actually needs the driver's attention — drives the
/// badge on the home tab.
final hasCriticalAlertsProvider = Provider<bool>(
  (ref) => ref
      .watch(dashboardAlertsProvider)
      .any((a) => a.severity == AlertSeverity.critical),
);

List<DashboardAlert> _serviceAlerts(Ref ref) {
  return ref
      .watch(upcomingServicesProvider)
      .where((s) => s.isOverdue || s.isDueSoon)
      .map((s) {
        final overdue = s.isOverdue;
        return DashboardAlert(
          id: 'service_${s.milestone.id}',
          kind: overdue ? AlertKind.serviceOverdue : AlertKind.serviceDueSoon,
          severity: overdue ? AlertSeverity.critical : AlertSeverity.warning,
          titleKey: overdue ? 'alertServiceOverdue' : 'alertServiceDueSoon',
          titleArgs: {'km': s.targetOdometer},
          // isOverdue can be true by calendar alone while kmRemaining is
          // still positive — "overdue by N km" only makes sense once the
          // odometer has actually passed the target.
          detailKey: s.kmRemaining < 0 ? 'kmOverdueLabel' : 'kmRemainingLabel',
          detailArgs: {'n': s.kmRemaining.abs()},
          colorValue: s.tier.colorValue,
          dueDate: s.estimatedDate,
        );
      })
      .toList();
}

List<DashboardAlert> _partAlerts(Ref ref) {
  return ref
      .watch(allPartsHealthProvider)
      .where((h) => h.status != HealthStatus.healthy)
      .map(
        (h) => DashboardAlert(
          id: 'part_${h.part.id}',
          kind: h.isOverdue ? AlertKind.partOverdue : AlertKind.partDueSoon,
          severity: h.isOverdue
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          titleKey: h.isOverdue ? 'alertPartOverdue' : 'alertPartDueSoon',
          // Resolved by the widget, which knows the active locale.
          titleArgs: {'partKey': h.part.l10nKey},
          detailKey: 'kmRemainingLabel',
          detailArgs: {'n': h.remainingKm},
          colorValue: h.part.colorValue,
          dueDate: h.estimatedDueDate,
        ),
      )
      .toList();
}

List<DashboardAlert> _documentAlerts(Vehicle vehicle) {
  final alerts = <DashboardAlert>[];

  void check({
    required DateTime? expiry,
    required String id,
    required AlertKind expiredKind,
    required AlertKind expiringKind,
    required String expiredKey,
    required String expiringKey,
    required int colorValue,
  }) {
    if (expiry == null) return;
    final days = DateX.daysUntil(expiry);
    if (days < 0) {
      alerts.add(
        DashboardAlert(
          id: id,
          kind: expiredKind,
          severity: AlertSeverity.critical,
          titleKey: expiredKey,
          detailKey: 'renewsOn',
          detailArgs: {'date': expiry.toIso8601String()},
          colorValue: colorValue,
          dueDate: expiry,
        ),
      );
    } else if (days <= _kDocumentWarningDays) {
      alerts.add(
        DashboardAlert(
          id: id,
          kind: expiringKind,
          severity: AlertSeverity.warning,
          titleKey: expiringKey,
          titleArgs: {'n': days},
          detailKey: 'renewsOn',
          detailArgs: {'date': expiry.toIso8601String()},
          colorValue: colorValue,
          dueDate: expiry,
        ),
      );
    }
  }

  check(
    expiry: vehicle.licenseExpiry,
    id: 'license',
    expiredKind: AlertKind.licenseExpired,
    expiringKind: AlertKind.licenseExpiring,
    expiredKey: 'alertLicenseExpired',
    expiringKey: 'alertLicenseExpiring',
    colorValue: 0xFF3B82F6,
  );
  check(
    expiry: vehicle.insuranceExpiry,
    id: 'insurance',
    expiredKind: AlertKind.insuranceExpired,
    expiringKind: AlertKind.insuranceExpiring,
    expiredKey: 'alertInsuranceExpired',
    expiringKey: 'alertInsuranceExpiring',
    colorValue: 0xFFA78BFA,
  );

  return alerts;
}

List<DashboardAlert> _odometerAlerts(Vehicle vehicle) {
  final last = vehicle.odometerUpdatedAt ?? vehicle.createdAt;
  final days = DateX.daysBetween(last, DateTime.now());
  if (days < _kOdometerStaleDays) return const [];
  return [
    DashboardAlert(
      id: 'odometer_stale',
      kind: AlertKind.odometerStale,
      severity: AlertSeverity.info,
      titleKey: 'alertOdometerStale',
      detailKey: 'alertOdometerStaleDetail',
      detailArgs: {'n': days},
      colorValue: 0xFF9A9AA6,
    ),
  ];
}
