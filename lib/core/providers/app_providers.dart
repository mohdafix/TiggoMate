import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local_storage_datasource.dart';
import '../../data/datasources/mock_vehicle_data_source.dart';
import '../../data/datasources/vehicle_data_source.dart';
import '../../data/models/assistant_message.dart';
import '../../data/models/energy_record.dart';
import '../../data/models/maintenance_record.dart';
import '../../data/models/telemetry.dart';
import '../../data/models/vehicle_profile.dart';
import '../../data/repositories/assistant_repository.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../services/ai/ai_service.dart';
import '../../services/ai/assistant_orchestrator.dart';
import '../../services/ai/tools/assistant_tools.dart';
import '../../services/voice/voice_service.dart';

// ---------------- Low-Level Providers ----------------
final localStorageProvider = Provider<LocalStorageDataSource>((ref) {
  throw UnimplementedError('localStorageProvider must be overridden in main');
});

final mockVehicleDataSourceProvider = Provider<MockVehicleDataSource>((ref) {
  final storage = ref.watch(localStorageProvider);
  return MockVehicleDataSource(
    initialSimulationActive: storage.getSimulationMode(),
  );
});

// ---------------- Repositories ----------------
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  final mockDataSource = ref.watch(mockVehicleDataSourceProvider);
  return VehicleRepository(storage: storage, mockDataSource: mockDataSource);
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return MaintenanceRepository(storage);
});

final energyRepositoryProvider = Provider<EnergyRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return EnergyRepository(storage);
});

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  final repo = KnowledgeRepository();
  repo.initialize();
  return repo;
});

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return AssistantRepository(storage);
});

// ---------------- Services & Tools ----------------
final toolRegistryProvider = Provider<AssistantToolRegistry>((ref) {
  return AssistantToolRegistry(
    vehicleRepository: ref.watch(vehicleRepositoryProvider),
    maintenanceRepository: ref.watch(maintenanceRepositoryProvider),
    energyRepository: ref.watch(energyRepositoryProvider),
    knowledgeRepository: ref.watch(knowledgeRepositoryProvider),
  );
});

final aiServiceProvider = Provider<AiService>((ref) {
  final storage = ref.watch(localStorageProvider);
  return OpenRouterAiService(backendUrl: storage.getAiBackendUrl());
});

final assistantOrchestratorProvider = Provider<AssistantOrchestrator>((ref) {
  return AssistantOrchestrator(
    toolRegistry: ref.watch(toolRegistryProvider),
    knowledgeRepository: ref.watch(knowledgeRepositoryProvider),
    vehicleRepository: ref.watch(vehicleRepositoryProvider),
    aiService: ref.watch(aiServiceProvider),
  );
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService();
});

// ---------------- Streams & Reactive State ----------------
final vehicleTelemetryStreamProvider = StreamProvider<VehicleTelemetry>((ref) {
  final repo = ref.watch(vehicleRepositoryProvider);
  return repo.watchTelemetry();
});

final vehicleConnectionStatusProvider = FutureProvider<VehicleConnectionStatus>(
  (ref) {
    final repo = ref.watch(vehicleRepositoryProvider);
    return repo.getConnectionStatus();
  },
);

// ---------------- State Notifiers ----------------
class VehicleProfileNotifier extends StateNotifier<VehicleProfile> {
  final VehicleRepository _repo;

  VehicleProfileNotifier(this._repo) : super(_repo.currentProfile);

  Future<void> updateProfile(VehicleProfile updated) async {
    await _repo.updateProfile(updated);
    state = updated;
  }

  Future<void> updateOdometer(double odo) async {
    await _repo.updateOdometer(odo);
    state = _repo.currentProfile;
  }

  Future<void> setSimulatedMode(bool enabled) async {
    await _repo.setSimulatedDataMode(enabled);
  }
}

final vehicleProfileProvider =
    StateNotifierProvider<VehicleProfileNotifier, VehicleProfile>((ref) {
      final repo = ref.watch(vehicleRepositoryProvider);
      return VehicleProfileNotifier(repo);
    });

