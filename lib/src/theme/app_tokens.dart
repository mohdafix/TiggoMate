import 'package:flutter/material.dart';
import 'accent.dart';

/// Material 3 Expressive semantic tokens shared across TiggoMate.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.ok,
    this.surfaceContainerLowest,
    this.surfaceContainerLow,
    this.surfaceContainer,
    this.surfaceContainerHigh,
    this.surfaceContainerHighest,
    this.borderSubtle,
    this.warn = const Color(0xFFD97706),
    this.onWarn = Colors.white,
    this.warnContainer = const Color(0xFFFEF3C7),
    this.accentContainer,
    this.onAccentContainer,
    this.dangerContainer,
    this.okContainer,
  });

  // Base Surfaces
  final Color bg;
  final Color surface;
  final Color surface2;

  // Material 3 Expressive Tonal Container Scales
  final Color? surfaceContainerLowest;
  final Color? surfaceContainerLow;
  final Color? surfaceContainer;
  final Color? surfaceContainerHigh;
  final Color? surfaceContainerHighest;

  // Outlines
  final Color border;
  final Color? borderSubtle;

  // Typographic Inks (Contrast-Verified)
  final Color ink;
  final Color ink2;
  final Color ink3;

  // Semantic Primary & Feedback
  final Color accent;
  final Color onAccent;
  final Color? accentContainer;
  final Color? onAccentContainer;

  final Color danger;
  final Color? dangerContainer;

  final Color ok;
  final Color? okContainer;

  final Color warn;
  final Color onWarn;
  final Color warnContainer;

  // Resolved M3 Container Getters
  Color get resolvedContainerLowest => surfaceContainerLowest ?? bg;
  Color get resolvedContainerLow => surfaceContainerLow ?? (isDark ? const Color(0xFF11141B) : const Color(0xFFF5F7FA));
  Color get resolvedContainer => surfaceContainer ?? surface;
  Color get resolvedContainerHigh => surfaceContainerHigh ?? surface2;
  Color get resolvedContainerHighest => surfaceContainerHighest ?? (isDark ? const Color(0xFF262C3A) : const Color(0xFFDDE1E9));
  Color get resolvedBorderSubtle => borderSubtle ?? (isDark ? const Color(0xFF1C212B) : const Color(0xFFE9EDF4));
  Color get resolvedAccentContainer => accentContainer ?? accent.withValues(alpha: isDark ? 0.22 : 0.15);
  Color get resolvedOnAccentContainer => onAccentContainer ?? (isDark ? accent : accent);
  Color get resolvedDangerContainer => dangerContainer ?? danger.withValues(alpha: isDark ? 0.22 : 0.12);
  Color get resolvedOkContainer => okContainer ?? ok.withValues(alpha: isDark ? 0.22 : 0.12);

  // Material 3 Expressive Corner Radii Scale
  static const double rXs = 4.0;
  static const double rSm = 8.0;
  static const double rMd = 12.0;
  static const double rLg = 16.0;
  static const double rXl = 24.0;
  static const double r2Xl = 28.0; // M3 Expressive signature squircle card & sheet
  static const double rFull = 999.0; // M3 Expressive signature pill

  // Interaction State Overlays (Material 3 State Layer Specs)
  Color get pressedOverlay => (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);
  Color get hoverOverlay => (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
  Color get focusRing => accent;

  static const light = AppTokens(
    bg: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F4F9),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F7FA),
    surfaceContainer: Color(0xFFECEEF4),
    surfaceContainerHigh: Color(0xFFE5E8EF),
    surfaceContainerHighest: Color(0xFFDDE1E9),
    border: Color(0xFFD8DDE6),
    borderSubtle: Color(0xFFE9EDF4),
    ink: Color(0xFF191C20),
    ink2: Color(0xFF43474E),
    ink3: Color(0xFF74777F),
    accent: Color(0xFF0F766E),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFCCFBF1),
    onAccentContainer: Color(0xFF115E59),
    danger: Color(0xFFBA1A1A),
    dangerContainer: Color(0xFFFFDAD6),
    warn: Color(0xFFD97706),
    onWarn: Color(0xFFFFFFFF),
    warnContainer: Color(0xFFFEF3C7),
    ok: Color(0xFF15803D),
    okContainer: Color(0xFFDCFCE7),
  );

  // "Aurora Cockpit" dark palette: one card surface step (surface2/elevated
  // is used sparingly), a softened lime accent, and a dedicated cyan used
  // only for climate so it never collides with the lime EV accent.
  static const dark = AppTokens(
    bg: Color(0xFF090A0D),
    surface: Color(0xFF121419),
    surface2: Color(0xFF1A1D25),
    surfaceContainerLowest: Color(0xFF060709),
    surfaceContainerLow: Color(0xFF121419),
    surfaceContainer: Color(0xFF161922),
    surfaceContainerHigh: Color(0xFF1A1D25),
    surfaceContainerHighest: Color(0xFF242837),
    border: Color(0xFF23262F),
    borderSubtle: Color(0xFF1A1C23),
    ink: Color(0xFFF1F3F8),
    ink2: Color(0xFFA5ADC0),
    ink3: Color(0xFF7B8296),
    accent: Color(0xFFC8FF4D),
    onAccent: Color(0xFF0A0B0E),
    accentContainer: Color(0xFF2B3600),
    onAccentContainer: Color(0xFFE2FFA0),
    danger: Color(0xFFFF5C5C),
    dangerContainer: Color(0xFF5A1414),
    warn: Color(0xFFFFC861),
    onWarn: Color(0xFF1F1500),
    warnContainer: Color(0xFF4A3400),
    ok: Color(0xFF4ADE80),
    okContainer: Color(0xFF0F3E1E),
  );

  bool get isDark => bg.computeLuminance() < 0.5;

  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 6)),
        ];

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surfaceContainerLowest,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? border,
    Color? borderSubtle,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
    Color? danger,
    Color? dangerContainer,
    Color? ok,
    Color? okContainer,
    Color? warn,
    Color? onWarn,
    Color? warnContainer,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surfaceContainerLowest: surfaceContainerLowest ?? this.surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccentContainer: onAccentContainer ?? this.onAccentContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      ok: ok ?? this.ok,
      okContainer: okContainer ?? this.okContainer,
      warn: warn ?? this.warn,
      onWarn: onWarn ?? this.onWarn,
      warnContainer: warnContainer ?? this.warnContainer,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surface2: Color.lerp(surface2, other.surface2, t) ?? surface2,
      surfaceContainerLowest: Color.lerp(surfaceContainerLowest, other.surfaceContainerLowest, t) ?? surfaceContainerLowest,
      surfaceContainerLow: Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t) ?? surfaceContainerLow,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t) ?? surfaceContainer,
      surfaceContainerHigh: Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t) ?? surfaceContainerHigh,
      surfaceContainerHighest: Color.lerp(surfaceContainerHighest, other.surfaceContainerHighest, t) ?? surfaceContainerHighest,
      border: Color.lerp(border, other.border, t) ?? border,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      ink2: Color.lerp(ink2, other.ink2, t) ?? ink2,
      ink3: Color.lerp(ink3, other.ink3, t) ?? ink3,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      onAccent: Color.lerp(onAccent, other.onAccent, t) ?? onAccent,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t) ?? accentContainer,
      onAccentContainer: Color.lerp(onAccentContainer, other.onAccentContainer, t) ?? onAccentContainer,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t) ?? dangerContainer,
      ok: Color.lerp(ok, other.ok, t) ?? ok,
      okContainer: Color.lerp(okContainer, other.okContainer, t) ?? okContainer,
      warn: Color.lerp(warn, other.warn, t) ?? warn,
      onWarn: Color.lerp(onWarn, other.onWarn, t) ?? onWarn,
      warnContainer: Color.lerp(warnContainer, other.warnContainer, t) ?? warnContainer,
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens {
    final cur = Theme.of(this).extension<AppTokens>();
    final curAccent = Accent.current.value;
    if (cur != null) {
      // Ensure tokens accent matches the current chosen accent
      final dynamicAccent = cur.isDark ? curAccent.night : curAccent.day;
      final dynamicOnAccent = cur.isDark ? curAccent.onNight : curAccent.onDay;
      if (cur.accent != dynamicAccent) {
        return cur.copyWith(accent: dynamicAccent, onAccent: dynamicOnAccent);
      }
      return cur;
    }
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark
        ? AppTokens.dark.copyWith(accent: curAccent.night, onAccent: curAccent.onNight)
        : AppTokens.light.copyWith(accent: curAccent.day, onAccent: curAccent.onDay);
  }
}
