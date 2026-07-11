// ReceiptParserService
//
// Extracts line items from any Philippine receipt exactly as written by MLKit OCR.
//
// Design philosophy (simplified):
//   - Find the merchant name from the first meaningful header line
//   - Find every line that has a peso amount at the end → that is an item
//   - Handle the two-line format (name on one line, price on next)
//   - Ignore CASH and CHANGE lines so the total is correct
//   - Return items exactly as OCR read them — no transformation
//   - The user fixes anything wrong in ReviewScreen
//
// Why simplified:
//   Philippine receipts have no standard format. Complex regex-based parsing
//   breaks on anything unexpected. A simple "find lines with amounts" approach
//   is more reliable across all receipt types and easier to maintain.

class ReceiptLineItem {
  final String name;
  final double amount;
  final int quantity;

  const ReceiptLineItem({
    required this.name,
    required this.amount,
    this.quantity = 1,
  });
}

class ParsedReceipt {
  final String merchantName;
  final List<ReceiptLineItem> lineItems;
  final double? grandTotal;
  final String? dateString;
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

  // Lines that are never items — skip these entirely
  static const List<String> _skipWords = [
    'change', 'cash', 'tendered', 'total', 'subtotal', 'sub total',
    'amount due', 'vat', 'tax', 'discount', 'loyalty',
    'cashier', 'staff', 'terminal', 'invoice', 'receipt',
    'tin:', 'bir', 'ptu', 'accr', 'series',
    'thank you', 'bawat', 'sulit', 'nothing follows',
    'this document', 'not valid', 'copy for',
    'address', 'tel:', 'philippines', 'corporation',
    '---', '===', '***',
  ];

  // ─── PUBLIC API ───────────────────────────────────────────────────────────

