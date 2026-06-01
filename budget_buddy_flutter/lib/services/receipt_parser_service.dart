// ReceiptParserService
//
// Extracts line items from any Philippine receipt exactly as written.
// No keyword mapping, no SKU expansion, no name translation.
// Whatever the receipt says is what gets saved — the user can edit
// item names in the ReviewScreen if needed.
//
// What this parser does:
//   1. Detects the merchant/store name from the receipt header
//   2. Extracts each line item with its name and amount exactly as printed
//   3. Handles two common Philippine receipt formats:
//      Format A — item name + price on same line (Jollibee, SM, Mercury Drug)
//      Format B — item name on one line, qty x price on next line (sari-sari, Easy Day)
//   4. Finds the correct grand total (ignoring CASH and CHANGE lines)
//   5. Extracts the date if present
//
// What this parser does NOT do:
//   - No keyword-to-display-name mapping
//   - No SKU abbreviation expansion
//   - No category classification (that's CategoryClassifierService's job)

class ReceiptLineItem {
  final String name;
  final double amount;
  final int quantity;

  const ReceiptLineItem({
    required this.name,
    required this.amount,
    this.quantity = 1,
  });

  @override
  String toString() =>
      'ReceiptLineItem(name: $name, amount: $amount, qty: $quantity)';
}

class ParsedReceipt {
  /// Detected merchant / store name from receipt header
  final String merchantName;

  /// All extracted line items, names exactly as printed on the receipt
  final List<ReceiptLineItem> lineItems;

  /// The grand total found on the receipt (TOTAL line, not CASH or CHANGE)
  final double? grandTotal;

  /// Date string found on receipt (raw, as printed)
  final String? dateString;

  /// Raw OCR text — shown in the collapsible debug view in ScanScreen
  final String rawText;

  const ParsedReceipt({
    required this.merchantName,
    required this.lineItems,
    required this.rawText,
    this.grandTotal,
    this.dateString,
  });
}

class ReceiptParserService {

  // ─── LINES TO ALWAYS SKIP ────────────────────────────────────────────────
  // These are never real purchased items — they are receipt metadata,
  // payment info, tax breakdowns, or promotional text.

  static const List<String> _skipPatterns = [
    // Payment lines — must skip to avoid grabbing CHANGE as an item
    'change', 'cash', 'cash tendered', 'amount tendered', 'amount paid',
    'cash in', 'tendered',
    // Tax / VAT breakdown
    'vatable', 'vat exempt', 'vat amount', 'vat_amt', 'zero-rated',
    'zero rated', 'withholding', 'witholding',
    // Totals and subtotals
    'total', 'subtotal', 'sub total', 'sub-total',
    'amount due', 'total due', 'total amount', 'total sales',
    'grand total',
    // Discounts and fees
    'less discount', 'senior citizen', 'pwd discount',
    'loyalty', 'points',
    // Receipt metadata
    'invoice', 'receipt', 'or number', 'si #', 'trans #', 'terminal',
    'cashier', 'staff', 'store#', 'store #', 'min #', 'sn#',
    'tin', 'bir', 'ptu', 'accr', 'series',
    'date issued', 'valid until', 'date',
    // Address / contact
    'address', 'tel', 'telefax', 'website', 'floor', 'city',
    'philippines', 'corporation', 'inc.', 'owned', 'operated',
    // Closing messages
    'thank you', 'thanks', 'please come again', 'have a nice day',
    'bawat visit', 'sulit', 'nothing follows', 'end of receipt',
    'this document', 'not valid', 'claim', 'serves as',
    'copy for', 'duplicate',
    // Promotions
    'buy p', 'win', 'travel rewards', 'dti fair', 'permit number',
    'saan man', 'kapitbiyahe', 'facebook',
    // Separators
    '---', '===', '***', '___',
  ];

  // ─── PUBLIC API ───────────────────────────────────────────────────────────

