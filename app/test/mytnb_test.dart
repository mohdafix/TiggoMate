import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/mytnb/mytnb_api.dart';
import 'package:tiggomate_app/src/ui/mytnb_connect_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TnbTariffCalculator Tests', () {
    test('Calculates Block 1 (<= 200 kWh) accurately', () {
      final bill = TnbTariffCalculator.calculateDomesticBill(150.0);
      expect(bill, closeTo(150.0 * 0.218, 0.001));

      final tariff = TnbTariffCalculator.calculateEffectiveTariff(150.0);
      expect(tariff, closeTo(0.218, 0.001));
    });

    test('Calculates Block 2 (201 - 300 kWh) accurately', () {
      // 200 @ 0.218 = 43.60; 50 @ 0.334 = 16.70; Total = 60.30
      final bill = TnbTariffCalculator.calculateDomesticBill(250.0);
      expect(bill, closeTo(43.60 + 16.70, 0.01));
    });

    test('Calculates Block 3 (301 - 600 kWh) accurately', () {
      // 200 @ 0.218 = 43.60
      // 100 @ 0.334 = 33.40
      // 150 @ 0.516 = 77.40
      // Total = 154.40
      final bill = TnbTariffCalculator.calculateDomesticBill(450.0);
      expect(bill, closeTo(154.40, 0.01));
    });

    test('Calculates Off-Peak and Marginal PHEV charging cost', () {
      // Tiggo 7 battery deficit 15 kWh
      final offPeakCost = TnbTariffCalculator.calculatePhevChargeCost(
        phevKwh: 15.0,
        isOffPeak: true,
      );
      expect(offPeakCost, closeTo(15.0 * 0.28, 0.01)); // RM 4.20

      // Marginal charging on top of 400 kWh household base
      final marginalCost = TnbTariffCalculator.calculatePhevChargeCost(
        phevKwh: 19.27,
        currentHouseholdKwh: 400.0,
        isOffPeak: false,
      );
      // In block 3 (400 to 419.27 kWh), rate is 0.516
      expect(marginalCost, closeTo(19.27 * 0.516, 0.05));
    });
  });

  group('MyTnbClient & Repository Tests', () {
    test('Demo login provides valid session and smart meter telemetry', () async {
      final client = MyTnbClient();
      final session = await client.login(
        email: 'demo@mytnb.com.my',
        password: 'demo',
        isDemo: true,
      );

      expect(session.isLoggedIn, isTrue);
      expect(session.isDemo, isTrue);
      expect(session.userId, contains('MYTNB'));

      final accounts = await client.getCustomerAccounts(session);
      expect(accounts.isNotEmpty, isTrue);

      final smartAccount = accounts.firstWhere((a) => a.isSmartMeter);
      expect(smartAccount.accountNumber, '220384918204');
      expect(smartAccount.accountDesc, contains('Bangi'));
      expect(smartAccount.currentUsageKwh, 482.6);
      expect(smartAccount.effectiveTariff, greaterThan(0.3));
    });

    test('MyTnbRepository stores and restores session', () async {
      final repo = MyTnbRepository();
      await repo.init();
      expect(repo.sessionNotifier.value, isNull);

      final account = await repo.login(
        email: 'demo',
        password: 'demo',
        isDemo: true,
      );
      expect(account, isNotNull);
      expect(repo.sessionNotifier.value, isNotNull);
      expect(repo.selectedAccountNotifier.value?.accountNumber, '220384918204');

      // Re-init should restore
      final repo2 = MyTnbRepository();
      await repo2.init();
      expect(repo2.sessionNotifier.value?.email, contains('mytnb'));
      expect(repo2.selectedAccountNotifier.value?.isSmartMeter, isTrue);

      // Logout should clear
      await repo2.logout();
      expect(repo2.sessionNotifier.value, isNull);
      expect(repo2.selectedAccountNotifier.value, isNull);
    });
  });

  group('MyTnbConnectDialog Widget Tests', () {
    testWidgets('Renders login form and can connect via demo mode', (tester) async {
      final repo = MyTnbRepository();
      await repo.init();

      double? updatedTariff;
      MyTnbAccount? updatedAccount;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyTnbConnectDialog(
              repository: repo,
              currentTariff: 0.57,
              onTariffUpdated: (rate, acc) {
                updatedTariff = rate;
                updatedAccount = acc;
              },
            ),
          ),
        ),
      );

      // Verify form elements exist
      expect(find.text('myTNB Smart Meter'), findsOneWidget);
      expect(find.text('Direct myTNB Sign In'), findsOneWidget);
      expect(find.text('Use Demo Smart Meter (Test Mode)'), findsOneWidget);

      // Tap demo connect button
      await tester.tap(find.text('Use Demo Smart Meter (Test Mode)'));
      await tester.pumpAndSettle();

      // Should now show connected view with Bangi Smart Meter
      expect(find.text('SMART METER'), findsOneWidget);
      expect(find.textContaining('220384918204'), findsOneWidget);
      expect(find.text('482.6 kWh'), findsOneWidget);
      expect(find.textContaining('Apply Live Tariff'), findsOneWidget);

      expect(updatedAccount, isNotNull);
      expect(updatedTariff, isNotNull);
    });
  });
}
