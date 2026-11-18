import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'accent.dart';
import 'app_tokens.dart';

/// App Theme Controller for managing Light, Dark, and System themes.
class AppThemeController extends ChangeNotifier {
  static final AppThemeController instance = AppThemeController._internal();
  AppThemeController._internal();

  static const String _kThemePrefKey = 'tm_app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // Default fallback to true for system if unknown
    return true;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kThemePrefKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'system';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      await prefs.setString(_kThemePrefKey, val);
    } catch (_) {}
  }

  Future<void> toggleTheme(BuildContext context) async {
    final currentIsDark = Theme.of(context).brightness == Brightness.dark;
    final next = currentIsDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

/// Unified Material 3 Expressive Theme Definition for TiggoMate.
/// Features:
/// 1. Obsidian Expressive Dark Mode: High-contrast PHEV cockpit with vibrant accents and tonal elevation.
/// 2. Clean Expressive Light Mode: Studio automotive aesthetic with soft ambient tonal containers.
class AppTheme {
  // Common Accents (Cyber Minimalist Automotive Palette)
  static const Color evTealDark = Color(0xFFD2F835);
  static const Color evTealLight = Color(0xFF65A30D);
  static const Color petrolAmberDark = Color(0xFFFF6E40);
  static const Color petrolAmberLight = Color(0xFFEA580C);

  /// Material 3 Expressive Light Theme
  static ThemeData light([Accent? a]) {
    final curAccent = a ?? Accent.current.value;
    final accentColor = curAccent.day;
    final onAccentColor = curAccent.onDay;
    final tokens = AppTokens.light.copyWith(
      accent: accentColor,
      onAccent: onAccentColor,
      accentContainer: accentColor.withValues(alpha: 0.15),
      onAccentContainer: accentColor,
    );

    final bg = tokens.bg;
    final cardBg = tokens.surface;
    final border = tokens.border;
    final textPrimary = tokens.ink;
    final textSecondary = tokens.ink2;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.light(
        primary: accentColor,
        onPrimary: onAccentColor,
        primaryContainer: tokens.resolvedAccentContainer,
        onPrimaryContainer: tokens.resolvedOnAccentContainer,
        secondary: textSecondary,
        onSecondary: bg,
        secondaryContainer: tokens.resolvedContainerHigh,
        onSecondaryContainer: textPrimary,
        tertiary: tokens.warn,
        onTertiary: tokens.onWarn,
        tertiaryContainer: tokens.warnContainer,
        onTertiaryContainer: tokens.warn,
        error: tokens.danger,
        onError: Colors.white,
        errorContainer: tokens.resolvedDangerContainer,
        onErrorContainer: tokens.danger,
        surface: cardBg,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        surfaceContainerLowest: tokens.resolvedContainerLowest,
        surfaceContainerLow: tokens.resolvedContainerLow,
        surfaceContainer: tokens.resolvedContainer,
        surfaceContainerHigh: tokens.resolvedContainerHigh,
        surfaceContainerHighest: tokens.resolvedContainerHighest,
        outline: border,
        outlineVariant: tokens.resolvedBorderSubtle,
        inverseSurface: const Color(0xFF191C20),
        onInverseSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: _sageTextTheme(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1.0,
        surfaceTintColor: accentColor.withValues(alpha: 0.05),
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Oswald',
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: cardBg,
        elevation: 0,
        indicatorColor: accentColor.withValues(alpha: 0.16),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accentColor, size: 24);
          }
          return IconThemeData(color: textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            );
          }
          return TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: onAccentColor,
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
          side: BorderSide(color: border, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: border, width: 1.0),
        backgroundColor: tokens.resolvedContainerLow,
        selectedColor: tokens.resolvedAccentContainer,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        modalBackgroundColor: cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.resolvedContainerLow,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: tokens.ink3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentColor, width: 2.0),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.resolvedBorderSubtle,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cardBg,
        contentTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1.2),
        ),
        elevation: 6,
      ),
      extensions: [tokens],
    );
  }

  /// Material 3 Expressive Obsidian Dark Theme
  static ThemeData dark([Accent? a]) {
    final curAccent = a ?? Accent.current.value;
    final accentColor = curAccent.night;
    final onAccentColor = curAccent.onNight;
    final tokens = AppTokens.dark.copyWith(
      accent: accentColor,
      onAccent: onAccentColor,
      accentContainer: accentColor.withValues(alpha: 0.22),
      onAccentContainer: accentColor,
    );

    final bg = tokens.bg;
    final cardBg = tokens.surface;
    final border = tokens.border;
    final textPrimary = tokens.ink;
    final textSecondary = tokens.ink2;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        onPrimary: onAccentColor,
        primaryContainer: tokens.resolvedAccentContainer,
        onPrimaryContainer: tokens.resolvedOnAccentContainer,
        secondary: textSecondary,
        onSecondary: bg,
        secondaryContainer: tokens.resolvedContainerHigh,
        onSecondaryContainer: textPrimary,
        tertiary: tokens.warn,
        onTertiary: tokens.onWarn,
        tertiaryContainer: tokens.warnContainer,
        onTertiaryContainer: tokens.warn,
        error: tokens.danger,
        onError: Colors.white,
        errorContainer: tokens.resolvedDangerContainer,
        onErrorContainer: tokens.danger,
        surface: cardBg,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        surfaceContainerLowest: tokens.resolvedContainerLowest,
        surfaceContainerLow: tokens.resolvedContainerLow,
        surfaceContainer: tokens.resolvedContainer,
        surfaceContainerHigh: tokens.resolvedContainerHigh,
        surfaceContainerHighest: tokens.resolvedContainerHighest,
        outline: border,
        outlineVariant: tokens.resolvedBorderSubtle,
        inverseSurface: const Color(0xFFE1E2E8),
        onInverseSurface: const Color(0xFF0C0E14),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: _sageTextTheme(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.resolvedContainerLow,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Oswald',
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: tokens.resolvedContainerLow,
        elevation: 0,
        indicatorColor: accentColor.withValues(alpha: 0.22),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accentColor, size: 24);
          }
          return IconThemeData(color: textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            );
          }
          return TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: onAccentColor,
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
          side: BorderSide(color: border, width: 1.2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: border, width: 1.0),
        backgroundColor: tokens.resolvedContainerLow,
        selectedColor: tokens.resolvedAccentContainer,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        modalBackgroundColor: cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.resolvedContainerLow,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: tokens.ink3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentColor, width: 2.0),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.resolvedBorderSubtle,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.surface2,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1.2),
        ),
        elevation: 6,
      ),
      extensions: [tokens],
    );
  }

  static ThemeData get lightTheme => light();
  static ThemeData get darkTheme => dark();
}

