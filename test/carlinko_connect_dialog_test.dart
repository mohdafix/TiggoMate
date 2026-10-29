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
                    onConnected: () {},
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

    // Verify dialog content is present in login view
    expect(find.text('CarLinko Telematics Cloud'), findsOneWidget);
    expect(find.text('Chery CarLinko Cloud Standby: Connect with your official CarLinko account. Once your dealer binds the vehicle VIN, live telematics and remote controls automatically sync in real time.'), findsOneWidget);
    expect(find.text('Single Session Notice: Chery CarLinko permits only one active mobile session. Connecting live here may log out your official phone app.'), findsOneWidget);
    expect(find.text('Connect Cloud'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // No overflow exception thrown
    expect(tester.takeException(), isNull);

    // Tap "Cancel" after ensuring it is visible
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('CarLinko Telematics Cloud'), findsNothing);

    repo.dispose();
  });

  testWidgets('CarlinkoConnectDialog renders Connected View when already authenticated', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = LiveCarLinkoRepository();
    repo.setPreActivationMode(account: 'linexsg@gmail.com');
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
              child: const Text('Open Connected Dialog'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open Connected Dialog'));
    await tester.pumpAndSettle();

    // Verify Connected View is presented
    expect(find.text('SESSION CONNECTED & ACTIVE'), findsOneWidget);
    expect(find.text('linexsg@gmail.com'), findsOneWidget);
    expect(find.text('Pending Car Bind (Pairing Required)'), findsOneWidget);
    expect(find.text('Refresh Cloud Sync'), findsOneWidget);
    expect(find.text('Switch Account'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);

    // Tap Refresh Cloud Sync
    await tester.ensureVisible(find.text('Refresh Cloud Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh Cloud Sync'));
    await tester.pumpAndSettle();
    expect(connectedCalled, isTrue);
    expect(find.text('Cloud telemetry refreshed successfully!'), findsOneWidget);

    // Tap Close after ensuring visible
    await tester.ensureVisible(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('SESSION CONNECTED & ACTIVE'), findsNothing);

    repo.dispose();
  });

  testWidgets('CarlinkoConnectDialog renders cleanly in Tesla Light mode with light background', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = LiveCarLinkoRepository();
    repo.setPreActivationMode(account: 'linexsg@gmail.com');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => CarlinkoConnectDialog(
                    repository: repo,
                    currentAccount: 'linexsg@gmail.com',
                    onConnected: () {},
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(Dialog);
    expect(dialogFinder, findsOneWidget);
    final Dialog dialog = tester.widget(dialogFinder);
    expect(dialog.backgroundColor, Colors.white);

    expect(find.text('CarLinko Telematics Cloud'), findsOneWidget);
    expect(find.text('SESSION CONNECTED & ACTIVE'), findsOneWidget);

    repo.dispose();
  });
}
