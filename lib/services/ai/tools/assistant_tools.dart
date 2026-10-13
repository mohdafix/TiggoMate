import 'package:uuid/uuid.dart';
import '../../../core/utils/cost_calculator.dart';
import '../../../data/models/assistant_message.dart';
import '../../../data/models/energy_record.dart';
import '../../../data/models/knowledge_document.dart';
import '../../../data/models/telemetry.dart';
import '../../../data/repositories/energy_repository.dart';
import '../../../data/repositories/knowledge_repository.dart';
import '../../../data/repositories/maintenance_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';

class ToolCallResult {
  final String toolName;
  final bool success;
  final dynamic data;
  final String? errorMessage;
  final List<DocumentCitation> citations;
  final bool isWriteOperation;

  const ToolCallResult({
    required this.toolName,
    required this.success,
    required this.data,
    this.errorMessage,
    this.citations = const [],
    this.isWriteOperation = false,
  });

  ToolExecutionRecord toRecord(Map<String, dynamic> arguments) {
    return ToolExecutionRecord(
      toolName: toolName,
      arguments: arguments,
      result: data ?? errorMessage,
      isWriteOperation: isWriteOperation,
    );
  }
}

/// Registry of typed, validated tools backed by actual application repositories.
class AssistantToolRegistry {
  final VehicleRepository vehicleRepository;
  final MaintenanceRepository maintenanceRepository;
  final EnergyRepository energyRepository;
  final KnowledgeRepository knowledgeRepository;
  final _uuid = const Uuid();

  AssistantToolRegistry({
    required this.vehicleRepository,
    required this.maintenanceRepository,
    required this.energyRepository,
    required this.knowledgeRepository,
  });

  /// 1. search_vehicle_manual(query)
  Future<ToolCallResult> searchVehicleManual(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.trim().isEmpty) {
      return const ToolCallResult(
        toolName: 'search_vehicle_manual',
        success: false,
        data: null,
        errorMessage: 'Query parameter cannot be empty',
      );
    }

    final results = knowledgeRepository.search(query.trim(), limit: 3);
    final citations = results
        .map((r) => r.chunk.toCitation(matchedExcerpt: r.matchedSnippet))
        .toList();

    final data = results
        .map(
          (r) => {
            'title': r.chunk.title,
            'section': r.chunk.section,
            'page': r.chunk.pageNumber,
            'snippet': r.matchedSnippet,
          },
        )
        .toList();

