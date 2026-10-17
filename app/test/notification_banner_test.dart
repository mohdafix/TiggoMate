import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/theme/app_theme.dart';
import 'package:tiggomate_app/src/ui/app_notification.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_repository.dart';
import 'package:tiggomate_app/src/ui/neo_dashboard.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await VehicleAlertsManager.instance.init();
    await VehicleAlertsManager.instance.clearAll();
  });

  group('VehicleAlertsManager Tests', () {
    test('VehicleAlertsManager adds alert and tracks unread count', () async {
      final manager = VehicleAlertsManager.instance;
      expect(manager.alerts.isEmpty, isTrue);
      expect(manager.unreadCount, 0);

      await manager.addAlert(
        VehicleAlertItem(
          id: 'test-1',
          title: 'Remote Lock',
          message: 'Doors locked successfully',
          timestamp: DateTime.now(),
          type: NotificationType.success,
          icon: Icons.lock_rounded,
          isRead: false,
        ),
      );

      expect(manager.alerts.length, 1);
      expect(manager.unreadCount, 1);
      expect(manager.alerts.first.title, 'Remote Lock');

      await manager.markAllAsRead();
      expect(manager.unreadCount, 0);

      await manager.clearAll();
      expect(manager.alerts.isEmpty, isTrue);
    });

    test('VehicleAlertItem JSON serialization preserves properties', () {
      final item = VehicleAlertItem(
        id: 'json-1',
        title: 'Charging Alert',
        message: '3.3 kW AC Active',
        timestamp: DateTime(2026, 10, 17, 10, 30),
        type: NotificationType.success,
        icon: Icons.bolt_rounded,
        isRead: false,
      );

      final json = item.toJson();
      final restored = VehicleAlertItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.message, item.message);
      expect(restored.type, NotificationType.success);
      expect(restored.isRead, false);
    });
  });

  group('AppNotification High Contrast & HUD Banner Tests', () {
    testWidgets('AppNotification shows floating HUD banner with white text in Obsidian Dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppNotification.show(
                      context,
                      title: 'Security Alert',
                      message: 'CarLinko: Doors Locked',
                      type: NotificationType.success,
                      icon: Icons.lock_rounded,
                    );
                  },
                  child: const Text('Show Dark Banner'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dark Banner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Security Alert'), findsOneWidget);
      expect(find.text('CarLinko: Doors Locked'), findsOneWidget);

      // Verify high contrast in Dark Mode: text must be pure white (#FFFFFF)
      final titleText = tester.widget<Text>(find.text('Security Alert'));
      expect(titleText.style?.color, Colors.white);

      // Verify background container color is high-contrast dark slate (#161E2E)
      final containers = tester.widgetList<Container>(find.byType(Container));
      final bannerContainer = containers.firstWhere(
        (c) => (c.decoration is BoxDecoration) &&
               ((c.decoration as BoxDecoration).color == const Color(0xFF161E2E)),
      );
      expect((bannerContainer.decoration as BoxDecoration).color, const Color(0xFF161E2E));

      AppNotification.dismiss();
      await tester.pump();
    });

    testWidgets('AppNotification shows floating HUD banner with dark text on white card in Tesla Light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppNotification.show(
                      context,
                      title: 'Smart Charging',
                      message: 'Charging started at 3.3 kW',
                      type: NotificationType.success,
                      icon: Icons.bolt_rounded,
                    );
                  },
                  child: const Text('Show Light Banner'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Light Banner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Smart Charging'), findsOneWidget);
      expect(find.text('Charging started at 3.3 kW'), findsOneWidget);

      // Verify high contrast in Light Mode: text must be dark charcoal (#0F172A)
      final titleText = tester.widget<Text>(find.text('Smart Charging'));
      expect(titleText.style?.color, const Color(0xFF0F172A));

      // Verify background container is pure crisp white (#FFFFFF)
      final containers = tester.widgetList<Container>(find.byType(Container));
      final bannerContainer = containers.firstWhere(
        (c) => (c.decoration is BoxDecoration) &&
               ((c.decoration as BoxDecoration).color == Colors.white),
      );
      expect((bannerContainer.decoration as BoxDecoration).color, Colors.white);

      AppNotification.dismiss();
      await tester.pump();
    });

    testWidgets('AppNotification banner auto-dismisses after duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppNotification.show(
                      context,
                      message: 'Auto dismiss test',
                      duration: const Duration(milliseconds: 500),
                    );
                  },
                  child: const Text('Trigger'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Auto dismiss test'), findsOneWidget);

      // Fast forward past duration
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Auto dismiss test'), findsNothing);
    });
  });

  group('VehicleAlertsSheet Widget Tests', () {
    testWidgets('VehicleAlertsSheet renders alert history and test triggers', (tester) async {
      await VehicleAlertsManager.instance.addAlert(
        VehicleAlertItem(
          id: 'alert-1',
          title: 'AC Pre-cooling',
          message: 'Cabin cooled to 22.0°C',
          timestamp: DateTime.now(),
          type: NotificationType.info,
          icon: Icons.ac_unit_rounded,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => VehicleAlertsSheet.show(context),
                  child: const Text('Open Alerts'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Alerts'));
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Alerts & History'), findsOneWidget);
      expect(find.text('AC Pre-cooling'), findsOneWidget);
      expect(find.text('Cabin cooled to 22.0°C'), findsOneWidget);

      // Verify Test Notification Buttons exist
      expect(find.textContaining('Test Notification Banners'), findsOneWidget);
      expect(find.text('🔒 Lock'), findsOneWidget);
      expect(find.text('⚡ Charging'), findsOneWidget);
      expect(find.text('❄️ Climate'), findsOneWidget);
      expect(find.text('⚠️ TPMS'), findsOneWidget);
    });
  });

  group('NeoDashboard Notification Bell Dock Integration', () {
    testWidgets('NeoDashboard header displays notification bell and opens VehicleAlertsSheet', (tester) async {
      final repo = MockVehicleRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: NeoDashboard(
              repository: repo,
              ownerName: 'Test Owner',
              carPlateNumber: 'VAG 7777',
              vehicleNickname: 'Chery Tiggo 7 PHEV CSH',
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

      // Find notification bell icon
      final bellFinder = find.byTooltip('Vehicle Alerts & History');
      expect(bellFinder, findsOneWidget);

      // Tap the notification bell
      await tester.tap(bellFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ensure VehicleAlertsSheet is displayed
      expect(find.text('Vehicle Alerts & History'), findsOneWidget);
    });
  });
}