  /// Parse raw OCR text into a [ParsedReceipt] with line items exactly
  /// as written on the receipt.
  ParsedReceipt parse(String rawText) {
    final lines = _cleanLines(rawText);

    final merchantName = _extractMerchant(lines);
    final dateString = _extractDate(rawText);
    final grandTotal = _extractGrandTotal(rawText);
    final lineItems = _extractLineItems(lines);

    return ParsedReceipt(
      merchantName: merchantName,
      lineItems: lineItems,
      grandTotal: grandTotal,
      dateString: dateString,
      rawText: rawText,
    );
  }

  // ─── MERCHANT NAME ────────────────────────────────────────────────────────

  String _extractMerchant(List<String> lines) {
    // The merchant name is almost always in the first few lines of the receipt.
    // We take the first line that:
    //   - is not empty
    //   - is not too short (< 3 chars) or too long (> 60 chars)
    //   - does not start with a number (avoids TIN, SN, reference numbers)
    //   - does not look like an address or metadata
    for (final line in lines.take(8)) {
      final cleaned = line.trim();
      if (cleaned.isEmpty) continue;
      if (cleaned.length < 3 || cleaned.length > 60) continue;
      if (RegExp(r'^\d').hasMatch(cleaned)) continue;

      final lower = cleaned.toLowerCase();
      // Skip obvious non-merchant lines
      if (lower.contains('philippines') ||
          lower.contains('corporation') ||
          lower.contains('operated') ||
          lower.contains('owned') ||
          lower.contains('vatregtin') ||
          lower.contains('vatreg') ||
          lower.contains('tel') ||
          lower.contains('address') ||
          lower.contains('floor') ||
          lower.contains('cor.') ||
          lower.contains('street') ||
          lower.contains('st.,') ||
          lower.contains('ave') ||
          lower.contains('city')) { continue; }

      return _toTitleCase(cleaned);
    }
    return 'Unknown Store';
  }

  // ─── DATE EXTRACTION ──────────────────────────────────────────────────────

  String? _extractDate(String text) {
    // MM/DD/YYYY or MM-DD-YYYY
    final mmddyyyy = RegExp(r'\b(\d{2}[\/\-]\d{2}[\/\-]\d{4})\b');
    // Month name: "March 19, 2026" or "19 March 2026"
    final monthName = RegExp(
      r'\b(\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|'
      r'May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|'
      r'Nov(?:ember)?|Dec(?:ember)?)\s+\d{4})\b',
      caseSensitive: false,
    );
    final m1 = mmddyyyy.firstMatch(text);
    if (m1 != null) return m1.group(1);
    final m2 = monthName.firstMatch(text);
    if (m2 != null) return m2.group(1);
    return null;
  }

  // ─── GRAND TOTAL ─────────────────────────────────────────────────────────

  double? _extractGrandTotal(String text) {
    // IMPORTANT: Skip CASH and CHANGE lines entirely.
    // e.g. 7-Eleven: Total (3) 143.00 / CASH 650.00 / CHANGE 507.00
    // We must return 143.00, not 507.00 or 650.00.

    bool isCashOrChangeLine(String lower) {
      final t = lower.trimLeft();
      return t.startsWith('change') ||
          t.startsWith('cash') ||
          t.contains('cash tendered') ||
          t.contains('amount tendered') ||
          t.contains('amount paid') ||
          t.contains('cash in');
    }

    final lines = text.split('\n');

    // 1. Explicit total patterns — checked line by line, skipping cash/change
    final totalPatterns = [
      // "Total (3) 143.00" — 7-Eleven format
      RegExp(r'total\s*\(\d+\)\s+([\d,]+\.\d{2})', caseSensitive: false),
      // "AMOUNT DUE:P 158.00" — BIR invoice format
      RegExp(r'amount\s+due[:\s]*[Pp]?\s*([\d,]+\.\d{2})', caseSensitive: false),
      // "Total Amount : 3,200.00"
      RegExp(r'total\s+amount[:\s]+([\d,]+\.\d{2})', caseSensitive: false),
      // "Total : 350.00" or "Total  350.00"
      RegExp(r'^total[:\s]+([\d,]+\.\d{2})', caseSensitive: false),
      // "Total Sales : 141.06"
      RegExp(r'total\s+sales[:\s]+([\d,]+\.\d{2})', caseSensitive: false),
      // "Total Due : 158.00"
      RegExp(r'total\s+due[:\s]+([\d,]+\.\d{2})', caseSensitive: false),
    ];

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (isCashOrChangeLine(lower)) continue;
      for (final pattern in totalPatterns) {
        final match = pattern.firstMatch(line.trim());
        if (match != null) {
          final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
          if (val != null && val > 0) return val;
        }
      }
    }

