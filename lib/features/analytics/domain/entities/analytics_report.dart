import 'dart:typed_data';

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
    this.category,
    this.categoryLabel,
    this.quantity,
    this.efficiency,
  });

  final DateTime date;

  /// `fuel`, `service` or `expense`. A stable key, never translated, so the
  /// CSV and JSON exports can be parsed the same way in any language.
  final String type;

  final String description;
  final int odometer;
  final double amount;

  /// What kind of thing this was, within its [type] — the expense category, or
  /// the grade of fuel. Also a stable key, for the same reason [type] is.
  ///
  /// A row that read `expense · 240.00` said nothing about whether that was
  /// parking, a fine or a new set of mats. Null on services, which have no
  /// sub-kind.
  final String? category;

  /// [category] translated, for the PDF. The machine-readable exports use the
  /// key; only the printed report uses this.
  final String? categoryLabel;

  final double? quantity;
  final double? efficiency;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'type': type,
    if (category != null) 'category': category,
    'description': description,
    'odometer': odometer,
    'amount': amount,
    'quantity': quantity,
    'efficiency': efficiency,
  };
}

/// The forward-looking half of the report.
///
/// Mirrors `VehicleForecast` rather than reaching for it, so the exporter stays
/// free of providers and the JSON/CSV writers see the same flat shape the PDF
/// does. Null when the vehicle has too little history to project from — the
/// renderer omits the section rather than printing zeros.
class ReportForecast {
  const ReportForecast({
    required this.avgDailyKm,
    required this.monthlyKm,
    required this.yearlyKm,
    required this.monthlyFuelCost,
    required this.yearlyFuelCost,
    required this.monthlyLiters,
    required this.monthlyMaintenanceCost,
    required this.yearlyMaintenanceCost,
    required this.monthlyOtherCost,
    required this.yearlyOtherCost,
    required this.monthlyPolicyCost,
    required this.yearlyPolicyCost,
  });

  final double avgDailyKm;
  final double monthlyKm;
  final double yearlyKm;

  final double monthlyFuelCost;
  final double yearlyFuelCost;
  final double monthlyLiters;

  final double monthlyMaintenanceCost;
  final double yearlyMaintenanceCost;

  final double monthlyOtherCost;
  final double yearlyOtherCost;

  /// Insurance and licensing, spread over the months each renewal covers.
  final double monthlyPolicyCost;
  final double yearlyPolicyCost;

  double get monthlyTotal =>
      monthlyFuelCost +
      monthlyMaintenanceCost +
      monthlyOtherCost +
      monthlyPolicyCost;

  double get yearlyTotal =>
      yearlyFuelCost +
      yearlyMaintenanceCost +
      yearlyOtherCost +
      yearlyPolicyCost;

  Map<String, dynamic> toJson() => {
    'avgDailyKm': avgDailyKm,
    'monthlyKm': monthlyKm,
    'yearlyKm': yearlyKm,
    'monthlyFuelCost': monthlyFuelCost,
    'yearlyFuelCost': yearlyFuelCost,
    'monthlyLiters': monthlyLiters,
    'monthlyMaintenanceCost': monthlyMaintenanceCost,
    'yearlyMaintenanceCost': yearlyMaintenanceCost,
    'monthlyOtherCost': monthlyOtherCost,
    'yearlyOtherCost': yearlyOtherCost,
    'monthlyPolicyCost': monthlyPolicyCost,
    'yearlyPolicyCost': yearlyPolicyCost,
    'monthlyTotal': monthlyTotal,
    'yearlyTotal': yearlyTotal,
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
    this.localeTag = 'en',
    this.currencyLabel = '',
    this.plateNumber,
    this.vehicleImage,
    this.forecast,
    this.efficiencySeries = const [],
    this.costPerKmSeries = const [],
    this.spendSlices = const [],
  });

  final String vehicleName;
  final String vehicleSubtitle;

  /// The language the report was generated in, carried on the report itself so
  /// the renderer can localise without a `BuildContext` — it runs off the UI
  /// thread and has no way to reach `Localizations.of`.
  final String localeTag;

  /// Already localised, so the renderer never has to know what currency means.
  final String currencyLabel;

  /// Printed on the report's identity card. Null when the driver never entered
  /// one, and the card simply omits the badge.
  final String? plateNumber;

  /// The vehicle photo, decoded once here rather than in the renderer.
  ///
  /// The builder runs without a `BuildContext` and must not touch storage, so
  /// it takes bytes it can hand straight to `pw.MemoryImage`. Null when the
  /// vehicle has no photo, or when the stored copy could not be decoded — a
  /// broken image is not worth failing an export over.
  final Uint8List? vehicleImage;
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

  /// Null when the vehicle has too little history to project from.
  final ReportForecast? forecast;

  double get totalCost => fuelCost + serviceCost + partsCost + otherCost;

  Map<String, dynamic> toJson() => {
    'locale': localeTag,
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
    if (forecast != null) 'forecast': forecast!.toJson(),
    'rows': rows.map((r) => r.toJson()).toList(),
    'charts': {
      'efficiency': efficiencySeries.map((p) => p.toJson()).toList(),
      'costPerKm': costPerKmSeries.map((p) => p.toJson()).toList(),
      'spend': spendSlices.map((s) => s.toJson()).toList(),
    },
  };
}
