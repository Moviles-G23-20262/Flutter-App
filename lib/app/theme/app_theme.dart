import 'package:flutter/material.dart';

// ─── Color Palette ──────────────────────────────────────────────────────────

/// All brand colours for Campus Swap, matching the CSS design tokens.
class AppColors {
  AppColors._();

  // Primary
  static const Color primary50  = Color(0xFFF8F8F9);
  static const Color primary100 = Color(0xFFEEEEF2);
  static const Color primary200 = Color(0xFFD7D9E5);
  static const Color primary300 = Color(0xFFAFB4D5);
  static const Color primary400 = Color(0xFF7883C9);
  static const Color primary500 = Color(0xFF3B4DC4);
  static const Color primary600 = Color(0xFF2E3DA4);
  static const Color primary700 = Color(0xFF222F81);
  static const Color primary800 = Color(0xFF18215D);
  static const Color primary900 = Color(0xFF11163C);
  static const Color primary950 = Color(0xFF0A0D1F);

  // Neutral
  static const Color neutral50  = Color(0xFFF9F9F9);
  static const Color neutral100 = Color(0xFFF2F2F2);
  static const Color neutral200 = Color(0xFFE8E8E8);
  static const Color neutral300 = Color(0xFFD3D3D5);
  static const Color neutral400 = Color(0xFFA1A1A6);
  static const Color neutral500 = Color(0xFF76777E);
  static const Color neutral600 = Color(0xFF59595F);
  static const Color neutral700 = Color(0xFF404045);
  static const Color neutral800 = Color(0xFF2A2A2D);
  static const Color neutral900 = Color(0xFF18191B);
  static const Color neutral950 = Color(0xFF0F0F10);

  // Success
  static const Color success400 = Color(0xFF6DD493);
  static const Color success500 = Color(0xFF24BC5C);
  static const Color success600 = Color(0xFF1A9D4B);

  // Warning
  static const Color warning400 = Color(0xFFE6B35B);
  static const Color warning500 = Color(0xFFF59F0A);
  static const Color warning600 = Color(0xFFCE8403);

  // Error
  static const Color error400 = Color(0xFFD97069);
  static const Color error500 = Color(0xFFDE2E21);
  static const Color error600 = Color(0xFFBA2217);

  // ── Dark Theme Semantic Tokens ─────────────────────────────────────────────
  static const Color darkBg           = neutral950;           // #0f0f10
  static const Color darkSurface      = neutral900;           // #18191b
  static const Color darkElevated     = neutral800;           // #2a2a2d
  static const Color darkBorder       = neutral800;           // #2a2a2d
  static const Color darkBorderSubtle = neutral700;           // #404045
  static const Color darkTextPrimary  = neutral50;            // #f9f9f9
  static const Color darkTextSecondary= neutral300;           // #d3d3d5
  static const Color darkTextMuted    = neutral500;           // #76777e
  static const Color darkAccent       = primary500;           // #3b4dc4
  static const Color darkAccentHi     = primary400;           // #7883c9
  static const Color darkAccentLo     = primary700;           // #222f81
  static const Color darkAccentTx     = neutral50;
  static const Color darkTagBg        = primary900;
  static const Color darkTagTx        = primary300;
  static const Color darkSuccess      = success400;
  static const Color darkWarning      = warning400;
  static const Color darkError        = error400;
  static const Color darkHeroFrom     = primary900;
  static const Color darkHeroTo       = primary700;
  static const Color darkShadowAccent = Color(0x8C222F81);    // rgba(34,47,129,0.55)
  static const Color darkShadowCard   = Color(0x73000000);    // rgba(0,0,0,0.45)

  // ── Light Theme Semantic Tokens ────────────────────────────────────────────
  static const Color lightBg           = primary50;
  static const Color lightSurface      = Color(0xFFFFFFFF);
  static const Color lightElevated     = primary100;
  static const Color lightBorder       = primary200;
  static const Color lightBorderSubtle = primary300;
  static const Color lightTextPrimary  = primary900;
  static const Color lightTextSecondary= primary800;
  static const Color lightTextMuted    = primary400;
  static const Color lightAccent       = primary500;
  static const Color lightAccentHi     = primary600;
  static const Color lightAccentLo     = primary700;
  static const Color lightAccentTx     = Color(0xFFFFFFFF);
  static const Color lightTagBg        = primary100;
  static const Color lightTagTx        = primary700;
  static const Color lightSuccess      = success600;
  static const Color lightWarning      = warning600;
  static const Color lightError        = error600;
  static const Color lightHeroFrom     = primary600;
  static const Color lightHeroTo       = primary500;
  static const Color lightShadowAccent = Color(0x2E222F81);
  static const Color lightShadowCard   = Color(0x1A3B4DC4);
}

