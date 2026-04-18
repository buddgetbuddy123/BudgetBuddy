import '../models/expense.dart';

Map<String, double> getCategoryBreakdown(List<Expense> expenses) {
  final breakdown = {
    'needs': 0.0,
    'wants': 0.0,
    'savings': 0.0,
  };

  for (final exp in expenses) {
    final category = exp.category.isNotEmpty ? exp.category : 'needs';
    breakdown[category] = (breakdown[category] ?? 0) + exp.amount;
  }

  return breakdown;
}

String _buildMessage(String title, String body) {
  return '$title\n\n$body';
}

String getAdvice({
  required double totalSpending,
  required List<Expense> expenses,
  required double weeklySpent,
  required double monthlySpent,
  double? weeklyBudget,
  double? monthlyBudget,
}) {
  if (expenses.isEmpty) {
    return 'Start tracking your expenses to get personalized budget advice.';
  }

  final categoryTotals = getCategoryBreakdown(expenses);
  final needsTotal = categoryTotals['needs'] ?? 0;
  final wantsTotal = categoryTotals['wants'] ?? 0;
  final savingsTotal = categoryTotals['savings'] ?? 0;

  final needsPercent = (needsTotal / totalSpending) * 100;
  final wantsPercent = (wantsTotal / totalSpending) * 100;
  final savingsPercent = (savingsTotal / totalSpending) * 100;

  final dates = expenses.map((e) => e.date).toList()..sort();
  final oldestExpense = dates.first;
  final newestExpense = dates.last;
  final daysDiff = newestExpense.difference(oldestExpense).inDays;
  final safeDaysDiff = daysDiff <= 0 ? 1 : daysDiff;

  final avgDailySpending = totalSpending / safeDaysDiff;
  final projectedMonthly = avgDailySpending * 30;

  if (savingsPercent < 10) {
    final needToSave = (totalSpending * 0.20) - savingsTotal;
    return _buildMessage(
      'Low savings alert',
      "You're only saving ${savingsPercent.toStringAsFixed(0)}% "
      "(₱${savingsTotal.toStringAsFixed(2)}) of your total spending. "
      "Try to save at least 20% by adding ₱${needToSave.toStringAsFixed(2)} more.",
    );
  }

  if (wantsPercent > 40) {
    final excessWants = wantsTotal - (totalSpending * 0.30);
    return _buildMessage(
      'High wants spending',
      "You're spending ${wantsPercent.toStringAsFixed(0)}% "
      "(₱${wantsTotal.toStringAsFixed(2)}) on wants. "
      "Recommended is 30%. You're over by ₱${excessWants.toStringAsFixed(2)}.",
    );
  }

  if (needsPercent > 60) {
    final excessNeeds = needsTotal - (totalSpending * 0.50);
    return _buildMessage(
      'High needs spending',
      "You're spending ${needsPercent.toStringAsFixed(0)}% "
      "(₱${needsTotal.toStringAsFixed(2)}) on needs. "
      "Review essential expenses and try to reduce about ₱${excessNeeds.toStringAsFixed(2)}.",
    );
  }

  if (monthlyBudget != null && monthlySpent > monthlyBudget) {
    final excess = monthlySpent - monthlyBudget;
    return _buildMessage(
      'Monthly budget exceeded',
      "You've spent ₱${monthlySpent.toStringAsFixed(2)} this month "
      "with a budget of ₱${monthlyBudget.toStringAsFixed(2)}. "
      "You're over by ₱${excess.toStringAsFixed(2)}.",
    );
  }

  if (weeklyBudget != null && weeklySpent > weeklyBudget) {
    final excess = weeklySpent - weeklyBudget;
    return _buildMessage(
      'Weekly budget exceeded',
      "You've spent ₱${weeklySpent.toStringAsFixed(2)} this week "
      "with a budget of ₱${weeklyBudget.toStringAsFixed(2)}. "
      "You're over by ₱${excess.toStringAsFixed(2)}.",
    );
  }

  if (projectedMonthly > 10000) {
    return _buildMessage(
      'High projected spending',
      "Based on your current rate of ₱${avgDailySpending.toStringAsFixed(2)} per day, "
      "you may spend ₱${projectedMonthly.toStringAsFixed(2)} this month.",
    );
  }

  if (projectedMonthly > 7000) {
    return _buildMessage(
      'Moderate-high spending',
      "You're averaging ₱${avgDailySpending.toStringAsFixed(2)} per day "
      "with a projected monthly spend of ₱${projectedMonthly.toStringAsFixed(2)}.",
    );
  }

  if (savingsPercent >= 25) {
    return _buildMessage(
      'Excellent savings',
      "You're saving ${savingsPercent.toStringAsFixed(0)}% "
      "(₱${savingsTotal.toStringAsFixed(2)}), which is above the 20% target.",
    );
  }

  if (savingsPercent >= 20) {
    return _buildMessage(
      'Great job',
      "You're saving ${savingsPercent.toStringAsFixed(0)}% "
      "(₱${savingsTotal.toStringAsFixed(2)}), which meets the 20% target.",
    );
  }

  if (savingsPercent >= 15) {
    final needMore = (totalSpending * 0.20) - savingsTotal;
    return _buildMessage(
      'Good savings',
      "You're saving ${savingsPercent.toStringAsFixed(0)}% "
      "(₱${savingsTotal.toStringAsFixed(2)}). "
      "Try to save ₱${needMore.toStringAsFixed(2)} more to reach 20%.",
    );
  }

  if (wantsPercent > 35) {
    return _buildMessage(
      'Spending breakdown',
      "Needs: ${needsPercent.toStringAsFixed(0)}%, "
      "Wants: ${wantsPercent.toStringAsFixed(0)}%, "
      "Savings: ${savingsPercent.toStringAsFixed(0)}%. "
      "Your wants spending is a bit high.",
    );
  }

  return _buildMessage(
    'Balanced spending',
    "Needs: ${needsPercent.toStringAsFixed(0)}%, "
    "Wants: ${wantsPercent.toStringAsFixed(0)}%, "
    "Savings: ${savingsPercent.toStringAsFixed(0)}%. "
    "You're close to the 50/30/20 rule.",
  );
}