    // 2. Any line with "total" — grab the last number, skip cash/change
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (isCashOrChangeLine(lower)) continue;
      if (lower.contains('total') &&
          !lower.contains('vat') &&
          !lower.contains('zero') &&
          !lower.contains('exempt') &&
          !lower.contains('item')) {
        final amounts = RegExp(r'([\d,]+\.\d{2})')
            .allMatches(line)
            .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0)
            .where((v) => v > 0)
            .toList();
        if (amounts.isNotEmpty) return amounts.last;
      }
    }

    // 3. Last resort: largest number in the receipt, skipping cash/change lines
    final allAmounts = <double>[];
    for (final line in lines) {
      if (isCashOrChangeLine(line.toLowerCase())) continue;
      RegExp(r'\b([\d,]+\.\d{2})\b').allMatches(line).forEach((m) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0;
        if (v >= 1.0) allAmounts.add(v);
      });
    }
    allAmounts.sort((a, b) => b.compareTo(a));
    return allAmounts.isNotEmpty ? allAmounts.first : null;
  }


  List<ReceiptLineItem> _extractLineItems(List<String> lines) {
    final items = <ReceiptLineItem>[];

    // Price at end of line (with optional V flag for VATable)
    final amountAtEnd = RegExp(r'[\s\t]+([\d,]+\.\d{2})\s*[Vv]?\s*$');

    // Format B qty line:
    // "3 EA X 16.00 48.00 V" — qty, optional unit label, X, unit price, [total]
    // "45.00 X 2 90.00 V"    — unit price, X, qty, [total]  (reversed)
    final qtyFormat1 = RegExp(
      r'^(\d+)\s*(?:EA|ea|Ea|PC|pc|PCS|pcs|x)?\s*[xX]\s*([\d,]+\.\d{2})',
    );
    // Reversed: unit price X qty (7-Eleven style: "45.00 X 2")
    final qtyFormat2 = RegExp(
      r'^([\d,]+\.\d{2})\s*[xX]\s*(\d+)',
    );

    String? pendingName; // item name from previous line (Format B)
    bool pastHeader = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase().trim();

      if (lower.isEmpty) continue;

      // Skip until we are past the receipt header
      if (!pastHeader) {
        if (_looksLikeItemsStart(lower)) {
          pastHeader = true;
        } else {
          continue;
        }
      }

      // Stop at total / summary section
      if (_isTotalLine(lower)) {
        pendingName = null;
        break;
      }

      // Skip noise lines
      if (_shouldSkipLine(lower)) {
        pendingName = null;
        continue;
      }

      // ── Try Format B variant 1: "3 EA X 16.00 [48.00 V]" ─────────────────
      final qty1Match = qtyFormat1.firstMatch(line.trim());
      if (qty1Match != null) {
        final qty = int.tryParse(qty1Match.group(1)!) ?? 1;
        final unitPrice =
            double.tryParse(qty1Match.group(2)!.replaceAll(',', '')) ?? 0;
        if (unitPrice > 0) {
          final name = (pendingName?.isNotEmpty == true)
              ? pendingName!
              : _extractNameBeforeQty(line, qty1Match.end);
          if (name.isNotEmpty) {
            items.add(ReceiptLineItem(
              name: name,
              amount: unitPrice * qty,
              quantity: qty,
            ));
          }
        }
        pendingName = null;
        continue;
      }

      // ── Try Format B variant 2: "45.00 X 2 [90.00 V]" ────────────────────
      final qty2Match = qtyFormat2.firstMatch(line.trim());
      if (qty2Match != null) {
        final unitPrice =
            double.tryParse(qty2Match.group(1)!.replaceAll(',', '')) ?? 0;
        final qty = int.tryParse(qty2Match.group(2)!) ?? 1;
        if (unitPrice > 0) {
          final name = (pendingName?.isNotEmpty == true)
              ? pendingName!
              : 'Item';
          items.add(ReceiptLineItem(
            name: name,
            amount: unitPrice * qty,
            quantity: qty,
          ));
        }
        pendingName = null;
        continue;
      }

      // ── Try Format A: item name + price on same line ───────────────────────
      final amountMatch = amountAtEnd.firstMatch(line);
      if (amountMatch != null) {
        final amount = double.tryParse(
          amountMatch.group(1)!.replaceAll(',', ''),
        );
        if (amount == null || amount <= 0) {
          pendingName = null;
          continue;
        }

        // Name = everything before the amount
        final rawName = line.substring(0, amountMatch.start).trim();

        // Skip if name is empty, too short, or just a number
        if (rawName.isEmpty ||
            rawName.length < 2 ||
            RegExp(r'^\d+$').hasMatch(rawName)) {
          pendingName = null;
          continue;
        }

        if (_shouldSkipLine(rawName.toLowerCase())) {
          pendingName = null;
          continue;
        }

        items.add(ReceiptLineItem(name: rawName, amount: amount));
        pendingName = null;
        continue;
      }

      // ── No price found on this line ────────────────────────────────────────
      // Could be a Format B item name line — store as pending.
      // Only store if it looks like a product name (not a barcode or separator).
      final trimmed = line.trim();
      if (trimmed.length >= 3 &&
          !RegExp(r'^[\d\s\-\=\*\.]+$').hasMatch(trimmed) &&
          !_shouldSkipLine(lower)) {
        pendingName = trimmed;
      } else {
        pendingName = null;
      }
    }

    return items;
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  /// Returns true when we've likely passed the receipt header and
  /// reached the item listing section.
  bool _looksLikeItemsStart(String lower) {
    // A line ending with a peso amount is almost certainly an item line
    if (RegExp(r'[\d,]+\.\d{2}\s*[Vv]?\s*$').hasMatch(lower)) return true;
    // qty x price pattern
    if (RegExp(r'\d+\s*[xX]\s*[\d,]+\.\d{2}').hasMatch(lower)) return true;
    return false;
  }

  /// Returns true if the line is a total/summary line — stop parsing items here.
  bool _isTotalLine(String lower) {
    return lower.trimLeft().startsWith('total') ||
        lower.trimLeft().startsWith('subtotal') ||
        lower.trimLeft().startsWith('sub total') ||
        lower.contains('amount due') ||
        lower.contains('total due') ||
        lower.contains('item(s)') ||
        lower.contains('items)');
  }

  /// Returns true if this line should be excluded from item extraction.
  bool _shouldSkipLine(String lower) {
    for (final pattern in _skipPatterns) {
      if (lower.contains(pattern)) return true;
    }
    // Lines that are purely numbers/barcodes
    if (RegExp(r'^\d{4,}$').hasMatch(lower.replaceAll(' ', ''))) return true;
    // Pure separator lines
    if (RegExp(r'^[=\-_\*\.\/\\]+$').hasMatch(lower)) return true;
    return false;
  }

  /// Extracts a trailing name after the qty pattern end index.
  /// Used when the item name is on the same line after the qty block.
  String _extractNameBeforeQty(String line, int afterQtyIndex) {
    if (afterQtyIndex >= line.length) return '';
    // Remove trailing amount and V flag
    return line
        .substring(afterQtyIndex)
        .replaceAll(RegExp(r'[\d,]+\.\d{2}\s*[Vv]?\s*$'), '')
        .trim();
  }

  List<String> _cleanLines(String text) {
    return text
        .split('\n')
        .map((l) => l
            .replaceAll('\r', '')
            .replaceAll('\t', '  ')
            .replaceAll(RegExp(r' {3,}'), '  ')
            .trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}