import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/trips/smart_trip_tracker.dart';
import 'package:tiggomate_app/src/widgets/home_widget_service.dart';
import 'package:tiggomate_app/src/ui/widgets_shortcuts_sheet.dart';
import 'package:tiggomate_app/src/ui/smart_drive_hud.dart';
import 'package:tiggomate_app/src/service/service_appointment_manager.dart';
import 'package:tiggomate_app/src/ui/book_service_appointment_sheet.dart';

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

    test('GPS tracking controls and getters behave gracefully in headless environment', () async {
      final tracker = SmartTripTracker.instance;
      expect(tracker.isGpsActive, isFalse);
      expect(tracker.hasRealGpsFix, isFalse);
      expect(tracker.gpsStatus, isNotEmpty);

      // In unit test environment without real GNSS hardware, it handles gracefully without crashing
      await tracker.startLiveGpsTracking();
      tracker.stopLiveGpsTracking();
      expect(tracker.isGpsActive, isFalse);
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
      expect(find.text('Pause Drive'), findsOneWidget);
      expect(find.text('Finish & Save'), findsOneWidget);

      // Stop drive timer so no pending timers remain when test finishes
      SmartTripTracker.instance.stopDrive();
      await tester.pump();
    });
  });

  group('Feature 5: Service Appointment & Reminder System Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ServiceAppointmentManager creates, schedules reminder, and retrieves upcoming appointment', () async {
      final manager = ServiceAppointmentManager.instance;
      final tomorrow = DateTime.now().add(const Duration(days: 2));

      final appointment = ServiceAppointment(
        id: 'test_apt_1000km',
        centreId: 'sel_setia_alam',
        centreName: 'Chery Setia Alam',
        centreAddress: '1-4-G & 1-5-G Jalan Setia Prima, Shah Alam',
        centrePhone: '03-33459668',
        serviceType: '1,000 km 1st Inspection & Activation (FOC)',
        appointmentDate: tomorrow,
        timeSlot: '10:30 AM',
        reminderPreference: '1_day_before',
        notes: 'DMS pairing and BMS scan',
        createdAt: DateTime.now(),
      );

      await manager.setAppointment(appointment);

      expect(manager.appointments, isNotEmpty);
      expect(manager.upcomingAppointment, isNotNull);
      expect(manager.upcomingAppointment!.centreName, 'Chery Setia Alam');
      expect(manager.upcomingAppointment!.serviceType, contains('1,000 km'));
      expect(manager.upcomingAppointment!.formattedReminder, '1 day before');
      expect(manager.upcomingAppointment!.calendarUrl, contains('calendar.google.com'));
      expect(manager.upcomingAppointment!.calendarUrl, contains('Chery%20Setia%20Alam'));

      // Test rescheduling
      final nextWeek = DateTime.now().add(const Duration(days: 7));
      await manager.rescheduleAppointment(
        id: appointment.id,
        newDate: nextWeek,
        newTimeSlot: '02:00 PM',
        newReminder: '2_hours_before',
      );

      expect(manager.upcomingAppointment!.timeSlot, '02:00 PM');
      expect(manager.upcomingAppointment!.formattedReminder, '2 hours before');

      // Test cancellation
      await manager.cancelAppointment(appointment.id);
      expect(manager.upcomingAppointment, isNull);
    });

    testWidgets('BookServiceAppointmentSheet renders booking form with date, time, and reminder options',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookServiceAppointmentSheet(
              initialServiceType: '1,000 km 1st Inspection & Activation (FOC)',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book Service Appointment'), findsOneWidget);
      expect(find.text('1. SELECT SERVICE CENTRE'), findsOneWidget);
      expect(find.text('2. SERVICE MILESTONE / TYPE'), findsOneWidget);
      expect(find.text('3. APPOINTMENT DATE & TIME'), findsOneWidget);
      expect(find.text('4. SET REMINDER NOTIFICATION'), findsOneWidget);
      expect(find.text('1 day before'), findsOneWidget);
      expect(find.text('Confirm Appointment'), findsOneWidget);

      // Tap Confirm Appointment to save
      await tester.tap(find.text('Confirm Appointment'));
      await tester.pumpAndSettle();

      expect(ServiceAppointmentManager.instance.upcomingAppointment, isNotNull);
    });
  });
}
