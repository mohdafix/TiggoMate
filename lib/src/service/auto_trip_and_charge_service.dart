import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../carlinko/vehicle_telemetry.dart';
import '../firebase/firebase_sync_service.dart';
import '../ui/app_notification.dart';
import '../ui/trips_logbook_screen.dart';

/// In-flight state of an ongoing vehicle driving trip.
class InFlightTrip {
  final DateTime startTs;
  final int startOdo;
  final int startSoc;
  final String? startLocation;
  DateTime lastMoveTs;
  int lastOdo;
  int lastSoc;
  String? lastLocation;
  final List<Offset> points;
  int evPoints;

  InFlightTrip({
    required this.startTs,
    required this.startOdo,
    required this.startSoc,
    this.startLocation,
    required this.lastMoveTs,
    required this.lastOdo,
    required this.lastSoc,
    this.lastLocation,
    List<Offset>? points,
    this.evPoints = 0,
  }) : points = points ?? [];

  Map<String, dynamic> toJson() => {
        'startTs': startTs.millisecondsSinceEpoch,
        'startOdo': startOdo,
        'startSoc': startSoc,
        'startLocation': startLocation,
        'lastMoveTs': lastMoveTs.millisecondsSinceEpoch,
        'lastOdo': lastOdo,
        'lastSoc': lastSoc,
        'lastLocation': lastLocation,
        'evPoints': evPoints,
      };

  factory InFlightTrip.fromJson(Map<String, dynamic> j) => InFlightTrip(
        startTs: DateTime.fromMillisecondsSinceEpoch(j['startTs'] as int),
        startOdo: j['startOdo'] as int,
        startSoc: j['startSoc'] as int,
        startLocation: j['startLocation'] as String?,
        lastMoveTs: DateTime.fromMillisecondsSinceEpoch(j['lastMoveTs'] as int),
        lastOdo: j['lastOdo'] as int,
        lastSoc: j['lastSoc'] as int,
        lastLocation: j['lastLocation'] as String?,
        evPoints: j['evPoints'] as int? ?? 0,
      );
}

/// In-flight state of an ongoing vehicle charging session.
class InFlightCharge {
  final DateTime startTs;
  final int startSoc;
  DateTime lastRiseTs;
  int maxSoc;
  double peakKw;
  int sampleCount;
  bool isDcFast;

  InFlightCharge({
    required this.startTs,
    required this.startSoc,
    required this.lastRiseTs,
    required this.maxSoc,
    this.peakKw = 0.0,
    this.sampleCount = 1,
    this.isDcFast = false,
  });

  Map<String, dynamic> toJson() => {
        'startTs': startTs.millisecondsSinceEpoch,
        'startSoc': startSoc,
        'lastRiseTs': lastRiseTs.millisecondsSinceEpoch,
        'maxSoc': maxSoc,
        'peakKw': peakKw,
        'sampleCount': sampleCount,
        'isDcFast': isDcFast,
      };

  factory InFlightCharge.fromJson(Map<String, dynamic> j) => InFlightCharge(
        startTs: DateTime.fromMillisecondsSinceEpoch(j['startTs'] as int),
        startSoc: j['startSoc'] as int,
        lastRiseTs: DateTime.fromMillisecondsSinceEpoch(j['lastRiseTs'] as int),
        maxSoc: j['maxSoc'] as int,
        peakKw: (j['peakKw'] as num?)?.toDouble() ?? 0.0,
        sampleCount: j['sampleCount'] as int? ?? 1,
        isDcFast: j['isDcFast'] as bool? ?? false,
      );
}

/// Automated Trip and Charging Session Detection & Logging Service.
///
/// Ported from the reverse-engineered Chery/Jaecoo T-Box telematics protocol
/// (`GodrezJr2/j5-ev-dashboard`). Reconstructs real trips and charging sessions
/// using proven automotive noise filters:
/// - 3-minute stationary bridging for red lights and passenger stops
/// - 12 km / 160 km/h cloud catch-up burst guards (rejects underground re-syncs)
/// - 10-minute / 2% SoC regenerative braking false-positive rejection
/// - Automatic Malaysian tariff calculations (TNB Home AC / Public DC)
class AutoTripAndChargeService extends ChangeNotifier {
  static final AutoTripAndChargeService instance = AutoTripAndChargeService._internal();

