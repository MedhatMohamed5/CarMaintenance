import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/presentation/screens/vehicle_form_sheet.dart';

/// Licence and insurance countdowns, side by side.
class DocumentsCard extends ConsumerWidget {
  const DocumentsCard({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.documents,
          icon: Icons.verified_user_outlined,
          actionLabel: l10n.edit,
          onAction: () => VehicleFormSheet.show(context, existing: vehicle),
        ),
        Row(
          children: [
            Expanded(
              child: _DocumentTile(
                title: l10n.carInsurance,
                expiry: vehicle.insuranceExpiry,
                icon: Icons.shield_outlined,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DocumentTile(
                title: l10n.carLicense,
                expiry: vehicle.licenseExpiry,
                icon: Icons.description_outlined,
                color: AppColors.blue,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 260.ms, duration: 380.ms).slideY(begin: 0.05);
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({
    required this.title,
    required this.expiry,
    required this.icon,
    required this.color,
  });

  final String title;
  final DateTime? expiry;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);

    final days = expiry == null ? null : DateX.daysUntil(expiry!);
    final expired = days != null && days < 0;
    // Under a month the countdown turns amber, past the date it turns red —
    // the same three-step ramp the parts bars use, for consistency.
    final valueColor = expiry == null
        ? context.tokens.textSecondary
        : expired
        ? AppColors.red
        : days! <= 30
        ? AppColors.amber
        : AppColors.green;

    return GlassCard(
      accent: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      onTap: null,
      child: Column(
        children: [
          AccentIconBadge(icon: icon, color: color, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: context.text.titleSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (expiry == null)
            Text(
              l10n.none,
              style: context.text.bodySmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            )
          else ...[
            Text(
              expired
                  ? l10n.expired
                  : l10n.fmt('remainingDays', {
                      'n': Fmt.int0(days!, locale),
                    }),
              textAlign: TextAlign.center,
              style: AppTypography.numeric(
                context.text.titleMedium,
              ).copyWith(color: valueColor),
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.renewsOn} ${Fmt.date(expiry!, locale)}',
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
