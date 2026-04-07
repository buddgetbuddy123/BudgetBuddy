import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../services/ocr_service.dart';
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

  String? imagePath;
  String extractedText = '';
  String category = 'needs';
  bool loading = false;
  bool isManualEntry = false;
  final storeController = TextEditingController();
  final amountController = TextEditingController();

  Future<void> pickImage(ImageSource source) async {
    final file = await picker.pickImage(source: source);
    if (file == null) return;
    setState(() {
      imagePath = file.path;
      isManualEntry = false;
    });
    await processImage(file.path);
  }

  Future<void> processImage(String path) async {
    setState(() => loading = true);
    try {
      final text = await ocr.extractText(path);
      setState(() => extractedText = text);
      final match = RegExp(r'(\d+[,.]?\d*\.?\d+)').firstMatch(text);
      if (match != null) {
        amountController.text = match.group(0)!.replaceAll(',', '');
      }
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> saveExpense() async {
    final store = storeController.text.trim();
    final amount = double.tryParse(amountController.text.trim());

    if (store.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid details')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Expense saved')));
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
    });
  }

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
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
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
                ? 'You are using Manual Entry mode'
                : 'You are using Receipt Scan mode',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 20),
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
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (extractedText.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(extractedText),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: storeController,
            decoration: const InputDecoration(
              labelText: 'Store Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: category,
            items: const [
              DropdownMenuItem(value: 'needs', child: Text('Needs')),
              DropdownMenuItem(value: 'wants', child: Text('Wants')),
              DropdownMenuItem(value: 'savings', child: Text('Savings')),
            ],
            onChanged: (value) => setState(() => category = value ?? 'needs'),
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: saveExpense,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Save Expense'),
          ),
        ],
      ),
    );
  }
}
