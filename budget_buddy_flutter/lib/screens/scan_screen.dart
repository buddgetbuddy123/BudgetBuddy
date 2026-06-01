import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../services/ocr_service.dart';
import '../services/storage_service.dart';
import '../services/category_classifier_service.dart';
import '../services/receipt_parser_service.dart';
import 'review_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final picker = ImagePicker();
  final storage = StorageService();
  final ocr = OcrService();
  final classifier = CategoryClassifierService();
  final parser = ReceiptParserService();

  String? imagePath;
  String extractedText = '';
  String category = 'needs';
  bool loading = false;
  bool isManualEntry = false;

  ClassificationResult? _lastClassification;

  final storeController = TextEditingController();
  final amountController = TextEditingController();

  // ─── IMAGE / OCR ─────────────────────────────────────────────────────────

  Future<void> pickImage(ImageSource source) async {
    final file = await picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (file == null) return;
    setState(() {
      imagePath = file.path;
      isManualEntry = false;
      extractedText = '';
    });
    await processImage(file.path);
  }

  Future<void> processImage(String path) async {
    setState(() => loading = true);
    try {
      final text = await ocr.extractText(path);

      if (!mounted) return;
      setState(() => extractedText = text);

      // Parse the receipt into structured line items
      final parsed = parser.parse(text);

      // If we got more than one line item, go straight to ReviewScreen
      if (parsed.lineItems.length > 1) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewScreen(
              parsedReceipt: parsed,
              imagePath: imagePath,
            ),
          ),
        );
        // After review screen pops, close scan screen too
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      // Single item or fallback — pre-fill the manual form fields
      _prefillFromParsed(parsed);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR error: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Pre-fill store name and amount from parsed receipt (single item case)
  void _prefillFromParsed(ParsedReceipt parsed) {
    if (parsed.merchantName.isNotEmpty) {
      storeController.text = parsed.merchantName;
    }

    if (parsed.lineItems.isNotEmpty) {
      amountController.text =
          parsed.lineItems.first.amount.toStringAsFixed(2);
    } else if (parsed.grandTotal != null) {
      amountController.text = parsed.grandTotal!.toStringAsFixed(2);
    }

    _autoClassify();
  }

  // ─── CLASSIFICATION ───────────────────────────────────────────────────────

  void _autoClassify() {
    final store = storeController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (store.isEmpty && amount == 0) return;

    final result = classifier.classify(
      storeName: store,
      amount: amount,
    );

    if (!mounted) return;
    setState(() {
      category = result.category;
      _lastClassification = result;
    });
  }

  void _toggleCategory() {
    setState(() {
      category = classifier.toggleCategory(category);
      _lastClassification = ClassificationResult(
        category: category,
        reason: 'Manually set by you.',
        confidence: 'high',
      );
    });
  }

  // ─── SAVE (manual / single item) ─────────────────────────────────────────

  Future<void> saveExpense() async {
    final store = storeController.text.trim();
    final amount = double.tryParse(amountController.text.trim());

    if (store.isEmpty || amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid store name and amount'),
        ),
      );
      return;
    }

    final expense = Expense(
      id: const Uuid().v4(),
      store: store,
      amount: amount,
      category: category,
      date: DateTime.now(),
      imagePath: imagePath,
      isManual: isManualEntry,
    );

    await storage.addExpense(expense);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ₱${amount.toStringAsFixed(2)} under ${_capitalize(category)}',
        ),
      ),
    );
    Navigator.pop(context);
  }

  void switchMode(bool manual) {
    setState(() {
      isManualEntry = manual;
      imagePath = null;
      extractedText = '';
      storeController.clear();
      amountController.clear();
      category = 'needs';
      _lastClassification = null;
    });
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ─── WIDGETS ─────────────────────────────────────────────────────────────

  Widget buildModeButton({
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
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.06),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
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

  Widget buildCategoryToggle() {
    final meta = classifier.categoryMeta(category);
    final color = Color(meta['color'] as int);
    final label = meta['label'] as String;
    final description = meta['description'] as String;

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
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _toggleCategory,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _iconForCategory(category),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Tap to change',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: confidenceColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        confidenceLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: confidenceColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_lastClassification != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _lastClassification!.reason,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        // Quick-tap pills
        Row(
          children: ['needs', 'wants', 'savings'].map((cat) {
            final isActive = cat == category;
            final catMeta = classifier.categoryMeta(cat);
            final catColor = Color(catMeta['color'] as int);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    category = cat;
                    _lastClassification = ClassificationResult(
                      category: cat,
                      reason: 'Manually set by you.',
                      confidence: 'high',
                    );
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? catColor.withValues(alpha: 0.15)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? catColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    catMeta['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive ? catColor : const Color(0xFF999999),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'needs': return Icons.fastfood;
      case 'wants': return Icons.sports_esports;
      case 'savings':
      default: return Icons.account_balance_wallet;
    }
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
      appBar: AppBar(title: const Text('Add Expense')),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          // Mode toggle
          Row(
            children: [
              buildModeButton(
                selected: !isManualEntry,
                icon: Icons.camera_alt,
                label: 'Scan Receipt',
                onTap: () => switchMode(false),
              ),
              const SizedBox(width: 10),
              buildModeButton(
                selected: isManualEntry,
                icon: Icons.edit,
                label: 'Manual Entry',
                onTap: () => switchMode(true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isManualEntry
                ? 'Manual Entry mode — fill in details below'
                : 'Scan mode — take a photo or choose from gallery',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 16),

          // Camera / gallery buttons
          if (!isManualEntry) ...[
            ElevatedButton.icon(
              onPressed: () => pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
            const SizedBox(height: 4),
            const Text(
              'For receipts with multiple items, you\'ll be taken to a review screen.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],

          if (loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Reading receipt...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],

          if (extractedText.isNotEmpty && !loading) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              title: const Text(
                'View raw OCR text',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    extractedText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // Store name
          TextField(
            controller: storeController,
            onChanged: (_) => _autoClassify(),
            decoration: const InputDecoration(
              labelText: 'Store / Item Name',
              hintText: 'e.g. Canteen, Jollibee, Tuition Fee',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.store_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // Amount
          TextField(
            controller: amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _autoClassify(),
            decoration: const InputDecoration(
              labelText: 'Amount (₱)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 16),

          // Category toggle
          buildCategoryToggle(),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton.icon(
            onPressed: saveExpense,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Save Expense'),
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