import '../datasources/local_storage_datasource.dart';
import '../models/maintenance_record.dart';

class MaintenanceRepository {
  final LocalStorageDataSource _storage;
  late MaintenanceState _state;

  MaintenanceRepository(this._storage) {
    _state = _storage.loadMaintenanceState();
  }

  MaintenanceState get state => _state;

  Future<void> addServiceRecord(ServiceRecord record) async {
    final updatedList = [record, ..._state.serviceRecords];
    // sort descending by mileage
    updatedList.sort((a, b) => b.mileageKm.compareTo(a.mileageKm));
    _state = MaintenanceState(
      intervalKm: _state.intervalKm,
      intervalMonths: _state.intervalMonths,
      serviceRecords: updatedList,
      tyreRecords: _state.tyreRecords,
      regulatoryExpiry: _state.regulatoryExpiry,
    );
    await _storage.saveMaintenanceState(_state);
  }

  Future<void> addTyreRecord(TyreRecord record) async {
    final updatedList = [record, ..._state.tyreRecords];
    updatedList.sort((a, b) => b.date.compareTo(a.date));
    _state = MaintenanceState(
      intervalKm: _state.intervalKm,
      intervalMonths: _state.intervalMonths,
      serviceRecords: _state.serviceRecords,
      tyreRecords: updatedList,
      regulatoryExpiry: _state.regulatoryExpiry,
    );
    await _storage.saveMaintenanceState(_state);
  }

  Future<void> updateRegulatoryExpiry(RegulatoryExpiry expiry) async {
    _state = MaintenanceState(
      intervalKm: _state.intervalKm,
      intervalMonths: _state.intervalMonths,
      serviceRecords: _state.serviceRecords,
      tyreRecords: _state.tyreRecords,
      regulatoryExpiry: expiry,
    );
    await _storage.saveMaintenanceState(_state);
  }

  Future<void> updateIntervals({
    required int intervalKm,
    required int intervalMonths,
  }) async {
    _state = MaintenanceState(
      intervalKm: intervalKm,
      intervalMonths: intervalMonths,
      serviceRecords: _state.serviceRecords,
      tyreRecords: _state.tyreRecords,
      regulatoryExpiry: _state.regulatoryExpiry,
    );
    await _storage.saveMaintenanceState(_state);
  }

  Map<String, dynamic> getNextServiceDue(
    double currentOdoKm,
    DateTime? purchaseDate,
  ) {
    return _state.calculateNextServiceDue(currentOdoKm, purchaseDate);
  }
}
