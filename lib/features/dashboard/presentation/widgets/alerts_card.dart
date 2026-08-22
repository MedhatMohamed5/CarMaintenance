import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/dashboard_alert.dart';
import '../providers/dashboard_providers.dart';

/// Stack of active warnings, ranked most urgent first.
///
/// Collapses to a single reassuring line when there is nothing wrong — an
/// empty warnings list is information too, and hiding the section entirely
/// would leave the driver wondering whether it ran.
class AlertsCard extends ConsumerWidget {
  const AlertsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(dashboardAlertsProvider);
    final l10n = context.l10n;

    if (alerts.isEmpty) {
      return GlassCard(
        accent: AppColors.green,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const AccentIconBadge(
              icon: Icons.verified_rounded,
              color: AppColors.green,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.noAlerts, style: context.text.bodyMedium),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '${l10n.alerts} (${alerts.length})',
          icon: Icons.notifications_active_outlined,
        ),
        // Keyed on the alert's own identity so a dismissed or resolved
        // alert never makes its neighbours replay.
        for (var i = 0; i < alerts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EntranceAnimation.item(
              key: ValueKey('alert-${alerts[i].id}'),
              index: i,
              step: const Duration(milliseconds: 60),
              duration: const Duration(milliseconds: 320),
              child: _AlertTile(alert: alerts[i]),
            ),
          ),
      ],
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({required this.alert});

  final DashboardAlert alert;

  static const Map<AlertSeverity, IconData> _icons = {
    AlertSeverity.critical: Icons.error_rounded,
    AlertSeverity.warning: Icons.warning_amber_rounded,
    AlertSeverity.info: Icons.info_outline_rounded,
  };

  Color _color(BuildContext context) => switch (alert.severity) {
    AlertSeverity.critical => AppColors.red,
    AlertSeverity.warning => AppColors.amber,
    AlertSeverity.info => context.tokens.textSecondary,
  };

  /// Resolves the alert's keys against the active locale. Part names arrive as
  /// a nested key (`partKey`) so the alert object itself stays language-free.
  String _title(AppLocalizations l10n, String locale) {
    final args = <String, Object?>{...alert.titleArgs};
    final partKey = args.remove('partKey');
    if (partKey is String) args['part'] = l10n.raw(partKey);
    if (args['km'] is int) args['km'] = Fmt.int0(args['km']! as int, locale);
    return l10n.fmt(alert.titleKey, args);
  }

  String? _detail(AppLocalizations l10n, String locale) {
    final key = alert.detailKey;
    if (key == null) return null;
    final args = <String, Object?>{...alert.detailArgs};
    if (args['n'] is int) args['n'] = Fmt.int0(args['n']! as int, locale);
    final rawDate = args['date'];
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        return '${l10n.raw(key)} ${Fmt.date(parsed, locale)}';
      }
    }
    return l10n.fmt(key, args);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final color = _color(context);
    final detail = _detail(l10n, locale);

    return GlassCard(
      accent: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AccentIconBadge(
            icon: _icons[alert.severity]!,
            color: color,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(l10n, locale),
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: context.text.bodySmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
