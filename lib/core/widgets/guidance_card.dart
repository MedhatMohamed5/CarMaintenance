import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// One piece of advice. Both halves are l10n keys, never literal text, so a
/// card reads the same way in Arabic as it does in English.
class GuidanceTip {
  const GuidanceTip({required this.titleKey, required this.bodyKey});

  final String titleKey;
  final String bodyKey;
}

/// A themed group of tips.
class GuidanceCategory {
  const GuidanceCategory({
    required this.labelKey,
    required this.icon,
    required this.color,
    required this.tips,
  });

  final String labelKey;
  final IconData icon;
  final Color color;
  final List<GuidanceTip> tips;
}

/// Categorised, collapsible advice.
///
/// Tabs rather than a long scroll: a dozen tips in one column reads as a wall
/// of text and gets skipped. One category is open at a time, and each tip
/// expands on tap, so the card stays compact until the driver is curious.
///
/// The content is pure data — a `const` list of [GuidanceCategory] — so adding
/// advice is one entry plus two strings per locale, with no widget change.
class GuidanceCard extends StatefulWidget {
  const GuidanceCard({
    super.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.categories,
    this.initialCategory = 0,
  });

  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final List<GuidanceCategory> categories;
  final int initialCategory;

  @override
  State<GuidanceCard> createState() => _GuidanceCardState();
}

class _GuidanceCardState extends State<GuidanceCard> {
  late int _category = widget.initialCategory.clamp(
    0,
    widget.categories.length - 1,
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
    final category = widget.categories[_category];

    return GlassCard(
      accent: category.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: category.color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.raw(widget.titleKey),
                      style: context.text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.raw(widget.subtitleKey),
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
                for (var i = 0; i < widget.categories.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _CategoryChip(
                    category: widget.categories[i],
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
                // Numbered within the category: the emergency steps are an
                // order of operations, not a menu.
                step: i + 1,
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

  final GuidanceCategory category;
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
    required this.step,
    required this.expanded,
    required this.onTap,
  });

  final GuidanceTip tip;
  final Color color;
  final int step;
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
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$step',
                      style: context.text.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
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
                    start: 32,
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