/// Oswald display headings + system body text, shared by light and dark.
TextTheme _sageTextTheme(Color primary, Color secondary) {
  const display = 'Oswald';
  return TextTheme(
    displayLarge: TextStyle(fontFamily: display, color: primary, fontSize: 40, fontWeight: FontWeight.w700, height: 1.05),
    displayMedium: TextStyle(fontFamily: display, color: primary, fontSize: 34, fontWeight: FontWeight.w700, height: 1.05),
    displaySmall: TextStyle(fontFamily: display, color: primary, fontSize: 28, fontWeight: FontWeight.w600, height: 1.1),
    headlineLarge: TextStyle(fontFamily: display, color: primary, fontSize: 26, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontFamily: display, color: primary, fontSize: 22, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontFamily: display, color: primary, fontSize: 20, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w700),
    titleSmall: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.w500),
    bodySmall: TextStyle(color: secondary, fontSize: 12, fontWeight: FontWeight.w500),
    labelLarge: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(color: secondary, fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(color: secondary, fontSize: 11, fontWeight: FontWeight.w600),
  );
}

/// Dynamic Theme-Aware Context Color Helper.
/// Allows widgets to dynamically query colors for light vs dark mode.
class AppColors {
  final BuildContext context;
  final bool isDark;

  AppColors(this.context) : isDark = Theme.of(context).brightness == Brightness.dark;

