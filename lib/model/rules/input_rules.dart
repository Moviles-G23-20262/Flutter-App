/// Character-level rules shared by the login and sign-up forms.
abstract final class InputRules {
  static const int maxEmailLength = 254;

  /// Emoji and pictographic symbols: the emoji planes (U+1F000-1FAFF, which include flags and
  /// skin tones), miscellaneous symbols and dingbats, technical symbols such as watches,
  /// arrows-and-stars blocks, variation selectors, zero-width joiner, keycap and tag characters.
  static final RegExp emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}'
    r'\u{FE00}-\u{FE0F}\u{200D}\u{20E3}\u{E0020}-\u{E007F}]',
    unicode: true,
  );

  static bool containsEmoji(String text) => emoji.hasMatch(text);

  /// Control characters (line breaks and tabs included) and the invisible ones: zero-width space,
  /// bidirectional marks, word joiner and byte-order mark. A zero-width joiner is not here: emoji
  /// sequences use it, and [emoji] already covers it.
  static final RegExp controlOrInvisible = RegExp(
    r'[\u{0000}-\u{001F}\u{007F}-\u{009F}\u{200B}-\u{200C}\u{200E}-\u{200F}\u{2028}-\u{202E}\u{2060}-\u{2064}\u{FEFF}]',
    unicode: true,
  );

  // ── Character counters ─────────────────────────────────────────────────────

  /// A counter turns amber from this share of the limit, before the field is full.
  static const double counterWarningRatio = 0.85;

  /// How full a text field is: [CounterLevel.normal] up to 85 % of [max], [CounterLevel.warning]
  /// from there, [CounterLevel.full] at [max].
  static CounterLevel counterLevel(int length, int max) {
    if (max <= 0) return CounterLevel.normal;
    if (length >= max) return CounterLevel.full;
    if (length >= max * counterWarningRatio) return CounterLevel.warning;
    return CounterLevel.normal;
  }
}

/// How close a text is to its limit; see [InputRules.counterLevel].
enum CounterLevel { normal, warning, full }
