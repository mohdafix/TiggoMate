import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_repository.dart';
import 'package:tiggomate_app/src/theme/app_theme.dart';
import 'package:tiggomate_app/src/ui/carlinko_connect_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CarlinkoConnectDialog renders without overflow on narrow 360px mobile screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = MockVehicleRepository();
    bool connectedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => CarlinkoConnectDialog(
                    repository: repo,
                    currentAccount: 'linexsg@gmail.com',
                    onConnected: () => connectedCalled = true,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog content is present
    expect(find.text('CarLinko Telematics Cloud'), findsOneWidget);
    expect(find.text('Pre-Activation Mode Active: Chery CarLinko telematics is activated by your authorised Chery 3S/4S centre during the 1,000 km initial vehicle service. Until activation, TiggoMate runs in high-fidelity Simulation Mode.'), findsOneWidget);
    expect(find.text('Single Session Notice: Chery CarLinko permits only one active mobile session. Connecting live here may log out your official phone app.'), findsOneWidget);
    expect(find.text('Connect Cloud'), findsOneWidget);
    expect(find.text('Use Simulation Mode'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // No overflow exception thrown
    expect(tester.takeException(), isNull);

    // Tap "Use Simulation Mode" after ensuring it is visible
    await tester.ensureVisible(find.text('Use Simulation Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Simulation Mode'));
    await tester.pumpAndSettle();

    expect(connectedCalled, isTrue);
    expect(find.text('CarLinko Telematics Cloud'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tm_carlinko_status'), equals('Demo'));

    repo.dispose();
  });
}