  AutoTripAndChargeService._internal() {
    _initService();
  }

  static const String _kTripsStorageKey = 'tm_logged_trips_v2';
  static const String _kExpenseStorageKey = 'tm_logged_expenses_v2';
  static const String _kInFlightTripKey = 'tm_inflight_trip_v1';
  static const String _kInFlightChargeKey = 'tm_inflight_charge_v1';

  // Constants grounded in Chery Super Hybrid / Jaecoo platform specifications
  static const double batteryCapacityKwh = 18.3; // Tiggo 7 Pro PHEV battery pack
  static const int tripGapSeconds = 180;          // 3 min stationary bridges traffic lights
  static const int maxPairGapSeconds = 1800;      // 30 min hole in log => do not bridge
  static const double odoMaxKmh = 160.0;          // Max plausible vehicle velocity
  static const double odoResyncKm = 12.0;         // Cloud catch-up burst threshold
  static const double minTripDistanceKm = 0.2;    // Minimum distance (200m) to log a trip
  static const int chargeParkMinSeconds = 600;    // 10 min stationary to reject regen descents
  static const int minGainPct = 2;                // Minimum 2% SoC gain for genuine charge
  static const int idleGapSeconds = 1800;         // 30 min no SoC rise => charge finished
  static const int maxSocDrop = 25;               // Single-frame drop guard

  InFlightTrip? _currentTrip;
  InFlightCharge? _currentCharge;
  DateTime? _lastTelemetryTs;
  int? _lastOdo;
  int? _lastSoc;
  Timer? _ticker;
  bool _initialized = false;

  InFlightTrip? get activeTrip => _currentTrip;
  InFlightCharge? get activeCharge => _currentCharge;
  bool get isTripActive => _currentTrip != null;
  bool get isChargeActive => _currentCharge != null;

  @visibleForTesting
  void resetForTesting() {
    _ticker?.cancel();
    _ticker = null;
    _currentTrip = null;
    _currentCharge = null;
    _lastTelemetryTs = null;
    _lastOdo = null;
    _lastSoc = null;
  }

