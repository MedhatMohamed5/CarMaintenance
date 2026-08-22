import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/emergency_contact.dart';
import 'fuel_guidance_cards.dart';

/// Emergency numbers and roadside guidance: who to call, what to do first,
/// what to do when the tank is empty, and how not to end up here again.
class EmergencySection extends ConsumerWidget {
  const EmergencySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.emergencyNumbers,
          icon: Icons.emergency_outlined,
        ),
        // Fixed tile height rather than an aspect ratio: on a wide viewport a
        // ratio would inflate these into oversized blocks.
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 68,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          children: [
            for (final contact in EmergencyContact.primary)
              _EmergencyTile(contact: contact),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final contact in EmergencyContact.values)
              if (!EmergencyContact.primary.contains(contact))
                _SecondaryDial(contact: contact),
          ],
        ),
        const SizedBox(height: 16),
        // Three peer cards, same rhythm: Roadside Tips carries no section
        // header, so neither do the two fuel cards. Each states its own title
        // inside the card, which is what makes them read as one stack.
        const _SafetyTipsCard(),
        const SizedBox(height: 12),
        const FuelEmergencyCard(),
        const SizedBox(height: 12),
        const FuelGuidelinesCard(),
      ],
    );
  }
}

class _EmergencyTile extends ConsumerWidget {
  const _EmergencyTile({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final color = Color(contact.colorValue);

    return GlassCard(
      accent: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () async {
        final ok = await ref.read(launcherServiceProvider).dial(contact.number);
        if (!ok && context.mounted) {
          showAppSnack(context, l10n.couldNotLaunch);
        }
      },
      child: Row(
        children: [
          AccentIconBadge(
            icon: Icons.phone_in_talk_rounded,
            color: color,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.raw(contact.l10nKey),
                  style: context.text.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    contact.number,
                    maxLines: 1,
                    style: AppTypography.numeric(
                      context.text.titleMedium,
                    ).copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryDial extends ConsumerWidget {
  const _SecondaryDial({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return PillChip(
      label: '${l10n.raw(contact.l10nKey)} · ${contact.number}',
      color: Color(contact.colorValue),
      icon: Icons.call_rounded,
      onTap: () async {
        final ok = await ref.read(launcherServiceProvider).dial(contact.number);
        if (!ok && context.mounted) {
          showAppSnack(context, l10n.couldNotLaunch);
        }
      },
    );
  }
}

class _SafetyTipsCard extends StatefulWidget {
  const _SafetyTipsCard();

  @override
  State<_SafetyTipsCard> createState() => _SafetyTipsCardState();
}

class _SafetyTipsCardState extends State<_SafetyTipsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GlassCard(
      accent: AppColors.amber,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AccentIconBadge(
                icon: Icons.health_and_safety_outlined,
                color: AppColors.amber,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.safetyTips, style: context.text.titleSmall),
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
                  for (var i = 0; i < SafetyTips.keys.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: context.text.labelSmall?.copyWith(
                                color: AppColors.amber,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.raw(SafetyTips.keys[i]),
                              style: context.text.bodySmall?.copyWith(
                                color: context.tokens.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
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
