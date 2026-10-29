import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/firebase/firebase_sync_service.dart';
import 'package:tiggomate_app/src/service/service_appointment_manager.dart';
import 'package:tiggomate_app/src/ui/settings_screen.dart';
import 'package:tiggomate_app/src/ui/trips_logbook_screen.dart';
import 'package:tiggomate_app/src/ui/app_notification.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseSyncService Unit & Offline Fallback Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('FirebaseSyncService singleton returns non-null instance', () {
      final service = FirebaseSyncService.instance;
      expect(service, isNotNull);
    });

    test('Gracefully handles uninitialized Firebase environment without crashing', () async {
      final service = FirebaseSyncService.instance;
      
      // In headless test without Firebase.initializeApp(), availability returns false
      expect(service.isFirebaseAvailable, isFalse);
      
      // Fetch operations return empty lists / null without throwing
      final apts = await service.fetchAppointments();
      expect(apts, isEmpty);

      final trips = await service.fetchTrips();
      expect(trips, isEmpty);

      final expenses = await service.fetchExpenses();
      expect(expenses, isEmpty);

      final settings = await service.fetchSettings();
      expect(settings, isNull);

      final alerts = await service.fetchAlerts();
      expect(alerts, isEmpty);
    });

    test('Sync operations execute safely and complete in headless/offline mode', () async {
      final service = FirebaseSyncService.instance;

      final testAppointment = ServiceAppointment(
        id: 'sync_apt_01',
        centreId: 'kl_segambut',
        centreName: 'Chery Segambut',
        centreAddress: 'Jalan Segambut, Kuala Lumpur',
        centrePhone: '03-62578899',
        serviceType: '1,000 km 1st Inspection',
        appointmentDate: DateTime.now().add(const Duration(days: 3)),
        timeSlot: '11:00 AM',
        reminderPreference: '1_day_before',
        notes: 'First vehicle health check',
        createdAt: DateTime.now(),
      );

      final testTrip = TripRecord(
        id: 'sync_trip_01',
        title: 'Cyberjaya Live Test',
        timestamp: DateTime.now().toIso8601String(),
        distanceKm: 28.5,
        durationMinutes: 32,
        evDistanceKm: 22.0,
        hevDistanceKm: 6.5,
        electricKwh: 4.2,
        petrolLitres: 0.4,
        costRm: 3.12,
        avgSpeedKmh: 53.4,
        highwayNote: 'Live GNSS • 77% EV Split',
        routePoints: const [Offset(0.2, 0.3), Offset(0.4, 0.6)],
        evPointCount: 15,
      );

      final testExpense = ExpenseRecord(
        id: 'sync_exp_01',
        type: 'public_ev',
        title: 'Shell Recharge DC fast charging',
        date: DateTime.now().toIso8601String(),
        amountRm: 24.50,
        units: 20.0,
        unitPrice: 1.225,
      );

      final testSettings = AppSettings(
        ownerName: 'Afix',
        carPlateNumber: 'CEY 777',
        vehicleNickname: 'CSH Tiggo',
        aiApiKey: '',
        aiModel: 'gemini-1.5-flash',
        aiHost: '',
        aiProvider: 'Google Gemini',
        carLinkoStatus: 'Active',
        tnbTariff: 0.571,
        fuelPrice: 2.05,
        vehicleSkinKey: 'carbon_black',
      );

      final testAlert = VehicleAlertItem(
        id: 'sync_alert_01',
        title: 'Service Due Soon',
        message: '1,000 km initial check due',
        timestamp: DateTime.now(),
        type: NotificationType.info,
        icon: Icons.calendar_today_outlined,
      );

      // Verify all sync triggers run without uncaught exceptions in offline mode
      await expectLater(service.syncAppointment(testAppointment), completes);
      await expectLater(service.syncTrip(testTrip), completes);
      await expectLater(service.syncExpense(testExpense), completes);
      await expectLater(service.syncSettings(testSettings), completes);
      await expectLater(service.syncAlert(testAlert), completes);
      await expectLater(service.deleteAppointment('sync_apt_01'), completes);
    });
  });
}
