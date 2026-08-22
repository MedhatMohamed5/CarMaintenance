import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/vehicle_paint.dart';
import '../providers/vehicle_providers.dart';
import '../screens/vehicle_form_sheet.dart';
import 'vehicle_image.dart';
import '../../../../core/widgets/entrance_animation.dart';

/// The dashboard hero: which car you are looking at, how far it has gone, and
/// a one-tap way to switch or update the odometer.
class VehicleHeroCard extends ConsumerWidget {
  const VehicleHeroCard({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final accent = VehiclePaint.accentFor(vehicle.colorValue);

    return EntranceAnimation(
      duration: const Duration(milliseconds: 380),
      slide: 0.06,
      child: VehicleImageBackdrop(
        imageBase64: vehicle.imageBase64,
        imageUrl: vehicle.imageUrl,
        accent: accent,
        child: GlassCard(
          accent: accent,
          elevated: true,
          blur: vehicle.hasImage,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          onTap: () => VehicleSwitcherSheet.show(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VehicleAvatar.of(vehicle, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.displayName,
                          style: context.text.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicle.subtitle,
                          style: context.text.bodySmall?.copyWith(
                            color: context.tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.unfold_more_rounded,
                    color: context.tokens.textSecondary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.currentOdometer,
                          style: context.text.labelSmall?.copyWith(
                            color: context.tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Counts up on first paint — the odometer feels like it is
                        // spinning to the current reading.
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: vehicle.currentOdometer.toDouble(),
                          ),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                Fmt.int0(value, locale),
                                style: AppTypography.numeric(
                                  context.text.headlineMedium,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.km,
                                style: context.text.labelMedium?.copyWith(
                                  color: context.tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _MiniAction(
                    icon: Icons.edit_road_rounded,
                    label: l10n.updateOdometer,
                    color: accent,
                    onTap: () => OdometerSheet.show(context, vehicle),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pick a vehicle, add one, or edit the current one.
class VehicleSwitcherSheet extends ConsumerWidget {
  const VehicleSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) => showAppSheet(
    context: context,
    builder: (_) => const VehicleSwitcherSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final selectedId = ref.watch(selectedVehicleProvider)?.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.myVehicles, style: context.text.titleLarge),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final v = vehicles[i];
              final accent = VehiclePaint.accentFor(v.colorValue);
              final selected = v.id == selectedId;
              return GlassCard(
                accent: selected ? accent : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                onTap: () async {
                  await ref
                      .read(selectedVehicleIdProvider.notifier)
                      .select(v.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Row(
                  children: [
                    VehicleAvatar.of(v, size: 42, showRing: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.displayName, style: context.text.titleSmall),
                          Text(
                            '${Fmt.int0(v.currentOdometer, locale)} ${l10n.km}',
                            style: context.text.bodySmall?.copyWith(
                              color: context.tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: l10n.edit,
                      onPressed: () {
                        Navigator.of(context).pop();
                        VehicleFormSheet.show(context, existing: v);
                      },
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded, color: accent, size: 20),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              VehicleFormSheet.show(context);
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.addVehicle),
          ),
        ),
      ],
    );
  }
}

/// Quick odometer bump — the single most frequent edit a user makes.
class OdometerSheet extends ConsumerStatefulWidget {
  const OdometerSheet({super.key, required this.vehicle});

  final Vehicle vehicle;

  static Future<void> show(BuildContext context, Vehicle vehicle) =>
      showAppSheet(
        context: context,
        builder: (_) => OdometerSheet(vehicle: vehicle),
      );

  @override
  ConsumerState<OdometerSheet> createState() => _OdometerSheetState();
}

class _OdometerSheetState extends ConsumerState<OdometerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.vehicle.currentOdometer.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeTagProvider);

    return AppSheetScaffold(
      formKey: _formKey,
      title: l10n.updateOdometer,
      icon: AppIcons.odometer,
      onSubmit: () async {
        if (!(_formKey.currentState?.validate() ?? false)) return;
        final value = int.tryParse(_controller.text.trim());
        if (value == null) return;
        await ref
            .read(vehicleControllerProvider.notifier)
            .updateOdometer(widget.vehicle.id, value);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      children: [
        AppTextField(
          controller: _controller,
          label: l10n.currentOdometer,
          required: true,
          numeric: true,
          suffix: l10n.km,
          validator: (value) {
            final parsed = int.tryParse(value?.trim() ?? '');
            if (parsed == null) return l10n.invalidNumber;
            // Odometers do not run backwards; catching it here explains why
            // rather than silently ignoring the entry.
            if (parsed < widget.vehicle.currentOdometer) {
              return '${l10n.currentOdometer}: '
                  '${Fmt.int0(widget.vehicle.currentOdometer, locale)}';
            }
            return null;
          },
        ),
      ],
    );
  }
}
