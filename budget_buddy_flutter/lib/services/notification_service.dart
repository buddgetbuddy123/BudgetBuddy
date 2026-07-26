import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─── PUSH NOTIFICATION SERVICE ────────────────────────────────────────────────
// Handles status-bar notifications (shows even when app is closed/background).
// Uses flutter_local_notifications v17 named-parameter API.

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      'ic_notification', // Ensure this icon is in res/drawable
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // v17 API: initialize takes named parameter `settings:`
    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Alias for budget_screen.dart compatibility.
  Future<void> showBudgetExceeded({
    required String type,
    required double spent,
    required double budget,
    required String dateRange,
  }) => showBudgetExceededPush(
    type: type,
    spent: spent,
    budget: budget,
    dateRange: dateRange,
  );

  /// Push notification shown in status bar when budget is exceeded after saving.
  Future<void> showBudgetExceededPush({
    required String type,
    required double spent,
    required double budget,
    required String dateRange,
  }) async {
    await init();

    final label = type == 'weekly' ? 'Weekly' : 'Monthly';
    final over = spent - budget;

    const androidDetails = AndroidNotificationDetails(
      'budget_exceeded',
      'Budget Exceeded',
      channelDescription: 'Alerts when spending exceeds budget limit',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // v17 API: show() uses named parameters id, title, body, notificationDetails
    await _plugin.show(
      id: type == 'weekly' ? 1 : 2,
      title: '⚠️ $label Budget Exceeded!',
      body:
          'You spent ₱${spent.toStringAsFixed(2)} of your '
          '₱${budget.toStringAsFixed(2)} $label budget ($dateRange). '
          'Over by ₱${over.toStringAsFixed(2)}.',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  /// Cancel a budget notification by type.
  Future<void> cancelBudgetNotification(String type) async {
    // v17 API: cancel() uses named parameter id
    await _plugin.cancel(id: type == 'weekly' ? 1 : 2);
  }
}

// ─── IN-APP WARNING DIALOG ────────────────────────────────────────────────────
// Called before saving an expense.
// If the new expense would push the user over their weekly or monthly budget,
// shows a pop-up warning and asks them to confirm or cancel.

class BudgetWarningDialog {
  /// Shows a warning dialog if [newAmount] would exceed [budget].
  /// Returns true if the user confirms they want to save anyway,
  /// false if they cancel.
  ///
  /// [currentSpent] — total already spent this period
  /// [budget]       — the budget limit set by the user
  /// [type]         — 'weekly' or 'monthly'
  /// [dateRange]    — e.g. "July 4–11, 2026"
  /// [newAmount]    — the amount the user is about to save
  static Future<bool> check({
    required BuildContext context,
    required double currentSpent,
    required double budget,
    required String type,
    required String dateRange,
    required double newAmount,
  }) async {
    final projectedTotal = currentSpent + newAmount;

    // No warning needed if within budget
    if (projectedTotal <= budget) return true;

    final label = type == 'weekly' ? 'Weekly' : 'Monthly';
    final over = projectedTotal - budget;
    final remaining = budget - currentSpent;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label Budget Warning',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCC0000),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adding ₱${newAmount.toStringAsFixed(2)} will exceed your '
              '$label budget ($dateRange).',
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 16),
            _warningRow(
              label: 'Budget limit',
              value: '₱${budget.toStringAsFixed(2)}',
              color: const Color(0xFF4A90E2),
            ),
            const SizedBox(height: 6),
            _warningRow(
              label: 'Already spent',
              value: '₱${currentSpent.toStringAsFixed(2)}',
              color: const Color(0xFF333333),
            ),
            const SizedBox(height: 6),
            _warningRow(
              label: 'Remaining',
              value: '₱${remaining.toStringAsFixed(2)}',
              color: remaining >= 0
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF4444),
            ),
            const SizedBox(height: 6),
            _warningRow(
              label: 'This expense',
              value: '₱${newAmount.toStringAsFixed(2)}',
              color: const Color(0xFFFF9800),
            ),
            const Divider(height: 20),
            _warningRow(
              label: 'Over budget by',
              value: '₱${over.toStringAsFixed(2)}',
              color: const Color(0xFFFF4444),
              bold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel — Don\'t Save',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  static Widget _warningRow({
    required String label,
    required String value,
    required Color color,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
