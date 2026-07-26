import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../services/expense_stats_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateToTab;
  final int refreshTick;

  const HomeScreen({
    super.key,
    required this.onNavigateToTab,
    required this.refreshTick,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final storage = StorageService();
  final statsService = ExpenseStatsService();

  late TabController _tabController;

  AppUser? currentUser;
  List<Expense> expenses = [];

  // Budget amounts
  double? weeklyBudget;
  double? monthlyBudget;

  // Spending totals
  double totalSpending = 0;
  int expenseCount = 0;
  double avgExpense = 0;
  double weeklySpent = 0;
  double monthlySpent = 0;
  double dailyAverage = 0;
  double projectedWeekly = 0;
  double projectedMonthly = 0;

  // Category totals
  double needsTotal = 0;
  double wantsTotal = 0;
  double savingsTotal = 0;

  // Budget period start dates
  DateTime? _weeklyBudgetStart;
  DateTime? _monthlyBudgetStart;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadExpenses();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) loadExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── LOAD ────────────────────────────────────────────────────────────────

  Future<void> loadExpenses() async {
    try {
      final user = await storage.getCurrentUser();
      final weekly = await storage.getWeeklyBudget();
      final monthly = await storage.getMonthlyBudget();
      final weeklyStart = await storage.getWeeklyBudgetDate();
      final monthlyStart = await storage.getMonthlyBudgetDate();
      final loaded = await storage.getExpenses();
      final stats = statsService.calculate(loaded);
      final avgDaily = statsService.projectedDailyAverage(loaded);

      // Category totals
      double needs = 0, wants = 0, savings = 0;
      for (final e in loaded) {
        if (e.category == 'needs') {
          needs += e.amount;
        } else if (e.category == 'wants') {
          wants += e.amount;
        } else {
          savings += e.amount;
        }
      }

      if (!mounted) return;
      setState(() {
        currentUser = user;
        expenses = loaded;
        weeklyBudget = weekly;
        monthlyBudget = monthly;
        _weeklyBudgetStart = weeklyStart;
        _monthlyBudgetStart = monthlyStart;
        totalSpending = stats.total;
        expenseCount = stats.count;
        avgExpense = stats.averageExpense;
        weeklySpent = stats.weeklyTotal;
        monthlySpent = stats.monthlyTotal;
        dailyAverage = avgDaily;
        projectedWeekly = avgDaily * 7;
        projectedMonthly = avgDaily * 30;
        needsTotal = needs;
        wantsTotal = wants;
        savingsTotal = savings;
      });
    } catch (e) {
      debugPrint('Error loading: $e');
    }
  }

  // ─── DATE RANGE HELPERS ──────────────────────────────────────────────────

  List<DateTime> get weeklyDays {
    DateTime start;

    if (_weeklyBudgetStart != null) {
      start = DateTime(
        _weeklyBudgetStart!.year,
        _weeklyBudgetStart!.month,
        _weeklyBudgetStart!.day,
      );
    } else {
      final now = DateTime.now();

      // Monday of the current week
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
    }

    return List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  List<DateTime> get monthlyDays {
    if (_monthlyBudgetStart != null) {
      final start = DateTime(
        _monthlyBudgetStart!.year,
        _monthlyBudgetStart!.month,
        _monthlyBudgetStart!.day,
      );
      return List.generate(30, (i) {
        final d = start.add(Duration(days: i));
        return DateTime(d.year, d.month, d.day);
      });
    }
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return List.generate(lastDay, (i) => DateTime(now.year, now.month, i + 1));
  }

  String get weeklyLabel {
    final days = weeklyDays;
    final s = days.first;
    final e = days.last;
    final fmt = DateFormat('MMM d');
    final yr = DateFormat('yyyy').format(s);
    return s.month == e.month
        ? '${fmt.format(s)}–${e.day}, $yr'
        : '${fmt.format(s)} – ${fmt.format(e)}, $yr';
  }

  String get monthlyLabel {
    if (_monthlyBudgetStart == null) {
      return DateFormat('MMMM yyyy').format(DateTime.now());
    }
    final days = monthlyDays;
    final s = days.first;
    final e = days.last;
    final fmt = DateFormat('MMM d');
    return '${fmt.format(s)} – ${fmt.format(e)}, ${e.year}';
  }

  Map<DateTime, double> _buildDailyTotals(List<DateTime> days) {
    final totals = <DateTime, double>{for (final d in days) d: 0.0};
    for (final e in expenses) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      if (totals.containsKey(d)) totals[d] = totals[d]! + e.amount;
    }
    return totals;
  }

  // ─── COLOURS ─────────────────────────────────────────────────────────────

  static const _blue = Color(0xFF4A90E2);
  static const _green = Color(0xFF4CAF50);
  static const _orange = Color(0xFFFF9800);
  static const _purple = Color(0xFF7E57C2);
  static const _red = Color(0xFFFF4444);
  static const _grey = Color(0xFF666666);
  static const _bgCard = Colors.white;

  Color _budgetColor(double ratio) {
    if (ratio >= 1) return _red;
    if (ratio >= 0.8) return _orange;
    return _green;
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────────

  Widget _card({required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.07),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: _grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── BUDGET PROGRESS CARD ────────────────────────────────────────────────

  Widget _buildBudgetProgress({
    required String label,
    required String dateRange,
    required double spent,
    required double? budget,
    required double projected,
  }) {
    if (budget == null) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(dateRange, style: const TextStyle(fontSize: 12, color: _grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline, color: _grey, size: 16),
                const SizedBox(width: 6),
                Text(
                  'No budget set — tap Budget to set one',
                  style: const TextStyle(fontSize: 12, color: _grey),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final ratio = (spent / budget).clamp(0.0, 1.0);
    final color = _budgetColor(spent / budget);
    final remaining = budget - spent;
    final exceeded = spent > budget;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Text(
                      dateRange,
                      style: const TextStyle(fontSize: 12, color: _grey),
                    ),
                  ],
                ),
              ),
              if (exceeded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _red),
                  ),
                  child: const Text(
                    'EXCEEDED',
                    style: TextStyle(
                      fontSize: 10,
                      color: _red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statPill('Spent', '₱${spent.toStringAsFixed(0)}', color),
              const SizedBox(width: 8),
              _statPill(
                exceeded ? 'Over by' : 'Remaining',
                '₱${remaining.abs().toStringAsFixed(0)}',
                exceeded ? _red : _green,
              ),
              const SizedBox(width: 8),
              _statPill('Budget', '₱${budget.toStringAsFixed(0)}', _blue),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.trending_up, size: 14, color: _grey),
              const SizedBox(width: 4),
              Text(
                'Projected: ₱${projected.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: _grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── PIE CHART ────────────────────────────────────────────────────────────

  Widget _buildPieChart({
    required double needs,
    required double wants,
    required double savings,
  }) {
    final total = needs + wants + savings;
    if (total == 0) {
      return _card(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No expenses yet', style: TextStyle(color: _grey)),
          ),
        ),
      );
    }

    final sections = [
      if (needs > 0)
        PieChartSectionData(
          value: needs,
          color: _green,
          radius: 55,
          title: '${(needs / total * 100).toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (wants > 0)
        PieChartSectionData(
          value: wants,
          color: _orange,
          radius: 55,
          title: '${(wants / total * 100).toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (savings > 0)
        PieChartSectionData(
          value: savings,
          color: _blue,
          radius: 55,
          title: '${(savings / total * 100).toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 35,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendItem(_green, 'Needs', '₱${needs.toStringAsFixed(0)}'),
              _legendItem(_orange, 'Wants', '₱${wants.toStringAsFixed(0)}'),
              _legendItem(_blue, 'Savings', '₱${savings.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, String value) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 12, color: _grey)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─── LINE CHART ───────────────────────────────────────────────────────────

  Widget _buildLineChart({
    required List<DateTime> days,
    required Color color,
    required String title,
  }) {
    final totals = _buildDailyTotals(days);
    final spots = List.generate(days.length, (i) {
      return FlSpot(i.toDouble(), totals[days[i]] ?? 0);
    });
    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => b > a ? b : a);
    final yMax = maxY <= 0 ? 100.0 : maxY * 1.25;
    final interval = days.length > 15 ? 5.0 : 2.0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (days.length - 1).toDouble(),
                minY: 0,
                maxY: yMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yMax / 5,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: const Color(0xFFF0F0F0), strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xFFE0E0E0)),
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
                      reservedSize: 32,
                      interval: interval,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('M/d').format(days[i]),
                            style: const TextStyle(fontSize: 10, color: _grey),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: yMax / 5,
                      getTitlesWidget: (value, _) => Text(
                        '₱${value.toInt()}',
                        style: const TextStyle(fontSize: 9, color: _grey),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '${DateFormat('MMM d').format(days[s.x.toInt()])}\n₱${s.y.toStringAsFixed(2)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    color: color,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 3,
                        color: color,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATS ROW ────────────────────────────────────────────────────────────

  Widget _buildStatsRow({
    required double spent,
    required double average,
    required double projected,
  }) {
    return _card(
      child: Row(
        children: [
          _statPill('Total Spent', '₱${spent.toStringAsFixed(0)}', _blue),
          const SizedBox(width: 8),
          _statPill('Daily Avg', '₱${average.toStringAsFixed(0)}', _purple),
          const SizedBox(width: 8),
          _statPill('Projected', '₱${projected.toStringAsFixed(0)}', _orange),
        ],
      ),
    );
  }

  // ─── WEEKLY TAB ───────────────────────────────────────────────────────────

  Widget _buildWeeklyTab() {
    // Filter expenses to weekly period
    final days = weeklyDays;
    final start = days.first;
    final end = days.last.add(const Duration(days: 1));
    double wNeeds = 0, wWants = 0, wSavings = 0;
    for (final e in expenses) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      if (!d.isBefore(start) && d.isBefore(end)) {
        if (e.category == 'needs') {
          wNeeds += e.amount;
        } else if (e.category == 'wants') {
          wWants += e.amount;
        } else {
          wSavings += e.amount;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: loadExpenses,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildBudgetProgress(
            label: 'Weekly Budget',
            dateRange: weeklyLabel,
            spent: weeklySpent,
            budget: weeklyBudget,
            projected: projectedWeekly,
          ),

          if (weeklyBudget != null) ...[
            _buildStatsRow(
              spent: weeklySpent,
              average: dailyAverage,
              projected: projectedWeekly,
            ),

            _buildLineChart(
              days: weeklyDays,
              color: _blue,
              title: 'Daily Spending — $weeklyLabel',
            ),

            _buildPieChart(needs: wNeeds, wants: wWants, savings: wSavings),
          ],
        ],
      ),
    );
  }

  // ─── MONTHLY TAB ──────────────────────────────────────────────────────────

    Widget _buildMonthlyTab() {
    final days = monthlyDays;
    final start = days.first;
    final end = days.last.add(const Duration(days: 1));
    double mNeeds = 0, mWants = 0, mSavings = 0;
    for (final e in expenses) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      if (!d.isBefore(start) && d.isBefore(end)) {
        if (e.category == 'needs') {
          mNeeds += e.amount;
        } else if (e.category == 'wants') {
          mWants += e.amount;
        } else {
          mSavings += e.amount;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: loadExpenses,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildBudgetProgress(
            label: 'Monthly Budget',
            dateRange: monthlyLabel,
            spent: monthlySpent,
            budget: monthlyBudget,
            projected: projectedMonthly,
          ),

          if (monthlyBudget != null) ...[
            _buildStatsRow(
              spent: monthlySpent,
              average: dailyAverage,
              projected: projectedMonthly,
            ),

            _buildLineChart(
              days: monthlyDays,
              color: _purple,
              title: 'Daily Spending — $monthlyLabel',
            ),

            _buildPieChart(needs: mNeeds, wants: mWants, savings: mSavings),
          ],
        ],
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: _blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(context, '/profile');
                  if (!mounted) return;
                  await loadExpenses();
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_circle,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hello, ${currentUser?.username ?? 'Student'}!',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(context, '/scan');
                  if (!mounted) return;
                  await loadExpenses();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Total spending hero
          Text(
            '₱${totalSpending.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Total Spending',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '$expenseCount expenses  •  Avg ₱${avgExpense.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 14),
          // Tab bar
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildWeeklyTab(), _buildMonthlyTab()],
            ),
          ),
        ],
      ),
    );
  }
}
