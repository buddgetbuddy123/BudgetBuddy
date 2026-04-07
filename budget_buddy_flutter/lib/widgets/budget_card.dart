import 'package:flutter/material.dart';

class BudgetCard extends StatelessWidget {
  final String title;
  final double spent;
  final double? budget;
  final VoidCallback onOpen;
  final VoidCallback onClear;
  final IconData icon;

  const BudgetCard({
    super.key,
    required this.title,
    required this.spent,
    required this.budget,
    required this.onOpen,
    required this.onClear,
    required this.icon,
  });

  double getProgressPercentage(double s, double? b) {
    if (b == null || b == 0) return 0;
    return ((s / b) * 100).clamp(0.0, 100.0);
  }

  Color getProgressColor(double p) {
    if (p >= 100) return const Color(0xFFFF4444);
    if (p >= 80) return const Color(0xFFFF9800);
    if (p >= 60) return const Color(0xFFFFC107);
    return const Color(0xFF4CAF50);
  }

  String getStatusText(double p) {
    if (p >= 100) return 'Budget exceeded!';
    if (p >= 80) return 'Approaching budget limit';
    if (p >= 60) return 'More than halfway';
    return 'On track!';
  }

  @override
  Widget build(BuildContext context) {
    final percentage = getProgressPercentage(spent, budget);
    final progressColor = getProgressColor(percentage);
    final remaining = budget != null ? budget! - spent : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 28, color: const Color(0xFF4A90E2)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (budget != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statBox(
                  label: 'Spent',
                  value: '₱${spent.toStringAsFixed(2)}',
                  color: progressColor,
                ),
                _statBox(
                  label: 'Budget',
                  value: '₱${budget!.toStringAsFixed(2)}',
                  color: const Color(0xFF333333),
                ),
                _statBox(
                  label: 'Remaining',
                  value: '₱${remaining.abs().toStringAsFixed(2)}',
                  color: remaining >= 0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF4444),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 12,
                      backgroundColor: const Color(0xFFF0F0F0),
                      valueColor: AlwaysStoppedAnimation(progressColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Center(
              child: Text(
                getStatusText(percentage),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Color(0xFF4A90E2),
                    ),
                    label: const Text(
                      'Update',
                      style: TextStyle(
                        color: Color(0xFF4A90E2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4A90E2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Color(0xFFFF4444),
                    ),
                    label: const Text(
                      'Clear',
                      style: TextStyle(
                        color: Color(0xFFFF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Set your ${title.toLowerCase()}:',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(minHeight: 70),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFDDDDDD),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: const [
                    Text(
                      '₱',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF666666),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap to enter',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_outlined,
                      size: 24,
                      color: Color(0xFF4A90E2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Tap to set budget',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}