import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate_app/src/service/price_book_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PriceBookService Dated Tariff & Fuel Tests', () {
    test('resolves dated AC vs DC vs all rates chronologically without altering past periods', () {
      final pb = PriceBookService(
        initialRules: [
          PriceRule(
            id: 'all_jan',
            kind: PriceKind.charge,
            scope: ChargeScope.all,
            effectiveFrom: DateTime(2025, 1, 1),
            pricePerUnit: 0.57,
            label: 'Base',
          ),
          PriceRule(
            id: 'ac_jul',
            kind: PriceKind.charge,
            scope: ChargeScope.ac,
            effectiveFrom: DateTime(2025, 7, 1),
            pricePerUnit: 0.28,
            label: 'TNB Off-Peak',
          ),
          PriceRule(
            id: 'dc_jul',
            kind: PriceKind.charge,
            scope: ChargeScope.dc,
            effectiveFrom: DateTime(2025, 7, 1),
            pricePerUnit: 1.45,
            label: 'DC Highway',
          ),
          PriceRule(
            id: 'fuel_jan',
            kind: PriceKind.fuel,
            effectiveFrom: DateTime(2025, 1, 1),
            pricePerUnit: 2.05,
          ),
          PriceRule(
            id: 'fuel_oct',
            kind: PriceKind.fuel,
            effectiveFrom: DateTime(2025, 10, 1),
            pricePerUnit: 2.60,
          ),
        ],
        initialOverrides: {'charge_special': 0.99},
      );

      // Historical May charge still uses RM 0.57
      expect(pb.rateForCharge(DateTime(2025, 5, 10), isDc: false), equals(0.57));
      expect(pb.rateForCharge(DateTime(2025, 5, 10), isDc: true), equals(0.57));

      // August AC vs DC uses specific scope rules
      expect(pb.rateForCharge(DateTime(2025, 8, 2), isDc: false), equals(0.28));
      expect(pb.rateForCharge(DateTime(2025, 8, 2), isDc: true), equals(1.45));

      // Session override wins cleanly over date rules
      expect(
        pb.rateForCharge(DateTime(2025, 8, 2), isDc: true, sessionId: 'charge_special'),
        equals(0.99),
      );

      // Fuel price history preserved before and after Oct change
      expect(pb.rateForFuel(DateTime(2025, 6, 15)), equals(2.05));
      expect(pb.rateForFuel(DateTime(2025, 10, 15)), equals(2.60));
    });

    test('recordSettingsRates preserves earlier periods when rate changes later', () async {
      final pb = PriceBookService(
        initialRules: [
          PriceRule(
            id: 'ac_init',
            kind: PriceKind.charge,
            scope: ChargeScope.ac,
            effectiveFrom: DateTime(2025, 1, 1),
            pricePerUnit: 0.57,
          ),
          PriceRule(
            id: 'fuel_init',
            kind: PriceKind.fuel,
            effectiveFrom: DateTime(2025, 1, 1),
            pricePerUnit: 2.05,
          ),
        ],
      );

      await pb.recordSettingsRates(
        tnbTariff: 0.31,
        fuelPrice: 2.15,
        effectiveFrom: DateTime(2026, 1, 15),
      );

      expect(pb.rateForCharge(DateTime(2025, 6, 1), isDc: false), equals(0.57));
      expect(pb.rateForCharge(DateTime(2026, 2, 1), isDc: false), equals(0.31));
      expect(pb.rateForFuel(DateTime(2025, 6, 1)), equals(2.05));
      expect(pb.rateForFuel(DateTime(2026, 2, 1)), equals(2.15));
    });
  });
}