// ─── Typography Scale ────────────────────────────────────────────────────────

/// Typography constants following a Perfect Fourth scale (×1.333).
class AppTextStyles {
  AppTextStyles._();

  // Font size constants
  static const double size2xs = 9.0;
  static const double sizeXs  = 12.0;
  static const double sizeSm  = 16.0;
  static const double sizeMd  = 21.0;
  static const double sizeLg  = 28.0;
  static const double sizeXl  = 38.0;
  static const double size2xl = 50.0;

  /// Heading style — large display text (Fraunces substitute: bold serif feel via weight).
  static TextStyle heading(Color color, {double fontSize = sizeMd}) => TextStyle(
    fontFamily: 'serif',
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: -0.02 * fontSize,
    height: 1.25,
  );

  /// Body style — standard readable text.
  static TextStyle body(Color color, {double fontSize = sizeSm, FontWeight fontWeight = FontWeight.w400}) => TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: 1.5,
  );

  /// Monospace style — for prices, timestamps, codes.
  static TextStyle mono(Color color, {double fontSize = sizeXs, FontWeight fontWeight = FontWeight.w400}) => TextStyle(
    fontFamily: 'monospace',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  /// Label style — uppercased small badges.
  static TextStyle label(Color color, {double fontSize = size2xs}) => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    color: color,
    letterSpacing: 0.04 * fontSize,
  );

  /// Price style — prominent accent-coloured heading number.
  static TextStyle price(Color color, {double fontSize = sizeSm}) => TextStyle(
    fontFamily: 'serif',
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color,
  );
}

// ─── Decoration Helpers ──────────────────────────────────────────────────────

/// Reusable BoxDecoration / BoxShadow helpers for Campus Swap widgets.
class AppDecorations {
  AppDecorations._();

