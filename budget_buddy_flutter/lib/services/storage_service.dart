import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/expense.dart';

class StorageService {
  static const _usersKey = 'users';
  static const _currentUserKey = 'currentUser';

  // FIX #1: Cache SharedPreferences instance — avoids calling getInstance()
  // multiple times per operation (was called twice per method before).
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _sharedPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

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

  // FIX #3: Removed weeklyAdviceApplied / monthlyAdviceApplied storage methods
  // entirely — those flags were loaded into state but never used for UI logic.
  // The AdviceScreen computed getters (isWeeklyRecommendationApplied, etc.)
  // already handle this correctly by comparing budget values directly.

  Future<List<Expense>> getExpenses() async {
    final prefs = await _sharedPrefs;
    final userId = await _requireCurrentUserId();
    final jsonString = prefs.getString(_expensesKeyForUser(userId));
    if (jsonString == null) return [];
    final decoded = List<Map<String, dynamic>>.from(json.decode(jsonString));
    return decoded.map(Expense.fromJson).toList();
  }

  Future<void> saveExpenses(List<Expense> expenses) async {
    final prefs = await _sharedPrefs;
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
    final prefs = await _sharedPrefs;
    final userId = await _requireCurrentUserId();
    await prefs.setString(_expensesKeyForUser(userId), json.encode([]));
  }

  Future<double?> getWeeklyBudget() async {
    final prefs = await _sharedPrefs;
    final userId = await _requireCurrentUserId();
    return prefs.getDouble(_weeklyBudgetKeyForUser(userId));
  }

  Future<double?> getMonthlyBudget() async {
    final prefs = await _sharedPrefs;
    final userId = await _requireCurrentUserId();
    return prefs.getDouble(_monthlyBudgetKeyForUser(userId));
  }

  Future<void> setWeeklyBudget(double value) async {
    final prefs = await _sharedPrefs;
    final userId = await _requireCurrentUserId();
    await prefs.setDouble(_weeklyBudgetKeyForUser(userId), value);
  }

  Future<void> setMonthlyBudget(double value) async {
    final prefs = await _sharedPrefs;
    final userId = await _requireCurrentUserId();
    await prefs.setDouble(_monthlyBudgetKeyForUser(userId), value);
  }

  Future<void> clearWeeklyBudget() async {
    final prefs = await _sharedPrefs;
    final userId = await _requireCurrentUserId();
    await prefs.remove(_weeklyBudgetKeyForUser(userId));
  }

  Future<void> clearMonthlyBudget() async {
    final prefs = await _sharedPrefs;
    final userId = await _requireCurrentUserId();
    await prefs.remove(_monthlyBudgetKeyForUser(userId));
  }

  Future<List<AppUser>> getUsers() async {
    final prefs = await _sharedPrefs;
    final jsonString = prefs.getString(_usersKey);
    if (jsonString == null) return [];
    final decoded = List<Map<String, dynamic>>.from(json.decode(jsonString));
    return decoded.map(AppUser.fromJson).toList();
  }

  Future<void> saveUsers(List<AppUser> users) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(
      _usersKey,
      json.encode(users.map((u) => u.toJson()).toList()),
    );
  }

  Future<AppUser?> getCurrentUser() async {
    final prefs = await _sharedPrefs;
    final jsonString = prefs.getString(_currentUserKey);
    if (jsonString == null) return null;
    return AppUser.fromJson(Map<String, dynamic>.from(json.decode(jsonString)));
  }

  Future<void> setCurrentUser(AppUser user) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_currentUserKey, json.encode(user.toJson()));
  }

  Future<void> clearCurrentUser() async {
    final prefs = await _sharedPrefs;
    await prefs.remove(_currentUserKey);
  }
}