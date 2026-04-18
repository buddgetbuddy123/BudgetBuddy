import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/expense.dart';

class StorageService {
  static const _usersKey = 'users';
  static const _currentUserKey = 'currentUser';

  Future<String> _requireCurrentUserId() async {
    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('No current user found');
    }
    return user.id;
  }

  String _expensesKeyForUser(String userId) => 'expenses_$userId';
  String _weeklyBudgetKeyForUser(String userId) => 'weeklyBudget_$userId';
  String _monthlyBudgetKeyForUser(String userId) => 'monthlyBudget_$userId';
  String _weeklyAdviceAppliedKeyForUser(String userId) =>
      'weeklyAdviceApplied_$userId';
  String _monthlyAdviceAppliedKeyForUser(String userId) =>
      'monthlyAdviceApplied_$userId';
  Future<List<Expense>> getExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    final jsonString = prefs.getString(_expensesKeyForUser(userId));
    if (jsonString == null) return [];
    final decoded = List<Map<String, dynamic>>.from(json.decode(jsonString));
    return decoded.map(Expense.fromJson).toList();
  }

  Future<void> saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.setString(
      _expensesKeyForUser(userId),
      json.encode(expenses.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addExpense(Expense expense) async {
    final expenses = await getExpenses();
    expenses.add(expense);
    await saveExpenses(expenses);
  }

  Future<void> deleteExpense(String id) async {
    final expenses = await getExpenses();
    expenses.removeWhere((e) => e.id == id);
    await saveExpenses(expenses);
  }

  Future<void> clearExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.setString(_expensesKeyForUser(userId), json.encode([]));
  }

  Future<double?> getWeeklyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    return prefs.getDouble(_weeklyBudgetKeyForUser(userId));
  }

  Future<double?> getMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    return prefs.getDouble(_monthlyBudgetKeyForUser(userId));
  }

  Future<void> setWeeklyBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.setDouble(_weeklyBudgetKeyForUser(userId), value);
  }

  Future<void> setMonthlyBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.setDouble(_monthlyBudgetKeyForUser(userId), value);
  }

  Future<void> clearWeeklyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.remove(_weeklyBudgetKeyForUser(userId));
  }

  Future<void> clearMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.remove(_monthlyBudgetKeyForUser(userId));
  }

  Future<bool> getWeeklyAdviceApplied() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    return prefs.getBool(_weeklyAdviceAppliedKeyForUser(userId)) ?? false;
  }

  Future<bool> getMonthlyAdviceApplied() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    return prefs.getBool(_monthlyAdviceAppliedKeyForUser(userId)) ?? false;
  }

  Future<void> setWeeklyAdviceApplied(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.setBool(_weeklyAdviceAppliedKeyForUser(userId), value);
  }

  Future<void> setMonthlyAdviceApplied(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.setBool(_monthlyAdviceAppliedKeyForUser(userId), value);
  }

  Future<void> clearWeeklyAdviceApplied() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.remove(_weeklyAdviceAppliedKeyForUser(userId));
  }

  Future<void> clearMonthlyAdviceApplied() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _requireCurrentUserId();
    await prefs.remove(_monthlyAdviceAppliedKeyForUser(userId));
  }

  Future<List<AppUser>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_usersKey);
    if (jsonString == null) return [];
    final decoded = List<Map<String, dynamic>>.from(json.decode(jsonString));
    return decoded.map(AppUser.fromJson).toList();
  }

  Future<void> saveUsers(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usersKey,
      json.encode(users.map((u) => u.toJson()).toList()),
    );
  }

  Future<AppUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_currentUserKey);
    if (jsonString == null) return null;
    return AppUser.fromJson(Map<String, dynamic>.from(json.decode(jsonString)));
  }

  Future<void> setCurrentUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, json.encode(user.toJson()));
  }

  Future<void> clearCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }
}