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
}
