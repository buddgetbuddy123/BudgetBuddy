import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/expense.dart';

class StorageService {
  static const _expensesKey = 'expenses';
  static const _weeklyBudgetKey = 'weeklyBudget';
  static const _monthlyBudgetKey = 'monthlyBudget';
  static const _usersKey = 'users';
  static const _currentUserKey = 'currentUser';

  Future<List<Expense>> getExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_expensesKey);
    if (jsonString == null) return [];
    final decoded = List<Map<String, dynamic>>.from(json.decode(jsonString));
    return decoded.map(Expense.fromJson).toList();
  }

  Future<void> saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _expensesKey,
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
    await prefs.setString(_expensesKey, json.encode([]));
  }

  Future<double?> getWeeklyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_weeklyBudgetKey);
  }

  Future<double?> getMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_monthlyBudgetKey);
  }

  Future<void> setWeeklyBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_weeklyBudgetKey, value);
  }

  Future<void> setMonthlyBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_monthlyBudgetKey, value);
  }

  Future<void> clearWeeklyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_weeklyBudgetKey);
  }

  Future<void> clearMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_monthlyBudgetKey);
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
