import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../vehicles/domain/entities/vehicle.dart';
import '../../../vehicles/presentation/screens/vehicle_form_sheet.dart';

class DocumentsCard extends ConsumerWidget {
  const DocumentsCard({super.key, required this.vehicle});

  final Vehicle vehicle;

  static const double _gap = 10;

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
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _DocumentTile(
                  title: l10n.carInsurance,
                  expiry: vehicle.insuranceExpiry,
                  icon: Icons.shield_outlined,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: _gap),
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

  static const double _badgeHeight = 28;
  static const double _captionHeight = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);

    final expiryDate = expiry;
    final days = expiryDate == null ? null : DateX.daysUntil(expiryDate);

    final Color statusColor;
    final String badgeLabel;
    if (days == null) {
      statusColor = context.tokens.textSecondary;
      badgeLabel = l10n.none;
    } else if (days < 0) {
      statusColor = AppColors.red;
      badgeLabel = l10n.expired;
    } else {
      statusColor = days <= 30 ? AppColors.amber : AppColors.green;
      badgeLabel = l10n.fmt('remainingDays', {'n': Fmt.int0(days, locale)});
    }

    final caption = expiryDate == null
        ? '—'
        : '${l10n.renewsOn} ${Fmt.date(expiryDate, locale)}';

    return GlassCard(
      accent: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AccentIconBadge(icon: icon, color: color, size: 42),
          const SizedBox(height: 12),
          SizedBox(
            height: _captionHeight,
            child: Align(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: context.text.titleSmall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _StatusBadge(
            label: badgeLabel,
            color: statusColor,
            height: _badgeHeight,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _captionHeight,
            child: Align(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  caption,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.height,
  });

  final String label;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: context.text.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
