import '../entities/expense.dart';

/// Totals and per-category shares for the expenses tab and the dashboard
/// spend card.
class ExpenseSummary {
  const ExpenseSummary({
    required this.total,
    required this.thisMonth,
    required this.slices,
    required this.monthlyTotals,
  });

  const ExpenseSummary.empty()
    : total = 0,
      thisMonth = 0,
      slices = const [],
      monthlyTotals = const {};

  final double total;
  final double thisMonth;

  /// Largest category first.
  final List<ExpenseSlice> slices;

  /// Month start → total, oldest first. Feeds the trend bars.
  final Map<DateTime, double> monthlyTotals;
}

class SummarizeExpenses {
  const SummarizeExpenses();

  ExpenseSummary call(List<Expense> expenses) {
    if (expenses.isEmpty) return const ExpenseSummary.empty();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    var total = 0.0;
    var thisMonth = 0.0;
    final byCategory = <ExpenseCategory, List<Expense>>{};
    final byMonth = <DateTime, double>{};

    for (final e in expenses) {
      total += e.amount;
      if (!e.date.isBefore(monthStart)) thisMonth += e.amount;
      byCategory.putIfAbsent(e.category, () => []).add(e);
      final m = DateTime(e.date.year, e.date.month);
      byMonth[m] = (byMonth[m] ?? 0) + e.amount;
    }

    final slices = byCategory.entries.map((entry) {
      final sum = entry.value.fold<double>(0, (s, e) => s + e.amount);
      return ExpenseSlice(
        category: entry.key,
        total: sum,
        count: entry.value.length,
        share: total <= 0 ? 0 : sum / total,
      );
    }).toList()..sort((a, b) => b.total.compareTo(a.total));

    final sortedMonths = byMonth.keys.toList()..sort();

    return ExpenseSummary(
      total: total,
      thisMonth: thisMonth,
      slices: slices,
      monthlyTotals: {for (final m in sortedMonths) m: byMonth[m]!},
    );
  }
}