    return ToolCallResult(
      toolName: 'search_vehicle_manual',
      success: true,
      data: data,
      citations: citations,
    );
  }

  /// 2. get_vehicle_profile()
  Future<ToolCallResult> getVehicleProfile(Map<String, dynamic> args) async {
    final profile = vehicleRepository.currentProfile;
    return ToolCallResult(
      toolName: 'get_vehicle_profile',
      success: true,
      data: profile.toMap(),
    );
  }

  /// 3. get_vehicle_connection_status()
  Future<ToolCallResult> getVehicleConnectionStatus(
    Map<String, dynamic> args,
  ) async {
    final status = await vehicleRepository.getConnectionStatus();
    return ToolCallResult(
      toolName: 'get_vehicle_connection_status',
      success: true,
      data: {
        'state': status.state.name,
        'providerName': status.providerName,
        'statusDescription': status.statusDescription,
        'isSimulated': status.isSimulated,
        'lastChecked': status.lastChecked.toIso8601String(),
      },
    );
  }

  /// 4. get_latest_vehicle_readings()
  Future<ToolCallResult> getLatestVehicleReadings(
    Map<String, dynamic> args,
  ) async {
    final status = await vehicleRepository.getConnectionStatus();
    final isSim = vehicleRepository.isSimulatedMode;

    if (!isSim && !status.isConnected) {
      return ToolCallResult(
        toolName: 'get_latest_vehicle_readings',
        success: true,
        data: {
          'status': 'Not Connected',
          'carlinkoStatus': 'Awaiting 1,000 km activation',
          'lastKnownOdometerKm':
              vehicleRepository.currentProfile.currentOdometerKm,
          'liveTelemetryAvailable': false,
          'message':
              'Live vehicle telemetry is unavailable. CarLinko has not been activated. '
              'Values cannot be fabricated.',
        },
      );
    }

    // When simulated mode is active:
    return ToolCallResult(
      toolName: 'get_latest_vehicle_readings',
      success: true,
      data: {
        'batteryPercentage': 78.0,
        'fuelPercentage': 85.0,
        'odometerKm': vehicleRepository.currentProfile.currentOdometerKm,
        'estimatedElectricRangeKm': 68.0,
        'estimatedTotalRangeKm': 820.0,
        'drivingMode': 'AUTO',
        'isCharging': false,
        'provenance': ReadingSource.simulated.name,
        'provenanceNote': 'SIMULATED DATA (Development/demo mode)',
      },
    );
  }

  /// 5. get_maintenance_records()
  Future<ToolCallResult> getMaintenanceRecords(
    Map<String, dynamic> args,
  ) async {
    final state = maintenanceRepository.state;
    return ToolCallResult(
      toolName: 'get_maintenance_records',
      success: true,
      data: {
        'serviceCount': state.serviceRecords.length,
        'totalCostRm': state.totalServiceCostRm,
        'services': state.serviceRecords.map((s) => s.toMap()).toList(),
      },
    );
  }

  /// 6. get_next_service_due()
  Future<ToolCallResult> getNextServiceDue(Map<String, dynamic> args) async {
    final odo = vehicleRepository.currentProfile.currentOdometerKm;
    final purchaseDate = vehicleRepository.currentProfile.purchaseDate;
    final due = maintenanceRepository.getNextServiceDue(odo, purchaseDate);

    return ToolCallResult(
      toolName: 'get_next_service_due',
      success: true,
      data: {
        'serviceName': due['serviceName'],
        'targetKm': due['targetKm'],
        'remainingKm': due['remainingKm'],
        'dueDate': (due['dueDate'] as DateTime).toIso8601String(),
        'isOverdue': due['isOverdue'],
        'isFirstMilestone': due['isFirstMilestone'],
      },
    );
  }

  /// 7. calculate_energy_cost(inputs)
  Future<ToolCallResult> calculateEnergyCost(Map<String, dynamic> args) async {
    try {
      final tariff =
          (args['tariffPerKwh'] as num?)?.toDouble() ??
          energyRepository.state.defaultTariffPerKwh;
      final petrolPrice =
          (args['petrolPricePerLiter'] as num?)?.toDouble() ??
          energyRepository.state.defaultPetrolPricePerLiter;

      final comparison = CostCalculator.compareCostPer100Km(
        electricityTariffPerKwh: tariff,
        petrolPricePerLiter: petrolPrice,
      );

      return ToolCallResult(
        toolName: 'calculate_energy_cost',
        success: true,
        data: comparison,
      );
    } catch (e) {
      return ToolCallResult(
        toolName: 'calculate_energy_cost',
        success: false,
        data: null,
        errorMessage: 'Invalid calculation arguments: $e',
      );
    }
  }

  /// 8. calculate_trip_cost(inputs)
  Future<ToolCallResult> calculateTripCost(Map<String, dynamic> args) async {
    try {
      final distance = (args['distanceKm'] as num?)?.toDouble();
      if (distance == null || distance <= 0) {
        return const ToolCallResult(
          toolName: 'calculate_trip_cost',
          success: false,
          data: null,
          errorMessage: 'Valid distance in km (> 0) is required',
        );
      }

      final kwh = (args['electricEnergyKwh'] as num?)?.toDouble() ?? 0.0;
      final liters = (args['fuelLiters'] as num?)?.toDouble() ?? 0.0;
      final tariff =
          (args['electricityTariffPerKwh'] as num?)?.toDouble() ??
          energyRepository.state.defaultTariffPerKwh;
      final petrolPrice =
          (args['petrolPricePerLiter'] as num?)?.toDouble() ??
          energyRepository.state.defaultPetrolPricePerLiter;

      final inputs = TripCostInputs(
        distanceKm: distance,
        electricEnergyKwh: kwh,
        fuelLiters: liters,
        electricityTariffPerKwh: tariff,
        petrolPricePerLiter: petrolPrice,
        chargingLossFraction: 0.10,
      );

      final result = CostCalculator.calculateTripCost(inputs);

      return ToolCallResult(
        toolName: 'calculate_trip_cost',
        success: true,
        data: {
          'distanceKm': result.distanceKm,
          'electricityCostRm': result.electricityCostRm,
          'petrolCostRm': result.petrolCostRm,
          'totalCostRm': result.totalCostRm,
          'costPerKmRm': result.costPerKmRm,
          'costPer100KmRm': result.costPer100KmRm,
          'savingsVersusPurePetrolRm': result.savingsVersusPurePetrolRm,
          'assumptions': result.assumptions,
        },
      );
    } catch (e) {
      return ToolCallResult(
        toolName: 'calculate_trip_cost',
        success: false,
        data: null,
        errorMessage: 'Error computing trip cost: $e',
      );
    }
  }

  /// 9. record_odometer(value) - WRITE OPERATION
  Future<ToolCallResult> recordOdometer(Map<String, dynamic> args) async {
    final value = (args['value'] as num?)?.toDouble();
    if (value == null || value < 0) {
      return const ToolCallResult(
        toolName: 'record_odometer',
        success: false,
        data: null,
        errorMessage: 'Invalid odometer value. Must be a positive number.',
        isWriteOperation: true,
      );
    }

    final current = vehicleRepository.currentProfile.currentOdometerKm;
    if (value < current) {
      return ToolCallResult(
        toolName: 'record_odometer',
        success: false,
        data: null,
        errorMessage:
            'New odometer value ($value km) cannot be less than current odometer ($current km).',
        isWriteOperation: true,
      );
    }

    await vehicleRepository.updateOdometer(value);
    return ToolCallResult(
      toolName: 'record_odometer',
      success: true,
      data: {'updatedOdometerKm': value, 'previousOdometerKm': current},
      isWriteOperation: true,
    );
  }

  /// 10. record_fuel_entry(inputs) - WRITE OPERATION
  Future<ToolCallResult> recordFuelEntry(Map<String, dynamic> args) async {
    try {
      final liters = (args['liters'] as num?)?.toDouble();
      final pricePerL =
          (args['pricePerLiter'] as num?)?.toDouble() ??
          energyRepository.state.defaultPetrolPricePerLiter;
      final odo =
          (args['odometerKm'] as num?)?.toDouble() ??
          vehicleRepository.currentProfile.currentOdometerKm;

      if (liters == null || liters <= 0) {
        return const ToolCallResult(
          toolName: 'record_fuel_entry',
          success: false,
          data: null,
          errorMessage: 'Liters must be greater than 0',
          isWriteOperation: true,
        );
      }

      final total = liters * pricePerL;
      final entry = FuelEntry(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        odometerKm: odo,
        liters: liters,
        pricePerLiter: pricePerL,
        totalCostRm: total,
        station: args['station'] as String? ?? 'Petronas / Shell',
        fuelGrade: args['fuelGrade'] as String? ?? 'RON95',
      );

      await energyRepository.addFuelEntry(entry);
      return ToolCallResult(
        toolName: 'record_fuel_entry',
        success: true,
        data: entry.toMap(),
        isWriteOperation: true,
      );
    } catch (e) {
      return ToolCallResult(
        toolName: 'record_fuel_entry',
        success: false,
        data: null,
        errorMessage: 'Validation failed: $e',
        isWriteOperation: true,
      );
    }
  }

  /// 11. record_charging_session(inputs) - WRITE OPERATION
  Future<ToolCallResult> recordChargingSession(
    Map<String, dynamic> args,
  ) async {
    try {
      final kwh = (args['energyKwh'] as num?)?.toDouble();
      final tariff =
          (args['tariffPerKwh'] as num?)?.toDouble() ??
          energyRepository.state.defaultTariffPerKwh;
      final odo =
          (args['odometerKm'] as num?)?.toDouble() ??
          vehicleRepository.currentProfile.currentOdometerKm;

      if (kwh == null || kwh <= 0) {
        return const ToolCallResult(
          toolName: 'record_charging_session',
          success: false,
          data: null,
          errorMessage: 'Energy charged (kWh) must be greater than 0',
          isWriteOperation: true,
        );
      }

      final total = kwh * tariff;
      final session = ChargingSession(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        odometerKm: odo,
        energyKwh: kwh,
        tariffPerKwh: tariff,
        totalCostRm: total,
        chargerType: args['chargerType'] as String? ?? 'Home AC Wallbox (7kW)',
        durationMinutes: (args['durationMinutes'] as num?)?.toInt() ?? 180,
      );

      await energyRepository.addChargingSession(session);
      return ToolCallResult(
        toolName: 'record_charging_session',
        success: true,
        data: session.toMap(),
        isWriteOperation: true,
      );
    } catch (e) {
      return ToolCallResult(
        toolName: 'record_charging_session',
        success: false,
        data: null,
        errorMessage: 'Validation failed: $e',
        isWriteOperation: true,
      );
    }
  }
}
