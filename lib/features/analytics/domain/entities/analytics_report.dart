/// One point on a report chart. Kept deliberately dumb — a date and a number —
/// so the PDF renderer never has to reach back into providers.
class ReportPoint {
  const ReportPoint({required this.date, required this.value});

  final DateTime date;
  final double value;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'value': value,
  };
}

/// One slice of the spend breakdown chart.
class ReportSlice {
  const ReportSlice({
    required this.label,
    required this.value,
    required this.colorValue,
  });

  final String label;
  final double value;
  final int colorValue;

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

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
    required this.avgLitersPer100Km,
    required this.costPerKm,
    required this.fuelCostPerKm,
    required this.partsCost,
    required this.rows,
    this.efficiencySeries = const [],
    this.costPerKmSeries = const [],
    this.spendSlices = const [],
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
  final double avgLitersPer100Km;

  /// Every cost stream over the tracked distance.
  final double costPerKm;

  /// Fuel alone over the tracked distance.
  final double fuelCostPerKm;

  final double partsCost;

  final List<ReportRow> rows;

  /// Chart series, oldest first. Empty when there is not enough history to
  /// plot; the renderer simply omits the panel.
  final List<ReportPoint> efficiencySeries;
  final List<ReportPoint> costPerKmSeries;
  final List<ReportSlice> spendSlices;

  double get totalCost => fuelCost + serviceCost + partsCost + otherCost;

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
    'partsCost': partsCost,
    'avgLitersPer100Km': avgLitersPer100Km,
    'avgEfficiency': avgEfficiency,
    'fuelCostPerKm': fuelCostPerKm,
    'costPerKm': costPerKm,
    'rows': rows.map((r) => r.toJson()).toList(),
    'charts': {
      'efficiency': efficiencySeries.map((p) => p.toJson()).toList(),
      'costPerKm': costPerKmSeries.map((p) => p.toJson()).toList(),
      'spend': spendSlices.map((s) => s.toJson()).toList(),
    },
  };
}
