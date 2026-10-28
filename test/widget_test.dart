import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/main.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_repository.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_telemetry.dart';
import 'package:tiggomate_app/src/mytnb/mytnb_api.dart';
import 'package:tiggomate_app/src/theme/app_theme.dart';
import 'package:tiggomate_app/src/ui/neo_dashboard.dart';
import 'package:tiggomate_app/src/ui/trips_logbook_screen.dart';
import 'package:tiggomate_app/src/ui/vehicle_radar_sheet.dart';
import 'package:tiggomate_app/src/ui/smart_charging_sheet.dart';
import 'package:tiggomate_app/src/ui/app_notification.dart';
import 'package:tiggomate_app/src/ui/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'tm_owner_name': 'Ahmad Razak',
      'tm_car_plate': 'VAG 7777',
      'tm_vehicle_nickname': 'Tiggo Grey Wolf',
      'tm_ai_api_key': 'sk-or-testkey123',
      'tm_ai_model': 'openai/gpt-4o-mini',
      'tm_ai_host': 'https://openrouter.ai/api/v1',
      'tm_ai_provider': 'OpenRouter',
      'tm_carlinko_status': 'Connected (Demo Telematics)',
      'tm_tnb_tariff': 0.57,
      'tm_fuel_price': 2.05,
      'tiggomate_has_chosen_auth': true,
      'tiggomate_auth_uid': 'test_user_1',
      'tiggomate_auth_is_guest': false,
      'tiggomate_auth_name': 'Ahmad Razak',
      'tiggomate_auth_plate': 'VAG 7777',
      'tm_has_completed_setup': true,
      'tiggomate_auth_nickname': 'Tiggo Grey Wolf',
    });
  });

  testWidgets('LoginScreen renders on first launch when not authenticated and allows guest entry', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'tiggomate_has_chosen_auth': false,
      'tm_has_completed_setup': true,
    });

    await tester.pumpWidget(const TiggoMateApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('TiggoMate'), findsWidgets);
    expect(find.text('Sign In with Firebase'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue as Guest Driver (Offline Mode)'), findsOneWidget);

    // Ensure visible and tap Continue as Guest
    await tester.ensureVisible(find.text('Continue as Guest Driver (Offline Mode)'));
    await tester.tap(find.text('Continue as Guest Driver (Offline Mode)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Chery Tiggo 7 PHEV CSH'), findsWidgets);
  });

  testWidgets('TiggoMate smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TiggoMateApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tiggo Grey Wolf'), findsWidgets);
    expect(find.textContaining('VAG 7777'), findsWidgets);
    expect(find.textContaining('Ahmad Razak'), findsWidgets);
    expect(find.textContaining('Chery Tiggo 7 PHEV CSH'), findsWidgets);
  });

  testWidgets('MarkdownMessageView renders formatted text without raw markdown markers', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownMessageView(
            content: '### Engine Header\n\n- **Current Battery SOC:** 78%\n> Citation text',
          ),
        ),
      ),
    );

    // Markdown markers should be parsed and removed from raw text
    expect(find.text('### Engine Header'), findsNothing);
    expect(find.text('Engine Header'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Current Battery SOC: 78%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('MaintenanceTab renders official Service Schedule & Pricing Guide with vehicle plate', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MaintenanceTab(
            settings: AppSettings(
              ownerName: 'Ahmad Razak',
              carPlateNumber: 'VAG 7777',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Service Schedule & Pricing'), findsOneWidget);
    expect(find.text('27 Aug 2026 Gazette'), findsOneWidget);
    expect(find.text('Chery Tiggo 7 PHEV CSH • VAG 7777 • Ahmad Razak'), findsOneWidget);
    expect(find.text('COMPULSORY FEE'), findsOneWidget);
    expect(find.text('RECOMMENDED TOTAL'), findsOneWidget);
  });

  testWidgets('SettingsScreen allows editing car plate number and saving', (WidgetTester tester) async {
    AppSettings current = const AppSettings(
      ownerName: 'Ahmad Razak',
      carPlateNumber: 'VAG 7777',
    );
    AppSettings? updated;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: current,
          myTnbRepo: MyTnbRepository(),
          onSave: (s) => updated = s,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings & Profile'), findsOneWidget);
    expect(find.text('VAG 7777'), findsOneWidget);

    // Find TextField for plate number and change it
    final plateField = find.widgetWithText(TextField, 'VAG 7777');
    await tester.enterText(plateField, 'WXY 8888');

    // Tap Save in AppBar
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(updated, isNotNull);
    expect(updated!.carPlateNumber, 'WXY 8888');
  });

  testWidgets('NeoDashboard renders NeoCharge UI with interactive tyre TPMS modal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = MockVehicleRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeoDashboard(
            repository: repo,
            ownerName: 'Ahmad Razak',
            carPlateNumber: 'VAG 7777',
            vehicleNickname: 'Tiggo Grey Wolf',
            tnbTariff: 0.57,
            fuelPrice: 2.05,
            onOpenSettings: () {},
            onOpenAssistant: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tiggo Grey Wolf'), findsOneWidget);
    expect(find.text('Basic Glance'), findsOneWidget);
    expect(find.text('Advanced Telemetry'), findsOneWidget);
    expect(find.text('Vehicle Quick Status'), findsOneWidget);
    expect(find.text('Direct TPMS Tire Pressures'), findsOneWidget);
    expect(find.text('EV RANGE'), findsOneWidget);

    // Verify CarLinko Dual-Energy glance banner
    expect(find.text('78% EV'), findsOneWidget);
    expect(find.text('82% Fuel'), findsOneWidget);
    expect(find.text('TOTAL RANGE'), findsOneWidget);

    // Verify CarLinko circular remote deck
    expect(find.text('Doors'), findsOneWidget);
    expect(find.text('Climate'), findsOneWidget);
    expect(find.text('Windows'), findsOneWidget);
    expect(find.text('Trunk'), findsOneWidget);
    expect(find.text('Locate'), findsOneWidget);

    // Test tapping Doors remote button
    await tester.tap(find.text('Doors'));
    await tester.pump();
    expect(find.text('Unlocked'), findsOneWidget);

    // Test tapping Climate remote button
    await tester.tap(find.text('Climate'));
    await tester.pump();
    expect(find.text('22°C ON'), findsOneWidget);

    // Test Dynamic 2D Vehicle Skin Customizer from Options Menu
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byType(PopupMenuButton<String>).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Vehicle Paint Studio'), findsOneWidget);
    await tester.tap(find.text('Vehicle Paint Studio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Vehicle Paint & Skin Studio sheet
    expect(find.text('Vehicle Paint & Skin Studio'), findsOneWidget);
    expect(find.text('Phantom Grey'), findsWidgets);
    expect(find.text('Bloodstone Red'), findsWidgets);
    expect(find.textContaining('Dual-Tone'), findsWidgets);

    // Select Bloodstone Red with contrasting black roof
    await tester.tap(find.text('Bloodstone Red').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Confirm button
    await tester.tap(find.textContaining('Set as Vehicle Skin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify confirmation toast
    expect(find.textContaining('Chery Tiggo 7 PHEV skin set to Bloodstone Red'), findsOneWidget);

    // Test switching to Advanced Telemetry mode
    await tester.tap(find.text('Advanced Telemetry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SESSION COST'), findsOneWidget);
    expect(find.text('Scheduled Charging'), findsOneWidget);
    expect(find.text('Monthly Spending Breakdown'), findsOneWidget);

    // Tap the 'Tyres' quick action button in Advanced mode
    await tester.tap(find.text('Tyres'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Direct TPMS modal opens
    expect(find.text('FL Tire Pressure'), findsOneWidget);
    expect(find.text('235 kPa'), findsOneWidget);
    expect(find.text('OPTIMAL'), findsOneWidget);

    repo.dispose();
  });

  testWidgets('MaintenanceTab supports toggling to Chery Service Centres around Malaysia', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const settings = AppSettings(
      ownerName: 'Ahmad Razak',
      carPlateNumber: 'VAG 7777',
      vehicleNickname: 'Tiggo Grey Wolf',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MaintenanceTab(settings: settings),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Schedule & Pricing'), findsOneWidget);
    expect(find.textContaining('Service Centres ('), findsOneWidget);

    // Tap Service Centres sub-tab
    await tester.tap(find.textContaining('Service Centres ('));
    await tester.pumpAndSettle();

    // Verify directory loaded
    expect(find.text('Chery 24/7 Roadside Careline'), findsOneWidget);
    expect(find.text('Chery Segambut'), findsOneWidget);

    // Search for Bangi centre
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'Bangi');
    await tester.pumpAndSettle();

    expect(find.text('Chery Bandar Baru Bangi 3S'), findsOneWidget);
    expect(find.text('Chery Segambut'), findsNothing);
  });

  testWidgets('TripsLogbookScreen renders route map, telemetry stats, and logs expense', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TripsLogbookScreen(
            tnbTariff: 0.57,
            fuelPrice: 2.05,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trips &'), findsOneWidget);
    expect(find.text('Expense Log'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Log Fuel/Charge'), findsOneWidget);

    // Monthly summary
    expect(find.text('Monthly Summary'), findsOneWidget);
    expect(find.textContaining('Saved'), findsOneWidget);
    expect(find.text('1,420'), findsOneWidget);

    // Featured trip
    expect(find.textContaining('Bangsar ➔ Putrajaya Sentral'), findsWidgets);
    expect(find.text('34.2 km'), findsOneWidget);
    expect(find.text('36 min'), findsOneWidget);
    expect(find.text('4.8 kWh'), findsOneWidget);
    expect(find.text('RM 3.15'), findsOneWidget);

    // 1. Test Add Trip from Malaysian Presets (Zero Typing)
    await tester.tap(find.text('Add Trip'));
    await tester.pumpAndSettle();

    expect(find.text('Add Trip from Malaysian Presets'), findsOneWidget);
    expect(find.textContaining('Airport Run'), findsOneWidget);

    // Tap on Airport Run preset
    await tester.tap(find.textContaining('Airport Run'));
    await tester.pumpAndSettle();

    // Verify confirmation and new trip featured
    expect(find.textContaining('Added Trip: ✈️ Airport Run'), findsOneWidget);
    expect(find.text('58.0 km'), findsOneWidget);

    // Dismiss notification banner so top bar button is hit-testable
    AppNotification.dismiss();
    await tester.pumpAndSettle();

    // 2. Test 1-Tap Log Fuel/Charge (Zero Typing)
    await tester.tap(find.text('Log Fuel/Charge'));
    await tester.pumpAndSettle();

    expect(find.text('1-Tap Fuel & Charge Logger'), findsOneWidget);
    expect(find.text('⛽ Petrol RON95'), findsOneWidget);
    expect(find.text('⚡ Home AC'), findsOneWidget);
    expect(find.text('🔌 Public EV'), findsOneWidget);

    // Tap 1-tap save button
    final saveBtn = find.widgetWithText(ElevatedButton, 'Save Fill-up: RM 50.00 (24.4 L)');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verify confirmation snackbar
    expect(find.textContaining('Logged Petronas Primax 95'), findsOneWidget);

    // Scroll to verify logged item in list
    final expenseSection = find.text('Logged Expenses & Fill-ups');
    await tester.ensureVisible(expenseSection);
    expect(expenseSection, findsOneWidget);
    expect(find.text('Petronas Primax 95'), findsWidgets);

    // 3. Test Trip Filter Chips
    expect(find.textContaining('All Drives'), findsOneWidget);
    expect(find.text('⚡ Pure EV (≥95%)'), findsOneWidget);
    expect(find.textContaining('Hybrid / Highway'), findsOneWidget);

    // Filter to Pure EV only
    await tester.tap(find.text('⚡ Pure EV (≥95%)'));
    await tester.pumpAndSettle();

    // 4. Test Export Modal
    AppNotification.dismiss();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Export Logbook & Expenses'), findsOneWidget);
    expect(find.text('WhatsApp / Summary'), findsOneWidget);
    expect(find.text('CSV Spreadsheet'), findsOneWidget);
    expect(find.text('Copy WhatsApp Message'), findsOneWidget);

    // Copy action
    await tester.tap(find.text('Copy WhatsApp Message'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Executive summary copied to clipboard!'), findsOneWidget);

    // Close export modal
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });

  testWidgets('VehicleRadarSheet renders circular radar HUD and navigation actions', (WidgetTester tester) async {
    final telemetry = VehicleTelemetry(
      lastUpdated: DateTime.now(),
      latitude: 3.1189,
      longitude: 101.6672,
      headingDegrees: 38.0,
      locationName: 'The Sphere, Bangsar South, KL',
      isParked: true,
      parkedDurationText: 'Parked 42m ago',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                VehicleRadarSheet.show(
                  context,
                  telemetry: telemetry,
                  onHornFlash: () {},
                );
              },
              child: const Text('Open Radar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Radar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Vehicle Radar & Finder'), findsOneWidget);
    expect(find.text('Circular Radar HUD'), findsOneWidget);
    expect(find.text('Nearby Chargers'), findsOneWidget);
    expect(find.text('The Sphere, Bangsar South, KL'), findsOneWidget);
    expect(find.text('Waze Route'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Horn & Flash'), findsOneWidget);
  });

  testWidgets('SmartChargingSheet renders optimizer, SoC slider, and saves schedule', (WidgetTester tester) async {
    final telemetry = VehicleTelemetry(
      lastUpdated: DateTime.now(),
      batteryPct: 78,
      electricRangeKm: 95,
      fuelRangeKm: 870,
      totalRangeKm: 965,
      isCharging: false,
      latitude: 3.1189,
      longitude: 101.6672,
      headingDegrees: 38.0,
      locationName: 'The Sphere, Bangsar South, KL',
      isParked: true,
      parkedDurationText: '42m ago',
    );

    bool saved = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                SmartChargingSheet.show(
                  context,
                  telemetry: telemetry,
                  isCharging: false,
                  scheduledCharging: true,
                  onToggleCharge: (_) {},
                  onSaveSchedule: (isSched, start, end, soc, kw) {
                    saved = true;
                  },
                );
              },
              child: const Text('Open Optimizer'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Optimizer'));
    await tester.pumpAndSettle();

    expect(find.text('Smart Charging & TNB Optimizer'), findsOneWidget);
    expect(find.text('Target Charge Limit'), findsOneWidget);
    expect(find.text('TNB Off-Peak Scheduler'), findsOneWidget);
    expect(find.text('AC Charging Power / Charger Rate'), findsOneWidget);
    expect(find.text('80% (Daily Saver)'), findsOneWidget);
    expect(find.text('Apply & Save'), findsOneWidget);

    // Switch to Power Curve & SOH tab
    await tester.tap(find.text('Power Curve & SOH'));
    await tester.pumpAndSettle();

    expect(find.text('PHEV AC Charging Curve'), findsOneWidget);
    expect(find.text('Battery Health & Diagnostics (SOH)'), findsOneWidget);
    expect(find.text('99.2%'), findsOneWidget);

    // Switch to TNB Tariff tab
    await tester.tap(find.text('TNB Tariff'));
    await tester.pumpAndSettle();

    expect(find.text('TNB Domestic Tariff A (Malaysia)'), findsOneWidget);
    expect(find.text('TNB EV Off-Peak (10 PM – 8 AM)'), findsOneWidget);
    expect(find.text('RON95 Petrol Equivalent'), findsOneWidget);

    // Tap Apply & Save
    await tester.tap(find.text('Apply & Save'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
  });
}

