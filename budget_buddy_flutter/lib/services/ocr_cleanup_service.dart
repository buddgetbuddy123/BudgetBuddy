class OcrCleanupService {
  String clean(String text) {
    String result = text;

    // Remove hidden characters
    result = result.replaceAll('\r', '');
    result = result.replaceAll('\t', ' ');
    result = result.replaceAll('\u00A0', ' ');

    final replacements = <String, String>{
      // ===== Receipt keywords =====
      'T0TAL': 'TOTAL',
      'TOTAI': 'TOTAL',
      'T0TAI': 'TOTAL',
      'T0TAL DUE': 'TOTAL DUE',

      '5UBTOTAL': 'SUBTOTAL',
      '5UB TOTAL': 'SUB TOTAL',

      'CA5H': 'CASH',
      'CA5': 'CASH',

      'CHAN6E': 'CHANGE',
      'CHANQE': 'CHANGE',

      'AM0UNT': 'AMOUNT',
      'AM0UNT DUE': 'AMOUNT DUE',

      'RECE1PT': 'RECEIPT',
      'MERCH4NT': 'MERCHANT',

      '1NVOICE': 'INVOICE',
      '1TEM': 'ITEM',
      '1TEMS': 'ITEMS',

      // ===== Months =====
      'JU1Y': 'JULY',
      'JANUARV': 'JANUARY',
      '0CT': 'OCT',
      'N0V': 'NOV',

      // ===== Currency =====
      'PHP.': 'PHP ',
      'PHP:': 'PHP ',
      'PHP,': 'PHP ',
      '₱ ': '₱',
      'P ': '₱',
    };

    replacements.forEach((wrong, correct) {
      // BUG FIX: `wrong` was passed straight into RegExp() unescaped.
      // Keys like 'PHP.' and 'PHP,' contain regex metacharacters — '.'
      // means "match any character", so RegExp('PHP.') was matching
      // "PHPx", "PHP5", "PHP " etc, not just a literal "PHP.". That could
      // silently mangle legitimate text (e.g. a merchant name "PHP2GO"
      // would get corrupted). We now escape the pattern so it only
      // matches the literal string it was written to represent.
      result = result.replaceAll(
        RegExp(_escapeRegex(wrong), caseSensitive: false),
        correct,
      );
    });

    // Fix OCR mistakes inside numbers
    result = result.replaceAllMapped(
      RegExp(r'(?<=\d)[Oo](?=\d)'),
      (_) => '0',
    );

    result = result.replaceAllMapped(
      RegExp(r'(?<=\d)[Il](?=\d)'),
      (_) => '1',
    );

    result = result.replaceAllMapped(
      RegExp(r'(?<=₱)[Oo](?=\d)'),
      (_) => '0',
    );

    result = result.replaceAllMapped(
      RegExp(r'(?<=PHP )[Oo](?=\d)'),
      (_) => '0',
    );

    // Handwriting-leaning confusions Cloud Vision occasionally produces
    // inside a run of digits (rarer with printed text, common enough with
    // handwriting to be worth correcting): l/I -> 1, S -> 5, B -> 8,
    // capital O already handled above.
    result = result.replaceAllMapped(
      RegExp(r'(?<=\d)[Ss](?=\d)'),
      (_) => '5',
    );
    result = result.replaceAllMapped(
      RegExp(r'(?<=\d)[Bb](?=\d)'),
      (_) => '8',
    );

    // Remove duplicate spaces
    result = result.replaceAll(RegExp(r'[ ]{2,}'), ' ');

    // Remove duplicate blank lines
    result = result.replaceAll(RegExp(r'\n{2,}'), '\n');

    return result.trim();
  }

  String _escapeRegex(String s) {
    return s.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (m) => '\\${m[0]}',
    );
  }
}