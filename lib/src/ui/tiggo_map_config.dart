import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available map styling options for TiggoMate radar and telemetry dashboards.
enum TiggoMapStyle {
  detailedDark,
  satellite,
  daylight,
}

extension TiggoMapStyleExt on TiggoMapStyle {
  String get label {
    switch (this) {
      case TiggoMapStyle.detailedDark:
        return 'Detailed Dark';
      case TiggoMapStyle.satellite:
        return 'Satellite';
      case TiggoMapStyle.daylight:
        return 'Daylight';
    }
  }

  String get shortLabel {
    switch (this) {
      case TiggoMapStyle.detailedDark:
        return 'Dark';
      case TiggoMapStyle.satellite:
        return 'Sat';
      case TiggoMapStyle.daylight:
        return 'Day';
    }
  }

  IconData get icon {
    switch (this) {
      case TiggoMapStyle.detailedDark:
        return Icons.dark_mode_rounded;
      case TiggoMapStyle.satellite:
        return Icons.satellite_alt_rounded;
      case TiggoMapStyle.daylight:
        return Icons.wb_sunny_rounded;
    }
  }

  String get urlTemplate {
    switch (this) {
      case TiggoMapStyle.detailedDark:
      case TiggoMapStyle.daylight:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case TiggoMapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  /// Refined Equinox automotive dark-mode matrix:
  /// - Full luminance desaturation across all channels (-0.21 R, -0.52 G, -0.08 B)
  ///   so green vegetation and yellow roads don't produce an olive/yellow tint.
  /// - Smoothly transforms daytime white tiles to sleek obsidian-slate (#121622)
  /// - Boosts roads, street labels, and outlines to crisp ice-silver (#CBD5E1)
  static const List<double> darkOsmMatrix = [
    -0.21, -0.52, -0.08, 0.0, 168.0,
    -0.21, -0.52, -0.08, 0.0, 174.0,
    -0.21, -0.52, -0.08, 0.0, 198.0,
     0.0,   0.0,   0.0,  1.0,   0.0,
  ];

  /// Wraps a FlutterMap in the appropriate color filter for this style.
  Widget wrapMap(Widget mapWidget) {
    if (this == TiggoMapStyle.detailedDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(darkOsmMatrix),
        child: mapWidget,
      );
    }
    return mapWidget;
  }
}

/// Global manager for map preferences across dashboard and radar sheets.
class TiggoMapConfig {
  static const String _prefKey = 'tiggomate_preferred_map_style';
  static final ValueNotifier<TiggoMapStyle> activeStyle = ValueNotifier<TiggoMapStyle>(TiggoMapStyle.detailedDark);
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        final match = TiggoMapStyle.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => TiggoMapStyle.detailedDark,
        );
        activeStyle.value = match;
      }
      _initialized = true;
    } catch (_) {}
  }

  static Future<void> setStyle(TiggoMapStyle style) async {
    activeStyle.value = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, style.name);
    } catch (_) {}
  }

  static Future<void> cycleStyle() async {
    final nextIndex = (activeStyle.value.index + 1) % TiggoMapStyle.values.length;
    await setStyle(TiggoMapStyle.values[nextIndex]);
  }
}
