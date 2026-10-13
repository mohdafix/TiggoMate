import 'package:flutter_test/flutter_test.dart';
import 'package:tiggomate/data/models/telemetry.dart';

void main() {
  group('Telemetry & Provenance Unit Tests', () {
    test(
      'VehicleTelemetry.disconnected contains honest unavailable states and no fake readings',
      () {
        final disconnected = VehicleTelemetry.disconnected(
          lastKnownOdo: 850.0,
          statusMessage: 'CarLinko Not Activated',
        );

        // Battery percentage MUST be unavailable (null value)
        expect(disconnected.batteryPercentage.value, isNull);
        expect(
          disconnected.batteryPercentage.source,
          ReadingSource.unavailable,
        );
        expect(disconnected.batteryPercentage.isAvailable, isFalse);

        // Fuel percentage MUST be unavailable
        expect(disconnected.fuelPercentage.value, isNull);
        expect(disconnected.fuelPercentage.source, ReadingSource.unavailable);

        // Ranges MUST be unavailable
        expect(disconnected.estimatedElectricRangeKm.value, isNull);
        expect(disconnected.estimatedTotalRangeKm.value, isNull);

        // Last known odo is flagged as user-entered
        expect(disconnected.odometerKm.value, 850.0);
        expect(disconnected.odometerKm.source, ReadingSource.userEntered);

        // Simulation mode flag must be false
        expect(disconnected.isSimulatedModeActive, isFalse);
      },
    );

    test(
      'VehicleTelemetry.simulated explicitly flags all readings as simulated',
      () {
        final sim = VehicleTelemetry.simulated(
          batteryPercent: 78.0,
          fuelPercent: 85.0,
          odo: 850.0,
          evRange: 68.0,
          totalRange: 820.0,
        );

        expect(sim.isSimulatedModeActive, isTrue);
        expect(sim.batteryPercentage.source, ReadingSource.simulated);
        expect(sim.batteryPercentage.value, 78.0);
        expect(sim.batteryPercentage.isSimulated, isTrue);
        expect(sim.batteryPercentage.categoryLabel, 'SIMULATED DATA (DEV)');

        expect(sim.fuelPercentage.source, ReadingSource.simulated);
        expect(sim.fuelPercentage.value, 85.0);

        expect(sim.estimatedElectricRangeKm.source, ReadingSource.simulated);
        expect(sim.estimatedElectricRangeKm.value, 68.0);
      },
    );

    test('ReadingProvenance distinguishes the 5 mandatory categories', () {
      final now = DateTime.now();

      final live = ReadingProvenance<double>(
        value: 80.0,
        unit: '%',
        source: ReadingSource.liveConnected,
        timestamp: now,
        connectionStatusLabel: 'Live Stream',
      );
      expect(live.isLive, isTrue);
      expect(live.categoryLabel, 'LIVE VERIFIED');

      final cached = ReadingProvenance<double>(
        value: 80.0,
        unit: '%',
        source: ReadingSource.previouslyRetrieved,
        timestamp: now.subtract(const Duration(hours: 2)),
        connectionStatusLabel: 'Cached',
      );
      expect(cached.isStale, isTrue);
      expect(cached.categoryLabel, 'CACHED (STALE)');

      final manual = ReadingProvenance<double>(
        value: 900.0,
        unit: 'km',
        source: ReadingSource.userEntered,
        timestamp: now,
        connectionStatusLabel: 'Manual',
      );
      expect(manual.isUserEntered, isTrue);
      expect(manual.categoryLabel, 'MANUAL ENTRY');

      final unavailable = ReadingProvenance<double>(
        value: null,
        unit: '%',
        source: ReadingSource.unavailable,
        timestamp: now,
        connectionStatusLabel: 'Disconnected',
      );
      expect(unavailable.isAvailable, isFalse);
      expect(unavailable.categoryLabel, 'UNAVAILABLE');
    });
  });
}
