// ReceiptParserService
//
// Extracts line items from any Philippine receipt exactly as written by OCR.
// Engine-agnostic: works the same whether the text came from the on-device
// ML Kit recognizer (printed text) or the cloud Vision recognizer
// (handwriting-capable) — both feed it plain newline-separated text via
// OcrService, so this class doesn't need to know or care which one ran.
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
//   Handwritten receipts in particular tend to have messier alignment, so
//   this leans even more on "the user fixes anything wrong in ReviewScreen"
//   rather than trying to perfectly regex-parse imperfect handwriting.

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
    'change',
    'cash',
    'tendered',
    'total',
    'subtotal',
    'sub total',
    'amount due',
    'vat',
    'tax',
    'discount',
    'loyalty',
    'cashier',
    'staff',
    'terminal',
    'invoice',
    'receipt',
    'tin:',
    'bir',
    'ptu',
    'accr',
    'series',
    'thank you',
    'bawat',
    'sulit',
    'nothing follows',
    'this document',
    'not valid',
    'copy for',
    'address',
    'tel:',
    'philippines',
    'corporation',
    '---',
    '===',
    '***',
    // Generic pre-printed receipt-book template labels (common on the
    // small carbon-copy "Sold To / Articles / Price / Amount" pads used
    // for handwritten sales) — these are field labels, never the
    // merchant name or an item.
    'sold to',
    'qty unit',
    'articles',
    'price amount',
    'signature',
    'warranty',
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
    final compactPhone = RegExp(r'^0\d{9,10}$');

    bool isPlausibleNamePart(String line) {
      final lower = line.toLowerCase();
      final compact = line.replaceAll(RegExp(r'[\s\-]'), '');
      return line.length >= 2 &&
          line.length <= 40 &&
          !RegExp(r'^\d').hasMatch(line) &&
          !compactPhone.hasMatch(compact) &&
          !_skipWords.any((w) => lower.contains(w));
    }

    bool looksLikeAddressLine(String line) {
      if (!RegExp(r'^\d').hasMatch(line)) return false;
      final lower = line.toLowerCase();
      return lower.contains('st.') ||
          lower.contains('st,') ||
          lower.contains(' st ') ||
          lower.contains('brgy') ||
          lower.contains('zone') ||
          lower.contains('ave') ||
          lower.contains('blvd') ||
          lower.contains('rd.') ||
          lower.contains('compound') ||
          lower.contains('subd') ||
          lower.contains('district');
    }

    // Strategy 1: on printed PH receipt letterheads, the company name is
    // almost always the line sitting directly ABOVE its street address
    // (e.g. "JKGI GAS MARKETING" / "1624 Zamora St, Brgy. 821..."). This
    // is a far more reliable signal than "first plausible header line",
    // which can land on an unrelated sidebar list of product/service
    // categories (e.g. "STOVES / HOSE & CLAMPS / REGULATORS") that some
    // letterheads print above the actual company name.
    for (int i = 0; i < lines.length - 1 && i < 20; i++) {
      if (!looksLikeAddressLine(lines[i + 1])) continue;
      if (isPlausibleNamePart(lines[i])) return _titleCase(lines[i]);
    }

    // Strategy 2: pre-printed receipt-book pads (the small carbon-copy
    // "Sold To / Articles / Price / Amount" pads used for informal
    // handwritten sales) are usually custom-printed for the shop that
    // uses them, with the shop's OWN name printed vertically down the
    // margin right next to their mobile number(s) (e.g. "LAKAY QUIAPO"
    // next to "0999 943 1025"). That is a much stronger merchant signal
    // on these templates than "first non-skip line", because the first
    // non-skip line there is usually the CUSTOMER's handwritten name
    // under "Sold To", not the seller.
    //
    // Whether the name comes before or after the phone number(s) in the
    // OCR output depends on which way that vertical text block happened
    // to be rotated — the recognizer can read it top-to-bottom or
    // bottom-to-top — so check both sides of the phone-number cluster,
    // and allow the name to span up to 2 lines (e.g. "LAKAY" / "QUIAPO").
    for (int i = 0; i < lines.length && i < 20; i++) {
      final compact = lines[i].replaceAll(RegExp(r'[\s\-]'), '');
      if (!compactPhone.hasMatch(compact)) continue;

      // Extend to cover a run of consecutive phone-number lines.
      int end = i;
      while (end + 1 < lines.length &&
          compactPhone.hasMatch(
            lines[end + 1].replaceAll(RegExp(r'[\s\-]'), ''),
          )) {
        end++;
      }

      final after = <String>[];
      for (int j = end + 1; j < lines.length && j < end + 3; j++) {
        if (!isPlausibleNamePart(lines[j])) break;
        after.add(lines[j]);
      }
      if (after.isNotEmpty) return _titleCase(after.join(' '));

      final before = <String>[];
      for (int j = i - 1; j >= 0 && j > i - 3; j--) {
        if (!isPlausibleNamePart(lines[j])) break;
        before.insert(0, lines[j]);
      }
      if (before.isNotEmpty) return _titleCase(before.join(' '));

      break; // only the first phone-number cluster is a merchant signal
    }

    // Strategy 3: scan the header for the first plausible business-name
    // line. Widened from 8 to 14: on pre-printed receipt-book templates,
    // several lines of printed field labels (Sold To / Address / Qty Unit
    // / Articles / Price Amount) usually come before the actual business
    // name, which is often handwritten or stamped further down.
    //
    // "Sold To" and "Address" are field labels whose VALUE (customer name,
    // customer address) sits on the line right after — that value must be
    // skipped too, or the customer gets mistaken for the merchant.
    bool skipNextValue = false;
    for (final line in lines.take(14)) {
      final lower = line.toLowerCase();
      if (skipNextValue) {
        skipNextValue = false;
        continue;
      }
      if (lower.contains('sold to') || lower.contains('address')) {
        skipNextValue = true;
        continue;
      }
      if (line.length < 3 || line.length > 60) continue;
      if (RegExp(r'^\d').hasMatch(line)) continue;
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
          lower.contains('philippines')) {
        continue;
      }
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

    // Amount at end of line, with optional V (VATable) flag and quantity.
    //
    // Printed receipts always show cents (e.g. "45.00"), so a strict
    // decimal requirement works there. Handwritten receipts, though,
    // are almost always written as whole pesos ("500", "1,000", "P1,000")
    // with no decimal point at all. A bare integer is too ambiguous to
    // treat as a price on its own (it could be a quantity, item number,
    // etc.), so we only relax the decimal requirement when the number is
    // marked with a peso sign (₱ or a bare "P" — OcrCleanupService
    // normalizes "P " to "₱", but an unspaced "P1,000" can still reach
    // here as-is) — that marker is a strong, low-risk signal that this
    // really is a price, not some other bare number on the line.
    //
    // The "P" must NOT be immediately preceded by another letter, or it
    // would match the tail of an unrelated abbreviation that happens to
    // end in "P" right before a run of digits — e.g. a printer's
    // accreditation number like "057MP20210000000001" (the "P" in "MP")
    // would otherwise be misread as a peso sign marking a huge fake price.
    final amountEnd = RegExp(
      r'(?:(?<![A-Za-z])[₱P]\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+\.\d{2}))\s*[Vv]?\s*$',
    );

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
        final isCashWord =
            RegExp(r'\bcash\b').hasMatch(lower) && !lower.contains('cashier');
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
          unitPrice =
              double.tryParse(qtyMatch.group(1)!.replaceAll(',', '')) ?? 0;
          qty = int.tryParse(qtyMatch.group(2) ?? '1') ?? 1;
        } else {
          // "3 EA X 16.00" format
          qty = int.tryParse(qtyMatch.group(3) ?? '1') ?? 1;
          unitPrice =
              double.tryParse(qtyMatch.group(4)!.replaceAll(',', '')) ?? 0;
        }

        if (unitPrice > 0) {
          final name = pendingName?.isNotEmpty == true ? pendingName! : 'Item';
          items.add(
            ReceiptLineItem(name: name, amount: unitPrice * qty, quantity: qty),
          );
        }
        pendingName = null;
        continue;
      }

      // Standard: name + amount on same line — same pastHeader guard
      final amountMatch = amountEnd.firstMatch(line);
      if (amountMatch != null && pastHeader) {
        final amountStr = amountMatch.group(1) ?? amountMatch.group(2);
        final amount = double.tryParse(amountStr!.replaceAll(',', ''));
        if (amount == null || amount <= 0) {
          pendingName = null;
          continue;
        }

        // Name = everything before the amount
        final name = line.substring(0, amountMatch.start).trim();

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

    // Handwritten totals are frequently split across two lines with NO
    // decimal point and NO peso marker at all, e.g.:
    //   TOTAL
    //   1000
    // A bare digit-only line is safe to accept here (unlike in _findItems)
    // because it's only ever trusted once paired with a preceding
    // TOTAL/CASH/CHANGE label in Step 2/3 below — an unrelated bare number
    // (a receipt/invoice number, a quantity) just ends up paired with
    // whatever ordinary text preceded it and is ignored, since that label
    // won't contain "total".
    final pureNumber = RegExp(r'^[\d,]+(?:\.\d{1,2})?$');

    bool isNonMonetaryLabel(String lower) {
      final t = lower.trim();
      if (t.isEmpty) return true;
      const nonMonetary = [
        'terms',
        'invoice',
        'series',
        'permit',
        'accreditation',
        'bir',
        'reg. tin',
        'reg tin',
        'tin:',
        ' tin',
        'qty',
        'unit',
        'reference',
        'or no',
        'control no',
        'date issued',
        'no.',
        'approved series',
        'bklts',
      ];
      return nonMonetary.any((w) => t.contains(w));
    }

    // Step 1: build (label, value) pairs — handles BOTH same-line and
    // split-line formats. lastLabel tracks the most recent non-numeric
    // line so a numeric-only line can be matched back to its label.
    String lastLabel = '';
    final pairs = <MapEntry<String, double>>[];

    for (final line in rawLines) {
      final lower = line.toLowerCase();

      if (pureNumber.hasMatch(line)) {
        // This line is JUST a number — pair it with the last seen label.
        // Skip it entirely if that label is something like "Terms" or an
        // invoice/series number field — otherwise a printed invoice
        // number sitting alone on its own line (e.g. "19732" right after
        // a blank "Terms" field) could out-rank the real total in the
        // Step 4 "largest value" fallback below.
        if (isNonMonetaryLabel(lastLabel)) continue;
        final cleaned = line.replaceAll(RegExp(r'[₱P,\s]'), '');
        final v = double.tryParse(cleaned);
        if (v != null && v > 0) {
          pairs.add(MapEntry(lastLabel, v));
        }
        continue;
      }

      // This line has text — check if it also has a trailing amount
      // (same-line format, e.g. "TOTAL DUE    599.00", or the handwritten
      // whole-peso equivalent "TOTAL DUE  ₱1,000" / "TOTAL DUE  P1,000").
      // A peso marker is required for the no-decimal case — without it,
      // trailing digits on ANY line (e.g. a receipt/invoice number) would
      // get misread as an amount. The marker also can't be preceded by
      // another letter, or it would match the tail of an unrelated
      // abbreviation ending in "P" (see the note on amountEnd above).
      final sameLine = RegExp(
        r'(?:(?<![A-Za-z])[₱P]\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+\.\d{2}))\s*[Vv]?\s*$',
      ).firstMatch(line);
      if (sameLine != null) {
        final raw = sameLine.group(1) ?? sameLine.group(2);
        final v = double.tryParse(raw!.replaceAll(',', ''));
        if (v != null && v > 0) {
          pairs.add(MapEntry(lower, v));
        }
      }

      // Always update lastLabel to this line's text, for the NEXT
      // numeric-only line to pair against
      lastLabel = lower;
    }

    // Step 1.5: on some thermal POS receipts, ML Kit reads the printed
    // field labels and their values as two separate blocks (grouped by
    // physical column rather than row), so a numeric-only line ends up
    // paired with whatever text happened to precede it in OCR order —
    // NOT the label it's actually printed next to. That can attach the
    // real total's own label ("Total Amount") to an unrelated value
    // (e.g. the VAT amount), while the true total sits further down,
    // orphaned from any label at all.
    //
    // The real total on these receipts is usually echoed several times
    // (e.g. once as "Total Sales", again folded into the cash/change
    // math) — a value repeating 3+ times is a much safer signal here
    // than trusting a label/value pairing that might be scrambled, so
    // check for that BEFORE trusting Step 2's label match.
    final frequency = <double, int>{};
    for (final pair in pairs) {
      if (isCashOrChangeLabel(pair.key)) continue;
      frequency[pair.value] = (frequency[pair.value] ?? 0) + 1;
    }
    double? mostRepeated;
    int bestCount = 0;
    for (final entry in frequency.entries) {
      if (entry.value > bestCount ||
          (entry.value == bestCount &&
              (mostRepeated == null || entry.key > mostRepeated))) {
        bestCount = entry.value;
        mostRepeated = entry.key;
      }
    }
    if (mostRepeated != null && bestCount >= 3) {
      return mostRepeated;
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
      RegExp(
        r'total\s*\(\d+\)\s+[₱P]?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'total\s+due[:\s]+[₱P]?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'amount\s+due[:\s]*[Pp₱]?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'total\s+amount[:\s]+[₱P]?\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
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
    final isCashLine =
        RegExp(r'^cash\b').hasMatch(t) && !t.startsWith('cashier');
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