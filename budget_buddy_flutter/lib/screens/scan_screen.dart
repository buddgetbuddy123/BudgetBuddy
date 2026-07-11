import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';
import '../services/category_classifier_service.dart';
import '../services/expense_stats_service.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/receipt_parser_service.dart';
import '../services/storage_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final picker = ImagePicker();
  final storage = StorageService();
  final ocr = OcrService();
  final parser = ReceiptParserService();
  final statsService = ExpenseStatsService();
  final notifications = NotificationService();

  final classifier = CategoryClassifierService();

  String? imagePath;
  String rawOcrText = '';

  bool loading = false;
  bool isManualEntry = false;

  String selectedCategory = 'needs';

  ClassificationResult? _lastClassification;

  final storeController = TextEditingController();
  final amountController = TextEditingController();

  static const Map<String, Map<String, dynamic>> _categoryMeta = {
    'needs': {
      'label': 'Needs',
      'description': 'Basic necessity — food, transport, school',
      'color': Color(0xFF4CAF50),
      'icon': Icons.fastfood,
    },
    'wants': {
      'label': 'Wants',
      'description': 'Comfort or lifestyle spending',
      'color': Color(0xFFFF9800),
      'icon': Icons.sports_esports,
    },
    'savings': {
      'label': 'Savings',
      'description': 'Money set aside intentionally',
      'color': Color(0xFF4A90E2),
      'icon': Icons.account_balance_wallet,
    },
  };

  Future<void> pickImage(ImageSource source) async {
    final file = await picker.pickImage(source: source, imageQuality: 90);

    if (file == null) return;

    setState(() {
      imagePath = file.path;
      isManualEntry = false;
      rawOcrText = '';
      storeController.clear();
      amountController.clear();
      selectedCategory = 'needs';
      _lastClassification = null;
    });

    await processImage(file.path);
  }

  // 2nd part

  // ─────────────────────────────────────────────────────────────
  // OCR
  // ─────────────────────────────────────────────────────────────

  Future<void> processImage(String path) async {
    setState(() => loading = true);

    try {
      final text = await ocr.extractText(path);
      final parsed = parser.parse(text);

      if (!mounted) return;

      setState(() {
        rawOcrText = text;

        // Fill merchant name
        if (parsed.merchantName.isNotEmpty &&
            parsed.merchantName != 'Unknown Store') {
          storeController.text = parsed.merchantName;
        }

        // Fill amount
        double? amount;

        if (parsed.grandTotal != null && parsed.grandTotal! > 0) {
          amount = parsed.grandTotal;
        } else if (parsed.lineItems.isNotEmpty) {
          amount = parsed.lineItems.first.amount;
        }

        if (amount != null) {
          amountController.text = amount.toStringAsFixed(2);
        }
      });

      // Automatically classify after OCR
      _autoClassify();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OCR error: $e')));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  //
  // AI AUTO CLASSIFICATION
  //

  void _autoClassify() {
    final store = storeController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0;

    if (store.isEmpty && amount == 0) return;

    final result = classifier.classify(storeName: store, amount: amount);

    if (!mounted) return;

    setState(() {
      selectedCategory = result.category;
      _lastClassification = result;
    });
  }

  void switchMode(bool manual) {
    setState(() {
      isManualEntry = manual;

      imagePath = null;
      rawOcrText = '';

      storeController.clear();
      amountController.clear();

      selectedCategory = 'needs';
      _lastClassification = null;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── SAVE ─────────────────────────────────────────────────────────────────

  Future<void> saveExpense() async {
    final store = storeController.text.trim();
    final amount = double.tryParse(amountController.text.trim());

    if (store.isEmpty) {
      _snack('Please enter a store or item name.');
      return;
    }
    if (amount == null || amount <= 0) {
      _snack('Please enter a valid amount.');
      return;
    }

    // ── Check budget before saving ─────────────────────────────────────────
    // Load current spending and budgets to check if this expense would
    // exceed weekly or monthly limits. Show warning dialog if it would.
    final expenses = await storage.getExpenses();
    final stats = statsService.calculate(expenses);
    final weekly = await storage.getWeeklyBudget();
    final monthly = await storage.getMonthlyBudget();

    // Date ranges for display in the warning
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final fmt = DateFormat('MMM d');
    final yr = DateFormat('yyyy').format(monday);
    final weekRange = monday.month == sunday.month
        ? '${fmt.format(monday)}–${sunday.day}, $yr'
        : '${fmt.format(monday)} – ${fmt.format(sunday)}, $yr';
    final monthRange = DateFormat('MMMM yyyy').format(now);

    if (!mounted) return;

    // Weekly budget warning
    if (weekly != null && stats.weeklyTotal + amount > weekly) {
      final proceed = await BudgetWarningDialog.check(
        context: context,
        currentSpent: stats.weeklyTotal,
        budget: weekly,
        type: 'weekly',
        dateRange: weekRange,
        newAmount: amount,
      );
      if (!proceed) return;
    }

    // Monthly budget warning
    if (monthly != null && stats.monthlyTotal + amount > monthly) {
      if (!mounted) return;
      final proceed = await BudgetWarningDialog.check(
        context: context,
        currentSpent: stats.monthlyTotal,
        budget: monthly,
        type: 'monthly',
        dateRange: monthRange,
        newAmount: amount,
      );
      if (!proceed) return;
    }

    // ── Save ───────────────────────────────────────────────────────────────
    final expense = Expense(
      id: const Uuid().v4(),
      store: store,
      amount: amount,
      category: selectedCategory,
      date: DateTime.now(),
      imagePath: imagePath,
      isManual: isManualEntry,
    );

    await storage.addExpense(expense);

    // Push notification if now exceeding budget after save
    final updatedExpenses = await storage.getExpenses();
    final updatedStats = statsService.calculate(updatedExpenses);

    if (weekly != null && updatedStats.weeklyTotal > weekly) {
      await notifications.showBudgetExceededPush(
        type: 'weekly',
        spent: updatedStats.weeklyTotal,
        budget: weekly,
        dateRange: weekRange,
      );
    }
    if (monthly != null && updatedStats.monthlyTotal > monthly) {
      await notifications.showBudgetExceededPush(
        type: 'monthly',
        spent: updatedStats.monthlyTotal,
        budget: monthly,
        dateRange: monthRange,
      );
    }

    if (!mounted) return;
    _snack(
      'Saved ₱${amount.toStringAsFixed(2)} under '
      '${_categoryMeta[selectedCategory]!['label']}',
    );
    Navigator.pop(context);
  }

  // ─── WIDGETS ─────────────────────────────────────────────────────────────

  Widget _modeButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4A90E2) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4A90E2), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF4A90E2),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF4A90E2),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Category selector — three pill buttons, user taps to pick
  Widget _buildCategoryPicker() {
    final meta = _categoryMeta[selectedCategory]!;
    final color = meta['color'] as Color;

    final confidence = _lastClassification?.confidence ?? 'low';

    final confidenceColor = confidence == 'high'
        ? Colors.green
        : confidence == 'medium'
        ? Colors.orange
        : Colors.grey;

    final confidenceLabel = confidence == 'high'
        ? 'Auto-classified'
        : confidence == 'medium'
        ? 'Likely correct'
        : 'Tap to verify';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'AI automatically suggests a category. Tap another if needed.',
          style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
        ),

        const SizedBox(height: 12),

        Row(
          children: _categoryMeta.entries.map((entry) {
            final key = entry.key;
            final item = entry.value;

            final isSelected = selectedCategory == key;
            final itemColor = item['color'] as Color;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = key;

                    _lastClassification = ClassificationResult(
                      category: key,
                      confidence: 'high',
                      reason: 'Manually set by you.',
                    );
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? itemColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected ? itemColor : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? itemColor : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(meta['icon'] as IconData, color: color, size: 22),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta['label'] as String,
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          meta['description'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      confidenceLabel,
                      style: TextStyle(
                        color: confidenceColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),

              if (_lastClassification != null) ...[
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        _lastClassification!.reason,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    storeController.dispose();
    amountController.dispose();
    ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode toggle
          Row(
            children: [
              _modeButton(
                selected: !isManualEntry,
                icon: Icons.camera_alt,
                label: 'Scan Receipt',
                onTap: () => switchMode(false),
              ),
              const SizedBox(width: 10),
              _modeButton(
                selected: isManualEntry,
                icon: Icons.edit,
                label: 'Manual Entry',
                onTap: () => switchMode(true),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scan buttons
          if (!isManualEntry) ...[
            ElevatedButton.icon(
              onPressed: () => pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Works with printed and handwritten receipts.',
              style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],

          // Loading indicator
          if (loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Reading receipt...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Raw OCR text (collapsible debug view)
          if (rawOcrText.isNotEmpty && !loading)
            ExpansionTile(
              title: const Text(
                'View raw OCR text',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  width: double.infinity,
                  child: Text(rawOcrText, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // Store / Item name
          TextField(
            controller: storeController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _autoClassify(),
            decoration: const InputDecoration(
              labelText: 'Store / Item Name',
              hintText: 'e.g. Jollibee, Canteen, Tuition Fee',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.store_outlined),
              labelStyle: TextStyle(color: Color(0xFF4A90E2)),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF4A90E2), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Amount — peso sign prefix
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _autoClassify(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
              prefixText: '₱ ',
              prefixStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
              labelStyle: TextStyle(color: Color(0xFF4A90E2)),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF4A90E2), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Category picker — manual selection, no auto-classification
          _buildCategoryPicker(),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton.icon(
            onPressed: saveExpense,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text(
              'Save Expense',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
