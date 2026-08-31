import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/dealer.dart';
import '../providers/dealer_providers.dart';
import '../screens/workshop_form_sheet.dart';

/// Horizontal room the two action buttons give back to their labels.
///
/// Material's default for an icon button reserves 16 leading / 24 trailing,
/// which on half a card is most of what the label had to work with.
const EdgeInsets _actionPadding = EdgeInsets.symmetric(horizontal: 8);

/// A button label that stays on one line.
///
/// `OutlinedButton.icon` lays its label out in a `Row`, so a string too wide
/// for the space wrapped onto a second line — and a wrapped `Text` defaults to
/// `TextAlign.start`, which is why it also sat off-centre. Arabic hits this
/// first: `فتح في الخرائط` is more than twice the width of `Maps`, in half a
/// card, next to an icon.
///
/// `BoxFit.scaleDown` only shrinks when the label genuinely does not fit, so
/// labels that already fit are untouched at full size.
class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, textAlign: TextAlign.center),
  );
}

/// One directory entry with its two primary actions: call, and navigate.
class DealerCard extends HookConsumerWidget {
  const DealerCard({super.key, required this.dealer});

  final Dealer dealer;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = useState(false);
    final l10n = context.l10n;
    final d = dealer;
    final color = _kindColor(d.kind);

    Future<void> call() async {
      final number = d.callableNumber;
      if (number == null) return;
      final ok = await ref.read(launcherServiceProvider).dial(number);
      if (!ok && context.mounted) {
        showAppSnack(context, context.l10n.couldNotLaunch);
      }
    }

    Future<void> openMap() async {
      // Only reachable when the row has coordinates — the button is not built
      // otherwise. `query` still rides along as the pin's label.
      final ok = await ref
          .read(launcherServiceProvider)
          .openMap(lat: d.latitude, lng: d.longitude, query: d.mapQuery);
      if (!ok && context.mounted) {
        showAppSnack(context, context.l10n.couldNotLaunch);
      }
    }

    return GlassCard(
      // List row: opaque surface, no backdrop blur to pay for.
      blur: false,
      accent: color,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      onTap: () => expanded.value = !expanded.value,
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
              // Says plainly whose row this is. A driver scanning a mixed
              // list needs to know which entries they can change before they
              // go looking for a button that is not there.
              if (d.isUserAdded)
                PillChip(
                  label: l10n.raw('workshopMine'),
                  color: AppColors.amber,
                  icon: Icons.person_outline_rounded,
                  dense: true,
                ),
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
          // **No pin, no button.** The directions button used to fall back to a
          // name-and-address search when a row carried no coordinates, which
          // reads as navigation and is not: the search lands on whatever the
          // map provider thinks that string means, and for a workshop on a
          // side street in Nasr City that is regularly the wrong governorate.
          // A button that cannot do what it says is worse than one that is not
          // there, so Call takes the full width instead.
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: d.callableNumber == null ? null : call,
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: _ActionLabel(l10n.call),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: context.colors.onSecondary,
                    minimumSize: const Size.fromHeight(44),
                    padding: _actionPadding,
                  ),
                ),
              ),
              if (d.hasCoordinates) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: openMap,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: _ActionLabel(l10n.openInMaps),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: color,
                      side: BorderSide(color: color.withValues(alpha: 0.45)),
                      padding: _actionPadding,
                    ),
                  ),
                ),
              ],
            ],
          ),
          AnimatedCrossFade(
            duration: AppDurations.expand,
            sizeCurve: Curves.fastOutSlowIn,
            crossFadeState: expanded.value
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
                  const SizedBox(height: 4),
                  _OwnerActions(dealer: d),
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

/// Edit and delete, offered only on a workshop the driver added.
///
/// **The standard directory is admin-defined and read-only here.** It is
/// published to every user identically, so a change made on one device could
/// only either be undone by the next publish or drift silently away from what
/// everyone else sees. Neither is a good answer, so the buttons are simply not
/// offered — and `DealerController` refuses the same two operations, so the
/// rule holds even if some future screen forgets it.
///
/// Rating stays available on every row, because a rating is this device's
/// opinion of the workshop rather than a change to it.
class _OwnerActions extends ConsumerWidget {
  const _OwnerActions({required this.dealer});

  final Dealer dealer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!dealer.isUserAdded) return const SizedBox.shrink();
    final l10n = context.l10n;

    return Row(
      children: [
        TextButton.icon(
          onPressed: () => WorkshopFormSheet.show(context, existing: dealer),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(l10n.edit),
          style: TextButton.styleFrom(
            foregroundColor: context.tokens.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: l10n.delete,
          onPressed: () => _delete(context, ref),
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: AppColors.red,
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    // Captured before the dialog: the card is rebuilt out from under this
    // callback the moment the row leaves the list.
    final container = ProviderScope.containerOf(context, listen: false);
    if (!await confirmDelete(context)) return;
    final removed = dealer;
    await container.read(dealerControllerProvider.notifier).remove(removed.id);
    if (!context.mounted) return;
    showUndoSnack(
      context,
      onUndo: () =>
          container.read(dealerControllerProvider.notifier).save(removed),
    );
  }
}