  /// Hero card gradient banner.
  static BoxDecoration heroGradient(Brightness brightness) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: brightness == Brightness.dark
          ? [AppColors.darkHeroFrom, AppColors.darkHeroTo]
          : [AppColors.lightHeroFrom, AppColors.lightHeroTo],
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: brightness == Brightness.dark ? AppColors.darkAccentLo : AppColors.lightAccentLo,
    ),
    boxShadow: [
      BoxShadow(
        color: brightness == Brightness.dark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent,
        blurRadius: 24,
        offset: const Offset(0, 6),
      ),
    ],
  );

  /// Standard card decoration.
  static BoxDecoration card(Brightness brightness) => BoxDecoration(
    color: brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder,
    ),
    boxShadow: [
      BoxShadow(
        color: brightness == Brightness.dark ? AppColors.darkShadowCard : AppColors.lightShadowCard,
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// Product card decoration (smaller radius, subtle shadow).
  static BoxDecoration productCard(Brightness brightness) => BoxDecoration(
    color: brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder,
    ),
    boxShadow: [
      BoxShadow(
        color: brightness == Brightness.dark ? AppColors.darkShadowCard : AppColors.lightShadowCard,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// Elevated container (filter panels, sticky notes).
  static BoxDecoration elevated(Brightness brightness) => BoxDecoration(
    color: brightness == Brightness.dark ? AppColors.darkElevated : AppColors.lightElevated,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
    ),
  );

  /// Accent button glow shadow.
  static List<BoxShadow> accentShadow(Brightness brightness) => [
    BoxShadow(
      color: brightness == Brightness.dark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent,
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  /// Tag / badge decoration.
  static BoxDecoration badge(Brightness brightness, {bool highlighted = false}) => BoxDecoration(
    color: highlighted
        ? (brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent)
        : (brightness == Brightness.dark ? AppColors.darkTagBg : AppColors.lightTagBg),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(
      color: brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
    ),
  );

  /// Pill chip decoration (active / inactive).
  static BoxDecoration pill(Brightness brightness, {required bool active}) => BoxDecoration(
    color: active
        ? (brightness == Brightness.dark ? AppColors.darkAccent : AppColors.lightAccent)
        : (brightness == Brightness.dark ? AppColors.darkElevated : AppColors.lightElevated),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(
      color: active
          ? (brightness == Brightness.dark ? AppColors.darkAccentLo : AppColors.lightAccentLo)
          : (brightness == Brightness.dark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
    ),
  );
}

// ─── ThemeData ───────────────────────────────────────────────────────────────

/// Main theme provider for Campus Swap.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme  => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg           = isDark ? AppColors.darkBg           : AppColors.lightBg;
    final surface      = isDark ? AppColors.darkSurface      : AppColors.lightSurface;
    final elevated     = isDark ? AppColors.darkElevated     : AppColors.lightElevated;
    final border       = isDark ? AppColors.darkBorder       : AppColors.lightBorder;
    final textPrimary  = isDark ? AppColors.darkTextPrimary  : AppColors.lightTextPrimary;
    final textSecondary= isDark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final textMuted    = isDark ? AppColors.darkTextMuted    : AppColors.lightTextMuted;
    final accent       = isDark ? AppColors.darkAccent       : AppColors.lightAccent;
    final accentHi     = isDark ? AppColors.darkAccentHi     : AppColors.lightAccentHi;
    final accentLo     = isDark ? AppColors.darkAccentLo     : AppColors.lightAccentLo;
    final error        = isDark ? AppColors.darkError        : AppColors.lightError;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: AppColors.darkAccentTx,
      primaryContainer: accentLo,
      onPrimaryContainer: textPrimary,
      secondary: accentHi,
      onSecondary: AppColors.darkAccentTx,
      secondaryContainer: elevated,
      onSecondaryContainer: textSecondary,
      tertiary: isDark ? AppColors.darkSuccess : AppColors.lightSuccess,
      onTertiary: AppColors.darkAccentTx,
      tertiaryContainer: elevated,
      onTertiaryContainer: textPrimary,
      error: error,
      onError: surface,
      errorContainer: elevated,
      onErrorContainer: error,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
      shadow: isDark ? AppColors.darkShadowCard : AppColors.lightShadowCard,
      inverseSurface: textPrimary,
      onInverseSurface: surface,
      inversePrimary: accentHi,
      surfaceTint: accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.heading(textPrimary, fontSize: AppTextStyles.sizeMd),
        iconTheme: IconThemeData(color: textSecondary),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accentHi,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textMuted, fontSize: AppTextStyles.sizeSm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: AppColors.darkAccentTx,
          elevation: 2,
          shadowColor: isDark ? AppColors.darkShadowAccent : AppColors.lightShadowAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: TextStyle(fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textSecondary,
          backgroundColor: elevated,
          side: BorderSide(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: TextStyle(fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentHi,
          textStyle: TextStyle(fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),

      iconTheme: IconThemeData(color: textMuted, size: 20),

      textTheme: TextTheme(
        displayLarge:  AppTextStyles.heading(textPrimary, fontSize: AppTextStyles.size2xl),
        displayMedium: AppTextStyles.heading(textPrimary, fontSize: AppTextStyles.sizeXl),
        displaySmall:  AppTextStyles.heading(textPrimary, fontSize: AppTextStyles.sizeLg),
        headlineLarge: AppTextStyles.heading(textPrimary, fontSize: AppTextStyles.sizeLg),
        headlineMedium:AppTextStyles.heading(textPrimary, fontSize: AppTextStyles.sizeMd),
        headlineSmall: AppTextStyles.heading(textPrimary, fontSize: AppTextStyles.sizeSm),
        titleLarge:    AppTextStyles.body(textPrimary, fontSize: AppTextStyles.sizeMd, fontWeight: FontWeight.w700),
        titleMedium:   AppTextStyles.body(textPrimary, fontSize: AppTextStyles.sizeSm, fontWeight: FontWeight.w600),
        titleSmall:    AppTextStyles.body(textPrimary, fontSize: AppTextStyles.sizeXs, fontWeight: FontWeight.w600),
        bodyLarge:     AppTextStyles.body(textPrimary, fontSize: AppTextStyles.sizeSm),
        bodyMedium:    AppTextStyles.body(textSecondary, fontSize: AppTextStyles.sizeXs),
        bodySmall:     AppTextStyles.body(textMuted, fontSize: AppTextStyles.size2xs),
        labelLarge:    AppTextStyles.label(textSecondary, fontSize: AppTextStyles.sizeXs),
        labelMedium:   AppTextStyles.label(textMuted, fontSize: AppTextStyles.size2xs),
        labelSmall:    AppTextStyles.label(textMuted, fontSize: AppTextStyles.size2xs),
      ),
    );
  }
}

