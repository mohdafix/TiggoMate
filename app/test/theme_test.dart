import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme & AppThemeController Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default system theme', () async {
      final ctrl = AppThemeController.instance;
      await ctrl.init();
      expect(ctrl.themeMode, equals(ThemeMode.system));
    });

    test('Can switch to Tesla Light mode and persist', () async {
      final ctrl = AppThemeController.instance;
      await ctrl.setThemeMode(ThemeMode.light);
      expect(ctrl.themeMode, equals(ThemeMode.light));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tm_app_theme_mode'), equals('light'));
    });

    test('Can switch to Obsidian Dark mode and persist', () async {
      final ctrl = AppThemeController.instance;
      await ctrl.setThemeMode(ThemeMode.dark);
      expect(ctrl.themeMode, equals(ThemeMode.dark));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tm_app_theme_mode'), equals('dark'));
    });

    test('Light theme creates valid ThemeData with Brightness.light', () {
      final light = AppTheme.lightTheme;
      expect(light.brightness, equals(Brightness.light));
      expect(light.scaffoldBackgroundColor, equals(const Color(0xFFF7F8FA)));
      expect(light.colorScheme.surface, equals(const Color(0xFFFFFFFF)));
    });

    test('Dark theme creates valid ThemeData with Brightness.dark', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.scaffoldBackgroundColor, equals(const Color(0xFF090D12)));
      expect(dark.colorScheme.surface, equals(const Color(0xFF131922)));
    });
  });
}