class MaintenanceNotifier extends StateNotifier<MaintenanceState> {
  final MaintenanceRepository _repo;

  MaintenanceNotifier(this._repo) : super(_repo.state);

  Future<void> addServiceRecord(ServiceRecord record) async {
    await _repo.addServiceRecord(record);
    state = _repo.state;
  }

  Future<void> addTyreRecord(TyreRecord record) async {
    await _repo.addTyreRecord(record);
    state = _repo.state;
  }

  Future<void> updateRegulatoryExpiry(RegulatoryExpiry expiry) async {
    await _repo.updateRegulatoryExpiry(expiry);
    state = _repo.state;
  }

  Future<void> updateIntervals(int km, int months) async {
    await _repo.updateIntervals(intervalKm: km, intervalMonths: months);
    state = _repo.state;
  }
}

final maintenanceStateProvider =
    StateNotifierProvider<MaintenanceNotifier, MaintenanceState>((ref) {
      final repo = ref.watch(maintenanceRepositoryProvider);
      return MaintenanceNotifier(repo);
    });

class EnergyNotifier extends StateNotifier<EnergyState> {
  final EnergyRepository _repo;

  EnergyNotifier(this._repo) : super(_repo.state);

  Future<void> addFuelEntry(FuelEntry entry) async {
    await _repo.addFuelEntry(entry);
    state = _repo.state;
  }

  Future<void> addChargingSession(ChargingSession session) async {
    await _repo.addChargingSession(session);
    state = _repo.state;
  }

  Future<void> updateTariffs(double tariff, double petrolPrice) async {
    await _repo.updateTariffs(
      electricityTariffPerKwh: tariff,
      petrolPricePerLiter: petrolPrice,
    );
    state = _repo.state;
  }
}

final energyStateProvider = StateNotifierProvider<EnergyNotifier, EnergyState>((
  ref,
) {
  final repo = ref.watch(energyRepositoryProvider);
  return EnergyNotifier(repo);
});

// ---------------- Chat Session State ----------------
class ChatState {
  final ConversationSession session;
  final bool isLoading;
  final String? errorMessage;

  const ChatState({
    required this.session,
    this.isLoading = false,
    this.errorMessage,
  });

  ChatState copyWith({
    ConversationSession? session,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChatState(
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AssistantRepository repo;
  final AssistantOrchestrator orchestrator;
  final VoiceService voiceService;

  ChatNotifier({
    required this.repo,
    required this.orchestrator,
    required this.voiceService,
  }) : super(ChatState(session: repo.activeSession));

  void selectSession(String sessionId) {
    repo.selectSession(sessionId);
    state = ChatState(session: repo.activeSession);
  }

  Future<void> createNewSession() async {
    final session = await repo.createNewSession();
    state = ChatState(session: session);
  }

  Future<void> deleteCurrentSession() async {
    final toDelete = state.session.id;
    await repo.deleteSession(toDelete);
    state = ChatState(session: repo.activeSession);
  }

  Future<void> sendUserQuery(String queryText) async {
    if (queryText.trim().isEmpty || state.isLoading) return;

    final userMessage = AssistantMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: queryText.trim(),
      timestamp: DateTime.now(),
    );

    // Save user message immediately
    await repo.addMessageToActiveSession(userMessage);
    state = state.copyWith(
      session: repo.activeSession,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final assistantResponse = await orchestrator.processUserQuery(
        userQuery: queryText.trim(),
      );

      await repo.addMessageToActiveSession(assistantResponse);

      // Trigger TTS if enabled
      voiceService.speakText(assistantResponse.content);

      state = state.copyWith(session: repo.activeSession, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to complete response: $e',
      );
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    repo: ref.watch(assistantRepositoryProvider),
    orchestrator: ref.watch(assistantOrchestratorProvider),
    voiceService: ref.watch(voiceServiceProvider),
  );
});
