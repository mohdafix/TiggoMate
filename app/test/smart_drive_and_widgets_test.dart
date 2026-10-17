import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/trips/smart_trip_tracker.dart';
import 'package:tiggomate_app/src/widgets/home_widget_service.dart';
import 'package:tiggomate_app/src/ui/widgets_shortcuts_sheet.dart';
import 'package:tiggomate_app/src/ui/smart_drive_hud.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 2: SmartTripTracker Powertrain & Offline Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial tracker state is idle', () {
      final tracker = SmartTripTracker.instance;
      expect(tracker.isTracking, isFalse);
      expect(tracker.totalDistanceKm, 0.0);
    });

    test('Start, record points, and classify EV vs HEV hybrid powertrain', () {
      final tracker = SmartTripTracker.instance;
      tracker.startDrive(title: 'Test Bangsar to MEX');

      expect(tracker.isTracking, isTrue);

      // Low speed pure EV point (< 70 km/h)
      tracker.recordPoint(
        x: 0.20,
        y: 0.25,
        speedKmh: 45.0,
      );

      expect(tracker.currentSpeedKmh, 45.0);
      expect(tracker.currentSpeedKmh <= 70.0, isTrue);

      // Highway overtaking speed triggering 1.5T DHT petrol engine (> 70 km/h)
      tracker.recordPoint(
        x: 0.35,
        y: 0.40,
        speedKmh: 95.0,
      );

      expect(tracker.currentSpeedKmh, 95.0);
      expect(tracker.currentSpeedKmh > 70.0, isTrue);
    });

    test('Finish trip and verify cost calculation & offline persistence', () async {
      final tracker = SmartTripTracker.instance;
      tracker.startDrive(
        title: 'Putrajaya Sentral Commute',
        tnbTariff: 0.571,
        fuelPrice: 2.05,
      );

      tracker.recordPoint(x: 0.20, y: 0.25, speedKmh: 50.0);
      tracker.recordPoint(x: 0.45, y: 0.55, speedKmh: 92.0);

      final tripRecord = await tracker.finishAndSaveTrip(
        title: 'Putrajaya Sentral Commute',
        highwayNote: 'Klang Valley Expressway (MEX)',
      );

      expect(tripRecord.title, 'Putrajaya Sentral Commute');
      expect(tripRecord.highwayNote, 'Klang Valley Expressway (MEX)');
      expect(tripRecord.routePoints, isNotEmpty);
      expect(tripRecord.costRm, isNonNegative);

      // Verify saved into SharedPreferences tm_logged_trips_v2
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('tm_logged_trips_v2');
      expect(stored, isNotNull);
      expect(stored!.contains('Putrajaya Sentral Commute'), isTrue);
    });
  });

  group('Feature 4: Android Widgets & Shortcuts Integration Tests', () {
    test('HomeWidgetService initializes and handles quick action stream', () async {
      final service = HomeWidgetService.instance;
      service.init();

      expect(service.onQuickAction, isNotNull);
    });

    testWidgets('WidgetsShortcutsSheet renders widget preview and launcher shortcuts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: WidgetsShortcutsSheet(
              batterySoc: 78,
              batteryRange: 95,
              fuelLevel: 82,
              fuelRange: 870,
              totalRange: 965,
              isLocked: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check Header and Widget Preview
      expect(find.text('Widgets & Quick Actions'), findsOneWidget);
      expect(find.text('HOME SCREEN WIDGET PREVIEW (4×2)'), findsOneWidget);
      expect(find.text('78%'), findsOneWidget);
      expect(find.text('95 km EV'), findsOneWidget);
      expect(find.text('965 km'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);

      // Check Widget Action Buttons
      expect(find.text('🔓 Unlock'), findsOneWidget);
      expect(find.text('❄️ 22°C'), findsOneWidget);
      expect(find.text('⚡ Charge'), findsOneWidget);
      expect(find.text('🚗 HUD'), findsOneWidget);

      // Check Static Shortcuts List
      expect(find.text('APP LAUNCHER SHORTCUTS (LONG-PRESS ICON)'), findsOneWidget);
      expect(find.text('Unlock Vehicle'), findsOneWidget);
      expect(find.text('Pre-cool Cabin (22.0°C)'), findsOneWidget);
      expect(find.text('Smart Charging Optimizer'), findsOneWidget);
      expect(find.text('Find My Car (Radar HUD)'), findsOneWidget);
      expect(find.text('Drive Mode HUD'), findsOneWidget);
    });

    testWidgets('SmartDriveHudSheet renders digital speedometer and cockpit HUD',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        SmartTripTracker.instance.stopDrive();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartDriveHudSheet(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check HUD Cockpit Elements
      expect(find.text('Smart Drive HUD'), findsOneWidget);
      expect(find.text('KM / H'), findsOneWidget);
      expect(find.text('EV Path'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('TRIP COST'), findsOneWidget);
      expect(find.text('Test Drive'), findsOneWidget);
      expect(find.text('Finish & Save'), findsOneWidget);

      // Stop drive timer so no pending timers remain when test finishes
      SmartTripTracker.instance.stopDrive();
      await tester.pump();
    });
  });
}
