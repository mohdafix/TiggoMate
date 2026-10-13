import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate/core/constants/app_theme.dart';
import 'package:tiggomate/core/providers/app_providers.dart';
import 'package:tiggomate/core/router/app_router.dart';
import 'package:tiggomate/data/datasources/local_storage_datasource.dart';

void main() {
  testWidgets(
    'TiggoMate launches and renders Home screen with honest empty states',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localStorage = LocalStorageDataSource(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageProvider.overrideWithValue(localStorage)],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: appRouter,
          ),
        ),
      );

      // Pump frames to complete async routing and initial microtasks
      await tester.pumpAndSettle();

      // Verify app bar vehicle nickname is rendered
      expect(find.text('Tiggo 7 CSH'), findsOneWidget);

      // Verify honest disconnected banner
      expect(find.text('CARLINKO: NOT ACTIVATED'), findsOneWidget);

      // Verify honest empty state for battery/fuel
      expect(find.text('Live Readings Unavailable'), findsOneWidget);

      // Verify quick action tiles
      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.text('Record Odo'), findsOneWidget);
      expect(find.text('Add Fuel'), findsOneWidget);
      expect(find.text('Add Charge'), findsOneWidget);

      // Verify 4 main navigation destinations in persistent bottom bar
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('My Car'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
    },
  );

  testWidgets('TiggoMate bottom navigation switches between tabs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final localStorage = LocalStorageDataSource(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageProvider.overrideWithValue(localStorage)],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: appRouter,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap 'AI Assistant' navigation destination
    await tester.tap(find.text('AI Assistant'));
    await tester.pumpAndSettle();
    expect(find.text('TiggoMate AI'), findsOneWidget);

    // Tap 'My Car' navigation destination
    await tester.tap(find.text('My Car'));
    await tester.pumpAndSettle();
    expect(find.text('CONNECTIVITY & TELEMATICS'), findsOneWidget);

    // Tap 'Maintenance' navigation destination
    await tester.tap(find.text('Maintenance'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance & Service'), findsOneWidget);
  });
}
