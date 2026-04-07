import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/storage_service.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  final storage = StorageService();

  double totalSpending = 0;
  int expenseCount = 0;
  double avgExpense = 0;
  double? weeklyBudget;
  double? monthlyBudget;
  double weeklySpent = 0;
  double monthlySpent = 0;
  AppUser? currentUser;

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      loadExpenses();
    }
  }

  Future<void> loadExpenses() async {
    try {
      final user = await storage.getCurrentUser();
      final weekly = await storage.getWeeklyBudget();
      final monthly = await storage.getMonthlyBudget();
      final expenses = await storage.getExpenses();

      final total = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);

      final now = DateTime.now();
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday % 7));
      final startOfMonth = DateTime(now.year, now.month, 1);

      double weekTotal = 0;
      double monthTotal = 0;

      for (final exp in expenses) {
        if (!exp.date.isBefore(startOfWeek)) {
          weekTotal += exp.amount;
        }
        if (!exp.date.isBefore(startOfMonth)) {
          monthTotal += exp.amount;
        }
      }

      if (!mounted) return;

      setState(() {
        currentUser = user;
        weeklyBudget = weekly;
        monthlyBudget = monthly;
        totalSpending = total;
        expenseCount = expenses.length;
        avgExpense = expenses.isNotEmpty ? total / expenses.length : 0;
        weeklySpent = weekTotal;
        monthlySpent = monthTotal;
      });
    } catch (error) {
      debugPrint('Error loading expenses: $error');
    }
  }

  Color getBudgetProgressColor(double ratio) {
    if (ratio >= 1) return const Color(0xFFFF4444);
    if (ratio >= 0.8) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }

  Widget buildUserHeader() {
    if (currentUser == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(context, '/profile');
          if (!mounted) return;
          await loadExpenses();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_circle,
                size: 40,
                color: Color(0xFF4A90E2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${currentUser!.username}!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to view profile',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFCCCCCC),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 20, 15, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Budget Buddy! 👋',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Track your spending by scanning receipts',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.1),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  '₱${totalSpending.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Total Spending',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: buildSmallStatCard(
                  icon: Icons.receipt_long,
                  value: '$expenseCount',
                  label: 'Receipts',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildSmallStatCard(
                  icon: Icons.trending_up,
                  value: '₱${avgExpense.toStringAsFixed(2)}',
                  label: 'Average',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSmallStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF4A90E2)),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBudgetProgressSection() {
    if (weeklyBudget == null && monthlyBudget == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Budget Progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 15),
          if (weeklyBudget != null)
            buildBudgetProgressCard(
              label: 'Weekly Budget',
              spent: weeklySpent,
              budget: weeklyBudget!,
            ),
          if (monthlyBudget != null)
            buildBudgetProgressCard(
              label: 'Monthly Budget',
              spent: monthlySpent,
              budget: monthlyBudget!,
            ),
        ],
      ),
    );
  }

  Widget buildBudgetProgressCard({
    required String label,
    required double spent,
    required double budget,
  }) {
    final ratio = budget == 0 ? 0.0 : spent / budget;
    final color = getBudgetProgressColor(ratio);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const Spacer(),
              Text(
                '₱${spent.toStringAsFixed(2)} / ₱${budget.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActionsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 15),
          buildActionButton(
            icon: Icons.camera_alt,
            title: 'Scan Receipt',
            subtitle: 'Add new expense',
            onTap: () async {
              await Navigator.pushNamed(context, '/scan');
              if (!mounted) return;
              await loadExpenses();
            },
          ),
          buildActionButton(
            icon: Icons.list,
            title: 'View History',
            subtitle: 'See all expenses',
            onTap: () => widget.onNavigateToTab(1),
          ),
          buildActionButton(
            icon: Icons.account_balance_wallet,
            title: 'Set Budget',
            subtitle: 'Manage spending limits',
            onTap: () => widget.onNavigateToTab(2),
          ),
          buildActionButton(
            icon: Icons.lightbulb,
            title: 'Get Advice',
            subtitle: 'Budget tips for you',
            onTap: () => widget.onNavigateToTab(3),
          ),
        ],
      ),
    );
  }

  Widget buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: const Color(0xFF4A90E2)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 24,
                color: Color(0xFFCCCCCC),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadExpenses,
      child: ListView(
        children: [
          buildUserHeader(),
          buildWelcomeCard(),
          buildStatsSection(),
          buildBudgetProgressSection(),
          buildActionsSection(),
        ],
      ),
    );
  }
} 