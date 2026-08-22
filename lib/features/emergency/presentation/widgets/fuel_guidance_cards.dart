import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/guidance_card.dart';

/// What to do when the tank runs dry, in the order it has to happen: make the
/// car safe, stop damaging it, then refuel correctly.
const List<GuidanceCategory> kFuelEmergencyCategories = [
  GuidanceCategory(
    labelKey: 'fuelEmgCatSafety',
    icon: Icons.warning_amber_rounded,
    color: AppColors.red,
    tips: [
      GuidanceTip(titleKey: 'fuelEmg1', bodyKey: 'fuelEmg1Body'),
      GuidanceTip(titleKey: 'fuelEmg2', bodyKey: 'fuelEmg2Body'),
      GuidanceTip(titleKey: 'fuelEmg3', bodyKey: 'fuelEmg3Body'),
    ],
  ),
  GuidanceCategory(
    labelKey: 'fuelEmgCatEngine',
    icon: Icons.build_circle_outlined,
    color: AppColors.amber,
    tips: [
      GuidanceTip(titleKey: 'fuelEmg4', bodyKey: 'fuelEmg4Body'),
      GuidanceTip(titleKey: 'fuelEmg5', bodyKey: 'fuelEmg5Body'),
      GuidanceTip(titleKey: 'fuelEmg6', bodyKey: 'fuelEmg6Body'),
    ],
  ),
  GuidanceCategory(
    labelKey: 'fuelEmgCatRefuel',
    icon: Icons.local_gas_station_outlined,
    color: AppColors.cyan,
    tips: [
      GuidanceTip(titleKey: 'fuelEmg7', bodyKey: 'fuelEmg7Body'),
      GuidanceTip(titleKey: 'fuelEmg8', bodyKey: 'fuelEmg8Body'),
      GuidanceTip(titleKey: 'fuelEmg9', bodyKey: 'fuelEmg9Body'),
    ],
  ),
];

/// How to spend less at the pump, and what a sudden rise in consumption is
/// usually telling you.
const List<GuidanceCategory> kFuelGuidelineCategories = [
  GuidanceCategory(
    labelKey: 'fuelGuideCatDriving',
    icon: Icons.route_rounded,
    color: AppColors.green,
    tips: [
      GuidanceTip(titleKey: 'fuelGuide1', bodyKey: 'fuelGuide1Body'),
      GuidanceTip(titleKey: 'fuelGuide2', bodyKey: 'fuelGuide2Body'),
      GuidanceTip(titleKey: 'fuelGuide3', bodyKey: 'fuelGuide3Body'),
    ],
  ),
  GuidanceCategory(
    labelKey: 'fuelGuideCatMaintenance',
    icon: Icons.tire_repair_rounded,
    color: AppColors.amber,
    tips: [
      GuidanceTip(titleKey: 'fuelGuide4', bodyKey: 'fuelGuide4Body'),
      GuidanceTip(titleKey: 'fuelGuide5', bodyKey: 'fuelGuide5Body'),
      GuidanceTip(titleKey: 'fuelGuide6', bodyKey: 'fuelGuide6Body'),
    ],
  ),
  GuidanceCategory(
    labelKey: 'fuelGuideCatLoad',
    icon: Icons.luggage_outlined,
    color: AppColors.cyan,
    tips: [
      GuidanceTip(titleKey: 'fuelGuide7', bodyKey: 'fuelGuide7Body'),
      GuidanceTip(titleKey: 'fuelGuide8', bodyKey: 'fuelGuide8Body'),
      GuidanceTip(titleKey: 'fuelGuide9', bodyKey: 'fuelGuide9Body'),
    ],
  ),
];

/// Out-of-fuel procedure, on the screen a stranded driver already has open.
class FuelEmergencyCard extends StatelessWidget {
  const FuelEmergencyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuidanceCard(
      titleKey: 'fuelEmergency',
      subtitleKey: 'fuelEmergencyHint',
      icon: Icons.local_gas_station_rounded,
      categories: kFuelEmergencyCategories,
    );
  }
}

/// Consumption and efficiency guidance, next to the emergency procedure that
/// exists because someone ran out.
class FuelGuidelinesCard extends StatelessWidget {
  const FuelGuidelinesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const GuidanceCard(
      titleKey: 'fuelGuidelines',
      subtitleKey: 'fuelGuidelinesHint',
      icon: Icons.eco_rounded,
      categories: kFuelGuidelineCategories,
    );
  }
}
