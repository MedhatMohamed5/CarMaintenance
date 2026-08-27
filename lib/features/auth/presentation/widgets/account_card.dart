import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../screens/auth_screen.dart';

/// The account section of Settings: who is signed in, or an invitation to be.
///
/// **States the storage situation plainly in both cases.** "On this device
/// only" is not a warning — plenty of drivers will never want an account — but
/// it is something they should know before they lose a phone, and a guest
/// account needs telling that a reinstall takes the data with it.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authStateProvider).valueOrNull;

    Future<void> open() => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen()));

    Future<void> signOut() async {
      // Not `confirmDelete`: signing out removes nothing, and a red *Delete*
      // button over that question describes the wrong action entirely.
      final confirmed = await confirmAction(
        context,
        message: l10n.raw('authSignOutConfirm'),
        confirmLabel: l10n.raw('authSignOut'),
        destructive: false,
      );
      if (!confirmed) return;
      await ref.read(authControllerProvider.notifier).signOut();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.raw('authTitle'),
          icon: Icons.account_circle_outlined,
        ),
        GlassCard(
          accent: user == null ? null : AppColors.green,
          child: user == null
              ? _SignedOut(onTap: open)
              : _SignedIn(
                  name: user.isAnonymous
                      ? l10n.raw('authAnonymous')
                      : user.label,
                  hint: user.isAnonymous
                      ? l10n.raw('authAnonymousHint')
                      : l10n.raw('syncCloudOn'),
                  onSignOut: signOut,
                ),
        ),
      ],
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.smartphone_rounded,
              size: 20,
              color: context.tokens.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.raw('authLocalOnly'),
                style: context.text.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.raw('authLocalOnlyHint'),
          style: context.text.bodySmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: Text(l10n.raw('authSignIn')),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
      ],
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({
    required this.name,
    required this.hint,
    required this.onSignOut,
  });

  final String name;
  final String hint;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.cloud_done_rounded,
              size: 20,
              color: AppColors.green,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.raw('authSignedInAs'),
                    style: context.text.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: context.text.bodySmall?.copyWith(
            color: context.tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: Text(l10n.raw('authSignOut')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }
}