  // Material 3 Expressive Tonal Hierarchy
  Color get bg => context.tokens.bg;
  Color get cardBg => context.tokens.surface;
  Color get tileBg => context.tokens.resolvedContainerHigh;
  Color get border => context.tokens.border;
  Color get borderSubtle => context.tokens.resolvedBorderSubtle;

  Color get containerLowest => context.tokens.resolvedContainerLowest;
  Color get containerLow => context.tokens.resolvedContainerLow;
  Color get container => context.tokens.resolvedContainer;
  Color get containerHigh => context.tokens.resolvedContainerHigh;
  Color get containerHighest => context.tokens.resolvedContainerHighest;

  Color get textPrimary => context.tokens.ink;
  Color get textSecondary => context.tokens.ink2;
  Color get textMuted => context.tokens.ink3;

  Color get accent => context.tokens.accent;
  Color get onAccent => context.tokens.onAccent;
  Color get accentContainer => context.tokens.resolvedAccentContainer;
  Color get onAccentContainer => context.tokens.resolvedOnAccentContainer;

  // Dual-energy accenting: EV side always follows the user's chosen accent
  // colour (so switching accents in Settings actually changes this), fuel
  // side is the fixed Aurora petrol-orange used everywhere fuel appears.
  Color get evTeal => context.tokens.accent;
  Color get petrolAmber => const Color(0xFFFF8A4C);

  Color get trackBg => isDark ? const Color(0xFF1E232F) : const Color(0xFFE5E8EF);

  // Dock & Control Buttons (M3 Expressive Floating Dock)
  Color get dockBg => isDark
      ? context.tokens.resolvedContainerLow.withValues(alpha: 0.95)
      : Colors.white.withValues(alpha: 0.95);
  Color get dockBtnBg => isDark ? context.tokens.resolvedContainerHigh : const Color(0xFFF1F4F9);
  Color get dockBtnIcon => isDark ? Colors.white : const Color(0xFF191C20);
  Color get dockShadow => isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.08);

  // Studio vehicle stage background
  Gradient get stageFloorGradient => isDark
      ? RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            accent.withValues(alpha: 0.18),
            context.tokens.resolvedContainerLowest,
          ],
        )
      : RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            accent.withValues(alpha: 0.12),
            context.tokens.bg,
          ],
        );

  // Design System Semantic Colors
  Color get surface => cardBg;
  Color get surfaceElevated => tileBg;
  Color get electricCyanSubtle => evTeal.withValues(alpha: 0.14);
  Color get petrolAmberSubtle => petrolAmber.withValues(alpha: 0.14);
  Color get infoBlue => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  Color get infoBlueSubtle => infoBlue.withValues(alpha: 0.14);
  Color get danger => context.tokens.danger;
  Color get dangerSubtle => context.tokens.resolvedDangerContainer;
  Color get success => context.tokens.ok;
  Color get successSubtle => context.tokens.resolvedOkContainer;
  Color get warning => context.tokens.warn;
  Color get warningSubtle => context.tokens.warnContainer;
}

/// Standardized Automotive Design System Tokens (Material 3 Expressive Scale)
class AppDesignTokens {
  // Spacing Scale
  static const double spaceXxs = 4.0;
  static const double spaceXs = 8.0;
  static const double spaceSm = 12.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 20.0;
  static const double spaceXl = 24.0;
  static const double spaceXxl = 32.0;

  // Corner Radii (M3 Expressive: 20-28dp squircle cards, 999dp pills)
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusCard = 20.0;
  static const double radiusSheet = 28.0;
  static const double radiusPill = 999.0;
  static const double radius2Xl = 28.0;
  static const double radiusFull = 999.0;

  // Touch Target Minimums
  static const double minTouchTarget = 48.0; // M3 Accessible touch target
  static const double buttonHeight = 48.0;

  // Standard Border Width
  static const double borderWidth = 1.0;
}
