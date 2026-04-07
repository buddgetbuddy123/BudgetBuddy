import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/scan_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const BudgetBuddyApp());
}

class BudgetBuddyApp extends StatelessWidget {
  const BudgetBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Budget Buddy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        '/main': (_) => const MainShell(),
        '/scan': (_) => const ScanScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}