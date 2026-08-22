import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/guidance_card.dart';

/// The advice itself, as data. Adding a tip is one entry here plus two strings
/// in each locale — no widget changes.
const List<GuidanceCategory> kEcoTipCategories = [
  GuidanceCategory(
    labelKey: 'ecoCatDriving',
    icon: Icons.route_rounded,
    color: AppColors.green,
    tips: [
      GuidanceTip(titleKey: 'ecoDriving1', bodyKey: 'ecoDriving1Body'),
      GuidanceTip(titleKey: 'ecoDriving2', bodyKey: 'ecoDriving2Body'),
      GuidanceTip(titleKey: 'ecoDriving3', bodyKey: 'ecoDriving3Body'),
    ],
  ),
  GuidanceCategory(
    labelKey: 'ecoCatClimate',
    icon: Icons.ac_unit_rounded,
    color: AppColors.cyan,
    tips: [
      GuidanceTip(titleKey: 'ecoClimate1', bodyKey: 'ecoClimate1Body'),
      GuidanceTip(titleKey: 'ecoClimate2', bodyKey: 'ecoClimate2Body'),
      GuidanceTip(titleKey: 'ecoClimate3', bodyKey: 'ecoClimate3Body'),
    ],
  ),
  GuidanceCategory(
    labelKey: 'ecoCatVehicle',
    icon: Icons.tire_repair_rounded,
    color: AppColors.amber,
    tips: [
      GuidanceTip(titleKey: 'ecoVehicle1', bodyKey: 'ecoVehicle1Body'),
      GuidanceTip(titleKey: 'ecoVehicle2', bodyKey: 'ecoVehicle2Body'),
      GuidanceTip(titleKey: 'ecoVehicle3', bodyKey: 'ecoVehicle3Body'),
    ],
  ),
];

/// Practical ways to spend less at the pump, grouped by what the driver
/// actually controls: how they drive, how they cool the cabin, and how the car
/// is loaded and maintained.
class EcoDrivingTipsCard extends StatelessWidget {
  const EcoDrivingTipsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuidanceCard(
      titleKey: 'ecoTips',
      subtitleKey: 'ecoTipsHint',
      icon: Icons.eco_rounded,
      categories: kEcoTipCategories,
    );
  }
}
