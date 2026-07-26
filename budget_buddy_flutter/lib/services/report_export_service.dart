import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';

class ReportExportService {
  // ─── JPEG ────────────────────────────────────────────────────────────────

  Future<void> exportAsJpeg({
    required ScreenshotController controller,
    required BuildContext context,
  }) async {
    final image = await controller.capture(pixelRatio: 2.0);
    if (image == null) {
  if (!context.mounted) return;
  _show(context, 'Could not capture report image.');
  return;
}
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/BudgetBuddy_Report_${_stamp()}.jpg',
    );
    await file.writeAsBytes(image);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Budget Buddy Report',
    );
  }

  // ─── PDF ─────────────────────────────────────────────────────────────────

  Future<void> exportAsPdf({
    required List<Expense> expenses,
    required double totalNeeds,
    required double totalWants,
    required double totalSavings,
    required BuildContext context,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    // Header colours
    const headerColor = PdfColor.fromInt(0xFF1F4E79);
    const needsColor  = PdfColor.fromInt(0xFF4CAF50);
    const wantsColor  = PdfColor.fromInt(0xFFFF9800);
    const savingsColor= PdfColor.fromInt(0xFF4A90E2);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // Title
          pw.Container(
            color: headerColor,
            padding: const pw.EdgeInsets.all(16),
            child: pw.Text(
              'Budget Buddy — Expense Report',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 18,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated: ${DateFormat('MMMM d, y • hh:mm a').format(DateTime.now())}',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),

          // Summary row
          pw.Row(children: [
            _pdfSummaryBox('Needs', totalNeeds, needsColor, boldFont),
            pw.SizedBox(width: 8),
            _pdfSummaryBox('Wants', totalWants, wantsColor, boldFont),
            pw.SizedBox(width: 8),
            _pdfSummaryBox('Savings', totalSavings, savingsColor, boldFont),
            pw.SizedBox(width: 8),
            _pdfSummaryBox(
              'Total',
              totalNeeds + totalWants + totalSavings,
              headerColor,
              boldFont,
            ),
          ]),
          pw.SizedBox(height: 20),

          // Table header
          pw.Text(
            'All Expenses',
            style: pw.TextStyle(font: boldFont, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Table header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerColor),
                children: ['Store / Item', 'Date', 'Category', 'Amount']
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              // Data rows
              ...expenses.map((e) {
                final isEven = expenses.indexOf(e) % 2 == 0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.grey100 : PdfColors.white,
                  ),
                  children: [
                    _pdfCell(e.store, font),
                    _pdfCell(
                      DateFormat('MMM d, y').format(e.date),
                      font,
                    ),
                    _pdfCell(_capitalize(e.category), font),
                    _pdfCell(
                      '₱${e.amount.toStringAsFixed(2)}',
                      boldFont,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/BudgetBuddy_Report_${_stamp()}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Budget Buddy Report',
    );
  }

  // ─── EXCEL ───────────────────────────────────────────────────────────────

  Future<void> exportAsExcel({
    required List<Expense> expenses,
    required double totalNeeds,
    required double totalWants,
    required double totalSavings,
    required BuildContext context,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Expenses'];

    // Remove default sheet
    excel.delete('Sheet1');

    // Header row style
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1F4E79'),
    );

    // Headers
    final headers = ['No.', 'Store / Item', 'Date', 'Category', 'Amount (₱)'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data rows
    for (int i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      final row = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(e.store);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(DateFormat('MMM d, y').format(e.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(_capitalize(e.category));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = DoubleCellValue(e.amount);
    }

    // Summary sheet
    final summary = excel['Summary'];
    summary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .value = TextCellValue('Category');
    summary.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
        .value = TextCellValue('Total (₱)');
    final summaryData = [
      ['Needs', totalNeeds],
      ['Wants', totalWants],
      ['Savings', totalSavings],
      ['TOTAL', totalNeeds + totalWants + totalSavings],
    ];
    for (int i = 0; i < summaryData.length; i++) {
      summary
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
          .value = TextCellValue(summaryData[i][0] as String);
      summary
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
          .value = DoubleCellValue(summaryData[i][1] as double);
    }

    // Auto-size columns (Excel package sets width in character units)
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 14);

    final bytes = excel.encode();
    if (bytes == null) {
      _show(context, 'Could not generate Excel file.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/BudgetBuddy_Report_${_stamp()}.xlsx',
    );
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Budget Buddy Report',
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  pw.Widget _pdfSummaryBox(
    String label,
    double amount,
    PdfColor color,
    pw.Font font,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '₱${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
    );
  }

  String _stamp() =>
      DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _show(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
