import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../services/category_classifier_service.dart';
import '../services/receipt_parser_service.dart';

// Represents one parsed line item with its assigned category and edit state
class ReviewItem {
  final String id;
  final String name;
  final double amount;
  final int quantity;
  String category;
  bool confirmed;

  ReviewItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.quantity,
    required this.category,
    this.confirmed = false,
  });
}

class ReviewScreen extends StatefulWidget {
  final ParsedReceipt parsedReceipt;
  final String? imagePath;

  const ReviewScreen({
    super.key,
    required this.parsedReceipt,
    this.imagePath,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final storage = StorageService();
  final classifier = CategoryClassifierService();
  final _uuid = const Uuid();

  late List<ReviewItem> items;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _buildReviewItems();
  }

  void _buildReviewItems() {
    items = widget.parsedReceipt.lineItems.map((lineItem) {
      final result = classifier.classify(
        storeName: '${widget.parsedReceipt.merchantName} ${lineItem.name}',
        amount: lineItem.amount,
      );
      return ReviewItem(
        id: _uuid.v4(),
        name: lineItem.name,
        amount: lineItem.amount,
        quantity: lineItem.quantity,
        category: result.category,
      );
    }).toList();
  }

  // ─── CATEGORY HELPERS ─────────────────────────────────────────────────────

  Color _categoryColor(String category) {
    switch (category) {
      case 'needs': return const Color(0xFF4CAF50);
      case 'wants': return const Color(0xFFFF9800);
      case 'savings': return const Color(0xFF4A90E2);
      default: return Colors.grey;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'needs': return Icons.fastfood;
      case 'wants': return Icons.sports_esports;
      case 'savings': return Icons.account_balance_wallet;
      default: return Icons.help_outline;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'needs': return 'Needs';
      case 'wants': return 'Wants';
      case 'savings': return 'Savings';
      default: return category;
    }
  }

  // ─── SAVE ─────────────────────────────────────────────────────────────────

  Future<void> _saveAll() async {
    if (saving) return;
    setState(() => saving = true);

    try {
      // Group by category — save as separate expenses per category group
      final grouped = <String, List<ReviewItem>>{};
      for (final item in items) {
        grouped.putIfAbsent(item.category, () => []).add(item);
      }

      for (final entry in grouped.entries) {
        final category = entry.key;
        final groupItems = entry.value;
        final groupTotal = groupItems.fold<double>(
          0, (sum, i) => sum + i.amount,
        );
        // Store name = merchant + category group summary
        final storeName = groupItems.length == 1
            ? '${widget.parsedReceipt.merchantName} — ${groupItems.first.name}'
            : '${widget.parsedReceipt.merchantName} (${groupItems.length} items)';

        final expense = Expense(
          id: _uuid.v4(),
          store: storeName,
          amount: groupTotal,
          category: category,
          date: DateTime.now(),
          imagePath: widget.imagePath,
          isManual: false,
        );

        await storage.addExpense(expense);
      }

      if (!mounted) return;

      final savedCount = grouped.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved $savedCount expense${savedCount > 1 ? 's' : ''} '
            'from ${widget.parsedReceipt.merchantName}',
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );

      // Pop back to home
      Navigator.of(context)
          .popUntil((route) => route.isFirst || route.settings.name == '/main');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ─── WIDGETS ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final merchant = widget.parsedReceipt.merchantName;
    final total = widget.parsedReceipt.grandTotal;
    final date = widget.parsedReceipt.dateString;
    const typeLabel = 'Receipt';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.07),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFF4A90E2)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  merchant,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4A90E2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 6),
            Text(
              'Date: $date',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
          ],
          if (total != null) ...[
            const SizedBox(height: 4),
            Text(
              'Receipt total: ₱${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: const Row(
        children: [
          Icon(Icons.touch_app, color: Colors.amber, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Review each item below. Tap the category badge to change it, then tap Save All.',
              style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<ReviewItem> sectionItems) {
    final color = _categoryColor(category);
    final icon = _categoryIcon(category);
    final label = _categoryLabel(category);
    final sectionTotal = sectionItems.fold<double>(
      0, (sum, i) => sum + i.amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '₱${sectionTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...sectionItems.map((item) => _buildItemCard(item)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildItemCard(ReviewItem item) {
    final color = _categoryColor(item.category);
    final label = _categoryLabel(item.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  if (item.quantity > 1)
                    Text(
                      'Qty: ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  Text(
                    '₱${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ),

            // Tap-to-change category badge
            GestureDetector(
              onTap: () {
                setState(() {
                  item.category = classifier.toggleCategory(item.category);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(_categoryIcon(item.category), color: color, size: 16),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      'tap to change',
                      style: TextStyle(
                        fontSize: 9,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final totalNeeds = items
        .where((i) => i.category == 'needs')
        .fold<double>(0, (s, i) => s + i.amount);
    final totalWants = items
        .where((i) => i.category == 'wants')
        .fold<double>(0, (s, i) => s + i.amount);
    final totalSavings = items
        .where((i) => i.category == 'savings')
        .fold<double>(0, (s, i) => s + i.amount);
    final grandTotal = totalNeeds + totalWants + totalSavings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.07),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          if (totalNeeds > 0)
            _summaryRow('Needs', totalNeeds, const Color(0xFF4CAF50)),
          if (totalWants > 0)
            _summaryRow('Wants', totalWants, const Color(0xFFFF9800)),
          if (totalSavings > 0)
            _summaryRow('Savings', totalSavings, const Color(0xFF4A90E2)),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                '₱${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    // Group items by category for display
    final needsItems = items.where((i) => i.category == 'needs').toList();
    final wantsItems = items.where((i) => i.category == 'wants').toList();
    final savingsItems = items.where((i) => i.category == 'savings').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        actions: [
          TextButton(
            onPressed: saving ? null : _saveAll,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save All',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'No items could be extracted from this receipt.\nTry manual entry instead.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(15),
              children: [
                _buildHeader(),
                _buildInstructions(),
                if (needsItems.isNotEmpty)
                  _buildCategorySection('needs', needsItems),
                if (wantsItems.isNotEmpty)
                  _buildCategorySection('wants', wantsItems),
                if (savingsItems.isNotEmpty)
                  _buildCategorySection('savings', savingsItems),
                const SizedBox(height: 8),
                _buildSummaryBar(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: saving ? null : _saveAll,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    saving ? 'Saving...' : 'Save All Expenses',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}