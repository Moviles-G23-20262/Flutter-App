import 'input_rules.dart';

/// Input rules of the "sell an item" form. They match the ones the server applies to a new listing,
/// so nothing the app lets through is refused with a 400. The price rules also protect the average
/// ticket (BQ15): a price of 45 instead of 45.000 would be counted as a real sale.
abstract final class ListingRules {
  /// Prices are whole Colombian pesos.
  static const int minPrice = 1000;
  static const int maxPrice = 50000000;

  static const int minTitleLength = 3;
  static const int maxTitleLength = 60;
  static const int minDescriptionLength = 10;
  static const int maxDescriptionLength = 330;
  static const int maxCourseCodeLength = 20;

  /// Longest text a person can type in the price field ("50.000.000" is 10 characters).
  static const int maxPriceInput = 12;

  static final RegExp _plainNumber = RegExp(r'^\d+$');

  /// "45.000", "45,000", "1.250.000": groups of exactly three digits after the first group.
  static final RegExp _groupedNumber = RegExp(r'^\d{1,3}(?:[.,]\d{3})+$');

  static final RegExp _manySpaces = RegExp(r'\s+');
  static final RegExp _lineBreaks = RegExp(r'[\n\r\t]');

  // ── Price ──────────────────────────────────────────────────────────────────

  /// The price in pesos, or `null` when the text is not a whole number of pesos. `.` and `,`
  /// separate thousands, so "45.000" and "45,000" are 45000, never 45.0; a decimal such as "45.5"
  /// is refused instead of being read as 455.
  static int? parsePrice(String raw) {
    final text = raw.trim();
    if (_plainNumber.hasMatch(text)) return int.tryParse(text);
    if (_groupedNumber.hasMatch(text)) return int.tryParse(text.replaceAll(RegExp(r'[.,]'), ''));
    return null;
  }

  static String? validatePrice(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return 'Enter a price.';
    final value = parsePrice(text);
    if (value == null) {
      // All digits but too many for an int: it is a number, just absurdly large.
      if (_plainNumber.hasMatch(text)) return _outOfRange;
      return 'Enter the price in whole pesos, like 45000 or 45.000.';
    }
    if (!value.toDouble().isFinite || value < minPrice || value > maxPrice) return _outOfRange;
    return null;
  }

  static const String _outOfRange = 'The price must be between \$1.000 and \$50.000.000 COP.';

  // ── Title and description ──────────────────────────────────────────────────

  /// Trimmed, with each run of whitespace turned into one space.
  static String normalizeTitle(String raw) => raw.trim().replaceAll(_manySpaces, ' ');

  /// Trimmed; line breaks inside are kept.
  static String normalizeDescription(String raw) => raw.trim();

  static String? validateTitle(String? raw) {
    final title = normalizeTitle(raw ?? '');
    if (title.isEmpty) return 'Add a title.';
    if (InputRules.containsEmoji(title)) return "The title can't contain emojis.";
    if (InputRules.controlOrInvisible.hasMatch(title)) return 'The title has characters that are not allowed.';
    if (title.length < minTitleLength || title.length > maxTitleLength) {
      return 'The title needs $minTitleLength to $maxTitleLength characters.';
    }
    return null;
  }

  static String? validateDescription(String? raw) {
    final description = normalizeDescription(raw ?? '');
    if (description.isEmpty) return 'Add a description.';
    if (InputRules.controlOrInvisible.hasMatch(description.replaceAll(_lineBreaks, ' '))) {
      return 'The description has characters that are not allowed.';
    }
    if (description.length < minDescriptionLength || description.length > maxDescriptionLength) {
      return 'The description needs $minDescriptionLength to $maxDescriptionLength characters.';
    }
    return null;
  }

  /// The course code is optional; when given it has at most [maxCourseCodeLength] characters.
  static String? validateCourseCode(String? raw) {
    final code = (raw ?? '').trim();
    if (code.length > maxCourseCodeLength) {
      return 'The course code is too long (at most $maxCourseCodeLength characters).';
    }
    return null;
  }
}
