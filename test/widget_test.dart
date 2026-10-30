import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/main.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_repository.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_skin.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_telemetry.dart';
import 'package:tiggomate_app/src/mytnb/mytnb_api.dart';
import 'package:tiggomate_app/src/theme/app_theme.dart';
import 'package:tiggomate_app/src/ui/ask_assistant_sheet.dart';
import 'package:tiggomate_app/src/ui/energy_screen.dart';
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

    expect(find.text('CHERY TIGGO 7 PHEV CSH'), findsWidgets);
  });

  testWidgets('TiggoMate smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TiggoMateApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TIGGO GREY WOLF'), findsWidgets);
    expect(find.textContaining('VAG 7777'), findsWidgets);
    expect(find.text('CAR'), findsOneWidget);
    expect(find.text('ASSISTANT'), findsOneWidget);
    expect(find.text('SERVICE'), findsOneWidget);
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

  testWidgets('MaintenanceTab renders next service and schedule pricing', (WidgetTester tester) async {
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

    expect(find.text('SCHEDULE & PRICING'), findsOneWidget);
    expect(find.text('NEXT · MONTH 1'), findsOneWidget);
    expect(find.text('1,000 km inspection'), findsOneWidget);
    expect(find.text('SCHEDULE · TO 150,000 KM'), findsOneWidget);
    expect(find.text('RM 407.50'), findsOneWidget);
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

  testWidgets('NeoDashboard renders bound telemetry, remote deck, and paint studio', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final semantics = tester.ensureSemantics();

    await VehicleSkinManager.instance.setSkin('khaki_white');
    final repo = MockVehicleRepository(withSampleData: true);

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

    expect(find.text('TIGGO GREY WOLF'), findsOneWidget);
    expect(find.text('VAG 7777'), findsOneWidget);

    // Carousel opens on Vehicle Livery (khaki white, set above).
    expect(find.text('VEHICLE LIVERY'), findsOneWidget);
    expect(find.textContaining('KHAKI WHITE'), findsOneWidget);

    // Bound telemetry comes from the repository. Swipe once to reach the
    // TPMS top view.
    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('TOP VIEW · TPMS COLD'), findsOneWidget);
    expect(find.text('235'), findsNWidgets(2));
    expect(find.text('TOTAL RANGE'), findsOneWidget);
    expect(find.text('EV 78% · 82 km'), findsOneWidget);
    expect(find.text('Fuel 100% · 838 km'), findsOneWidget);

    // Remote deck
    expect(find.text('DOORS'), findsOneWidget);
    expect(find.text('CLIMATE'), findsOneWidget);
    expect(find.text('WINDOWS'), findsOneWidget);
    expect(find.text('TRUNK'), findsOneWidget);
    expect(find.text('LOCATE'), findsOneWidget);
    expect(find.text('ENGINE'), findsOneWidget);

    // Test tapping Doors remote button
    expect(find.text('Locked'), findsOneWidget);
    await tester.tap(find.text('DOORS'));
    await tester.pump();
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.textContaining('CarLinko: Doors Unlocked'), findsOneWidget);
    AppNotification.dismiss();
    await tester.pump(const Duration(seconds: 4));

    // Swipe back to Vehicle Livery (the first page). It no longer offers a
    // picker — paint is chosen in Settings/setup — so simulate that change
    // directly and confirm this page just reflects it.
    await tester.drag(find.byType(PageView), const Offset(800, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('VEHICLE LIVERY'), findsOneWidget);
    expect(find.text('CHOOSE IN SETTINGS'), findsOneWidget);

    await VehicleSkinManager.instance.setSkin('bloodstone_red');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('BLOODSTONE RED'), findsOneWidget);

    AppNotification.dismiss();
    await tester.pump(const Duration(seconds: 4));
    semantics.dispose();
    repo.dispose();
  });

  testWidgets('NeoDashboard does not invent telemetry when no car is bound', (WidgetTester tester) async {
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

    expect(find.textContaining('Pending Car Bind'), findsOneWidget);
    expect(find.text('232'), findsNothing);
    expect(find.text('EV 24% · 22 km'), findsNothing);
    expect(find.text('Fuel 79% · 664 km'), findsNothing);
    expect(find.text('120 m NE'), findsNothing);
    expect(find.text('Locked'), findsNothing);

    // Placeholders instead of readings
    expect(find.text('EV --% · -- km'), findsOneWidget);
    expect(find.text('Fuel --% · -- km'), findsOneWidget);

    // TPMS readings live on the carousel's TPMS page; swipe once from the
    // default Vehicle Livery page to reach it.
    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('kPa · --°'), findsNWidgets(4));

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

    expect(find.text('SCHEDULE & PRICING'), findsOneWidget);
    expect(find.textContaining('SERVICE CENTRES ('), findsOneWidget);

    // Tap Service Centres sub-tab
    await tester.tap(find.textContaining('SERVICE CENTRES ('));
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

  testWidgets('TripsLogbookScreen logs trips and fuel, and opens export', (WidgetTester tester) async {
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

    expect(find.text('LOG'), findsOneWidget);
    expect(find.text('ENTRIES'), findsOneWidget);

    // 1. Test Add Trip from Malaysian Presets (Zero Typing)
    await tester.tap(find.text('+ Trip'));
    await tester.pumpAndSettle();

    expect(find.text('Add Trip from Malaysian Presets'), findsOneWidget);
    expect(find.textContaining('Airport Run'), findsOneWidget);

    // Tap on Airport Run preset
    await tester.tap(find.textContaining('Airport Run'));
    await tester.pumpAndSettle();

    // Verify confirmation and that the trip was saved
    expect(find.textContaining('Added Trip: ✈️ Airport Run'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tm_logged_trips_v2'), contains('Airport Run'));

    // Dismiss notification banner so top bar button is hit-testable
    AppNotification.dismiss();
    await tester.pumpAndSettle();

    // 2. Test 1-Tap Log Fuel/Charge (Zero Typing)
    await tester.tap(find.text('+ Fuel'));
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

    // Verify confirmation
    expect(find.textContaining('Logged Petronas Primax 95'), findsOneWidget);

    // 3. Test Export Modal
    AppNotification.dismiss();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Export CSV / PDF'));
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

  testWidgets('TripsLogbookScreen shows logged records and real totals, not sample data', (WidgetTester tester) async {
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

    bool richTextShows(String text) => tester
        .widgetList<RichText>(find.byType(RichText))
        .any((w) => w.text.toPlainText() == text);

    // Empty log: nothing invented
    expect(find.text('KL → Ipoh (NSE)'), findsNothing);
    expect(find.text('No entries this month'), findsOneWidget);
    expect(find.text('61%'), findsNothing);
    expect(richTextShows('0 km'), isTrue);

    await tester.tap(find.text('+ Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Airport Run'));
    await tester.pumpAndSettle();
    AppNotification.dismiss();
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Fuel'));
    await tester.pumpAndSettle();
    final saveBtn = find.widgetWithText(ElevatedButton, 'Save Fill-up: RM 50.00 (24.4 L)');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    AppNotification.dismiss();
    await tester.pumpAndSettle();

    // Both records and their totals now show
    expect(find.textContaining('Airport Run'), findsOneWidget);
    expect(find.text('Petronas Primax 95'), findsOneWidget);
    expect(find.text('58 km'), findsOneWidget);
    expect(find.text('RM 50.00'), findsOneWidget);
    expect(richTextShows('58 km'), isTrue);
    expect(richTextShows('RM 50'), isTrue);
    expect(find.text('No entries this month'), findsNothing);

    // Filters: a petrol fill-up counts as FUEL, not EV ('EV' is also the chart legend)
    await tester.tap(find.text('FUEL'));
    await tester.pumpAndSettle();
    expect(find.text('Petronas Primax 95'), findsOneWidget);
    await tester.tap(find.text('EV').last);
    await tester.pumpAndSettle();
    expect(find.text('Petronas Primax 95'), findsNothing);

    // Records stay in their own month
    await tester.tap(find.text('ALL'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('Petronas Primax 95'), findsNothing);
    expect(find.text('No entries this month'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('Petronas Primax 95'), findsOneWidget);
  });

  testWidgets('TripsLogbookScreen header fits every month name on a narrow phone', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    for (int i = 0; i < 12; i++) {
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('TripsLogbookScreen CSV export uses real dates', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

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

    await tester.tap(find.text('+ Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Airport Run'));
    await tester.pumpAndSettle();
    AppNotification.dismiss();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Export CSV / PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV Spreadsheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy CSV Data'));
    await tester.pumpAndSettle();

    final today = DateTime.now().toIso8601String().substring(0, 10);
    expect(copied, contains('"$today"'));
    expect(copied, isNot(contains('Just now')));
  });

  testWidgets('AskAssistantSheet answers last-trip questions from the real logbook', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Future<bool> replyContains(String question, String expected) async {
      await tester.enterText(find.byType(TextField), question);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      return tester
          .widgetList<RichText>(find.byType(RichText))
          .any((w) => w.text.toPlainText().contains(expected));
    }

    Future<void> pumpSheet() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: AskAssistantSheet()),
        ),
      );
      await tester.pump();
    }

    SharedPreferences.setMockInitialValues({});
    await pumpSheet();
    expect(await replyContains('last trip', 'You have no trips logged yet'), isTrue);

    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'tm_logged_trips_v2': jsonEncode([
        {
          'id': 'trip_$now',
          'title': 'Ipoh run',
          'timestamp': 'x',
          'distanceKm': 40.0,
          'durationMinutes': 30,
          'evDistanceKm': 20.0,
          'hevDistanceKm': 20.0,
          'electricKwh': 3.0,
          'petrolLitres': 1.5,
          'costRm': 4.8,
          'avgSpeedKmh': 80.0,
          'highwayNote': '',
          'routePoints': <List<double>>[],
          'evPointCount': 0,
        },
      ]),
    });
    await pumpSheet();
    expect(await replyContains('last trip', 'Ipoh run (40.0 km)'), isTrue);
    expect(find.textContaining('Home → Bangsar South'), findsNothing);
  });

  testWidgets('EnergyScreen shows placeholders when the battery level is unknown', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: EnergyScreen(
          telemetry: VehicleTelemetry.unbound(),
          isCharging: false,
        ),
      ),
    );
    await tester.pump();

    bool richTextShows(String text) => tester
        .widgetList<RichText>(find.byType(RichText))
        .any((w) => w.text.toPlainText().startsWith(text));

    expect(richTextShows('--'), isTrue);
    expect(richTextShows('24'), isFalse);
    expect(find.text('--:--'), findsOneWidget);
    expect(find.text('-- kWh'), findsOneWidget);
    expect(find.text('RM --'), findsNWidgets(3));
  });

  testWidgets('VehicleRadarSheet does not invent distance, position or lock state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => VehicleRadarSheet.show(
                context,
                telemetry: VehicleTelemetry.fromBlobMap({}, isSimulated: false),
                onHornFlash: () {},
              ),
              child: const Text('Open Radar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Radar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Location unavailable'), findsOneWidget);
    expect(find.text('Coordinates unavailable'), findsOneWidget);
    expect(find.text('120 m away (2m)'), findsNothing);
    expect(find.text('Secured & Stationary'), findsNothing);
    expect(find.text('Doors closed'), findsOneWidget);
  });

  testWidgets('VehicleRadarSheet ranks saved chargers by real distance from the car', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Future<void> openChargersFor(VehicleTelemetry telemetry) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VehicleRadarSheet.show(context, telemetry: telemetry, onHornFlash: () {}),
                child: const Text('Open Radar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Radar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Nearby Chargers'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Parked right at one charger: it comes first, at zero distance
    await openChargersFor(VehicleTelemetry(lastUpdated: DateTime.now(), latitude: 3.1091, longitude: 101.6612));
    expect(find.text('Find Chargers Near Car'), findsOneWidget);
    expect(find.text('0 m'), findsOneWidget);
    expect(find.textContaining('Available'), findsNothing);
    expect(find.textContaining('RM '), findsNothing);
    expect(find.text('450 m'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Shell Recharge - Pantai Sentral')).dy,
      lessThan(tester.getTopLeft(find.text('ChargEV - Nexus Bangsar South')).dy),
    );

    // In Penang: the Bangsar South chargers are honestly far away
    await tester.pumpWidget(const SizedBox());
    await openChargersFor(VehicleTelemetry(lastUpdated: DateTime.now(), latitude: 5.4141, longitude: 100.3288));
    expect(find.textContaining(RegExp(r'^\d{3} km$')), findsNWidgets(3));

    // No position: no distances, and nothing to search around
    await tester.pumpWidget(const SizedBox());
    await openChargersFor(VehicleTelemetry(lastUpdated: DateTime.now()));
    expect(find.text('Car location unavailable'), findsOneWidget);
    expect(find.text('--'), findsNWidgets(3));
  });

  testWidgets('TripsLogbookScreen removes sample records saved by older builds', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now().millisecondsSinceEpoch;
    Map<String, dynamic> trip(String id, String title) => {
          'id': id,
          'title': title,
          'timestamp': 'x',
          'distanceKm': 10.0,
          'durationMinutes': 10,
          'evDistanceKm': 10.0,
          'hevDistanceKm': 0.0,
          'electricKwh': 2.0,
          'petrolLitres': 0.0,
          'costRm': 1.0,
          'avgSpeedKmh': 40.0,
          'highwayNote': '',
          'routePoints': <List<double>>[],
          'evPointCount': 0,
        };
    SharedPreferences.setMockInitialValues({
      'tm_logged_trips_v2': jsonEncode([trip('trip_$now', 'My real drive'), trip('trip_3', 'KL → Ipoh (NSE)')]),
    });

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

    expect(find.text('My real drive'), findsOneWidget);
    expect(find.text('KL → Ipoh (NSE)'), findsNothing);
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

