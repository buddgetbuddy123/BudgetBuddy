import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../services/expense_stats_service.dart';
import '../services/report_export_service.dart';
import '../widgets/expense_card.dart';
class HistoryScreen extends StatefulWidget {
 final int refreshTick;
 const HistoryScreen({super.key, required this.refreshTick});
 @override
 State<HistoryScreen> createState() => _HistoryScreenState();
}
class _HistoryScreenState extends State<HistoryScreen> {
 final storage = StorageService();
 final statsService = ExpenseStatsService();
 final exportService = ReportExportService();
 final screenshotController = ScreenshotController();
 List<Expense> expenses = [];
 ExpenseStats? _cachedStats;
 bool _exporting = false;
 // Filter state
 String _filterCategory = 'all'; // 'all', 'needs', 'wants', 'savings'
 String _sortBy = 'date_desc'; // 'date_desc', 'date_asc', 'amount_desc', 'amount_asc'
 @override
 void initState() {
 super.initState();
 loadExpenses();
 }
 @override
 void didUpdateWidget(covariant HistoryScreen oldWidget) {
 super.didUpdateWidget(oldWidget);
 if (oldWidget.refreshTick != widget.refreshTick) loadExpenses();
 }
 Future<void> loadExpenses() async {
 final loaded = await storage.getExpenses();
 loaded.sort((a, b) => b.date.compareTo(a.date));
 if (!mounted) return;
 setState(() {
 expenses = loaded;
 _cachedStats = statsService.calculate(loaded);
 });
 }
 Future<void> deleteExpense(String id) async {
 await storage.deleteExpense(id);
 await loadExpenses();
 }
 Future<void> clearAll() async {
 final confirmed = await showDialog<bool>(
 context: context,
 builder: (_) => AlertDialog(
 title: const Text('Clear all expenses?'),
 content: const Text(
 'This will permanently remove all saved expenses.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(context, false),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () => Navigator.pop(context, true),
 child: const Text('Delete All',
 style: TextStyle(color: Colors.red)),
 ),
 ],
 ),
 );
 if (confirmed != true) return;
 await storage.clearExpenses();
 await loadExpenses();
 }
 // ─── EXPORT ──────────────────────────────────────────────────────────────
 Future<void> _showExportOptions() async {
 final stats = _cachedStats;
 if (stats == null || expenses.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('No expenses to export.')),
 );
 return;
 }
 await showModalBottomSheet(
 context: context,
 shape: const RoundedRectangleBorder(
 borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
 ),
 builder: (_) => SafeArea(
 child: Padding(
 padding: const EdgeInsets.all(20),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Text(
 'Export Report As',
 style: TextStyle(
 fontSize: 18, fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 4),
 const Text(
 'Choose a format to save or share your expense report.',
 style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
 ),
 const SizedBox(height: 20),
 _exportOption(
 icon: Icons.picture_as_pdf,
 color: const Color(0xFFE53935),
 label: 'PDF',
 description: 'Best for printing and sharing',
 onTap: () async {
 Navigator.pop(context);
 await _doExport('pdf');
 },
 ),
 const SizedBox(height: 12),
 _exportOption(
 icon: Icons.image,
 color: const Color(0xFF4A90E2),
 label: 'JPEG Image',
 description: 'Best for saving a screenshot',
 onTap: () async {
 Navigator.pop(context);
 await _doExport('jpeg');
 },
 ),
 const SizedBox(height: 12),
 _exportOption(
 icon: Icons.table_chart,
 color: const Color(0xFF4CAF50),
 label: 'Excel (.xlsx)',
 description: 'Best for data analysis',
 onTap: () async {
 Navigator.pop(context);
 await _doExport('excel');
 },
 ),
 const SizedBox(height: 8),
 ],
 ),
 ),
 ),
 );
 }
 Widget _exportOption({
 required IconData icon,
 required Color color,
 required String label,
 required String description,
 required VoidCallback onTap,
 }) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.07),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: color.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(icon, color: color, size: 24),
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label,
 style: TextStyle(
 fontSize: 15,
 fontWeight: FontWeight.bold,
 color: color)),
 Text(description,
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF666666))),
 ],
 ),
 ),
 Icon(Icons.chevron_right, color: color),
 ],
 ),
 ),
 );
 }
 Future<void> _doExport(String format) async {
 if (_exporting) return;
 setState(() => _exporting = true);
 
 // Calculate category totals
 double needs = 0;
double wants = 0;
double savings = 0;

for (final e in expenses) {
  if (e.category == 'needs') {
    needs += e.amount;
  } else if (e.category == 'wants') {
    wants += e.amount;
  } else {
    savings += e.amount;
  }
}
 try {
 switch (format) {
 case 'pdf':
 await exportService.exportAsPdf(
 expenses: expenses,
 totalNeeds: needs,
 totalWants: wants,
 totalSavings: savings,
 context: context,
 );
 case 'jpeg':
 await exportService.exportAsJpeg(
 controller: screenshotController,
 context: context,
 );
 case 'excel':
 await exportService.exportAsExcel(
 expenses: expenses,
 totalNeeds: needs,
 totalWants: wants,
 totalSavings: savings,
 context: context,
 );
 }
 } catch (e) {
 if (!mounted) return;
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Export failed: $e')),
 );
 } finally {
 if (mounted) setState(() => _exporting = false);
 }
 }
 // ─── FILTER & SORT ────────────────────────────────────────────────────────
 List<Expense> get _filteredExpenses {
 var list = expenses.where((e) {
 if (_filterCategory == 'all') return true;
 return e.category == _filterCategory;
 }).toList();
 switch (_sortBy) {
 case 'date_asc':
 list.sort((a, b) => a.date.compareTo(b.date));
 case 'amount_desc':
 list.sort((a, b) => b.amount.compareTo(a.amount));
 case 'amount_asc':
 list.sort((a, b) => a.amount.compareTo(b.amount));
 default: // date_desc
 list.sort((a, b) => b.date.compareTo(a.date));
 }
 return list;
 }
 // ─── SUMMARY CARDS ────────────────────────────────────────────────────────
 Widget _buildSummaryRow() {
 final stats = _cachedStats;
 return SizedBox(
 height: 80,
 child: ListView(
 scrollDirection: Axis.horizontal,
 padding: const EdgeInsets.symmetric(horizontal: 4),
 children: [
 _summaryChip(
 'Total',
 '₱${stats?.total.toStringAsFixed(2) ?? '0.00'}',
 const Color(0xFF4A90E2),
 ),
 _summaryChip(
 'This Week',
 '₱${stats?.weeklyTotal.toStringAsFixed(2) ?? '0.00'}',
 const Color(0xFF7E57C2),
 ),
 _summaryChip(
 'This Month',
 '₱${stats?.monthlyTotal.toStringAsFixed(2) ?? '0.00'}',
 const Color(0xFF26A69A),
 ),
 _summaryChip(
 'Expenses',
 '${stats?.count ?? 0}',
 const Color(0xFFFF9800),
 ),
 ],
 ),
 );
 }
 Widget _summaryChip(String label, String value, Color color) {
 return Container(
 margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
 decoration: BoxDecoration(
 color: color,
 borderRadius: BorderRadius.circular(12),
 boxShadow: [
 BoxShadow(
 color: color.withValues(alpha: 0.3),
 blurRadius: 6,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Text(value,
 style: const TextStyle(
 color: Colors.white,
 fontSize: 15,
 fontWeight: FontWeight.bold)),
 Text(label,
 style: const TextStyle(
 color: Colors.white70, fontSize: 11)),
 ],
 ),
 );
 }
 // ─── FILTER BAR ───────────────────────────────────────────────────────────
 Widget _buildFilterBar() {
 const cats = ['all', 'needs', 'wants', 'savings'];
 const catColors = {
 'all': Color(0xFF4A90E2),
 'needs': Color(0xFF4CAF50),
 'wants': Color(0xFFFF9800),
 'savings': Color(0xFF4A90E2),
 };
 const catLabels = {
 'all': 'All',
 'needs': 'Needs',
 'wants': 'Wants',
 'savings': 'Savings',
 };
 return SingleChildScrollView(
 scrollDirection: Axis.horizontal,
 padding: const EdgeInsets.symmetric(horizontal: 8),
 child: Row(
 children: cats.map((cat) {
 final selected = _filterCategory == cat;
 final color = catColors[cat]!;
 return GestureDetector(
 onTap: () => setState(() => _filterCategory = cat),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 150),
 margin: const EdgeInsets.symmetric(horizontal: 4),
 padding:
 const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
 decoration: BoxDecoration(
 color: selected ? color : const Color(0xFFF5F5F5),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(
 color: selected ? color : const Color(0xFFDDDDDD),
 ),
 ),
 child: Text(
 catLabels[cat]!,
 style: TextStyle(
 fontSize: 13,
 fontWeight: selected
 ? FontWeight.bold
 : FontWeight.normal,
 color: selected ? Colors.white : const Color(0xFF666666),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 );
 }
 // ─── BUILD ────────────────────────────────────────────────────────────────
 @override
 Widget build(BuildContext context) {
 final filtered = _filteredExpenses;
 return Scaffold(
 backgroundColor: const Color(0xFFF5F7FA),
 appBar: AppBar(
 title: const Text(
 'Expense History',
 style: TextStyle(
 fontWeight: FontWeight.bold, color: Colors.white),
 ),
 backgroundColor: const Color(0xFF4A90E2),
 foregroundColor: Colors.white,
 elevation: 0,
 actions: [
 // Sort button
 PopupMenuButton<String>(
 icon: const Icon(Icons.sort, color: Colors.white),
 tooltip: 'Sort',
 onSelected: (v) => setState(() => _sortBy = v),
 itemBuilder: (_) => [
 const PopupMenuItem(
 value: 'date_desc',
 child: Text('Newest first')),
 const PopupMenuItem(
 value: 'date_asc',
 child: Text('Oldest first')),
 const PopupMenuItem(
 value: 'amount_desc',
 child: Text('Highest amount')),
 const PopupMenuItem(
 value: 'amount_asc',
 child: Text('Lowest amount')),
 ],
 ),
 // Export button
 IconButton(
 icon: _exporting
 ? const SizedBox(
 width: 20,
 height: 20,
 child: CircularProgressIndicator(
 strokeWidth: 2, color: Colors.white))
 : const Icon(Icons.file_download_outlined,
 color: Colors.white),
 tooltip: 'Export Report',
 onPressed: _exporting ? null : _showExportOptions,
 ),
 // Clear all button
 IconButton(
 icon: const Icon(Icons.delete_sweep, color: Colors.white),
 tooltip: 'Clear All',
 onPressed: clearAll,
 ),
 ],
 ),
 body: expenses.isEmpty
 ? const Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.receipt_long,
 size: 64, color: Color(0xFFCCCCCC)),
 SizedBox(height: 16),
 Text('No Expense History Yet',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.w600,
 color: Color(0xFF999999))),
 SizedBox(height: 8),
 Text('Add an expense to get started.',
 style: TextStyle(
 fontSize: 13, color: Color(0xFFAAAAAA))),
 ],
 ),
 )
 : Screenshot(
 controller: screenshotController,
 child: RefreshIndicator(
 onRefresh: loadExpenses,
 child: CustomScrollView(
 slivers: [
 // Summary chips
 SliverToBoxAdapter(
 child: Padding(
 padding: const EdgeInsets.only(top: 12, bottom: 4),
 child: _buildSummaryRow(),
 ),
 ),
 // Filter bar
 SliverToBoxAdapter(
 child: Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _buildFilterBar(),
 ),
 ),
 // Result count
 SliverToBoxAdapter(
 child: Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 16, vertical: 4),
 child: Text(
 '${filtered.length} expense${filtered.length == 1 ? '' : 's'}',
 style: const TextStyle(
 fontSize: 12, color: Color(0xFF888888)),
 ),
 ),
 ),
 // Expense list
 if (filtered.isEmpty)
 const SliverToBoxAdapter(
 child: Padding(
 padding: EdgeInsets.all(40),
 child: Center(
 child: Text(
 'No expenses in this category.',
 style: TextStyle(
 color: Color(0xFF999999),
 fontSize: 14),
 ),
 ),
 ),
 )
 else
 SliverList(
 delegate: SliverChildBuilderDelegate(
 (context, index) {
 final e = filtered[index];
 // Date header
 final showHeader = index == 0 ||
 !_sameDay(
 filtered[index - 1].date, e.date);
 return Column(
 crossAxisAlignment:
 CrossAxisAlignment.start,
 children: [
 if (showHeader)
 Padding(
 padding: const EdgeInsets.fromLTRB(
 16, 12, 16, 4),
 child: Text(
 _dateHeader(e.date),
 style: const TextStyle(
 fontSize: 12,
 fontWeight: FontWeight.w600,
 color: Color(0xFF888888),
 letterSpacing: 0.5,
 ),
 ),
 ),
 Padding(
 padding: const EdgeInsets.symmetric(
 horizontal: 12),
 child: ExpenseCard(
 expense: e,
 onDelete: () =>
 deleteExpense(e.id),
 ),
 ),
 ],
 );
 },
 childCount: filtered.length,
 ),
 ),
 const SliverToBoxAdapter(
 child: SizedBox(height: 24)),
 ],
 ),
 ),
 ),
 );
 }
 // ─── HELPERS ─────────────────────────────────────────────────────────────
 bool _sameDay(DateTime a, DateTime b) =>
 a.year == b.year && a.month == b.month && a.day == b.day;
 String _dateHeader(DateTime date) {
 final now = DateTime.now();
 final today = DateTime(now.year, now.month, now.day);
 final d = DateTime(date.year, date.month, date.day);
 if (d == today) return 'TODAY';
 if (d == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
 return DateFormat('MMMM d, yyyy').format(date).toUpperCase();
 }
}