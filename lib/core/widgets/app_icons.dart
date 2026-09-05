import 'package:flutter/material.dart';

/// Maps the string `iconKey`s carried by domain enums to concrete icons.
///
/// The domain layer stays framework-free — it names an icon, it does not import
/// Material to hold an `IconData`.
class AppIcons {
  const AppIcons._();

  static const Map<String, IconData> _map = {
    // Parts
    'oil': Icons.water_drop_outlined,
    'filter': Icons.filter_alt_outlined,
    'air': Icons.air_rounded,
    'brake': Icons.disc_full_outlined,
    'fluid': Icons.opacity_rounded,
    'tire': Icons.trip_origin_rounded,
    'coolant': Icons.ac_unit_rounded,
    'spark': Icons.bolt_rounded,
    'battery': Icons.battery_charging_full_rounded,
    // Expenses
    'build': Icons.build_rounded,
    'star': Icons.auto_awesome_rounded,
    'parking': Icons.local_parking_rounded,
    'gavel': Icons.gavel_rounded,
    'wash': Icons.local_car_wash_rounded,
    'road': Icons.add_road_rounded,
    'shield': Icons.verified_user_outlined,
    'doc': Icons.description_outlined,
    'more': Icons.more_horiz_rounded,
    // Services
    'service': Icons.build_circle_outlined,
    'serviceRepair': Icons.report_problem_rounded,
  };

  static IconData of(String key) => _map[key] ?? Icons.circle_outlined;

  // Frequently used icons, named once so screens stay consistent.
  static const IconData home = Icons.dashboard_rounded;
  static const IconData serviceLog = Icons.build_circle_outlined;
  static const IconData schedule = Icons.event_note_rounded;
  static const IconData fuel = Icons.local_gas_station_rounded;
  static const IconData expenses = Icons.receipt_long_rounded;
  static const IconData workshops = Icons.location_on_outlined;
  static const IconData emergency = Icons.warning_amber_rounded;
  static const IconData vehicle = Icons.directions_car_filled_rounded;
  static const IconData odometer = Icons.speed_rounded;
  static const IconData calendar = Icons.calendar_month_rounded;
  static const IconData phone = Icons.phone_in_talk_rounded;
  static const IconData map = Icons.map_outlined;
}
