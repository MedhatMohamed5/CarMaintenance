import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/fuel_metric.dart';
import '../providers/fuel_providers.dart';

/// Presentation layer for [FuelMetric]: units, labels, formatting and the
/// quality colour. Everything upstream stays in L/100 km.
extension FuelMetricDisplay on FuelMetric {
  /// Short unit shown beside a number, e.g. `L/100km`.
  String unit(AppLocalizations l10n) => l10n.raw(unitKey);

  /// Long name shown in the toggle, e.g. `Litres / 100 km`.
  String label(AppLocalizations l10n) => l10n.raw(labelKey);

  /// Converts from the engine's L/100 km and formats for display.
  ///
  /// Always two decimals, always a number: the maths guarantees a finite,
  /// non-negative double, so `0.00` is the empty state. A dash here reads as a
  /// failure and hides the fact that the figure is simply still zero.
  String format(double litersPer100Km, String locale) =>
      Fmt.dec2(of(litersPer100Km), locale);

  /// Ring-gauge ceiling, chosen so a typical car sits around two thirds full
  /// in either unit.
  double get gaugeCeiling => this == FuelMetric.litersPer100Km ? 20 : 25;

  double gaugeValue(double litersPer100Km) {
    final value = of(litersPer100Km);
    return value <= 0 ? 0 : (value / gaugeCeiling).clamp(0.0, 1.0);
  }
}

/// Consumption bands, always judged on L/100 km so the colour means the same
/// thing whichever unit is on screen.
Color fuelEconomyColor(double litersPer100Km) {
  if (litersPer100Km <= 0) return AppColors.cyan;
  if (litersPer100Km <= 7) return AppColors.green;
  if (litersPer100Km <= 10) return AppColors.amber;
  return AppColors.orange;
}

/// Compact unit switch. L/100 km is the primary metric; km/L is the optional
/// secondary, one tap away and remembered.
class FuelMetricToggle extends ConsumerWidget {
  const FuelMetricToggle({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final metric = ref.watch(fuelMetricProvider);
    final tokens = context.tokens;

    return Semantics(
      label: l10n.displayMetric,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => ref.read(fuelMetricProvider.notifier).toggle(),
          child: Container(
            padding: EdgeInsetsDirectional.fromSTEB(
              dense ? 8 : 10,
              dense ? 3 : 5,
              dense ? 6 : 8,
              dense ? 3 : 5,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: tokens.surfaceHigh,
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.unit(l10n),
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.swap_horiz_rounded,
                  size: dense ? 13 : 15,
                  color: tokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
