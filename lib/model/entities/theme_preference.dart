/// How the app picks light or dark.
enum ThemePreference {
  /// Follows the phone's ambient light sensor (falls back to the system theme without one).
  auto,
  light,
  dark;

  String get displayName {
    switch (this) {
      case ThemePreference.auto:
        return 'Auto';
      case ThemePreference.light:
        return 'Light';
      case ThemePreference.dark:
        return 'Dark';
    }
  }
}
