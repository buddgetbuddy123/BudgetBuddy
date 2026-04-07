import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final storage = StorageService();

  AppUser? currentUser;
  int totalReceipts = 0;
  double totalSpent = 0;
  double? weeklyBudget;
  double? monthlyBudget;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = await storage.getCurrentUser();
    final expenses = await storage.getExpenses();
    final weekly = await storage.getWeeklyBudget();
    final monthly = await storage.getMonthlyBudget();

    if (!mounted) return;

    setState(() {
      currentUser = user;
      totalReceipts = expenses.length;
      totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
      weeklyBudget = weekly;
      monthlyBudget = monthly;
      loading = false;
    });
  }

  Widget statTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Icon(icon, color: const Color(0xFF4A90E2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> handleLogout() async {
    await storage.clearCurrentUser();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
                  const Icon(
                    Icons.account_circle,
                    size: 90,
                    color: Color(0xFF4A90E2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentUser?.username ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Account ID: ${currentUser?.id ?? '-'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            statTile(Icons.receipt_long, 'Total receipts', '$totalReceipts'),
            const SizedBox(height: 12),
            statTile(
              Icons.account_balance_wallet,
              'Total spent',
              '₱${totalSpent.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            statTile(
              Icons.calendar_today,
              'Weekly budget',
              weeklyBudget == null ? 'Not set' : '₱${weeklyBudget!.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            statTile(
              Icons.calendar_month,
              'Monthly budget',
              monthlyBudget == null ? 'Not set' : '₱${monthlyBudget!.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: handleLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}