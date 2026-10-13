import 'package:shared_preferences/shared_preferences.dart';
import '../models/vehicle_profile.dart';
import '../models/maintenance_record.dart';
import '../models/energy_record.dart';
import '../models/assistant_message.dart';

class LocalStorageDataSource {
  static const _keyVehicleProfile = 'tiggomate_vehicle_profile';
  static const _keyMaintenanceState = 'tiggomate_maintenance_state';
  static const _keyEnergyState = 'tiggomate_energy_state';
  static const _keyConversations = 'tiggomate_conversations';
  static const _keySimulationMode = 'tiggomate_simulation_mode';
  static const _keyAiBackendUrl = 'tiggomate_ai_backend_url';
  static const _keyAiModelName = 'tiggomate_ai_model_name';

  final SharedPreferences _prefs;

  LocalStorageDataSource(this._prefs);

  // ---------------- Vehicle Profile ----------------
  Future<void> saveVehicleProfile(VehicleProfile profile) async {
    await _prefs.setString(_keyVehicleProfile, profile.toJson());
  }

  VehicleProfile loadVehicleProfile() {
    final raw = _prefs.getString(_keyVehicleProfile);
    if (raw != null && raw.isNotEmpty) {
      try {
        return VehicleProfile.fromJson(raw);
      } catch (_) {
        return VehicleProfile.initial();
      }
    }
    return VehicleProfile.initial();
  }

  // ---------------- Maintenance State ----------------
  Future<void> saveMaintenanceState(MaintenanceState state) async {
    await _prefs.setString(_keyMaintenanceState, state.toJson());
  }

  MaintenanceState loadMaintenanceState() {
    final raw = _prefs.getString(_keyMaintenanceState);
    if (raw != null && raw.isNotEmpty) {
      try {
        return MaintenanceState.fromJson(raw);
      } catch (_) {
        return const MaintenanceState();
      }
    }
    return const MaintenanceState();
  }

  // ---------------- Energy State ----------------
  Future<void> saveEnergyState(EnergyState state) async {
    await _prefs.setString(_keyEnergyState, state.toJson());
  }

  EnergyState loadEnergyState() {
    final raw = _prefs.getString(_keyEnergyState);
    if (raw != null && raw.isNotEmpty) {
      try {
        return EnergyState.fromJson(raw);
      } catch (_) {
        return const EnergyState();
      }
    }
    return const EnergyState();
  }

  // ---------------- Assistant Conversations ----------------
  Future<void> saveConversations(List<ConversationSession> sessions) async {
    final list = sessions.map((s) => s.toJson()).toList();
    await _prefs.setStringList(_keyConversations, list);
  }

  List<ConversationSession> loadConversations() {
    final rawList = _prefs.getStringList(_keyConversations);
    if (rawList == null || rawList.isEmpty) return [];
    final list = <ConversationSession>[];
    for (final raw in rawList) {
      try {
        list.add(ConversationSession.fromJson(raw));
      } catch (_) {}
    }
    return list;
  }

  // ---------------- Settings ----------------
  bool getSimulationMode() => _prefs.getBool(_keySimulationMode) ?? false;

  Future<void> setSimulationMode(bool enabled) async {
    await _prefs.setBool(_keySimulationMode, enabled);
  }

  String getAiBackendUrl() =>
      _prefs.getString(_keyAiBackendUrl) ?? 'https://api.tiggomate.app/v1/ai';

  Future<void> setAiBackendUrl(String url) async {
    await _prefs.setString(_keyAiBackendUrl, url);
  }

  String getAiModelName() =>
      _prefs.getString(_keyAiModelName) ?? 'openai/gpt-4o-mini';

  Future<void> setAiModelName(String model) async {
    await _prefs.setString(_keyAiModelName, model);
  }

  // ---------------- Cache Clearing ----------------
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
