import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import 'common_widgets.dart';

/// Where a service or a part stands, as one of four states.
///
/// **The single place a due-state becomes a label, a colour and an icon.**
/// Two screens used to answer this question separately — the dashboard's next
/// service card and the maintenance schedule — and they had already disagreed:
/// the same "due soon" state showed a clock on one screen and a warning
/// triangle on the other. A user seeing both in one session has no way to know
/// they mean the same thing.
///
/// Mapping lives on the enum rather than in either screen, so a new state, a
/// recoloured one or a changed icon lands everywhere at once.
enum ServiceStatus {
  done(color: AppColors.green, icon: Icons.check_circle_rounded),
  healthy(color: AppColors.green, icon: Icons.check_circle_rounded),
  dueSoon(color: AppColors.amber, icon: Icons.schedule_rounded),
  overdue(color: AppColors.red, icon: Icons.priority_high_rounded);

  const ServiceStatus({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    ServiceStatus.done => l10n.raw('done'),
    ServiceStatus.healthy => l10n.healthy,
    ServiceStatus.dueSoon => l10n.dueSoon,
    ServiceStatus.overdue => l10n.overdue,
  };

  /// Resolved in one order everywhere: finished first, then late, then near.
  ///
  /// The order matters and used to be implicit in each screen's `if` chain —
  /// an overdue item that had since been completed read as overdue on one
  /// screen and done on the other.
  static ServiceStatus resolve({
    bool isCompleted = false,
    required bool isOverdue,
    required bool isDueSoon,
  }) {
    if (isCompleted) return ServiceStatus.done;
    if (isOverdue) return ServiceStatus.overdue;
    if (isDueSoon) return ServiceStatus.dueSoon;
    return ServiceStatus.healthy;
  }
}

/// [ServiceStatus] as the pill the app shows everywhere else.
///
/// [showHealthy] exists because the two screens legitimately differ on one
/// point: a schedule listing every milestone would be a wall of green badges,
/// so it omits them, while a card showing one upcoming service wants to say
/// that it is fine. That is a display choice, not a different meaning, so it is
/// a flag here rather than a second widget.
class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge({
    super.key,
    required this.status,
    this.showHealthy = true,
  });

  final ServiceStatus status;
  final bool showHealthy;

  @override
  Widget build(BuildContext context) {
    if (status == ServiceStatus.healthy && !showHealthy) {
      return const SizedBox.shrink();
    }

    return PillChip(
      label: status.label(context.l10n),
      color: status.color,
      icon: status.icon,
      selected: true,
      dense: true,
    );
  }
}
