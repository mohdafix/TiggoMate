import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_repository.dart';
import 'package:tiggomate_app/src/carlinko/vehicle_skin.dart';
import 'package:tiggomate_app/src/ui/neo_dashboard.dart';
import 'package:tiggomate_app/src/ui/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Vehicle Skin Models & Manager', () {
    test('getVehicleSkinByKey returns correct skins and handles fallback', () {
      final white = getVehicleSkinByKey('khaki_white');
      expect(white.key, 'khaki_white');
      expect(white.name, 'Khaki White');
      expect(white.assetPath, 'assets/images/car_hero_khaki_white.png');

      final grey = getVehicleSkinByKey('phantom_grey');
      expect(grey.key, 'phantom_grey');
      expect(grey.name, 'Phantom Grey');
      expect(grey.assetPath, 'assets/images/car_hero_phantom_grey.png');

      final red = getVehicleSkinByKey('bloodstone_red');
      expect(red.key, 'bloodstone_red');
      expect(red.name, 'Bloodstone Red');
      expect(red.isDualTone, isTrue);
      expect(red.assetPath, 'assets/images/car_hero_bloodstone_red.png');

      final fallback = getVehicleSkinByKey('non_existent_key');
      expect(fallback.key, 'khaki_white');
    });

    test('VehicleSkinManager updates state, notifies listeners, and persists', () async {
      final manager = VehicleSkinManager.instance;
      await manager.init();

      int notificationCount = 0;
      void listener() {
        notificationCount++;
      }

      manager.addListener(listener);

      await manager.setSkin('bloodstone_red');
      expect(manager.currentSkinKey, 'bloodstone_red');
      expect(manager.currentSkin.name, 'Bloodstone Red');
      expect(notificationCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tm_vehicle_color_skin'), 'bloodstone_red');

      // Setting same skin should not trigger notification
      await manager.setSkin('bloodstone_red');
      expect(notificationCount, 1);

      await manager.setSkin('phantom_grey');
      expect(manager.currentSkinKey, 'phantom_grey');
      expect(notificationCount, 2);

      manager.removeListener(listener);
    });

    test('AppSettings preserves and copies vehicleSkinKey', () {
      const settings = AppSettings(
        ownerName: 'Mohd Afix',
        carPlateNumber: 'VAG 7777',
        vehicleSkinKey: 'bloodstone_red',
      );

      expect(settings.vehicleSkinKey, 'bloodstone_red');

      final updated = settings.copyWith(vehicleSkinKey: 'phantom_grey');
      expect(updated.vehicleSkinKey, 'phantom_grey');
      expect(updated.ownerName, 'Mohd Afix');
    });

    test('SettingsService saves and loads vehicleSkinKey', () async {
      const settings = AppSettings(
        ownerName: 'Mohd Afix',
        carPlateNumber: 'VAG 7777',
        vehicleSkinKey: 'bloodstone_red',
      );

      await SettingsService.save(settings);
      final loaded = await SettingsService.load();
      expect(loaded.vehicleSkinKey, 'bloodstone_red');
    });
  });

  group('NeoDashboard Vehicle Skin Reactivity', () {
    testWidgets('NeoDashboard reactively updates car render when VehicleSkinManager changes', (tester) async {
      await VehicleSkinManager.instance.setSkin('khaki_white');
      final repo = MockVehicleRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NeoDashboard(
              repository: repo,
              ownerName: 'Mohd Afix',
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
      await tester.pump(const Duration(milliseconds: 350));

      // Verify initial car image is khaki white
      final initialImageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/car_hero_khaki_white.png',
      );
      expect(initialImageFinder, findsOneWidget);

      // Now change vehicle skin to Bloodstone Red via VehicleSkinManager
      await VehicleSkinManager.instance.setSkin('bloodstone_red');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify car image immediately updated to bloodstone red
      final redImageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/car_hero_bloodstone_red.png',
      );
      expect(redImageFinder, findsOneWidget);

      // Now change vehicle skin to Phantom Grey
      await VehicleSkinManager.instance.setSkin('phantom_grey');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final greyImageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/car_hero_phantom_grey.png',
      );
      expect(greyImageFinder, findsOneWidget);
    });
  });
}
