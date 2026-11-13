import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../carlinko/vehicle_telemetry.dart';

enum Volt12HealthStatus {
  healthy('Healthy', '12V battery is in prime condition'),
  fair('Fair', 'Slightly low resting voltage; monitor'),
  low('Warning (Low)', '12V battery discharging; start car or charge soon'),
  critical('Critical', 'High risk of 12V failure; jump/trickle charge required');

  final String label;
  final String description;
  const Volt12HealthStatus(this.label, this.description);
}

enum LfpBalanceStatus {
  balanced('Balanced & Calibrated', 'BMS cell voltages are well calibrated'),
  dueSoon('Balancing Due Soon', 'Consider charging to 100% on AC to balance cells'),
  overdue('Cell Balancing Due', 'LFP pack requires 100% AC soak to recalibrate BMS');

  final String label;
  final String description;
  const LfpBalanceStatus(this.label, this.description);
}

/// Battery Health & LFP Cell Balance Service
///
/// Ported from GodrezJr2/j5-ev-dashboard:
/// - 7-day rolling 12V auxiliary battery minimum voltage & status (volt12_min7d, volt12_status)
/// - Parked vampiric drain rate (% SoC lost/24h and mV lost/24h while parked)
/// - LFP pack BMS balancing tracker (days since last 100% charge)
class BatteryHealthService extends ChangeNotifier {
  static final BatteryHealthService instance = BatteryHealthService._internal();

  BatteryHealthService._internal() {
    _init();
  }

  static const String _kLast100TsKey = 'tm_batt_last_100_ts';
  static const String _kVolt12HistoryKey = 'tm_batt_volt12_history';
  static const String _kParkedSnapshotKey = 'tm_batt_parked_snapshot';

  DateTime? _last100ChargeTs;
  final List<Map<String, dynamic>> _volt12History = []; // [{'ts': ms, 'volt': double}]
  Map<String, dynamic>? _parkedSnapshot; // {'ts': ms, 'soc': int, 'volt': double}
  double? _parkedSocDrainPerDay;
  double? _parkedVoltDrainMvPerDay;
  bool _initialized = false;

  DateTime? get last100ChargeTs => _last100ChargeTs;
  double? get parkedSocDrainPerDay => _parkedSocDrainPerDay;
  double? get parkedVoltDrainMvPerDay => _parkedVoltDrainMvPerDay;

  int get daysSinceLast100 {
    if (_last100ChargeTs == null) return 7; // Default reasonable baseline if not yet recorded
    return DateTime.now().difference(_last100ChargeTs!).inDays;
  }

  LfpBalanceStatus get lfpStatus {
    final days = daysSinceLast100;
    if (days <= 7) return LfpBalanceStatus.balanced;
    if (days <= 14) return LfpBalanceStatus.dueSoon;
    return LfpBalanceStatus.overdue;
  }

  double getMinVolt12Last7Days(double currentVolt) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    double minV = currentVolt > 0 ? currentVolt : 12.6;
    for (final item in _volt12History) {
      final ts = item['ts'] as int? ?? 0;
      final v = (item['volt'] as num?)?.toDouble() ?? 0.0;
      if (ts >= cutoff && v > 5.0 && v < minV) {
        minV = v;
      }
    }
    return minV;
  }

  Volt12HealthStatus getVolt12Status(double currentVolt) {
    if (currentVolt <= 0) return Volt12HealthStatus.healthy;
    if (currentVolt >= 12.4) return Volt12HealthStatus.healthy;
    if (currentVolt >= 12.1) return Volt12HealthStatus.fair;
    if (currentVolt >= 11.8) return Volt12HealthStatus.low;
    return Volt12HealthStatus.critical;
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_kLast100TsKey);
      if (ts != null && ts > 0) {
        _last100ChargeTs = DateTime.fromMillisecondsSinceEpoch(ts);
      }
      final rawHist = prefs.getString(_kVolt12HistoryKey);
      if (rawHist != null && rawHist.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawHist);
        _volt12History.addAll(decoded.cast<Map<String, dynamic>>());
      }
      final rawParked = prefs.getString(_kParkedSnapshotKey);
      if (rawParked != null && rawParked.isNotEmpty) {
        _parkedSnapshot = jsonDecode(rawParked) as Map<String, dynamic>;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('BatteryHealthService init error: $e');
    }
  }

  /// Process incoming telemetry frame to maintain health & drain metrics
  Future<void> processTelemetry(VehicleTelemetry t) async {
    final now = t.lastUpdated;
    final int soc = t.batteryPct;
    final double volt = t.volt12;

    // 1. Auto-detect 100% full charge (LFP cell balance event)
    if (soc >= 100) {
      if (_last100ChargeTs == null || now.difference(_last100ChargeTs!).inHours >= 12) {
        _last100ChargeTs = now;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kLast100TsKey, now.millisecondsSinceEpoch);
        notifyListeners();
      }
    }

    // 2. 12V voltage rolling record
    if (volt > 5.0 && volt < 16.0) {
      final cutoff = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      _volt12History.removeWhere((item) => (item['ts'] as int? ?? 0) < cutoff);

      final lastRecordedTs = _volt12History.isNotEmpty
          ? (_volt12History.last['ts'] as int? ?? 0)
          : 0;
      // Record once every 15 minutes to save storage
      if (now.millisecondsSinceEpoch - lastRecordedTs > 15 * 60 * 1000) {
        _volt12History.add({
          'ts': now.millisecondsSinceEpoch,
          'volt': double.parse(volt.toStringAsFixed(2)),
        });
        _persistVolt12History();
      }
    }

    // 3. Parked vampiric drain calculation
    if (t.isParked && !t.isCharging && t.speedKmH <= 0.5) {
      if (_parkedSnapshot == null) {
        // Start new parked measurement session
        _parkedSnapshot = {
          'ts': now.millisecondsSinceEpoch,
          'soc': soc,
          'volt': volt,
        };
        _persistParkedSnapshot();
      } else {
        final startTs = _parkedSnapshot!['ts'] as int? ?? 0;
        final startSoc = _parkedSnapshot!['soc'] as int? ?? soc;
        final startVolt = (_parkedSnapshot!['volt'] as num?)?.toDouble() ?? volt;
        final elapsedHours = (now.millisecondsSinceEpoch - startTs) / (3600.0 * 1000.0);

        if (elapsedHours >= 2.0 && soc <= startSoc) {
          final socDelta = (startSoc - soc).toDouble();
          final voltDeltaMv = (startVolt - volt) * 1000.0;
          _parkedSocDrainPerDay = (socDelta / elapsedHours) * 24.0;
          _parkedVoltDrainMvPerDay = (voltDeltaMv / elapsedHours) * 24.0;
          notifyListeners();
        }
      }
    } else {
      // Vehicle is moving or charging -> reset parked snapshot
      if (_parkedSnapshot != null) {
        _parkedSnapshot = null;
        _persistParkedSnapshot();
      }
    }
  }

  /// Manually mark that the battery was charged to 100% today
  Future<void> mark100PercentChargedNow() async {
    _last100ChargeTs = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLast100TsKey, _last100ChargeTs!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> _persistVolt12History() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kVolt12HistoryKey, jsonEncode(_volt12History));
    } catch (_) {}
  }

  Future<void> _persistParkedSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_parkedSnapshot != null) {
        await prefs.setString(_kParkedSnapshotKey, jsonEncode(_parkedSnapshot));
      } else {
        await prefs.remove(_kParkedSnapshotKey);
      }
    } catch (_) {}
  }
}
