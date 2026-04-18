import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'budget_screen.dart';
import 'advice_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;
  int refreshTick = 0;

  void changeTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  void triggerRefresh() {
    setState(() {
      refreshTick++;
    });
  }

  Widget getCurrentPage() {
    switch (currentIndex) {
      case 0:
        return HomeScreen(onNavigateToTab: changeTab, refreshTick: refreshTick);
      case 1:
        return HistoryScreen(refreshTick: refreshTick);
      case 2:
        return BudgetScreen(refreshTick: refreshTick);
      case 3:
        return AdviceScreen(refreshTick: refreshTick);
      default:
        return HomeScreen(onNavigateToTab: changeTab, refreshTick: refreshTick);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(top: true, bottom: false, child: getCurrentPage()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Advice',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/scan');
          if (!mounted) return;
          triggerRefresh();
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
