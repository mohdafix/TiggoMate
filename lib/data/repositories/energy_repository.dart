import '../datasources/local_storage_datasource.dart';
import '../models/energy_record.dart';

class EnergyRepository {
  final LocalStorageDataSource _storage;
  late EnergyState _state;

  EnergyRepository(this._storage) {
    _state = _storage.loadEnergyState();
  }

  EnergyState get state => _state;

  Future<void> addFuelEntry(FuelEntry entry) async {
    final updatedList = [entry, ..._state.fuelEntries];
    updatedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _state = EnergyState(
      fuelEntries: updatedList,
      chargingSessions: _state.chargingSessions,
      defaultTariffPerKwh: _state.defaultTariffPerKwh,
      defaultPetrolPricePerLiter: _state.defaultPetrolPricePerLiter,
    );
    await _storage.saveEnergyState(_state);
  }

  Future<void> addChargingSession(ChargingSession session) async {
    final updatedList = [session, ..._state.chargingSessions];
    updatedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _state = EnergyState(
      fuelEntries: _state.fuelEntries,
      chargingSessions: updatedList,
      defaultTariffPerKwh: _state.defaultTariffPerKwh,
      defaultPetrolPricePerLiter: _state.defaultPetrolPricePerLiter,
    );
    await _storage.saveEnergyState(_state);
  }

  Future<void> updateTariffs({
    required double electricityTariffPerKwh,
    required double petrolPricePerLiter,
  }) async {
    _state = EnergyState(
      fuelEntries: _state.fuelEntries,
      chargingSessions: _state.chargingSessions,
      defaultTariffPerKwh: electricityTariffPerKwh,
      defaultPetrolPricePerLiter: petrolPricePerLiter,
    );
    await _storage.saveEnergyState(_state);
  }
}
