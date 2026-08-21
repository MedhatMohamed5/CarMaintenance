class ReportRow {
  const ReportRow({
    required this.date,
    required this.type,
    required this.description,
    required this.odometer,
    required this.amount,
    this.quantity,
    this.efficiency,
  });

  final DateTime date;
  final String type;
  final String description;
  final int odometer;
  final double amount;
  final double? quantity;
  final double? efficiency;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'type': type,
    'description': description,
    'odometer': odometer,
    'amount': amount,
    'quantity': quantity,
    'efficiency': efficiency,
  };
}

class AnalyticsReport {
  const AnalyticsReport({
    required this.vehicleName,
    required this.vehicleSubtitle,
    required this.generatedAt,
    required this.rangeStart,
    required this.rangeEnd,
    required this.currentOdometer,
    required this.fuelCost,
    required this.serviceCost,
    required this.otherCost,
    required this.distanceKm,
    required this.liters,
    required this.avgEfficiency,
    required this.costPerKm,
    required this.rows,
  });

  final String vehicleName;
  final String vehicleSubtitle;
  final DateTime generatedAt;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int currentOdometer;

  final double fuelCost;
  final double serviceCost;
  final double otherCost;
  final int distanceKm;
  final double liters;
  final double avgEfficiency;
  final double costPerKm;

  final List<ReportRow> rows;

  double get totalCost => fuelCost + serviceCost + otherCost;

  Map<String, dynamic> toJson() => {
    'vehicleName': vehicleName,
    'vehicleSubtitle': vehicleSubtitle,
    'generatedAt': generatedAt.toIso8601String(),
    'rangeStart': rangeStart.toIso8601String(),
    'rangeEnd': rangeEnd.toIso8601String(),
    'currentOdometer': currentOdometer,
    'fuelCost': fuelCost,
    'serviceCost': serviceCost,
    'otherCost': otherCost,
    'totalCost': totalCost,
    'distanceKm': distanceKm,
    'liters': liters,
    'avgEfficiency': avgEfficiency,
    'costPerKm': costPerKm,
    'rows': rows.map((r) => r.toJson()).toList(),
  };
}
