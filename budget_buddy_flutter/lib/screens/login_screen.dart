import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final storage = StorageService();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool showPassword = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final user = await storage.getCurrentUser();
    if (!mounted) return;
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  Future<void> handleSubmit() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _show('Please enter both username and password');
      return;
    }

    if (isLogin) {
      final users = await storage.getUsers();
      final match = users.where(
        (u) => u.username.trim() == username && u.password == password,
      );

      if (match.isNotEmpty) {
        await storage.setCurrentUser(match.first);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        _show('Invalid username or password');
      }
    } else {
      if (password.length < 4) {
        _show('Password must be at least 4 characters');
        return;
      }

      final users = await storage.getUsers();
      final exists = users.any((u) => u.username.trim() == username);

      if (exists) {
        _show('Username already exists');
        return;
      }

      final newUser = AppUser(
        id: const Uuid().v4(),
        username: username,
        password: password,
        createdAt: DateTime.now(),
      );

      users.add(newUser);
      await storage.saveUsers(users);
      await storage.setCurrentUser(newUser);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget authTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4A90E2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4A90E2),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = isLogin ? 'Welcome Back' : 'Create Account';
    final subtitle = isLogin
        ? 'You are in Login mode'
        : 'You are in Sign Up mode';
    final primaryButtonText = isLogin ? 'Login' : 'Create Account';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 46,
                    backgroundColor: Color(0xFFE5F2FF),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 54,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'Budget Buddy',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB9D6FB)),
                    ),
                    child: Row(
                      children: [
                        authTab(
                          label: 'Login',
                          selected: isLogin,
                          onTap: () => setState(() => isLogin = true),
                        ),
                        const SizedBox(width: 8),
                        authTab(
                          label: 'Sign Up',
                          selected: !isLogin,
                          onTap: () => setState(() => isLogin = false),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isLogin
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLogin
                            ? const Color(0xFF4A90E2)
                            : const Color(0xFF7E57C2),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isLogin ? Icons.login : Icons.person_add_alt_1,
                          size: 36,
                          color: isLogin
                              ? const Color(0xFF4A90E2)
                              : const Color(0xFF7E57C2),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isLogin
                                ? const Color(0xFF4A90E2)
                                : const Color(0xFF7E57C2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                        icon: Icon(
                          showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  ElevatedButton.icon(
                    onPressed: handleSubmit,
                    icon: Icon(isLogin ? Icons.login : Icons.person_add),
                    label: Text(primaryButtonText),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      isLogin
                          ? 'Already have an account? You are on Login.'
                          : 'New here? You are on Sign Up.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isLogin
                            ? const Color(0xFF4A90E2)
                            : const Color(0xFF7E57C2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
