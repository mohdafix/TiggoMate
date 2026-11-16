import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_repository.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_telemetry.dart';
import 'package:tiggomate_app/src/theme/app_theme.dart';
import 'package:tiggomate_app/src/ui/climate_control_sheet.dart';
import 'package:tiggomate_app/src/ui/windows_control_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('WindowsControlSheet builds without layout errors', (WidgetTester tester) async {
    final repo = MockVehicleRepository(withSampleData: true);
    final telemetry = repo.currentTelemetry;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => WindowsControlSheet.show(
              context,
              repository: repo,
              telemetry: telemetry,
              initialWindowsVented: false,
            ),
            child: const Text('Open Windows'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Windows'));
    await tester.pump();

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'WindowsControlSheet threw: $exception');

    expect(find.text('Windows & Sunroof'), findsOneWidget);
    expect(find.text('Vent'), findsOneWidget);
    expect(find.text('SUNROOF GLASS'), findsOneWidget);
    expect(find.text('SUNSHADE CURTAIN'), findsOneWidget);

    repo.dispose();
  });

  testWidgets('ClimateControlSheet builds without layout errors', (WidgetTester tester) async {
    final telemetry = VehicleTelemetry(lastUpdated: DateTime.now());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ClimateControlSheet.show(
              context,
              telemetry: telemetry,
              initialAcOn: true,
              initialTempC: 22.0,
              initialDurationMin: 10,
              onApply: (_, __, ___, {bool? rapidCool, bool? frontDefrost, bool? rearDefrost, bool? airPurifier, int? fanGear, int? seatHeatDriver, int? seatVentDriver, int? seatHeatPass, int? seatVentPass, bool? steeringHeat}) {},
            ),
            child: const Text('Open Climate'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Climate'));
    await tester.pump();

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'ClimateControlSheet threw: $exception');

    expect(find.text('Climate & Seat Comfort'), findsOneWidget);
    expect(find.text('CABIN TARGET TEMPERATURE'), findsOneWidget);
  });

  testWidgets('ClimateControlSheet in Defrost Mode builds without overflow on narrow device', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final telemetry = VehicleTelemetry(lastUpdated: DateTime.now(), frontDefrost: true, rearDefrost: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ClimateControlSheet.show(
              context,
              telemetry: telemetry,
              isDefrostMode: true,
              initialAcOn: true,
              initialTempC: 28.0,
              initialDurationMin: 10,
              initialFrontDefrost: true,
              initialRearDefrost: true,
              onApply: (_, __, ___, {bool? rapidCool, bool? frontDefrost, bool? rearDefrost, bool? airPurifier, int? fanGear, int? seatHeatDriver, int? seatVentDriver, int? seatHeatPass, int? seatVentPass, bool? steeringHeat}) {},
            ),
            child: const Text('Open Defrost'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Defrost'));
    await tester.pump();

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'Defrost Sheet threw: $exception');

    expect(find.text('Windshield Defrost & Demist'), findsOneWidget);
    expect(find.text('Chery Front & Rear Demister'), findsOneWidget);
    expect(find.text('Max Defrost'), findsOneWidget);
    expect(find.text('Front Screen'), findsOneWidget);
    expect(find.text('Rear Glass'), findsOneWidget);
    expect(find.text('ACTIVATE RAPID DEFROST (28.0°C)'), findsOneWidget);
  });
}