List<String> getBudgetTips({
  required double totalSpending,
  required List<Expense> expenses,
  required double weeklySpent,
  required double monthlySpent,
  double? weeklyBudget,
  double? monthlyBudget,
}) {
  if (expenses.isEmpty) {
    return [];
  }

  final tips = <String>[];
  final categoryTotals = getCategoryBreakdown(expenses);

  final needsTotal = categoryTotals['needs'] ?? 0;
  final wantsTotal = categoryTotals['wants'] ?? 0;
  final savingsTotal = categoryTotals['savings'] ?? 0;

  final needsPercent = (needsTotal / totalSpending) * 100;
  final wantsPercent = (wantsTotal / totalSpending) * 100;
  final savingsPercent = (savingsTotal / totalSpending) * 100;

  final dates = expenses.map((e) => e.date).toList()..sort();
  final oldestExpense = dates.first;
  final newestExpense = dates.last;
  final daysDiff = newestExpense.difference(oldestExpense).inDays;
  final safeDaysDiff = daysDiff <= 0 ? 1 : daysDiff;

  final avgDailySpending = totalSpending / safeDaysDiff;
  final projectedWeekly = avgDailySpending * 7;
  final projectedMonthly = avgDailySpending * 30;

  if (savingsPercent < 15) {
    final needToSave = (totalSpending * 0.20) - savingsTotal;
    final wantsCutPercent =
        wantsTotal > 0 ? ((needToSave / wantsTotal) * 100) : 0.0;

    tips.add(
      "Save more. You're at ${savingsPercent.toStringAsFixed(0)}% savings. "
      "Try to save ₱${needToSave.toStringAsFixed(2)} more by cutting wants by "
      "${wantsCutPercent.toStringAsFixed(0)}%.",
    );
  } else if (savingsPercent >= 20) {
    tips.add(
      "Great savings rate at ${savingsPercent.toStringAsFixed(0)}%. "
      "You're meeting the 20% target.",
    );
  }

  if (wantsPercent > 35) {
    final excessWants = wantsTotal - (totalSpending * 0.30);
    tips.add(
      "Reduce wants from ${wantsPercent.toStringAsFixed(0)}% to 30%. "
      "Cut about ₱${excessWants.toStringAsFixed(2)} in non-essential spending.",
    );
  } else if (wantsPercent <= 30) {
    tips.add(
      "Your wants spending is under control at ${wantsPercent.toStringAsFixed(0)}%.",
    );
  }

  if (needsPercent > 55) {
    tips.add(
      "Needs are ${needsPercent.toStringAsFixed(0)}%. "
      "Review essentials like meals and transportation for possible savings.",
    );
  }

  if (projectedMonthly > 8000) {
    const dailyTarget = 233.0;
    final needToCut = avgDailySpending - dailyTarget;
    tips.add(
      "You're spending ₱${avgDailySpending.toStringAsFixed(2)} per day. "
      "Try reducing by ₱${needToCut.toStringAsFixed(2)} daily.",
    );
  } else if (projectedMonthly > 5000) {
    tips.add(
      "Your spending is moderate at ₱${avgDailySpending.toStringAsFixed(2)} per day.",
    );
  } else {
    tips.add(
      "You're maintaining a low daily average of ₱${avgDailySpending.toStringAsFixed(2)}.",
    );
  }

  if (weeklyBudget == null && monthlyBudget == null) {
    tips.add(
      "Set a budget. Based on your spending, try a weekly budget of "
      "₱${(projectedWeekly * 0.9).toStringAsFixed(2)}.",
    );
  }

  final avgExpense = totalSpending / expenses.length;
  if (avgExpense > 250) {
    tips.add(
      "Your average expense is ₱${avgExpense.toStringAsFixed(2)}. "
      "Look for cheaper alternatives where possible.",
    );
  }

  return tips.take(3).toList();
}

