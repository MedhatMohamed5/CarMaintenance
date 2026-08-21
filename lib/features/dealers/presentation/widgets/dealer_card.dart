import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/dealer.dart';
import '../providers/dealer_providers.dart';

/// One directory entry with its two primary actions: call, and navigate.
class DealerCard extends ConsumerStatefulWidget {
  const DealerCard({super.key, required this.dealer});

  final Dealer dealer;

  @override
  ConsumerState<DealerCard> createState() => _DealerCardState();
}

class _DealerCardState extends ConsumerState<DealerCard> {
  bool _expanded = false;

  static Color _kindColor(DealerKind kind) => switch (kind) {
    DealerKind.authorizedService => AppColors.cyan,
    DealerKind.specializedCenter => AppColors.green,
    DealerKind.showroom => AppColors.purple,
    DealerKind.independentWorkshop => AppColors.teal,
    DealerKind.tireShop => AppColors.blue,
    DealerKind.towing => AppColors.orange,
  };

  static IconData _kindIcon(DealerKind kind) => switch (kind) {
    DealerKind.authorizedService => Icons.verified_rounded,
    DealerKind.specializedCenter => Icons.engineering_rounded,
    DealerKind.showroom => Icons.storefront_rounded,
    DealerKind.independentWorkshop => Icons.handyman_rounded,
    DealerKind.tireShop => Icons.trip_origin_rounded,
    DealerKind.towing => Icons.car_crash_rounded,
  };

  Future<void> _call() async {
    final number = widget.dealer.callableNumber;
    if (number == null) return;
    final ok = await ref.read(launcherServiceProvider).dial(number);
    if (!ok && mounted) {
      showAppSnack(context, context.l10n.couldNotLaunch);
    }
  }

  Future<void> _openMap() async {
    final d = widget.dealer;
    // Coordinates when we have them, a name+address search when we do not —
    // never a guessed pin.
    final ok = await ref
        .read(launcherServiceProvider)
        .openMap(
          lat: d.latitude,
          lng: d.longitude,
          query: d.mapQuery,
        );
    if (!ok && mounted) {
      showAppSnack(context, context.l10n.couldNotLaunch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.dealer;
    final color = _kindColor(d.kind);

    return GlassCard(
      accent: color,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccentIconBadge(icon: _kindIcon(d.kind), color: color, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: context.text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: context.tokens.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            d.address ?? d.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (d.rating != null)
                Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: AppColors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          d.rating!.toStringAsFixed(1),
                          style: context.text.labelMedium,
                        ),
                      ],
                    ),
                    Text(
                      '(${d.ratingCount})',
                      style: context.text.labelSmall?.copyWith(
                        fontSize: 9,
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChip(
                label: l10n.raw(d.kind.l10nKey),
                color: color,
                selected: true,
                dense: true,
              ),
              PillChip(label: d.city, dense: true),
              if (d.hotline != null)
                PillChip(
                  label: '${l10n.hotline} ${d.hotline}',
                  color: AppColors.green,
                  icon: AppIcons.phone,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: d.callableNumber == null ? null : _call,
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: Text(l10n.call),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: context.colors.onSecondary,
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openMap,
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text(l10n.openInMaps),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.45)),
                  ),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d.openingHours != null)
                    _InfoLine(
                      icon: Icons.schedule_rounded,
                      label: l10n.openingHours,
                      value: d.openingHours!,
                    ),
                  if (d.allNumbers.isNotEmpty)
                    _InfoLine(
                      icon: AppIcons.phone,
                      label: l10n.phone,
                      value: d.allNumbers.join('  /  '),
                    ),
                  if (d.brand != null)
                    _InfoLine(
                      icon: Icons.workspace_premium_outlined,
                      label: l10n.make,
                      value: d.brand!,
                    ),
                  if (d.serviceKeys.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.services}:',
                      style: context.text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final key in d.serviceKeys)
                          PillChip(label: l10n.raw(key), dense: true),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _RatingRow(dealer: d),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: context.tokens.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          Expanded(child: Text(value, style: context.text.labelMedium)),
        ],
      ),
    );
  }
}

/// Five taps, one running average. Ratings are local to the device — the app
/// makes no claim of being a review platform.
class _RatingRow extends ConsumerWidget {
  const _RatingRow({required this.dealer});

  final Dealer dealer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Row(
      children: [
        Text(
          '${l10n.raw('rateThisPlace')}:',
          style: context.text.labelSmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const Spacer(),
        for (var star = 1; star <= 5; star++)
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () async {
              await ref
                  .read(dealerControllerProvider.notifier)
                  .rate(dealer.id, star.toDouble());
              if (!context.mounted) return;
              showAppSnack(context, l10n.raw('thanksForRating'));
            },
            icon: Icon(
              (dealer.rating ?? 0) >= star
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              size: 20,
              color: AppColors.amber,
            ),
          ),
      ],
    );
  }
}