  ParsedReceipt parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.replaceAll('\r', '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return ParsedReceipt(
      merchantName: _findMerchant(lines),
      lineItems: _findItems(lines),
      grandTotal: _findTotal(rawText),
      dateString: _findDate(rawText),
      rawText: rawText,
    );
  }

  // ─── MERCHANT ─────────────────────────────────────────────────────────────

  String _findMerchant(List<String> lines) {
    for (final line in lines.take(8)) {
      if (line.length < 3 || line.length > 60) continue;
      if (RegExp(r'^\d').hasMatch(line)) continue;
      final lower = line.toLowerCase();
      if (_skipWords.any((w) => lower.contains(w))) continue;
      if (lower.contains('owned') ||
          lower.contains('operated') ||
          lower.contains('vatregtin') ||
          lower.contains('vat reg') ||
          lower.contains('tel #') ||
          lower.contains('cor.') ||
          lower.contains('st.,') ||
          lower.contains('ave.,') ||
          lower.contains('city,') ||
          lower.contains('philippines')) { continue; }
      return _titleCase(line);
    }
    return 'Unknown Store';
  }

  // ─── ITEM EXTRACTION ─────────────────────────────────────────────────────
  //
  // Simple rule:
  //   Any line ending with a peso amount = an item line.
  //   The item name is everything before the amount.
  //   Exception: if the name is empty, use the previous line as the name
  //   (handles two-line format: name on line N, price on line N+1).

  List<ReceiptLineItem> _findItems(List<String> lines) {
    final items = <ReceiptLineItem>[];

    // Amount at end of line, with optional V (VATable) flag and quantity
    final amountEnd = RegExp(r'([\d,]+\.\d{2})\s*[Vv]?\s*$');

    // Qty x price pattern on a line (e.g. "45.00 X 2" or "3 EA X 16.00")
    final qtyLine = RegExp(
      r'(?:([\d,]+\.\d{2})\s*[xX]\s*(\d+)|(\d+)\s*(?:EA|ea|PC|pc)?\s*[xX]\s*([\d,]+\.\d{2}))',
    );

    bool pastHeader = false;
    String? pendingName;

    for (final line in lines) {
      final lower = line.toLowerCase();

      // Stop at total/payment section — this must run BEFORE _shouldSkip,
      // and must use break (not continue), otherwise CASH/CHANGE lines that
      // also match _skipWords would just get skipped and the loop would
      // keep reading further lines as if they were still items.
      if (_isTotalOrPaymentLine(lower)) {
        pendingName = null;
        break;
      }

      // Skip metadata and noise (header info, tax lines, etc.)
      // Safety check: if this line is somehow a cash/change line that
      // _isTotalOrPaymentLine missed (e.g. unexpected OCR spacing),
      // break here too instead of silently skipping and continuing.
      // IMPORTANT: use word-boundary regex, not .contains('cash') —
      // .contains('cash') incorrectly matches "Cashier", which would
      // wrongly stop the loop on the cashier name line and discard
      // every item on the receipt.
      if (_shouldSkip(lower)) {
        final isCashWord = RegExp(r'\bcash\b').hasMatch(lower) &&
            !lower.contains('cashier');
        final isChangeWord = RegExp(r'\bchange\b').hasMatch(lower);
        final isTotalWord = RegExp(r'\btotal\b').hasMatch(lower);
        if (isCashWord || isChangeWord || isTotalWord) {
          pendingName = null;
          break;
        }
        pendingName = null;
        continue;
      }

      // Start collecting items once we see a line with an amount.
      // IMPORTANT: pendingName tracking (further below) must still run
      // even while !pastHeader, otherwise the very first item's name line
      // — which appears right before the line that triggers pastHeader —
      // gets skipped via `continue` here and is lost, causing the first
      // item to fall back to the generic "Item" placeholder name.
      if (!pastHeader && amountEnd.hasMatch(line)) {
        pastHeader = true;
      }

      // Try qty x price format — only treat as an item once pastHeader,
      // otherwise a header line that coincidentally matches this pattern
      // (rare, but possible) could leak in as a fake item.
      final qtyMatch = qtyLine.firstMatch(line);
      if (qtyMatch != null && pastHeader) {
        double unitPrice = 0;
        int qty = 1;

        if (qtyMatch.group(1) != null) {
          // "45.00 X 2" format
          unitPrice = double.tryParse(
                qtyMatch.group(1)!.replaceAll(',', ''),
              ) ?? 0;
          qty = int.tryParse(qtyMatch.group(2) ?? '1') ?? 1;
        } else {
          // "3 EA X 16.00" format
          qty = int.tryParse(qtyMatch.group(3) ?? '1') ?? 1;
          unitPrice = double.tryParse(
                qtyMatch.group(4)!.replaceAll(',', ''),
              ) ?? 0;
        }

        if (unitPrice > 0) {
          final name = pendingName?.isNotEmpty == true
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

      // Standard: name + amount on same line — same pastHeader guard
      final amountMatch = amountEnd.firstMatch(line);
      if (amountMatch != null && pastHeader) {
        final amount = double.tryParse(
          amountMatch.group(1)!.replaceAll(',', ''),
        );
        if (amount == null || amount <= 0) {
          pendingName = null;
          continue;
        }

        // Name = everything before the amount
        final name = line
            .substring(0, amountMatch.start)
            .trim();

        if (name.isNotEmpty &&
            name.length >= 2 &&
            !RegExp(r'^\d+$').hasMatch(name) &&
            !_shouldSkip(name.toLowerCase())) {
          items.add(ReceiptLineItem(name: name, amount: amount));
        } else if (pendingName?.isNotEmpty == true) {
          // Name was on previous line
          items.add(ReceiptLineItem(name: pendingName!, amount: amount));
        }
        pendingName = null;
        continue;
      }

      // No amount — store as potential pending name for next line
      if (line.length >= 3 &&
          !RegExp(r'^[\d\s\-=\*.]+$').hasMatch(line) &&
          !_shouldSkip(lower)) {
        pendingName = line;
      } else {
        pendingName = null;
      }
    }

    return items;
  }

  // ─── GRAND TOTAL ─────────────────────────────────────────────────────────
  //
  // CRITICAL: thermal receipt OCR frequently splits a label and its value
  // onto SEPARATE lines because of how the original receipt is column-
  // aligned (label left, amount right). For example:
  //
  //   TOTAL DUE
  //   599.00
  //   CASH
  //   600.00
  //   CHANGE
  //   1.00
  //
  // A line-by-line check that only looks at the CURRENT line for "cash" or
  // "change" will miss this entirely, because "600.00" by itself contains
  // no such word — the word is on the PREVIOUS line. This was the actual
  // bug: CASH's value (600.00) was being picked up as the total because
  // the exclusion never looked backward to the label line above it.
  //
  // Fix: build a list of (label, value) pairs by pairing each numeric-only
  // line with the nearest preceding non-numeric line, THEN apply the
  // cash/change exclusion against the PAIRED label, not just the value line.

  double? _findTotal(String text) {
    final rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    bool isCashOrChangeLabel(String lower) {
      final t = lower.trim();
      return t == 'cash' ||
          t.startsWith('cash') ||
          t == 'change' ||
          t.startsWith('change') ||
          t.contains('tendered') ||
          t.contains('cash in') ||
          t.contains('amount paid');
    }

    bool isTotalLabel(String lower) {
      final t = lower.trim();
      return t.startsWith('total') ||
          t.contains('total due') ||
          t.contains('total amount') ||
          t.contains('amount due') ||
          t.contains('total sales');
    }

    final pureNumber = RegExp(r'^[\d,]+\.\d{2}$');

    // Step 1: build (label, value) pairs — handles BOTH same-line and
    // split-line formats. lastLabel tracks the most recent non-numeric
    // line so a numeric-only line can be matched back to its label.
    String lastLabel = '';
    final pairs = <MapEntry<String, double>>[];

    for (final line in rawLines) {
      final lower = line.toLowerCase();

      if (pureNumber.hasMatch(line)) {
        // This line is JUST a number — pair it with the last seen label
        final v = double.tryParse(line.replaceAll(',', ''));
        if (v != null && v > 0) {
          pairs.add(MapEntry(lastLabel, v));
        }
        continue;
      }

      // This line has text — check if it also has a trailing amount
      // (same-line format, e.g. "TOTAL DUE    599.00")
      final sameLine = RegExp(r'([\d,]+\.\d{2})\s*[Vv]?\s*$').firstMatch(line);
      if (sameLine != null) {
        final v = double.tryParse(sameLine.group(1)!.replaceAll(',', ''));
        if (v != null && v > 0) {
          pairs.add(MapEntry(lower, v));
        }
      }

      // Always update lastLabel to this line's text, for the NEXT
      // numeric-only line to pair against
      lastLabel = lower;
    }

    // Step 2: search the paired (label, value) list for the total,
    // explicitly excluding anything paired with a cash/change label
    for (final pair in pairs) {
      if (isCashOrChangeLabel(pair.key)) continue;
      if (isTotalLabel(pair.key)) return pair.value;
    }

    // Step 3: any pair whose label contains "total" but isn't VAT-related
    for (final pair in pairs) {
      if (isCashOrChangeLabel(pair.key)) continue;
      if (pair.key.contains('total') &&
          !pair.key.contains('vat') &&
          !pair.key.contains('zero') &&
          !pair.key.contains('exempt') &&
          !pair.key.contains('item')) {
        return pair.value;
      }
    }

    // Step 4: last resort — largest value among all pairs, excluding
    // anything paired with a cash/change label
    double? largest;
    for (final pair in pairs) {
      if (isCashOrChangeLabel(pair.key)) continue;
      if (largest == null || pair.value > largest) {
        largest = pair.value;
      }
    }
    if (largest != null) return largest;

    // Step 5: absolute fallback — if pairing somehow found nothing
    // (e.g. unusual receipt layout), fall back to scanning raw text
    // for ANY total-labelled amount on a single line.
    final fallbackPatterns = [
      RegExp(r'total\s*\(\d+\)\s+([\d,]+\.\d{2})', caseSensitive: false),
      RegExp(r'total\s+due[:\s]+([\d,]+\.\d{2})', caseSensitive: false),
      RegExp(r'amount\s+due[:\s]*[Pp]?\s*([\d,]+\.\d{2})', caseSensitive: false),
      RegExp(r'total\s+amount[:\s]+([\d,]+\.\d{2})', caseSensitive: false),
    ];
    for (final line in rawLines) {
      final lower = line.toLowerCase();
      if (isCashOrChangeLabel(lower)) continue;
      for (final p in fallbackPatterns) {
        final m = p.firstMatch(line);
        if (m != null) {
          final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
          if (v != null && v > 0) return v;
        }
      }
    }

    return null;
  }

  // ─── DATE ────────────────────────────────────────────────────────────────

  String? _findDate(String text) {
    final m1 = RegExp(r'\b(\d{2}[\/\-]\d{2}[\/\-]\d{4})\b').firstMatch(text);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(
      r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+\d{4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    return m2?.group(1);
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  bool _isTotalOrPaymentLine(String lower) {
    final t = lower.trimLeft();
    // CRITICAL: must NOT use t.startsWith('cash') alone — "Cashier" also
    // starts with "cash" and would incorrectly trigger a stop here,
    // silently discarding the entire item list. Use word-boundary checks
    // so "cash" only matches as a whole word or "cash:"/"cash " etc,
    // never as a prefix of a longer word like "cashier".
    final isCashLine = RegExp(r'^cash\b').hasMatch(t) &&
        !t.startsWith('cashier');
    final isChangeLine = RegExp(r'^change\b').hasMatch(t);
    return t.startsWith('total') ||
        t.startsWith('subtotal') ||
        t.startsWith('sub total') ||
        isChangeLine ||
        isCashLine ||
        t.contains('amount due') ||
        t.contains('item(s)');
  }

  bool _shouldSkip(String lower) {
    return _skipWords.any((w) => lower.contains(w)) ||
        RegExp(r'^\d{5,}$').hasMatch(lower.replaceAll(' ', '')) ||
        RegExp(r'^[=\-_\*\.\/\\]{3,}$').hasMatch(lower);
  }

  String _titleCase(String text) {
    return text
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
