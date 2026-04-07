import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDelete;

  const ExpenseCard({super.key, required this.expense, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (expense.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(expense.imagePath!), width: 60, height: 60, fit: BoxFit.cover),
              ),
            if (expense.imagePath != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.store, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(DateFormat('MMM d, y • hh:mm a').format(expense.date)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₱${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