  Future<void> _initService() async {
    if (_initialized) return;
    _initialized = true;
    await _restoreInFlight();
    final bool isTesting = Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTesting) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _checkTimeouts());
    }
  }

  Future<void> _restoreInFlight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripJson = prefs.getString(_kInFlightTripKey);
      if (tripJson != null && tripJson.isNotEmpty) {
        _currentTrip = InFlightTrip.fromJson(jsonDecode(tripJson) as Map<String, dynamic>);
      }
      final chargeJson = prefs.getString(_kInFlightChargeKey);
      if (chargeJson != null && chargeJson.isNotEmpty) {
        _currentCharge = InFlightCharge.fromJson(jsonDecode(chargeJson) as Map<String, dynamic>);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('AutoTripAndChargeService restore error: $e');
    }
  }

  Future<void> _persistInFlight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentTrip != null) {
        await prefs.setString(_kInFlightTripKey, jsonEncode(_currentTrip!.toJson()));
      } else {
        await prefs.remove(_kInFlightTripKey);
      }

      if (_currentCharge != null) {
        await prefs.setString(_kInFlightChargeKey, jsonEncode(_currentCharge!.toJson()));
      } else {
        await prefs.remove(_kInFlightChargeKey);
      }
    } catch (_) {}
  }

  /// Process incoming telemetry frame from CarLinko repository.
  void processTelemetry(
    VehicleTelemetry t, {
    double? tnbTariff,
    double? fuelPrice,
  }) {
    if (!t.isBound || t.odometerKm <= 0) {
      return;
    }

    final now = t.lastUpdated;
    final int odo = t.odometerKm;
    final int soc = t.batteryPct;
    final double speed = t.speedKmH;
    final bool hwCharging = t.isCharging || t.chargePowerKw > 0;
    final double powerKw = t.chargePowerKw;
    final String? loc = t.locationName.isNotEmpty && t.locationName != 'Location unavailable'
        ? t.locationName
        : null;

    // First frame initialization
    if (_lastTelemetryTs == null || _lastOdo == null || _lastSoc == null) {
      _lastTelemetryTs = now;
      _lastOdo = odo;
      _lastSoc = soc;
      if (hwCharging) {
        _currentCharge = InFlightCharge(
          startTs: now,
          startSoc: soc,
          lastRiseTs: now,
          maxSoc: soc,
          peakKw: powerKw,
          sampleCount: 1,
          isDcFast: powerKw > 22.0,
        );
      }
      return;
    }

    final dtSec = now.difference(_lastTelemetryTs!).inSeconds.abs();
    final dOdo = odo - _lastOdo!;
    final dSoc = soc - _lastSoc!;

    // 1. Process Trip State Machine
    _processTripFrame(
      now: now,
      odo: odo,
      soc: soc,
      speed: speed,
      dtSec: dtSec,
      dOdo: dOdo,
      loc: loc,
      tnbTariff: tnbTariff,
    );

    // 2. Process Charging Session State Machine
    _processChargeFrame(
      now: now,
      odo: odo,
      soc: soc,
      dOdo: dOdo,
      dSoc: dSoc,
      dtSec: dtSec,
      hwCharging: hwCharging,
      powerKw: powerKw,
      tnbTariff: tnbTariff,
    );

    _lastTelemetryTs = now;
    _lastOdo = odo;
    _lastSoc = soc;
  }

  void _processTripFrame({
    required DateTime now,
    required int odo,
    required int soc,
    required double speed,
    required int dtSec,
    required int dOdo,
    String? loc,
    double? tnbTariff,
  }) {
    // Hole in log guard: >30 min gap means we cannot bridge continuous driving
    if (dtSec > maxPairGapSeconds) {
      if (_currentTrip != null) {
        _finalizeTrip(_currentTrip!, tnbTariff: tnbTariff);
        _currentTrip = null;
        _persistInFlight();
      }
      return;
    }

    // Odometer backwards glitch: close trip
    if (dOdo < 0) {
      if (_currentTrip != null) {
        _finalizeTrip(_currentTrip!, tnbTariff: tnbTariff);
        _currentTrip = null;
        _persistInFlight();
      }
      return;
    }

    // Vehicle is moving: odometer increasing or positive speed while moving
    if (dOdo > 0 || speed > 1.0) {
      // Cloud catch-up burst guard: re-sync from deadzone/basement
      final double maxAllowedBurst = [
        odoResyncKm,
        (dtSec / 3600.0) * odoMaxKmh,
      ].reduce((a, b) => a > b ? a : b);

      if (dOdo > maxAllowedBurst) {
        // Discard burst from current trip to prevent distorted 700+ km/h averages
        if (_currentTrip != null) {
          _finalizeTrip(_currentTrip!, tnbTariff: tnbTariff);
          _currentTrip = null;
          _persistInFlight();
        }
        return;
      }

      // Close any active charging session because the vehicle is driving
      if (_currentCharge != null) {
        _finalizeCharge(_currentCharge!, tnbTariff: tnbTariff);
        _currentCharge = null;
      }

      if (_currentTrip == null) {
        // Open new trip
        _currentTrip = InFlightTrip(
          startTs: _lastTelemetryTs ?? now,
          startOdo: _lastOdo ?? odo,
          startSoc: _lastSoc ?? soc,
          startLocation: loc,
          lastMoveTs: now,
          lastOdo: odo,
          lastSoc: soc,
          lastLocation: loc,
          evPoints: speed > 0 && soc > 0 ? 1 : 0,
        );
      } else {
        // Update active trip
        _currentTrip!.lastMoveTs = now;
        _currentTrip!.lastOdo = odo;
        _currentTrip!.lastSoc = soc;
        if (loc != null) _currentTrip!.lastLocation = loc;
        if (speed > 0 && soc > 0) _currentTrip!.evPoints++;
      }
      _persistInFlight();
    } else {
      // Vehicle is stationary (dOdo == 0 and speed <= 1.0)
      if (_currentTrip != null) {
        final parkedSec = now.difference(_currentTrip!.lastMoveTs).inSeconds;
        if (parkedSec > tripGapSeconds) {
          // Parked > 3 minutes => trip completed!
          _finalizeTrip(_currentTrip!, tnbTariff: tnbTariff);
          _currentTrip = null;
          _persistInFlight();
        }
      }
    }
  }

  void _processChargeFrame({
    required DateTime now,
    required int odo,
    required int soc,
    required int dOdo,
    required int dSoc,
    required int dtSec,
    required bool hwCharging,
    required double powerKw,
    double? tnbTariff,
  }) {
    // If the vehicle is actively driving, it cannot be charging
    if (dOdo > 0) {
      if (_currentCharge != null) {
        _finalizeCharge(_currentCharge!, tnbTariff: tnbTariff);
        _currentCharge = null;
        _persistInFlight();
      }
      return;
    }

    final bool isStationary = dOdo == 0;

    // Detect charging: direct hardware flag or stationary SoC rise
    if (hwCharging || (isStationary && dSoc > 0)) {
      final bool isDc = powerKw > 22.0;

      if (_currentCharge == null) {
        _currentCharge = InFlightCharge(
          startTs: _lastTelemetryTs ?? now,
          startSoc: _lastSoc ?? soc,
          lastRiseTs: now,
          maxSoc: soc,
          peakKw: powerKw,
          sampleCount: 1,
          isDcFast: isDc,
        );
      } else {
        if (soc > _currentCharge!.maxSoc) {
          _currentCharge!.maxSoc = soc;
          _currentCharge!.lastRiseTs = now;
        }
        if (powerKw > _currentCharge!.peakKw) {
          _currentCharge!.peakKw = powerKw;
        }
        if (isDc) _currentCharge!.isDcFast = true;
        _currentCharge!.sampleCount++;
      }
      _persistInFlight();
    } else if (_currentCharge != null) {
      // Parked without charging flag or rise
      final idleSec = now.difference(_currentCharge!.lastRiseTs).inSeconds;
      final bool socDropped = soc < _currentCharge!.maxSoc - 1;

      // Unplugged or 30 minutes idle => session done
      if (idleSec > idleGapSeconds || socDropped) {
        _finalizeCharge(_currentCharge!, tnbTariff: tnbTariff);
        _currentCharge = null;
        _persistInFlight();
      }
    }
  }

  void _checkTimeouts() {
    final now = DateTime.now();

    // Check if in-flight trip timed out while stationary
    if (_currentTrip != null) {
      final parkedSec = now.difference(_currentTrip!.lastMoveTs).inSeconds;
      if (parkedSec > tripGapSeconds) {
        _finalizeTrip(_currentTrip!);
        _currentTrip = null;
        _persistInFlight();
      }
    }

    // Check if in-flight charging session timed out
    if (_currentCharge != null) {
      final idleSec = now.difference(_currentCharge!.lastRiseTs).inSeconds;
      if (idleSec > idleGapSeconds) {
        _finalizeCharge(_currentCharge!);
        _currentCharge = null;
        _persistInFlight();
      }
    }
  }

  Future<void> _finalizeTrip(InFlightTrip t, {double? tnbTariff}) async {
    final distKm = (t.lastOdo - t.startOdo).toDouble();
    if (distKm < minTripDistanceKm) {
      // Ignore insignificant micro-parking shuffles (<200m)
      return;
    }

    final durSec = t.lastMoveTs.difference(t.startTs).inSeconds;
    final durMin = (durSec / 60.0).round().clamp(1, 1440);
    final avgSpeed = (distKm / (durMin / 60.0)).clamp(1.0, 180.0);

    // Energy calculation
    final socDrop = (t.startSoc - t.lastSoc).clamp(0, 100);
    final kwhUsed = (socDrop / 100.0) * batteryCapacityKwh;
    final tariff = tnbTariff ?? 0.57; // Default TNB Home Tariff RM 0.57/kWh
    final costRm = kwhUsed * tariff;

    // EV distance attribution
    final double evKm = socDrop > 0 ? distKm : 0.0;
    final double hevKm = distKm - evKm;

    final String fromStr = t.startLocation ?? 'Start Point';
    final String toStr = t.lastLocation ?? 'Destination';
    final String title = fromStr == toStr || toStr == 'Destination'
        ? '🚗 Trip ($fromStr)'
        : '🚗 $fromStr ➔ $toStr';

    final now = DateTime.now();
    final tripRecord = TripRecord(
      id: 'auto_trip_${now.millisecondsSinceEpoch}',
      title: title,
      timestamp: _formatTimestamp(t.startTs),
      distanceKm: double.parse(distKm.toStringAsFixed(1)),
      durationMinutes: durMin,
      evDistanceKm: double.parse(evKm.toStringAsFixed(1)),
      hevDistanceKm: double.parse(hevKm.toStringAsFixed(1)),
      electricKwh: double.parse(kwhUsed.toStringAsFixed(2)),
      petrolLitres: 0.0,
      costRm: double.parse(costRm.toStringAsFixed(2)),
      avgSpeedKmh: double.parse(avgSpeed.toStringAsFixed(1)),
      highwayNote: '${avgSpeed.toStringAsFixed(0)} km/h avg • ${socDrop > 0 ? '$socDrop% battery used' : 'Hybrid cruise'}',
      routePoints: const [
        Offset(0.15, 0.50),
        Offset(0.35, 0.40),
        Offset(0.65, 0.42),
        Offset(0.85, 0.50),
      ],
      evPointCount: 4,
    );

    await _saveTripToStorage(tripRecord);

    // Post Alert Notification
    VehicleAlertsManager.instance.addAlert(
      VehicleAlertItem(
        id: 'trip_${now.millisecondsSinceEpoch}',
        title: 'Auto Trip Logged',
        message: '${tripRecord.title} • ${tripRecord.distanceKm} km in $durMin min (RM ${tripRecord.costRm.toStringAsFixed(2)})',
        timestamp: now,
        type: NotificationType.success,
        icon: Icons.directions_car_rounded,
        isRead: false,
      ),
    );

    notifyListeners();
  }

  Future<void> _finalizeCharge(InFlightCharge c, {double? tnbTariff}) async {
    final socGain = c.maxSoc - c.startSoc;
    final durSec = c.lastRiseTs.difference(c.startTs).inSeconds;

    // Reject regen downhill false-positives: require >=10 min or >=2% SoC gain
    if (durSec < chargeParkMinSeconds && socGain < minGainPct) {
      return;
    }

    final kwhAdded = (socGain / 100.0) * batteryCapacityKwh;
    if (kwhAdded < 0.3) {
      return; // Ignore fractional test ticks
    }

    final bool isPublic = c.isDcFast || c.peakKw > 22.0;
    final double unitRate = isPublic ? 1.30 : (tnbTariff ?? 0.57);
    final double amountRm = kwhAdded * unitRate;

    final now = DateTime.now();
    final expense = ExpenseRecord(
      id: 'auto_charge_${now.millisecondsSinceEpoch}',
      type: isPublic ? 'public_ev' : 'home_ac',
      title: isPublic
          ? '⚡ DC Fast Charge (+${socGain}% SoC)'
          : '🔌 AC Wallbox Charge (+${socGain}% SoC)',
      date: _formatDate(c.startTs),
      amountRm: double.parse(amountRm.toStringAsFixed(2)),
      units: double.parse(kwhAdded.toStringAsFixed(1)),
      unitPrice: unitRate,
      odometerKm: _lastOdo,
    );

    await _saveExpenseToStorage(expense);

    // Post Alert Notification
    VehicleAlertsManager.instance.addAlert(
      VehicleAlertItem(
        id: 'charge_${now.millisecondsSinceEpoch}',
        title: 'Auto Charge Logged',
        message: '${expense.title} • +${expense.units} kWh (RM ${expense.amountRm.toStringAsFixed(2)})',
        timestamp: now,
        type: NotificationType.success,
        icon: Icons.bolt_rounded,
        isRead: false,
      ),
    );

    notifyListeners();
  }

  Future<void> _saveTripToStorage(TripRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTripsStorageKey);
      final List<dynamic> list = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];
      list.insert(0, record.toJson());
      await prefs.setString(_kTripsStorageKey, jsonEncode(list));
      unawaited(FirebaseSyncService.instance.syncTrip(record));
    } catch (e) {
      debugPrint('Error saving auto trip: $e');
    }
  }

  Future<void> _saveExpenseToStorage(ExpenseRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kExpenseStorageKey);
      final List<dynamic> list = raw != null && raw.isNotEmpty ? jsonDecode(raw) : [];
      list.insert(0, record.toJson());
      await prefs.setString(_kExpenseStorageKey, jsonEncode(list));
      unawaited(FirebaseSyncService.instance.syncExpense(record));
    } catch (e) {
      debugPrint('Error saving auto expense: $e');
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    if (isToday) {
      return 'Today $hour:$minute $ampm';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $hour:$minute $ampm';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
