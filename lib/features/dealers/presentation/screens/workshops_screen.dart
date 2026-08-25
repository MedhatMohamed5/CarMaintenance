import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/screen_insets.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/entrance_animation.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/dealer.dart';
import '../providers/dealer_providers.dart';
import '../widgets/dealer_card.dart';
import 'workshop_form_sheet.dart';
import '../../../../core/widgets/app_fab_location.dart';

/// Tab 6. Authorised centres and the user's own workshops.
///
/// Emergency and towing contacts live on their own tab; duplicating them here
/// only buried the directory this screen exists for.
class WorkshopsScreen extends ConsumerStatefulWidget {
  const WorkshopsScreen({super.key});

  @override
  ConsumerState<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends ConsumerState<WorkshopsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(dealerQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dealers = ref.watch(filteredDealersProvider);
    final kindFilter = ref.watch(dealerKindFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.workshopsAndDealers)),
      // One rule for every FAB in the app; see `AppFabLocation`.
      floatingActionButtonLocation: AppFab.of(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => WorkshopFormSheet.show(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.addWorkshop),
        backgroundColor: AppColors.cyan,
        foregroundColor: context.colors.onPrimary,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: context.screenPadding(top: 4, hasFab: true),
            children: [
              const _HotlineBanner(),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (v) =>
                    ref.read(dealerQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: l10n.searchDealers,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(dealerQueryProvider.notifier).state = '';
                            setState(() {});
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    PillChip(
                      label: l10n.all,
                      selected: kindFilter == null,
                      onTap: () =>
                          ref.read(dealerKindFilterProvider.notifier).state =
                              null,
                    ),
                    for (final kind in DealerKind.values) ...[
                      const SizedBox(width: 8),
                      PillChip(
                        label: l10n.raw(kind.l10nKey),
                        selected: kindFilter == kind,
                        onTap: () =>
                            ref.read(dealerKindFilterProvider.notifier).state =
                                kindFilter == kind ? null : kind,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (dealers.isEmpty)
                AppEmptyState(
                  icon: AppIcons.workshops,
                  title: l10n.noDealers,
                  actionLabel: l10n.addWorkshop,
                  dense: true,
                  onAction: () => WorkshopFormSheet.show(context),
                )
              else
                _DealerGrid(dealers: dealers),
            ],
          ),
        ),
      ),
    );
  }
}

/// The directory.
///
/// **Deliberately not lazy.** It was briefly a `SliverList.builder`, on the
/// theory that building every card up front was the cost. It was not: a
/// directory is a few dozen entries at most, so the eager `Column` builds them
/// in one pass and is done, while the sliver version paid a `SliverLayoutBuilder`,
/// a per-row key lookup and — because `EntranceAnimation` keeps its element
/// alive — a keep-alive registration for every card the user ever scrolled
/// past. That was measurably worse in the hand. Laziness earns its overhead
/// only when the list can actually get long.
class _DealerGrid extends StatelessWidget {
  const _DealerGrid({required this.dealers});

  final List<Dealer> dealers;

  static const double _gap = 10;
  static const double _minCardWidth = 340;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _minCardWidth).floor().clamp(
          1,
          3,
        );
        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < dealers.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == dealers.length - 1 ? 0 : _gap,
                  ),
                  child: _card(dealers[i], i),
                ),
            ],
          );
        }

        final cardWidth =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (var i = 0; i < dealers.length; i++)
              SizedBox(width: cardWidth, child: _card(dealers[i], i)),
          ],
        );
      },
    );
  }

  /// Keyed on the dealer id so the entrance state follows the card across a
  /// column-count change: rotating the device re-lays-out the grid, and the
  /// cards must not fade in again.
  static Widget _card(Dealer dealer, int index) => EntranceAnimation.item(
    key: ValueKey('dealer-${dealer.id}'),
    index: index,
    step: const Duration(milliseconds: 45),
    duration: const Duration(milliseconds: 320),
    child: DealerCard(dealer: dealer),
  );
}

/// The single number that always works, pinned above the directory.
class _HotlineBanner extends ConsumerWidget {
  const _HotlineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hotline = ref.watch(authorizedHotlineProvider);

    return GlassCard(
      accent: AppColors.cyan,
      elevated: true,
      onTap: () async {
        final ok = await ref.read(launcherServiceProvider).dial(hotline);
        if (!ok && context.mounted) {
          showAppSnack(context, l10n.couldNotLaunch);
        }
      },
      child: Row(
        children: [
          const AccentIconBadge(
            icon: Icons.support_agent_rounded,
            color: AppColors.cyan,
            size: 46,
            filled: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hotline,
                  style: context.text.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                Text(
                  hotline,
                  style: context.text.headlineSmall?.copyWith(
                    color: AppColors.cyan,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.call_rounded, color: AppColors.cyan),
        ],
      ),
    );
  }
}
