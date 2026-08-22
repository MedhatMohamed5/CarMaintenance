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

/// Categorised advice, built to the Roadside Tips card's visual architecture.
///
/// Everything structural is shared with `_SafetyTipsCard`: a [GlassCard] at
/// default padding and radius, an [AccentIconBadge] at 38, a `titleSmall`
/// header, a chevron that rotates half a turn over 240 ms, and an
/// `AnimatedCrossFade` body on an `easeOutCubic` size curve. Rows use the same
/// 22 px numbered disc at 16% accent and a 10 px gap.
///
/// **Every step reads in full.** The card itself opens and closes, but the
/// steps inside it do not: each one shows its title and its body at once. An
/// emergency instruction the driver has to tap to read is an instruction they
/// will not read, and the same argument applies to advice they are skimming.
/// The category chips remain because nine tips in one column is a wall, and
/// they switch content rather than hiding it.
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
  bool _expanded = false;

  late int _category = widget.initialCategory.clamp(
    0,
    widget.categories.length - 1,
  );

  void _selectCategory(int index) {
    if (index == _category) return;
    HapticFeedback.selectionClick();
    setState(() => _category = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = widget.categories[_category];
    final accent = category.color;

    return GlassCard(
      accent: accent,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentIconBadge(icon: widget.icon, color: accent, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.raw(widget.titleKey),
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 2),
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
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 240),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 14),
                  for (var i = 0; i < category.tips.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == category.tips.length - 1 ? 0 : 14,
                      ),
                      child: _TipRow(
                        tip: category.tips[i],
                        color: accent,
                        // Numbered like Roadside Tips: the emergency steps are
                        // an order of operations, not a menu.
                        step: i + 1,
                      ),
                    ),
                ],
              ),
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
            // Same 16% accent wash the numbered discs use, so a selected chip
            // and a step marker read as the same material.
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
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One numbered step, stated in full.
///
/// Static by design: no tap target, no chevron, no animation. The numbered
/// disc, the 10 px gap and the 1.5 line height are the Roadside Tips row; the
/// body simply hangs underneath the title, indented to the title's own left
/// edge so the number stays the only thing in the margin.
class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip, required this.color, required this.step});

  final GuidanceTip tip;
  final Color color;
  final int step;

  /// Disc width plus its gap. The body lines up with the title, not the number.
  static const double _bodyIndent = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurface,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: _bodyIndent),
          child: Text(
            l10n.raw(tip.bodyKey),
            style: context.text.bodySmall?.copyWith(
              color: tokens.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
