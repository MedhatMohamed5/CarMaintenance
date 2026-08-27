import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'animated_counter.dart';
import 'glass_card.dart';

/// One headline figure in a card: an icon, the number, and what it measures.
///
/// **Extracted from two identical copies that had drifted apart.** The fuel
/// screen and the analytics grid each carried a private `_SummaryTile` with the
/// same constructor, the same body and — word for word — the same doc comment.
/// Then one of them was fixed: `12.68 L/100km` is wider than a two-column tile
/// on a small phone, so the analytics copy gained a `FittedBox` and the fuel
/// copy kept clipping. That is what duplicated UI costs: the bug is only ever
/// fixed where someone happened to look.
///
/// The surviving behaviour is the fixed one. [emptyLabel] came from the
/// analytics copy too — a tile with nothing to show prints a dash rather than
/// counting up to zero.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
    required this.unit,
    required this.color,
    this.emptyLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  });

  final IconData icon;
  final String label;

  /// The raw figure. Counted up on mount, formatted by [format] as it goes.
  final double value;
  final String Function(double value) format;

  final String unit;
  final Color color;

  /// Printed instead of a count when there is no data yet.
  final String? emptyLabel;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: color,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: color),
          // `12.68 L/100km` is wider than a two-column tile on a small phone;
          // scaling keeps the whole figure readable instead of clipping it.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: CountingStatValue(
              value: value,
              format: format,
              unit: unit,
              emptyLabel: emptyLabel,
              style: context.text.titleMedium,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
