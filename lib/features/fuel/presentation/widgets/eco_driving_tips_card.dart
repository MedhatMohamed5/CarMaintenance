import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

/// One piece of advice. Both halves are l10n keys, never literal text, so the
/// card reads the same way in Arabic as it does in English.
class EcoTip {
  const EcoTip({required this.titleKey, required this.bodyKey});

  final String titleKey;
  final String bodyKey;
}

/// A themed group of tips.
class EcoTipCategory {
  const EcoTipCategory({
    required this.labelKey,
    required this.icon,
    required this.color,
    required this.tips,
  });

  final String labelKey;
  final IconData icon;
  final Color color;
  final List<EcoTip> tips;
}

/// The advice itself, as data. Adding a tip is one entry here plus two strings
/// in each locale — no widget changes.
const List<EcoTipCategory> kEcoTipCategories = [
  EcoTipCategory(
    labelKey: 'ecoCatDriving',
    icon: Icons.route_rounded,
    color: AppColors.green,
    tips: [
      EcoTip(titleKey: 'ecoDriving1', bodyKey: 'ecoDriving1Body'),
      EcoTip(titleKey: 'ecoDriving2', bodyKey: 'ecoDriving2Body'),
      EcoTip(titleKey: 'ecoDriving3', bodyKey: 'ecoDriving3Body'),
    ],
  ),
  EcoTipCategory(
    labelKey: 'ecoCatClimate',
    icon: Icons.ac_unit_rounded,
    color: AppColors.cyan,
    tips: [
      EcoTip(titleKey: 'ecoClimate1', bodyKey: 'ecoClimate1Body'),
      EcoTip(titleKey: 'ecoClimate2', bodyKey: 'ecoClimate2Body'),
      EcoTip(titleKey: 'ecoClimate3', bodyKey: 'ecoClimate3Body'),
    ],
  ),
  EcoTipCategory(
    labelKey: 'ecoCatVehicle',
    icon: Icons.tire_repair_rounded,
    color: AppColors.amber,
    tips: [
      EcoTip(titleKey: 'ecoVehicle1', bodyKey: 'ecoVehicle1Body'),
      EcoTip(titleKey: 'ecoVehicle2', bodyKey: 'ecoVehicle2Body'),
      EcoTip(titleKey: 'ecoVehicle3', bodyKey: 'ecoVehicle3Body'),
    ],
  ),
];

/// Practical ways to spend less at the pump, grouped by what the driver
/// actually controls: how they drive, how they cool the cabin, and how the car
/// is loaded and maintained.
///
/// Tabs rather than a long scroll — nine tips in one column reads as a wall of
/// text and gets skipped. One category is open at a time, and the body of each
/// tip expands on tap so the card stays compact until the driver is curious.
class EcoDrivingTipsCard extends StatefulWidget {
  const EcoDrivingTipsCard({super.key, this.initialCategory = 0});

  final int initialCategory;

  @override
  State<EcoDrivingTipsCard> createState() => _EcoDrivingTipsCardState();
}

class _EcoDrivingTipsCardState extends State<EcoDrivingTipsCard> {
  late int _category = widget.initialCategory.clamp(
    0,
    kEcoTipCategories.length - 1,
  );

  /// Index of the open tip within the current category, or `null` for none.
  /// Reset on category change so a stale index can never point past the end.
  int? _openTip;

  void _selectCategory(int index) {
    if (index == _category) return;
    HapticFeedback.selectionClick();
    setState(() {
      _category = index;
      _openTip = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = kEcoTipCategories[_category];

    return GlassCard(
      accent: category.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_rounded, size: 20, color: category.color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.raw('ecoTips'), style: context.text.titleSmall),
                    const SizedBox(height: 1),
                    Text(
                      l10n.raw('ecoTipsHint'),
                      style: context.text.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < kEcoTipCategories.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _CategoryChip(
                    category: kEcoTipCategories[i],
                    selected: i == _category,
                    onTap: () => _selectCategory(i),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < category.tips.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == category.tips.length - 1 ? 0 : 8,
              ),
              child: _TipRow(
                tip: category.tips[i],
                color: category.color,
                expanded: _openTip == i,
                onTap: () =>
                    setState(() => _openTip = _openTip == i ? null : i),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final EcoTipCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? color.withValues(alpha: 0.16)
                : tokens.surfaceHigh,
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.45) : tokens.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: 15,
                color: selected ? color : tokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.raw(category.labelKey),
                style: context.text.labelSmall?.copyWith(
                  color: selected ? color : tokens.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.tip,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  final EcoTip tip;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: tokens.surfaceHigh,
            border: Border.all(
              color: expanded ? color.withValues(alpha: 0.35) : tokens.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.raw(tip.titleKey),
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 16,
                    top: 7,
                    end: 4,
                  ),
                  child: Text(
                    l10n.raw(tip.bodyKey),
                    style: context.text.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
