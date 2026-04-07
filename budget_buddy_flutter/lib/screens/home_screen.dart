import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    loadData();
  }

  Future<void> loadData() async {
    currentUser = await storage.getCurrentUser();
    weeklyBudget = await storage.getWeeklyBudget();
    monthlyBudget = await storage.getMonthlyBudget();
    final expenses = await storage.getExpenses();

    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
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
      if (!exp.date.isBefore(startOfWeek)) weekTotal += exp.amount;
      if (!exp.date.isBefore(startOfMonth)) monthTotal += exp.amount;
    }

    if (!mounted) return;

    setState(() {
      totalSpending = total;
      expenseCount = expenses.length;
      avgExpense = expenses.isEmpty ? 0 : total / expenses.length;
      weeklySpent = weekTotal;
      monthlySpent = monthTotal;
    });
  }

  Widget actionButton(
    IconData icon,
    String title,
    String subtitle,
    String route,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4A90E2)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).pushNamed(route);
          if (!mounted) return;
          await loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Buddy'),
        actions: [
          IconButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await storage.clearCurrentUser();
              if (!mounted) return;
              navigator.pushReplacementNamed('/');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            if (currentUser != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF4A90E2)),
                  title: Text('Hello, ${currentUser!.username}!'),
                  subtitle: const Text('Welcome back'),
                ),
              ),
            Card(
              color: const Color(0xFF4A90E2),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '₱${totalSpending.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Total Spending',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: const Text('Receipts'),
                      subtitle: Text('$expenseCount'),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: const Text('Average'),
                      subtitle: Text('₱${avgExpense.toStringAsFixed(2)}'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            actionButton(
              Icons.camera_alt,
              'Scan Receipt',
              'Add new expense',
              '/scan',
            ),
            actionButton(
              Icons.list,
              'View History',
              'See all expenses',
              '/history',
            ),
            actionButton(
              Icons.wallet,
              'Set Budget',
              'Manage spending limits',
              '/budget',
            ),
            actionButton(
              Icons.lightbulb,
              'Get Advice',
              'Budget tips for you',
              '/advice',
            ),
          ],
        ),
      ),
    );
  }
}
