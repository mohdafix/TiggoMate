import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiggomate/data/datasources/local_storage_datasource.dart';
import 'package:tiggomate/data/datasources/mock_vehicle_data_source.dart';
import 'package:tiggomate/data/models/knowledge_document.dart';
import 'package:tiggomate/data/models/vehicle_profile.dart';
import 'package:tiggomate/data/repositories/energy_repository.dart';
import 'package:tiggomate/data/repositories/knowledge_repository.dart';
import 'package:tiggomate/data/repositories/maintenance_repository.dart';
import 'package:tiggomate/data/repositories/vehicle_repository.dart';
import 'package:tiggomate/services/ai/tools/assistant_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AssistantToolRegistry toolRegistry;
  late VehicleRepository vehicleRepository;
  late MaintenanceRepository maintenanceRepository;
  late EnergyRepository energyRepository;
  late KnowledgeRepository knowledgeRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageDataSource(prefs);
    final mockDataSource = MockVehicleDataSource(
      initialSimulationActive: false,
    );

    vehicleRepository = VehicleRepository(
      storage: storage,
      mockDataSource: mockDataSource,
    );
    maintenanceRepository = MaintenanceRepository(storage);
    energyRepository = EnergyRepository(storage);

    knowledgeRepository = KnowledgeRepository();
    knowledgeRepository.loadDirectChunks([
      const KnowledgeChunk(
        id: 'auto_mode_test',
        title: 'Hybrid Driving Modes: AUTO, EV, and HEV Operation',
        section: 'Driving & Operating Modes',
        documentName: 'Chery Tiggo 7 PHEV Malaysian Market Guide',
        pageNumber: 28,
        market: 'Malaysia',
        content: 'AUTO mode balances the engine and dual electric motors.',
        tags: ['auto mode', 'engine'],
      ),
    ]);

    toolRegistry = AssistantToolRegistry(
      vehicleRepository: vehicleRepository,
      maintenanceRepository: maintenanceRepository,
      energyRepository: energyRepository,
      knowledgeRepository: knowledgeRepository,
    );
  });

  group('AssistantToolRegistry Unit Tests', () {
    test(
      'search_vehicle_manual returns citations and snippets for valid query',
      () async {
        final res = await toolRegistry.searchVehicleManual({
          'query': 'auto mode',
        });
        expect(res.success, isTrue);
        expect(res.citations, isNotEmpty);
        expect(res.citations.first.pageNumber, 28);
        expect(
          res.citations.first.documentTitle,
          'Chery Tiggo 7 PHEV Malaysian Market Guide',
        );
      },
    );

    test('get_vehicle_profile returns Malaysian market details', () async {
      final res = await toolRegistry.getVehicleProfile({});
      expect(res.success, isTrue);
      final data = res.data as Map<String, dynamic>;
      expect(data['model'], 'Tiggo 7 PHEV CSH');
      expect(data['market'], 'Malaysia');
    });

    test(
      'get_latest_vehicle_readings returns honest not-connected when simulated mode is off',
      () async {
        final res = await toolRegistry.getLatestVehicleReadings({});
        expect(res.success, isTrue);
        final data = res.data as Map<String, dynamic>;
        expect(data['liveTelemetryAvailable'], isFalse);
        expect(data['status'], 'Not Connected');
      },
    );

    test(
      'get_next_service_due identifies first 1,000 km CarLinko inspection milestone',
      () async {
        final res = await toolRegistry.getNextServiceDue({});
        expect(res.success, isTrue);
        final data = res.data as Map<String, dynamic>;
        expect(data['isFirstMilestone'], isTrue);
        expect(data['targetKm'], 1000.0);
      },
    );

    test(
      'record_odometer validates that new odometer cannot decrease',
      () async {
        // Set initial odometer to 850
        await vehicleRepository.updateProfile(
          VehicleProfile.initial().copyWith(currentOdometerKm: 850.0),
        );

        // Attempt to decrease to 800
        final failure = await toolRegistry.recordOdometer({'value': 800.0});
        expect(failure.success, isFalse);
        expect(
          failure.errorMessage,
          contains('cannot be less than current odometer'),
        );

        // Successfully increase to 920
        final success = await toolRegistry.recordOdometer({'value': 920.0});
        expect(success.success, isTrue);
        expect(vehicleRepository.currentProfile.currentOdometerKm, 920.0);
      },
    );

    test(
      'record_fuel_entry validates that fuel volume must be greater than zero',
      () async {
        final failure = await toolRegistry.recordFuelEntry({'liters': -5.0});
        expect(failure.success, isFalse);

        final success = await toolRegistry.recordFuelEntry({
          'liters': 30.0,
          'pricePerLiter': 2.05,
          'station': 'Petronas KLCC',
        });
        expect(success.success, isTrue);
        expect(energyRepository.state.fuelEntries.length, 1);
        expect(energyRepository.state.fuelEntries.first.liters, 30.0);
      },
    );

    test(
      'record_charging_session validates that kWh must be greater than zero',
      () async {
        final failure = await toolRegistry.recordChargingSession({
          'energyKwh': 0.0,
        });
        expect(failure.success, isFalse);

        final success = await toolRegistry.recordChargingSession({
          'energyKwh': 15.5,
          'tariffPerKwh': 0.516,
        });
        expect(success.success, isTrue);
        expect(energyRepository.state.chargingSessions.length, 1);
        expect(energyRepository.state.chargingSessions.first.energyKwh, 15.5);
      },
    );
  });
}
