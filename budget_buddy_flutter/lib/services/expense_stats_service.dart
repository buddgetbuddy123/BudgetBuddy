import '../models/expense.dart';

class ExpenseStats {
  final double total;
  final double weeklyTotal;
  final double monthlyTotal;
  final double averageExpense;
  final int count;

  const ExpenseStats({
    required this.total,
    required this.weeklyTotal,
    required this.monthlyTotal,
    required this.averageExpense,
    required this.count,
  });
}

class ExpenseStatsService {
  DateTime _startOfWeek(DateTime now) {
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
  }

  DateTime _startOfMonth(DateTime now) {
    return DateTime(now.year, now.month, 1);
  }

  ExpenseStats calculate(List<Expense> expenses) {
    final now = DateTime.now();
    final startOfWeek = _startOfWeek(now);
    final startOfMonth = _startOfMonth(now);

    double total = 0;
    double weekly = 0;
    double monthly = 0;

    for (final exp in expenses) {
      total += exp.amount;

      if (!exp.date.isBefore(startOfWeek)) {
        weekly += exp.amount;
      }

      if (!exp.date.isBefore(startOfMonth)) {
        monthly += exp.amount;
      }
    }

    return ExpenseStats(
      total: total,
      weeklyTotal: weekly,
      monthlyTotal: monthly,
      averageExpense: expenses.isEmpty ? 0 : total / expenses.length,
      count: expenses.length,
    );
  }

  double projectedDailyAverage(List<Expense> expenses) {
    if (expenses.isEmpty) return 0;

    final dates = expenses.map((e) => e.date).toList()..sort();
    final daysDiff = dates.length <= 1
        ? 1
        : dates.last.difference(dates.first).inDays.clamp(1, 999999);

    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    return total / daysDiff;
  }

  double projectedWeekly(List<Expense> expenses) {
    return projectedDailyAverage(expenses) * 7;
  }

  double projectedMonthly(List<Expense> expenses) {
    return projectedDailyAverage(expenses) * 30;
  }
}