import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/vehicle_providers.dart';
import '../screens/vehicle_form_sheet.dart';

/// The one thing every logging form needs before it can mean anything: a car
/// to log against.
///
/// **Enforced at `show()`, not at the call sites.** Every entry point in the
/// app funnels through a sheet's own static opener — the dashboard's quick
/// actions, each screen's FAB, the empty-state buttons, the schedule — and
/// guarding those one by one is a rule that has to be remembered every time a
/// new one is added. Guarding the opener is a rule that cannot be forgotten.
///
/// The failure this replaces was not a crash. Every form saves against
/// `selectedVehicleIdOrFirstProvider`, which is null with an empty garage, and
/// the controllers answer that with `return false` — so the driver filled in a
/// fuel log, pressed save, and got "something went wrong" with no hint that
/// the missing piece was a car.
class VehicleRequired {
  const VehicleRequired._();

  /// Whether the caller may proceed to open its form.
  ///
  /// With no vehicle, prompts for one. If the driver adds it there and then,
  /// this returns true and the form they originally asked for opens — the
  /// detour is the app's fault, so it should not also cost them the tap.
  static Future<bool> ensure(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    if (container.read(vehiclesProvider).isNotEmpty) return true;

    final wantsVehicle = await showAppSheet<bool>(
      context: context,
      builder: (_) => const _NoVehiclePrompt(),
    );
    if (wantsVehicle != true || !context.mounted) return false;

    // Opened from the caller's context, not the prompt's: that element is gone
    // by the time this line runs.
    await VehicleFormSheet.show(context);
    return container.read(vehiclesProvider).isNotEmpty;
  }
}

/// Shown when a form is reached with an empty garage anyway — a deep link, a
/// restored route, or a vehicle deleted while the sheet was open.
///
/// The sheets guard their own openers, so in practice this is the second lock
/// on the same door. It exists because the first one is a `Future<bool>` that
/// a future call site could forget to await, and the cost of being wrong here
/// is a form that silently refuses to save.
class NoVehicleFallback extends StatelessWidget {
  const NoVehicleFallback({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppEmptyState(
            icon: Icons.directions_car_filled_outlined,
            title: l10n.raw('noVehicles'),
            message: l10n.raw('noVehiclesHint'),
            dense: true,
          ),
          const SizedBox(height: 4),
          _AddVehicleButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await VehicleFormSheet.show(context);
            },
          ),
        ],
      ),
    );
  }
}

/// The block-and-offer sheet: says what is missing, and does something about
/// it in one tap.
class _NoVehiclePrompt extends StatelessWidget {
  const _NoVehiclePrompt();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AccentIconBadge(
                icon: Icons.directions_car_filled_rounded,
                color: context.colors.primary,
                size: 58,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.raw('noVehicles'),
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.raw('noVehiclesHint'),
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: context.tokens.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            _AddVehicleButton(onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: context.tokens.textSecondary,
              ),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVehicleButton extends StatelessWidget {
  const _AddVehicleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.add_rounded, size: 20),
    label: Text(context.l10n.raw('addVehicle')),
    style: FilledButton.styleFrom(
      backgroundColor: context.colors.primary,
      foregroundColor: context.colors.onPrimary,
      elevation: 0,
    ),
  );
}
