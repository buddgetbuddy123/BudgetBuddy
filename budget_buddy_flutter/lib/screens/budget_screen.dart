import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../widgets/budget_card.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final storage = StorageService();

  double? savedWeekly;
  double? savedMonthly;
  double weeklySpent = 0;
  double monthlySpent = 0;

  @override
  void initState() {
    super.initState();
    loadBudgetAndExpenses();
  }

  Future<void> loadBudgetAndExpenses() async {
    try {
      final weekly = await storage.getWeeklyBudget();
      final monthly = await storage.getMonthlyBudget();
      final expenses = await storage.getExpenses();

      final now = DateTime.now();
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday % 7));
      final startOfMonth = DateTime(now.year, now.month, 1);

      double wTotal = 0;
      double mTotal = 0;

      for (final exp in expenses) {
        if (!exp.date.isBefore(startOfWeek)) {
          wTotal += exp.amount;
        }
        if (!exp.date.isBefore(startOfMonth)) {
          mTotal += exp.amount;
        }
      }

      if (!mounted) return;

      setState(() {
        savedWeekly = weekly;
        savedMonthly = monthly;
        weeklySpent = wTotal;
        monthlySpent = mTotal;
      });
    } catch (err) {
      debugPrint('Error loading budget: $err');
    }
  }

  Future<void> inputBudget(String type) async {
    final controller = TextEditingController(
      text: type == 'weekly'
          ? (savedWeekly?.round().toString() ?? '')
          : (savedMonthly?.round().toString() ?? ''),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(type == 'weekly' ? 'Weekly Budget' : 'Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter amount',
            prefixText: '₱ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, controller.text),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Set Budget'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    final num = double.tryParse(result);
    if (num == null || num <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number')),
      );
      return;
    }

    try {
      if (type == 'weekly') {
        await storage.setWeeklyBudget(num);
      } else {
        await storage.setMonthlyBudget(num);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${type == 'weekly' ? 'Weekly' : 'Monthly'} budget set to ₱${num.toStringAsFixed(0)}',
          ),
        ),
      );

      await loadBudgetAndExpenses();
    } catch (err) {
      debugPrint('Save budget error: $err');
    }
  }

  Future<void> clearBudget(String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Budget'),
        content: Text('Remove your $type budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFFF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (type == 'weekly') {
      await storage.clearWeeklyBudget();
    } else {
      await storage.clearMonthlyBudget();
    }

    if (!mounted) return;
    await loadBudgetAndExpenses();
  }

  Widget buildInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 10),
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
        children: [
          Icon(
            Icons.info_outline,
            size: 32,
            color: Color(0xFF4A90E2),
          ),
          SizedBox(height: 10),
          Text(
            'Budget Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Set weekly or monthly budget limits to track your spending goals and stay on target!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTipsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 5),
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
            'Budget Tips',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 15),
          _TipRow(text: 'Start with a weekly budget to build good habits'),
          SizedBox(height: 12),
          _TipRow(text: 'Keep 10–20% buffer for unexpected expenses'),
          SizedBox(height: 12),
          _TipRow(text: 'Review and adjust your budget monthly'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadBudgetAndExpenses,
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          buildInfoCard(),
          BudgetCard(
            title: 'Weekly Budget',
            spent: weeklySpent,
            budget: savedWeekly,
            onOpen: () => inputBudget('weekly'),
            onClear: () => clearBudget('weekly'),
            icon: Icons.calendar_today,
          ),
          BudgetCard(
            title: 'Monthly Budget',
            spent: monthlySpent,
            budget: savedMonthly,
            onOpen: () => inputBudget('monthly'),
            onClear: () => clearBudget('monthly'),
            icon: Icons.calendar_month_outlined,
          ),
          buildTipsCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String text;

  const _TipRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF4A90E2),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}