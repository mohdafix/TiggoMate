import 'package:flutter/material.dart';
import 'accent.dart';

/// Semantic colour tokens shared across the app (DashMate design system).
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
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color ok;

  static const light = AppTokens(
    bg: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    ink: Color(0xFF0F172A),
    ink2: Color(0xFF475569),
    ink3: Color(0xFF64748B),
    accent: Color(0xFF0F766E),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
    ok: Color(0xFF15803D),
  );

  static const dark = AppTokens(
    bg: Color(0xFF0A0B0E),
    surface: Color(0xFF12141A),
    surface2: Color(0xFF1A1D24),
    border: Color(0xFF1E222B),
    ink: Color(0xFFF1F5F9),
    ink2: Color(0xFFA3ACB9),
    ink3: Color(0xFF717684),
    accent: Color(0xFFD2F835),
    onAccent: Color(0xFF0A0B0E),
    danger: Color(0xFFF87171),
    ok: Color(0xFFD2F835),
  );

  bool get isDark => bg.computeLuminance() < 0.5;

  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 4)),
        ];

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? ok,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      ok: ok ?? this.ok,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surface2: Color.lerp(surface2, other.surface2, t) ?? surface2,
      border: Color.lerp(border, other.border, t) ?? border,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      ink2: Color.lerp(ink2, other.ink2, t) ?? ink2,
      ink3: Color.lerp(ink3, other.ink3, t) ?? ink3,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      onAccent: Color.lerp(onAccent, other.onAccent, t) ?? onAccent,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      ok: Color.lerp(ok, other.ok, t) ?? ok,
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
