import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../utils/advice_helper.dart';

class AdviceScreen extends StatefulWidget {
  final int refreshTick;

  const AdviceScreen({super.key, required this.refreshTick});

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  final storage = StorageService();

  List<Expense> expenses = [];
  double totalSpending = 0;
  double dailyAverage = 0;
  double projectedMonthly = 0;
  double projectedWeekly = 0;
  double weeklySpent = 0;
  double monthlySpent = 0;

  double? weeklyBudget;
  double? monthlyBudget;

  bool weeklyAdviceApplied = false;
  bool monthlyAdviceApplied = false;

  String advice = '';
  List<String> tips = [];
  Map<String, dynamic>? categoryAnalysis;
  Map<String, dynamic>? recommendedBudgets;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant AdviceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      load();
    }
  }

  Future<void> load() async {
    final loaded = await storage.getExpenses();
    final savedWeeklyBudget = await storage.getWeeklyBudget();
    final savedMonthlyBudget = await storage.getMonthlyBudget();
    final savedWeeklyAdviceApplied = await storage.getWeeklyAdviceApplied();
    final savedMonthlyAdviceApplied = await storage.getMonthlyAdviceApplied();

    final total = loaded.fold<double>(0, (sum, e) => sum + e.amount);

    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
    final startOfMonth = DateTime(now.year, now.month, 1);

    double week = 0;
    double month = 0;

    for (final e in loaded) {
      if (!e.date.isBefore(startOfWeek)) week += e.amount;
      if (!e.date.isBefore(startOfMonth)) month += e.amount;
    }

    double avgDaily = 0;
    double projMonthly = 0;
    double projWeekly = 0;
    Map<String, dynamic>? recommended;

    if (loaded.isNotEmpty) {
      final dates = loaded.map((e) => e.date).toList()..sort();
      final daysDiff = dates.length <= 1
          ? 1
          : dates.last.difference(dates.first).inDays.clamp(1, 999999);

      avgDaily = total / daysDiff;
      projMonthly = avgDaily * 30;
      projWeekly = avgDaily * 7;

      recommended = {
        'weekly': {
          'ideal': (avgDaily * 7 * 0.9).round(),
          'current': projWeekly.round(),
          'message': 'Based on your current spending',
        },
        'monthly': {
          'ideal': (avgDaily * 30 * 0.9).round(),
          'current': projMonthly.round(),
          'message': 'Suggested to reduce spending by 10%',
        },
      };
    }

    if (!mounted) return;

    setState(() {
      expenses = loaded;
      totalSpending = total;
      weeklySpent = week;
      monthlySpent = month;
      dailyAverage = avgDaily;
      projectedMonthly = projMonthly;
      projectedWeekly = projWeekly;
      weeklyBudget = savedWeeklyBudget;
      monthlyBudget = savedMonthlyBudget;
      weeklyAdviceApplied = savedWeeklyAdviceApplied;
      monthlyAdviceApplied = savedMonthlyAdviceApplied;
      recommendedBudgets = recommended;

      advice = getAdvice(
        totalSpending: total,
        expenses: loaded,
        weeklySpent: week,
        monthlySpent: month,
        weeklyBudget: savedWeeklyBudget,
        monthlyBudget: savedMonthlyBudget,
      );

      tips = getBudgetTips(
        totalSpending: total,
        expenses: loaded,
        weeklySpent: week,
        monthlySpent: month,
        weeklyBudget: savedWeeklyBudget,
        monthlyBudget: savedMonthlyBudget,
      );

      categoryAnalysis = getCategoryAnalysis(loaded);
    });
  }

  Future<void> applyRecommendedBudget(String type) async {
    if (recommendedBudgets == null) return;

    final int value = type == 'weekly'
        ? recommendedBudgets!['weekly']['ideal'] as int
        : recommendedBudgets!['monthly']['ideal'] as int;

    if (type == 'weekly') {
      await storage.setWeeklyBudget(value.toDouble());
      await storage.setWeeklyAdviceApplied(true);
    } else {
      await storage.setMonthlyBudget(value.toDouble());
      await storage.setMonthlyAdviceApplied(true);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${type == 'weekly' ? 'Weekly' : 'Monthly'} budget set to ₱$value!',
        ),
      ),
    );

    await load();
  }

  bool get isWeeklyRecommendationApplied {
    if (recommendedBudgets == null || weeklyBudget == null) return false;
    return weeklyBudget ==
        (recommendedBudgets!['weekly']['ideal'] as int).toDouble();
  }

  bool get isMonthlyRecommendationApplied {
    if (recommendedBudgets == null || monthlyBudget == null) return false;
    return monthlyBudget ==
        (recommendedBudgets!['monthly']['ideal'] as int).toDouble();
  }

  Widget buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.analytics, size: 48, color: Color(0xFF4A90E2)),
            const SizedBox(height: 12),
            const Text(
              'Your Spending Analysis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    label: 'Total Spent',
                    value: '₱${totalSpending.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _statBox(
                    label: 'Daily Avg',
                    value: '₱${dailyAverage.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _statBox(
                    label: 'Monthly Projected',
                    value: '₱${projectedMonthly.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox({required String label, required String value}) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A90E2),
          ),
        ),
      ],
    );
  }

  Widget buildCategoryCard() {
    if (categoryAnalysis == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '50/30/20 Rule Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            buildCategoryRow(
              icon: Icons.fastfood,
              iconColor: Colors.green,
              label: 'Needs',
              percent: categoryAnalysis!['needs']['percentage'].toStringAsFixed(
                0,
              ),
              target: categoryAnalysis!['needs']['target'].toString(),
              amount: categoryAnalysis!['needs']['amount'],
            ),
            buildCategoryRow(
              icon: Icons.sports_esports,
              iconColor: Colors.orange,
              label: 'Wants',
              percent: categoryAnalysis!['wants']['percentage'].toStringAsFixed(
                0,
              ),
              target: categoryAnalysis!['wants']['target'].toString(),
              amount: categoryAnalysis!['wants']['amount'],
            ),
            buildCategoryRow(
              icon: Icons.account_balance_wallet,
              iconColor: const Color(0xFF4A90E2),
              label: 'Savings',
              percent: categoryAnalysis!['savings']['percentage']
                  .toStringAsFixed(0),
              target: categoryAnalysis!['savings']['target'].toString(),
              amount: categoryAnalysis!['savings']['amount'],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCategoryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String percent,
    required String target,
    required dynamic amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '(Target: $target%)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              '₱${(amount as num).toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A90E2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecommendationCard() {
    if (recommendedBudgets == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5F2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A90E2), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Budget (Based on Your Spending)',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'To reduce spending by 10% from current rate',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          buildBudgetRecommendationBox(
            title: 'Weekly Budget',
            current: recommendedBudgets!['weekly']['current'] as int,
            ideal: recommendedBudgets!['weekly']['ideal'] as int,
            isApplied: isWeeklyRecommendationApplied,
            appliedBudget: weeklyBudget,
            onApply: () => applyRecommendedBudget('weekly'),
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 12),
          buildBudgetRecommendationBox(
            title: 'Monthly Budget',
            current: recommendedBudgets!['monthly']['current'] as int,
            ideal: recommendedBudgets!['monthly']['ideal'] as int,
            isApplied: isMonthlyRecommendationApplied,
            appliedBudget: monthlyBudget,
            onApply: () => applyRecommendedBudget('monthly'),
            icon: Icons.calendar_month,
          ),
        ],
      ),
    );
  }

  Widget buildBudgetRecommendationBox({
    required String title,
    required int current,
    required int ideal,
    required bool isApplied,
    required double? appliedBudget,
    required VoidCallback onApply,
    required IconData icon,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4A90E2)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Current Rate:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱ $current',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF4A90E2),
                  size: 28,
                ),
                Column(
                  children: [
                    const Text(
                      'Recommended:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱ $ideal',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!isApplied)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    appliedBudget == null
                        ? 'Apply Recommended Budget'
                        : 'Update to Recommended Budget',
                  ),
                ),
              )
            else
              Text(
                'Applied budget: ₱${appliedBudget?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildAdviceCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber),
              SizedBox(width: 10),
              Text(
                'Your Budget Coach Says:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(advice, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }

  Widget buildTipsSection() {
    if (tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Action Steps',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...tips.map(
          (tip) => Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(tip),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advice')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            buildSummaryCard(),
            const SizedBox(height: 12),
            buildCategoryCard(),
            const SizedBox(height: 12),
            buildRecommendationCard(),
            const SizedBox(height: 12),
            buildAdviceCard(),
            const SizedBox(height: 16),
            buildTipsSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