Map<String, dynamic> getRecommendedBudgets(List<Expense> expenses) {
  if (expenses.isEmpty) {
    return {
      'weekly': 1500,
      'monthly': 5000,
      'currentWeekly': 0,
      'currentMonthly': 0,
      'message': 'Default student budget recommendations',
    };
  }

  final totalSpending = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);
  final dates = expenses.map((e) => e.date).toList()..sort();

  final oldestExpense = dates.first;
  final newestExpense = dates.last;
  final daysDiff = newestExpense.difference(oldestExpense).inDays;
  final safeDaysDiff = daysDiff <= 0 ? 1 : daysDiff;

  final avgDailySpending = totalSpending / safeDaysDiff;
  final currentWeekly = avgDailySpending * 7;
  final currentMonthly = avgDailySpending * 30;

  final recommendedWeekly = (currentWeekly * 0.9).round();
  final recommendedMonthly = (currentMonthly * 0.9).round();

  return {
    'weekly': recommendedWeekly,
    'monthly': recommendedMonthly,
    'currentWeekly': currentWeekly.round(),
    'currentMonthly': currentMonthly.round(),
    'message':
        'Based on your current ₱${avgDailySpending.toStringAsFixed(2)}/day spending',
  };
}

Map<String, dynamic>? getCategoryAnalysis(List<Expense> expenses) {
  if (expenses.isEmpty) {
    return null;
  }

  final breakdown = getCategoryBreakdown(expenses);
  final total =
      (breakdown['needs'] ?? 0) +
      (breakdown['wants'] ?? 0) +
      (breakdown['savings'] ?? 0);

  return {
    'needs': {
      'amount': breakdown['needs'] ?? 0,
      'percentage': ((breakdown['needs'] ?? 0) / total) * 100,
      'target': 50,
      'status': ((breakdown['needs'] ?? 0) / total) * 100 <= 55 ? 'good' : 'high',
    },
    'wants': {
      'amount': breakdown['wants'] ?? 0,
      'percentage': ((breakdown['wants'] ?? 0) / total) * 100,
      'target': 30,
      'status': ((breakdown['wants'] ?? 0) / total) * 100 <= 35 ? 'good' : 'high',
    },
    'savings': {
      'amount': breakdown['savings'] ?? 0,
      'percentage': ((breakdown['savings'] ?? 0) / total) * 100,
      'target': 20,
      'status': ((breakdown['savings'] ?? 0) / total) * 100 >= 15 ? 'good' : 'low',
    },
    'total': total,
  };
}