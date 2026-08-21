import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'vehicle_care_logo.dart';

/// Branded app-bar header: logo badge plus a dual-tone wordmark that splits the
/// localised title into its two halves, so it reads correctly in Arabic and
/// English without hard-coding either.
class AppBrandTitle extends StatelessWidget {
  const AppBrandTitle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.appTitle.trim();
    final split = title.indexOf(' ');
    final lead = split == -1 ? title : title.substring(0, split);
    final tail = split == -1 ? '' : title.substring(split + 1);

    final badge = compact ? 26.0 : 32.0;
    final base = (compact ? context.text.titleMedium : context.text.titleLarge)
        ?.copyWith(letterSpacing: -0.2, height: 1.1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(badge * 0.3),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(
                  alpha: context.isDark ? 0.35 : 0.18,
                ),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: VehicleCareLogo(size: badge),
        ),
        SizedBox(width: compact ? 8 : 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: lead,
                    style: base?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.colors.onSurface,
                    ),
                  ),
                  if (tail.isNotEmpty) ...[
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: tail,
                      style: base?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan,
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
