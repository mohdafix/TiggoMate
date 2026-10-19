import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Theme Controller for managing Light (Tesla), Dark (Obsidian), and System themes.
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

/// Unified Theme Definition for TiggoMate.
/// Features:
/// 1. Obsidian Dark Mode: High-contrast cyberpunk PHEV cockpit (#090D12).
/// 2. Tesla Light Mode: Pure minimalist white/off-white studio aesthetic (#F7F8FA).
class AppTheme {
  // Common Accents
  static const Color evTealDark = Color(0xFF00D2AA);
  static const Color evTealLight = Color(0xFF00A389);
  static const Color petrolAmberDark = Color(0xFFFF9F1C);
  static const Color petrolAmberLight = Color(0xFFD97706);

  /// Tesla-Style Light Theme
  static ThemeData get lightTheme {
    const bg = Color(0xFFF7F8FA);
    const cardBg = Color(0xFFFFFFFF);
    const border = Color(0xFFE5E7EB);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF111827),
        secondary: evTealLight,
        surface: cardBg,
        onSurface: textPrimary,
        inverseSurface: Color(0xFF111827),
        onInverseSurface: Colors.white,
        error: Color(0xFFDC2626),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg,
        indicatorColor: const Color(0xFF111827).withValues(alpha: 0.08),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF111827));
          }
          return const IconThemeData(color: textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.normal,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        modalBackgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        contentTextStyle: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        elevation: 6,
      ),
    );
  }

  /// Obsidian Dark Theme
  static ThemeData get darkTheme {
    const bg = Color(0xFF090D12);
    const cardBg = Color(0xFF131922);
    const border = Color(0xFF232D3D);
    const textPrimary = Colors.white;
    const textSecondary = Colors.white70;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: evTealDark,
        secondary: Color(0xFF2F81F7),
        surface: cardBg,
        onSurface: textPrimary,
        inverseSurface: Color(0xFF161E2E),
        onInverseSurface: Colors.white,
        error: Color(0xFFF85149),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1117),
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0D1117),
        indicatorColor: evTealDark.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: evTealDark);
          }
          return const IconThemeData(color: Colors.white60);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: evTealDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.normal,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        modalBackgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0D1117),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: evTealDark, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF161E2E),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF2D3A4F), width: 1.2),
        ),
        elevation: 6,
      ),
    );
  }
}

/// Dynamic Theme-Aware Context Color Helper.
/// Allows widgets to dynamically query colors for light vs dark mode.
class AppColors {
  final BuildContext context;
  final bool isDark;

  AppColors(this.context) : isDark = Theme.of(context).brightness == Brightness.dark;

  Color get bg => isDark ? const Color(0xFF090D12) : const Color(0xFFF7F8FA);
  Color get cardBg => isDark ? const Color(0xFF0D1219) : Colors.white;
  Color get tileBg => isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6);
  Color get border => isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB);
  
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF111827);
  Color get textSecondary => isDark ? Colors.white70 : const Color(0xFF4B5563);
  Color get textMuted => isDark ? Colors.white38 : const Color(0xFF9CA3AF);

  Color get evTeal => isDark ? AppTheme.evTealDark : AppTheme.evTealLight;
  Color get petrolAmber => isDark ? AppTheme.petrolAmberDark : AppTheme.petrolAmberLight;

  Color get trackBg => isDark ? const Color(0xFF1E2837) : const Color(0xFFE5E7EB);
  
  // Dock & Control Buttons (Tesla style in light mode)
  Color get dockBg => isDark ? const Color(0xFF131922).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95);
  Color get dockBtnBg => isDark ? const Color(0xFF1C2433) : const Color(0xFFF3F4F6);
  Color get dockBtnIcon => isDark ? Colors.white : const Color(0xFF1F2937);
  Color get dockShadow => isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.08);

  // Studio vehicle stage background
  Gradient get stageFloorGradient => isDark
      ? RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            const Color(0xFF142030).withValues(alpha: 0.4),
            const Color(0xFF090D12),
          ],
        )
      : RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            const Color(0xFFF7F8FA),
          ],
        );

  // Design System Semantic Colors
  Color get surface => cardBg;
  Color get surfaceElevated => tileBg;
  Color get borderSubtle => isDark ? const Color(0xFF18202D) : const Color(0xFFEDF2F7);
  Color get electricCyanSubtle => evTeal.withValues(alpha: 0.12);
  Color get petrolAmberSubtle => petrolAmber.withValues(alpha: 0.12);
  Color get infoBlue => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  Color get infoBlueSubtle => infoBlue.withValues(alpha: 0.12);
  Color get danger => isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  Color get dangerSubtle => danger.withValues(alpha: 0.12);
  Color get success => isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
  Color get successSubtle => success.withValues(alpha: 0.12);
}

/// Standardized Automotive Design System Tokens
class AppDesignTokens {
  // Spacing Scale
  static const double spaceXxs = 4.0;
  static const double spaceXs = 8.0;
  static const double spaceSm = 12.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 20.0;
  static const double spaceXl = 24.0;
  static const double spaceXxl = 32.0;

  // Corner Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusCard = 16.0;
  static const double radiusSheet = 24.0;
  static const double radiusPill = 20.0;

  // Touch Target Minimums
  static const double minTouchTarget = 44.0;
  static const double buttonHeight = 48.0;

  // Standard Border Width
  static const double borderWidth = 1.0;
}

