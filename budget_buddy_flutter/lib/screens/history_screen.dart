import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../widgets/expense_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final storage = StorageService();
  List<Expense> expenses = [];
  bool showCharts = true;

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    final loaded = await storage.getExpenses();
    loaded.sort((a, b) => b.date.compareTo(a.date));
    if (!mounted) return;
    setState(() {
      expenses = loaded;
    });
  }

  Future<void> deleteExpense(String id) async {
    await storage.deleteExpense(id);
    await loadExpenses();
  }

  Future<void> clearAll() async {
    await storage.clearExpenses();
    await loadExpenses();
  }

  double getMonthlySpending() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return expenses
        .where((expense) => !expense.date.isBefore(startOfMonth))
        .fold<double>(0, (sum, expense) => sum + expense.amount);
  }

  double getWeeklySpending() {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));

    return expenses
        .where((expense) => !expense.date.isBefore(startOfWeek))
        .fold<double>(0, (sum, expense) => sum + expense.amount);
  }

  double getTotalSpending() {
    return expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
  }

  int getExpenseCount() {
    return expenses.length;
  }

  List<DateTime> getLast7Days() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return DateTime(day.year, day.month, day.day);
    });
  }

  Map<DateTime, double> getDailyTotals() {
    final days = getLast7Days();
    final totals = <DateTime, double>{
      for (final d in days) d: 0.0,
    };

    for (final expense in expenses) {
      final d = DateTime(expense.date.year, expense.date.month, expense.date.day);
      if (totals.containsKey(d)) {
        totals[d] = totals[d]! + expense.amount;
      }
    }

    return totals;
  }

  List<FlSpot> getLineSpots() {
    final dailyTotals = getDailyTotals();
    final days = getLast7Days();

    return List.generate(days.length, (index) {
      final day = days[index];
      return FlSpot(index.toDouble(), dailyTotals[day] ?? 0.0);
    });
  }

  double getMaxY() {
    final spots = getLineSpots();
    if (spots.isEmpty) return 100;

    final maxValue = spots
        .map((e) => e.y)
        .fold<double>(0, (prev, y) => y > prev ? y : prev);

    if (maxValue <= 100) return 100;
    return (maxValue * 1.2).ceilToDouble();
  }

  List<DateTime> getDaysOfCurrentMonth() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;

    return List.generate(lastDay, (index) {
      return DateTime(now.year, now.month, index + 1);
    });
  }

  Map<DateTime, double> getMonthlyDailyTotals() {
    final days = getDaysOfCurrentMonth();
    final totals = <DateTime, double>{
      for (final d in days) d: 0.0,
    };

    for (final expense in expenses) {
      final d = DateTime(expense.date.year, expense.date.month, expense.date.day);
      if (totals.containsKey(d)) {
        totals[d] = totals[d]! + expense.amount;
      }
    }

    return totals;
  }

  List<FlSpot> getMonthlyLineSpots() {
    final dailyTotals = getMonthlyDailyTotals();
    final days = getDaysOfCurrentMonth();

    return List.generate(days.length, (index) {
      final day = days[index];
      return FlSpot(index.toDouble(), dailyTotals[day] ?? 0.0);
    });
  }

  double getMonthlyMaxY() {
    final spots = getMonthlyLineSpots();
    if (spots.isEmpty) return 100;

    final maxValue = spots
        .map((e) => e.y)
        .fold<double>(0, (prev, y) => y > prev ? y : prev);

    if (maxValue <= 100) return 100;
    return (maxValue * 1.2).ceilToDouble();
  }

  Map<String, double> getCategoryTotals() {
    final totals = <String, double>{
      'needs': 0,
      'wants': 0,
      'savings': 0,
    };

    for (final expense in expenses) {
      totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
    }

    return totals;
  }

  List<PieChartSectionData> getPieSections() {
    final totals = getCategoryTotals();

    final colors = <String, Color>{
      'needs': Colors.green,
      'wants': Colors.orange,
      'savings': const Color(0xFF4A90E2),
    };

    final labels = <String, String>{
      'needs': 'Needs',
      'wants': 'Wants',
      'savings': 'Savings',
    };

    return totals.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => PieChartSectionData(
            value: entry.value,
            color: colors[entry.key]!,
            radius: 58,
            title: '${labels[entry.key]}\n₱${entry.value.toStringAsFixed(0)}',
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        )
        .toList();
  }

  Widget buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummarySection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildSummaryCard(
                title: 'Monthly',
                value: '₱${getMonthlySpending().toStringAsFixed(2)}',
                icon: Icons.calendar_month,
                color: const Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildSummaryCard(
                title: 'Weekly',
                value: '₱${getWeeklySpending().toStringAsFixed(2)}',
                icon: Icons.date_range,
                color: const Color(0xFF7E57C2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: buildSummaryCard(
                title: 'Total',
                value: '₱${getTotalSpending().toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet,
                color: const Color(0xFF26A69A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildSummaryCard(
                title: 'Expenses',
                value: '${getExpenseCount()}',
                icon: Icons.receipt_long,
                color: const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildLineChart() {
    final days = getLast7Days();
    final spots = getLineSpots();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Last 7 Days Spending',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: getMaxY(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: getMaxY() / 5,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= days.length) {
                            return const SizedBox.shrink();
                          }

                          final label = DateFormat('MM/dd').format(days[index]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: getMaxY() / 5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '₱${value.toInt()}',
                            style: const TextStyle(fontSize: 11),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final date = DateFormat('MMM d').format(days[index]);
                          return LineTooltipItem(
                            '$date\n₱${spot.y.toStringAsFixed(2)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 4,
                      color: const Color(0xFF4A90E2),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF4A90E2),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMonthlyLineChart() {
    final days = getDaysOfCurrentMonth();
    final spots = getMonthlyLineSpots();
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Monthly Spending - $monthLabel',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (days.length - 1).toDouble(),
                  minY: 0,
                  maxY: getMonthlyMaxY(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: getMonthlyMaxY() / 5,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: days.length > 15 ? 4 : 2,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= days.length) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${days[index].day}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: getMonthlyMaxY() / 5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '₱${value.toInt()}',
                            style: const TextStyle(fontSize: 11),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final date = DateFormat('MMM d').format(days[index]);
                          return LineTooltipItem(
                            '$date\n₱${spot.y.toStringAsFixed(2)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 4,
                      color: const Color(0xFF7E57C2),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF7E57C2),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF7E57C2).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPieChart() {
    final sections = getPieSections();

    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Spending by Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 38,
                  sections: sections,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _LegendItem(color: Colors.green, label: 'Needs'),
                _LegendItem(color: Colors.orange, label: 'Wants'),
                _LegendItem(color: Color(0xFF4A90E2), label: 'Savings'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildExpensesBox() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Expenses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 360,
              child: expenses.isEmpty
                  ? const Center(child: Text('No expenses found'))
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return ExpenseCard(
                            expense: expense,
                            onDelete: () => deleteExpense(expense.id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense History')),
        body: const Center(
          child: Text(
            'No Expense History Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                showCharts = !showCharts;
              });
            },
            icon: Icon(showCharts ? Icons.visibility_off : Icons.visibility),
          ),
          IconButton(
            onPressed: clearAll,
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadExpenses,
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            buildSummarySection(),
            const SizedBox(height: 12),
            if (showCharts) ...[
              buildLineChart(),
              const SizedBox(height: 12),
              buildMonthlyLineChart(),
              const SizedBox(height: 12),
              buildPieChart(),
              const SizedBox(height: 12),
            ],
            buildExpensesBox(),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}