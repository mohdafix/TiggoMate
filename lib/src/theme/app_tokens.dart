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

  // "Kinetic Volt" light palette: soft off-white matte background, pure
  // white cards with hairline borders, electric chartreuse (#E8F40C)
  // primary accent with dark ink text on top. Pill-shaped buttons/chips,
  // 28-32px card radii. Source: Stitch design export (cockpit_hud_kinetic_light).
  static const light = AppTokens(
    bg: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F4F6),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF3F4F6),
    surfaceContainer: Color(0xFFEDEEF0),
    surfaceContainerHigh: Color(0xFFE7E8EA),
    surfaceContainerHighest: Color(0xFFE1E2E4),
    border: Color(0xFFECEEF1),
    borderSubtle: Color(0xFFF0F1F3),
    ink: Color(0xFF191C1E),
    ink2: Color(0xFF474832),
    ink3: Color(0xFF787960),
    accent: Color(0xFFE8F40C),
    onAccent: Color(0xFF111111),
    accentContainer: Color(0xFFF3F999),
    onAccentContainer: Color(0xFF686E00),
    danger: Color(0xFFBA1A1A),
    dangerContainer: Color(0xFFFFDAD6),
    warn: Color(0xFFC27A12),
    onWarn: Color(0xFFFFFFFF),
    warnContainer: Color(0xFFF6E6C8),
    ok: Color(0xFF006E2F),
    okContainer: Color(0xFF9FFFAD),
  );

  // "Obsidian Telemetry" dark palette: true-black AMOLED canvas, dark
  // telemetry card surfaces, neon volt-green primary accent with glow
  // effects, dedicated cyan reserved for climate state. Monospace
  // (Space Mono) readouts for live numeric telemetry. Source: Stitch
  // design export (vehicle_status_cockpit_hud_haptic_sound_cues).
  static const dark = AppTokens(
    bg: Color(0xFF000000),
    surface: Color(0xFF0D0E12),
    surface2: Color(0xFF14161D),
    surfaceContainerLowest: Color(0xFF000000),
    surfaceContainerLow: Color(0xFF0D0E12),
    surfaceContainer: Color(0xFF14161D),
    surfaceContainerHigh: Color(0xFF1A1D27),
    surfaceContainerHighest: Color(0xFF222530),
    border: Color(0xFF222530),
    borderSubtle: Color(0xFF181A22),
    ink: Color(0xFFFFFFFF),
    ink2: Color(0xFF8F96A8),
    ink3: Color(0xFF5B6175),
    accent: Color(0xFFD2F835),
    onAccent: Color(0xFF000000),
    accentContainer: Color(0x1FD2F835),
    onAccentContainer: Color(0xFFD2F835),
    danger: Color(0xFFFF4D4D),
    dangerContainer: Color(0x1AFF4D4D),
    warn: Color(0xFF25E2D9),
    onWarn: Color(0xFF00201E),
    warnContainer: Color(0x1F25E2D9),
    ok: Color(0xFF22C55E),
    okContainer: Color(0x1F22C55E),
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
