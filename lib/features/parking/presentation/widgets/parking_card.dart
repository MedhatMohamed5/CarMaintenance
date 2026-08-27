import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/parking_providers.dart';
import '../screens/parking_sheet.dart';

/// The dashboard's parking badge.
///
/// **Renders nothing when no spot is saved.** The dashboard already carries
/// nine cards; a tenth that says "you have not parked anywhere" is a row of
/// dead pixels on every screen the driver ever opens. Pinning a spot lives in
/// the quick actions above; this card only exists while there is a car waiting
/// somewhere.
class ParkingCard extends ConsumerWidget {
  const ParkingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(activeParkingProvider);
    if (saved == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);

    Future<void> openMap() async {
      final ok = await ref
          .read(launcherServiceProvider)
          .openMap(lat: saved.latitude, lng: saved.longitude);
      if (!ok && context.mounted) {
        showAppSnack(context, l10n.couldNotLaunch);
      }
    }

    Future<void> clear() async {
      await ref.read(parkingControllerProvider.notifier).clear();
      if (!context.mounted) return;
      showAppSnack(
        context,
        l10n.raw('parkingCleared'),
        icon: Icons.check_rounded,
      );
    }

    return GlassCard(
      accent: AppColors.cyan,
      onTap: () => ParkingSheet.show(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentIconBadge(
                icon: Icons.local_parking_rounded,
                color: AppColors.cyan,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.raw('parkingTitle'),
                      style: context.text.titleSmall,
                    ),
                    Text(
                      '${l10n.raw('parkingParkedAt')} '
                      '${Fmt.date(saved.timestamp, locale)}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // The words the driver wrote are what actually finds the car once
          // they are inside the garage, so they sit above the map button
          // rather than behind a tap.
          if (saved.hasDetails) ...[
            const SizedBox(height: 12),
            if (saved.floorOrSection != null)
              _DetailLine(
                icon: Icons.layers_outlined,
                text: saved.floorOrSection!,
              ),
            if (saved.note != null)
              _DetailLine(
                icon: Icons.sticky_note_2_outlined,
                text: saved.note!,
              ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              // Hidden without a usable fix: a pin at 0,0 would send the
              // driver to the Atlantic. The written details still stand.
              if (saved.hasFix) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: openMap,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: Text(
                      l10n.raw('parkingDirections'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: context.colors.onPrimary,
                      minimumSize: const Size.fromHeight(42),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: clear,
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: Text(
                    l10n.raw('parkingFound'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
          if (!saved.hasFix) ...[
            const SizedBox(height: 8),
            Text(
              l10n.raw('parkingNoFix'),
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: context.tokens.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: context.text.bodySmall)),
      ],
    ),
  );
}
