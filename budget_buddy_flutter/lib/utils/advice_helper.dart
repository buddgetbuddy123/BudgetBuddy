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

String getAdvice({
  required double totalSpending,
  required List<Expense> expenses,
  required double weeklySpent,
  required double monthlySpent,
  double? weeklyBudget,
  double? monthlyBudget,
}) {
  if (expenses.isEmpty) {
    return 'Start tracking your expenses to get personalized budget advice! 🎯';
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
    return "💰 LOW SAVINGS ALERT! You're only saving ${savingsPercent.toStringAsFixed(0)}% "
        "(₱${savingsTotal.toStringAsFixed(2)}) of your total spending. "
        "You should be saving at least 20% (₱${needToSave.toStringAsFixed(2)} more). "
        "Cut back on wants to increase savings!";
  }

  if (wantsPercent > 40) {
    final excessWants = wantsTotal - (totalSpending * 0.30);
    return "🎮 HIGH WANTS SPENDING! You're spending ${wantsPercent.toStringAsFixed(0)}% "
        "(₱${wantsTotal.toStringAsFixed(2)}) on wants. Recommended is 30%. "
        "You're overspending on wants by ₱${excessWants.toStringAsFixed(2)}. "
        "Reduce entertainment, dining out, and treats!";
  }

  if (needsPercent > 60) {
    final excessNeeds = needsTotal - (totalSpending * 0.50);
    return "🍔 HIGH NEEDS SPENDING! You're spending ${needsPercent.toStringAsFixed(0)}% "
        "(₱${needsTotal.toStringAsFixed(2)}) on needs. Recommended is 50%. "
        "Review if all expenses are truly essential. Can you meal prep? "
        "Find cheaper alternatives? You could save ₱${excessNeeds.toStringAsFixed(2)}.";
  }

  if (monthlyBudget != null && monthlySpent > monthlyBudget) {
    final excess = monthlySpent - monthlyBudget;
    return "🚨 BUDGET EXCEEDED! You've spent ₱${monthlySpent.toStringAsFixed(2)} this month "
        "(budget: ₱${monthlyBudget.toStringAsFixed(2)}). You're over by "
        "₱${excess.toStringAsFixed(2)}. Your wants are ${wantsPercent.toStringAsFixed(0)}%. "
        "STOP all non-essential spending now!";
  }

  if (weeklyBudget != null && weeklySpent > weeklyBudget) {
    final excess = weeklySpent - weeklyBudget;
    return "⚠️ WEEKLY BUDGET EXCEEDED! You've spent ₱${weeklySpent.toStringAsFixed(2)} this week "
        "(budget: ₱${weeklyBudget.toStringAsFixed(2)}). You're over by "
        "₱${excess.toStringAsFixed(2)}. Avoid wants for the rest of the week!";
  }

  if (projectedMonthly > 10000) {
    return "📊 HIGH PROJECTED SPENDING! Based on your current rate "
        "(₱${avgDailySpending.toStringAsFixed(2)}/day), you're projected to spend "
        "₱${projectedMonthly.toStringAsFixed(2)} per month. This is very high for a student! "
        "Current breakdown: Needs ${needsPercent.toStringAsFixed(0)}%, "
        "Wants ${wantsPercent.toStringAsFixed(0)}%, "
        "Savings ${savingsPercent.toStringAsFixed(0)}%.";
  }

  if (projectedMonthly > 7000) {
    return "⚡ MODERATE-HIGH SPENDING. You're averaging ₱${avgDailySpending.toStringAsFixed(2)} "
        "per day (₱${projectedMonthly.toStringAsFixed(2)}/month projected). "
        "Try to reduce daily spending to ₱200-230. "
        "Your wants (${wantsPercent.toStringAsFixed(0)}%) could be reduced.";
  }

  if (savingsPercent >= 25) {
    return "🏆 EXCELLENT SAVINGS! You're saving ${savingsPercent.toStringAsFixed(0)}% "
        "(₱${savingsTotal.toStringAsFixed(2)}) - above the 20% target! Keep this up! "
        "Your spending is balanced: Needs ${needsPercent.toStringAsFixed(0)}%, "
        "Wants ${wantsPercent.toStringAsFixed(0)}%.";
  }

  if (savingsPercent >= 20) {
    return "✅ GREAT JOB! You're saving ${savingsPercent.toStringAsFixed(0)}% "
        "(₱${savingsTotal.toStringAsFixed(2)}) - hitting the 20% target! "
        "Your budget breakdown: Needs ${needsPercent.toStringAsFixed(0)}%, "
        "Wants ${wantsPercent.toStringAsFixed(0)}%. Keep it up!";
  }

  if (savingsPercent >= 15) {
    final needMore = (totalSpending * 0.20) - savingsTotal;
    return "👍 GOOD SAVINGS! You're saving ${savingsPercent.toStringAsFixed(0)}% "
        "(₱${savingsTotal.toStringAsFixed(2)}). Almost at 20% target! "
        "Try to save ₱${needMore.toStringAsFixed(2)} more by reducing wants "
        "(currently ${wantsPercent.toStringAsFixed(0)}%).";
  }

  if (wantsPercent > 35) {
    return "📊 Spending Breakdown: Needs ${needsPercent.toStringAsFixed(0)}%, "
        "Wants ${wantsPercent.toStringAsFixed(0)}%, "
        "Savings ${savingsPercent.toStringAsFixed(0)}%. "
        "Your wants spending is slightly high. Aim for 30% to improve savings!";
  }

  return "✨ BALANCED SPENDING! Needs ${needsPercent.toStringAsFixed(0)}%, "
      "Wants ${wantsPercent.toStringAsFixed(0)}%, "
      "Savings ${savingsPercent.toStringAsFixed(0)}%. "
      "You're close to the ideal 50/30/20 rule. Keep tracking to maintain this!";
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
      "💰 Save more! You're at ${savingsPercent.toStringAsFixed(0)}% savings "
      "(₱${savingsTotal.toStringAsFixed(2)}). Target is 20%. "
      "Save ₱${needToSave.toStringAsFixed(2)} more by cutting wants by "
      "${wantsCutPercent.toStringAsFixed(0)}%.",
    );
  } else if (savingsPercent >= 20) {
    tips.add(
      "✅ Great savings rate at ${savingsPercent.toStringAsFixed(0)}%! "
      "You're meeting the 20% target. Keep this up!",
    );
  }

  if (wantsPercent > 35) {
    final excessWants = wantsTotal - (totalSpending * 0.30);
    final savingsGain = excessWants;
    tips.add(
      "🎮 Reduce wants from ${wantsPercent.toStringAsFixed(0)}% to 30%. "
      "Cut ₱${excessWants.toStringAsFixed(2)} in entertainment/treats "
      "to boost savings by ₱${savingsGain.toStringAsFixed(2)}.",
    );
  } else if (wantsPercent <= 30) {
    tips.add(
      "👍 Wants spending is good at ${wantsPercent.toStringAsFixed(0)}% "
      "(target: 30%). You're controlling discretionary spending well!",
    );
  }

  if (needsPercent > 55) {
    tips.add(
      "🍔 Needs are ${needsPercent.toStringAsFixed(0)}% (target: 50%). "
      "Review essentials: Can you meal prep instead of buying meals? "
      "Walk short distances? Batch errands to save transport?",
    );
  }

  if (projectedMonthly > 8000) {
    const dailyTarget = 233.0;
    final needToCut = avgDailySpending - dailyTarget;
    tips.add(
      "📊 You're spending ₱${avgDailySpending.toStringAsFixed(2)}/day "
      "(₱${projectedMonthly.toStringAsFixed(2)}/month projected). "
      "Reduce to ₱${dailyTarget.toStringAsFixed(0)}/day by cutting "
      "₱${needToCut.toStringAsFixed(2)} daily.",
    );
  } else if (projectedMonthly > 5000) {
    tips.add(
      "📈 Moderate spending: ₱${avgDailySpending.toStringAsFixed(2)}/day "
      "(₱${projectedMonthly.toStringAsFixed(2)}/month projected). "
      "You're on track for student budget!",
    );
  } else {
    tips.add(
      "🌟 Low spending! ₱${avgDailySpending.toStringAsFixed(2)}/day average. "
      "Great control! Make sure you're not compromising on needs.",
    );
  }

  if (weeklyBudget == null && monthlyBudget == null) {
    tips.add(
      "💡 Set a budget! Based on your spending "
      "(₱${projectedMonthly.toStringAsFixed(2)}/month), "
      "try a weekly budget of ₱${(projectedWeekly * 0.9).toStringAsFixed(2)} "
      "to reduce spending by 10%.",
    );
  }

  final avgExpense = totalSpending / expenses.length;
  if (avgExpense > 250) {
    tips.add(
      "💳 Average expense is ₱${avgExpense.toStringAsFixed(2)}. "
      "You're making expensive purchases. Look for budget alternatives "
      "or buy in bulk to reduce cost per transaction.",
    );
  }

  return tips.take(3).toList();
}

Map<String, dynamic> getRecommendedBudgets(List<Expense> expenses) {
  if (expenses.isEmpty) {
    return {
      'weekly': 1500,
      'monthly': 5000,
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