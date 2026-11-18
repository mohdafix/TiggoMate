import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../mytnb/mytnb_api.dart';
import 'mytnb_connect_dialog.dart';
import 'app_notification.dart';
import 'daily_km_bar_painter.dart';
import '../theme/app_tokens.dart';
import '../firebase/firebase_sync_service.dart';
import '../service/auto_trip_and_charge_service.dart';

/// Model representing a completed PHEV trip.
class TripRecord {
  final String id;
  final String title;
  final String timestamp;
  final double distanceKm;
  final int durationMinutes;
  final double evDistanceKm;
  final double hevDistanceKm;
  final double electricKwh;
  final double petrolLitres;
  final double costRm;
  final double avgSpeedKmh;
  final String highwayNote;
  final List<Offset> routePoints; // Normalized 0.0-1.0 coords for canvas map
  final int evPointCount; // Points driven on EV

  const TripRecord({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.distanceKm,
    required this.durationMinutes,
    required this.evDistanceKm,
    required this.hevDistanceKm,
    required this.electricKwh,
    required this.petrolLitres,
    required this.costRm,
    required this.avgSpeedKmh,
    required this.highwayNote,
    required this.routePoints,
    required this.evPointCount,
  });

  double get evRatio => distanceKm > 0 ? (evDistanceKm / distanceKm) * 100 : 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'timestamp': timestamp,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'evDistanceKm': evDistanceKm,
        'hevDistanceKm': hevDistanceKm,
        'electricKwh': electricKwh,
        'petrolLitres': petrolLitres,
        'costRm': costRm,
        'avgSpeedKmh': avgSpeedKmh,
        'highwayNote': highwayNote,
        'routePoints': routePoints.map((p) => [p.dx, p.dy]).toList(),
        'evPointCount': evPointCount,
      };

  factory TripRecord.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['routePoints'] as List<dynamic>? ?? [];
    final points = rawPoints.map((item) {
      final list = item as List<dynamic>;
      return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
    }).toList();

    return TripRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      timestamp: json['timestamp'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationMinutes: json['durationMinutes'] as int,
      evDistanceKm: (json['evDistanceKm'] as num).toDouble(),
      hevDistanceKm: (json['hevDistanceKm'] as num).toDouble(),
      electricKwh: (json['electricKwh'] as num).toDouble(),
      petrolLitres: (json['petrolLitres'] as num).toDouble(),
      costRm: (json['costRm'] as num).toDouble(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num).toDouble(),
      highwayNote: json['highwayNote'] as String,
      routePoints: points,
      evPointCount: json['evPointCount'] as int? ?? points.length,
    );
  }
}

/// Model representing a logged expense (Petrol, Home AC, or Public EV).
class ExpenseRecord {
  final String id;
  final String type; // 'petrol', 'home_ac', 'public_ev'
  final String title;
  final String date;
  final double amountRm;
  final double units; // Litres or kWh
  final double unitPrice; // RM/L or RM/kWh
  final int? odometerKm;

  const ExpenseRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.amountRm,
    required this.units,
    required this.unitPrice,
    this.odometerKm,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'date': date,
        'amountRm': amountRm,
        'units': units,
        'unitPrice': unitPrice,
        'odometerKm': odometerKm,
      };

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        date: json['date'] as String,
        amountRm: (json['amountRm'] as num).toDouble(),
        units: (json['units'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        odometerKm: json['odometerKm'] as int?,
      );
}

/// Preset for Malaysian Public Charging Stations
class PublicChargingPreset {
  final String stationName;
  final String network;
  final String powerInfo;
  final double defaultKwh;
  final double defaultCostRm;
  final String rateDescription;

  const PublicChargingPreset({
    required this.stationName,
    required this.network,
    required this.powerInfo,
    required this.defaultKwh,
    required this.defaultCostRm,
    required this.rateDescription,
  });
}

const List<PublicChargingPreset> kMalaysianChargingStations = [
  PublicChargingPreset(
    stationName: 'Suria KLCC P2',
    network: 'Gentari',
    powerInfo: '7 kW AC Wallbox',
    defaultKwh: 12.0,
    defaultCostRm: 10.80,
    rateDescription: 'RM 0.18 / min (~RM 10.80 full charge)',
  ),
  PublicChargingPreset(
    stationName: 'Mid Valley Megamall P1',
    network: 'ChargEV',
    powerInfo: '11 kW AC Type 2',
    defaultKwh: 15.0,
    defaultCostRm: 12.00,
    rateDescription: 'RM 0.80 / kWh (~RM 12.00 for 15 kWh)',
  ),
  PublicChargingPreset(
    stationName: 'Sunway Pyramid Oasis P4',
    network: 'JomCharge',
    powerInfo: '11 kW AC Type 2',
    defaultKwh: 14.5,
    defaultCostRm: 14.50,
    rateDescription: 'RM 1.00 / kWh (~RM 14.50 top-up)',
  ),
  PublicChargingPreset(
    stationName: 'PLUS R&R Ayer Keroh (Southbound)',
    network: 'Gentari',
    powerInfo: '60 kW DC / 11 kW AC',
    defaultKwh: 16.0,
    defaultCostRm: 22.40,
    rateDescription: 'RM 1.40 / kWh (Highway DC Fast)',
  ),
  PublicChargingPreset(
    stationName: 'PLUS R&R Tapah (Northbound)',
    network: 'ChargEV',
    powerInfo: '50 kW DC Fast',
    defaultKwh: 15.0,
    defaultCostRm: 18.00,
    rateDescription: 'RM 1.20 / kWh (Highway Fast)',
  ),
  PublicChargingPreset(
    stationName: 'IOI City Mall Putrajaya',
    network: 'DC Handal',
    powerInfo: '47 kW DC Fast',
    defaultKwh: 13.0,
    defaultCostRm: 16.90,
    rateDescription: 'RM 1.30 / kWh (Autopay available)',
  ),
  PublicChargingPreset(
    stationName: 'Pavilion Bukit Jalil B1',
    network: 'JomCharge',
    powerInfo: '11 kW AC Type 2',
    defaultKwh: 11.0,
    defaultCostRm: 12.10,
    rateDescription: 'RM 1.10 / kWh (~RM 12.10 session)',
  ),
  PublicChargingPreset(
    stationName: 'Bangsar Village II Ground',
    network: 'Gentari',
    powerInfo: '7 kW AC Wallbox',
    defaultKwh: 8.5,
    defaultCostRm: 8.16,
    rateDescription: 'RM 0.16 / min (~RM 8.16 for 50 min)',
  ),
];

/// Malaysian Real-World Trip Presets for Chery Tiggo 7 PHEV
const List<TripRecord> kMalaysianTripPresets = [
  TripRecord(
    id: 'preset_office',
    title: '🏢 Office Commute (Damansara ➔ KLCC)',
    timestamp: 'Today 08:30 AM',
    distanceKm: 16.8,
    durationMinutes: 28,
    evDistanceKm: 16.8,
    hevDistanceKm: 0.0,
    electricKwh: 2.4,
    petrolLitres: 0.0,
    costRm: 1.37,
    avgSpeedKmh: 36.0,
    highwayNote: 'Sprint / Kerinchi • 100% Pure EV',
    routePoints: [
      Offset(0.20, 0.45),
      Offset(0.35, 0.42),
      Offset(0.50, 0.40),
      Offset(0.68, 0.38),
      Offset(0.80, 0.42),
    ],
    evPointCount: 5,
  ),
  TripRecord(
    id: 'preset_airport',
    title: '✈️ Airport Run (PJ ➔ KLIA T1/T2)',
    timestamp: 'Today 11:15 AM',
    distanceKm: 58.0,
    durationMinutes: 46,
    evDistanceKm: 34.8,
    hevDistanceKm: 23.2,
    electricKwh: 5.6,
    petrolLitres: 1.6,
    costRm: 6.47,
    avgSpeedKmh: 76.0,
    highwayNote: 'MEX / ELITE Highway • 60% EV / 40% HEV',
    routePoints: [
      Offset(0.25, 0.20),
      Offset(0.35, 0.32),
      Offset(0.48, 0.45),
      Offset(0.55, 0.62),
      Offset(0.65, 0.85),
    ],
    evPointCount: 3,
  ),
  TripRecord(
    id: 'preset_genting',
    title: '🏔️ Genting Highlands Hill Climb',
    timestamp: 'Weekend 09:00 AM',
    distanceKm: 54.0,
    durationMinutes: 52,
    evDistanceKm: 13.5,
    hevDistanceKm: 40.5,
    electricKwh: 6.5,
    petrolLitres: 3.8,
    costRm: 11.50,
    avgSpeedKmh: 62.0,
    highwayNote: 'Karak Highway • 25% EV / 75% HEV (Sport Mode)',
    routePoints: [
      Offset(0.20, 0.80),
      Offset(0.40, 0.65),
      Offset(0.55, 0.50),
      Offset(0.70, 0.35),
      Offset(0.85, 0.18),
    ],
    evPointCount: 2,
  ),
  TripRecord(
    id: 'preset_mall',
    title: '🛒 Mid Valley / 1 Utama Mall Run',
    timestamp: 'Yesterday 02:20 PM',
    distanceKm: 11.4,
    durationMinutes: 22,
    evDistanceKm: 11.4,
    hevDistanceKm: 0.0,
    electricKwh: 1.6,
    petrolLitres: 0.0,
    costRm: 0.91,
    avgSpeedKmh: 31.0,
    highwayNote: 'Federal Highway • 100% Pure EV',
    routePoints: [
      Offset(0.30, 0.60),
      Offset(0.45, 0.55),
      Offset(0.60, 0.58),
    ],
    evPointCount: 3,
  ),
  TripRecord(
    id: 'preset_ipoh',
    title: '🚗 Balik Kampung (PJ ➔ Ipoh)',
    timestamp: '11 Oct 2026',
    distanceKm: 205.0,
    durationMinutes: 135,
    evDistanceKm: 72.0,
    hevDistanceKm: 133.0,
    electricKwh: 12.0,
    petrolLitres: 9.2,
    costRm: 25.70,
    avgSpeedKmh: 91.0,
    highwayNote: 'PLUS Highway • 35% EV / 65% Hybrid',
    routePoints: [
      Offset(0.50, 0.85),
      Offset(0.52, 0.70),
      Offset(0.48, 0.50),
      Offset(0.46, 0.30),
      Offset(0.44, 0.15),
    ],
    evPointCount: 2,
  ),
  TripRecord(
    id: 'preset_kuantan',
    title: '🌴 East Coast Highway (KL ➔ Kuantan)',
    timestamp: '05 Oct 2026',
    distanceKm: 245.0,
    durationMinutes: 165,
    evDistanceKm: 58.0,
    hevDistanceKm: 187.0,
    electricKwh: 10.5,
    petrolLitres: 12.8,
    costRm: 32.22,
    avgSpeedKmh: 89.0,
    highwayNote: 'LPT Highway • 24% EV / 76% Hybrid',
    routePoints: [
      Offset(0.15, 0.65),
      Offset(0.35, 0.50),
      Offset(0.55, 0.42),
      Offset(0.75, 0.38),
      Offset(0.90, 0.35),
    ],
    evPointCount: 2,
  ),
];

class TripsLogbookScreen extends StatefulWidget {
  final double tnbTariff;
  final double fuelPrice;
  final int currentOdometerKm;
  final int currentBatteryPct;
  final MyTnbRepository? myTnbRepo;

  const TripsLogbookScreen({
    super.key,
    this.tnbTariff = 0.57,
    this.fuelPrice = 2.05,
    this.currentOdometerKm = 1420,
    this.currentBatteryPct = 78,
    this.myTnbRepo,
  });

  @override
  State<TripsLogbookScreen> createState() => _TripsLogbookScreenState();
}

/// IDs of the sample trips older builds seeded, which could get saved alongside real data.
const Set<String> kLegacySampleTripIds = {'trip_1', 'trip_2', 'trip_3', 'trip_4'};

final RegExp _epochMsPattern = RegExp(r'\d{13}');

/// Real records carry their creation time in the ID, as epoch milliseconds.
DateTime recordTimeFromId(String id) {
  final match = _epochMsPattern.firstMatch(id);
  return match == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(int.parse(match.group(0)!));
}

/// The most recent trip saved on this device, or null when none has been logged.
Future<TripRecord?> loadLatestSavedTrip() async {
  final trips = await loadRecentTrips(limit: 1);
  return trips.isEmpty ? null : trips.first;
}

/// Up to [limit] most recent real (non-sample) trips saved on this device,
/// newest first.
Future<List<TripRecord>> loadRecentTrips({int limit = 10}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_TripsLogbookScreenState._kTripsStorageKey);
    if (raw == null || raw.isEmpty) return const [];
    final trips = (jsonDecode(raw) as List<dynamic>)
        .map((t) => TripRecord.fromJson(t as Map<String, dynamic>))
        .where((t) => !kLegacySampleTripIds.contains(t.id))
        .toList();
    if (trips.isEmpty) return const [];
    trips.sort((a, b) => recordTimeFromId(b.id).compareTo(recordTimeFromId(a.id)));
    return trips.take(limit).toList();
  } catch (_) {
    return const [];
  }
}

/// Formatted summary of recent driving trips & active trip for AI Copilot context injection.
Future<String> getTripSummaryForAi({int limit = 5}) async {
  final parts = <String>[];

  // 1. Check in-flight active trip from AutoTripAndChargeService
  try {
    final active = AutoTripAndChargeService.instance.activeTrip;
    if (active != null) {
      final elapsedMin = DateTime.now().difference(active.startTs).inMinutes;
      final startLoc = (active.startLocation != null && active.startLocation!.isNotEmpty)
          ? active.startLocation!
          : 'Origin';
      final currentDist = (active.lastOdo - active.startOdo).clamp(0, 9999);
      parts.add('Active Drive in Progress: Started at ${active.startTs.hour.toString().padLeft(2, '0')}:${active.startTs.minute.toString().padLeft(2, '0')} '
          'from $startLoc (~$elapsedMin min ago, distance so far: ~$currentDist km, start battery: ${active.startSoc}%).');
    }
  } catch (_) {}

  // 2. Load recent saved trips
  final trips = await loadRecentTrips(limit: limit);
  if (trips.isNotEmpty) {
    final last = trips.first;
    final energy = [
      if (last.electricKwh > 0) '${last.electricKwh.toStringAsFixed(1)} kWh EV',
      if (last.petrolLitres > 0) '${last.petrolLitres.toStringAsFixed(1)}L petrol',
    ].join(', ');
    parts.add('Latest Completed Trip: "${last.title}" (${last.timestamp})'
        '\n    - Distance: ${last.distanceKm.toStringAsFixed(1)} km'
        '\n    - Duration: ${last.durationMinutes} min (Avg speed: ${last.avgSpeedKmh.toStringAsFixed(0)} km/h)'
        '\n    - Powertrain Split: ${last.evRatio.round()}% EV (${last.evDistanceKm.toStringAsFixed(1)} km EV${last.hevDistanceKm > 0 ? ", ${last.hevDistanceKm.toStringAsFixed(1)} km HEV" : ""})'
        '${energy.isNotEmpty ? "\n    - Energy Consumed: $energy" : ""}'
        '\n    - Cost: RM ${last.costRm.toStringAsFixed(2)}'
        '${last.highwayNote.isNotEmpty ? "\n    - Notes: ${last.highwayNote}" : ""}');

    if (trips.length > 1) {
      parts.add('Previous Logged Trips:');
      for (final t in trips.skip(1)) {
        parts.add('- "${t.title}" (${t.timestamp}): ${t.distanceKm.toStringAsFixed(1)} km, ${t.evRatio.round()}% EV, RM ${t.costRm.toStringAsFixed(2)}');
      }
    }
  } else {
    parts.add('No completed trips recorded yet in the logbook (user can tap "+ Add Trip" in the LOG tab or let Auto-Trip detect drives when connected).');
  }

  return parts.join('\n  ');
}

/// One row of the logbook's ENTRIES list: a trip or an expense.
class _LogEntry {
  final DateTime when;
  final String title;
  final String detail;
  final String value;
  final bool isEv;

  const _LogEntry({
    required this.when,
    required this.title,
    required this.detail,
    required this.value,
    required this.isEv,
  });
}

class _TripsLogbookScreenState extends State<TripsLogbookScreen> {
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // IDs of the sample records older builds seeded, which could get saved alongside real data.
  static const Set<String> _sampleTripIds = kLegacySampleTripIds;
  static const Set<String> _sampleExpenseIds = {'exp_1', 'exp_2'};

  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String get _selectedMonth => '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}';
  List<TripRecord> _trips = [];
  List<ExpenseRecord> _customExpenses = [];

  static const String _kExpenseStorageKey = 'tm_logged_expenses_v2';
  static const String _kTripsStorageKey = 'tm_logged_trips_v2';

  @override
  void initState() {
    super.initState();
    _loadStoredData();
    AutoTripAndChargeService.instance.addListener(_onAutoUpdate);
  }

  void _onAutoUpdate() {
    if (mounted) _loadStoredData();
  }

  @override
  void dispose() {
    AutoTripAndChargeService.instance.removeListener(_onAutoUpdate);
    super.dispose();
  }

  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final rawExpenses = prefs.getString(_kExpenseStorageKey);
      if (rawExpenses != null && rawExpenses.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawExpenses);
        setState(() {
          _customExpenses = decoded
              .map((e) => ExpenseRecord.fromJson(e as Map<String, dynamic>))
              .where((e) => !_sampleExpenseIds.contains(e.id))
              .toList();
        });
      }

      final rawTrips = prefs.getString(_kTripsStorageKey);
      if (rawTrips != null && rawTrips.isNotEmpty) {
        final List<dynamic> decodedTrips = jsonDecode(rawTrips);
        final loaded = decodedTrips
            .map((t) => TripRecord.fromJson(t as Map<String, dynamic>))
            .where((t) => !_sampleTripIds.contains(t.id))
            .toList();
        setState(() {
          _trips = loaded;
        });
      }
      unawaited(_syncFromCloud());
    } catch (_) {}
  }

  Future<void> _saveExpense(ExpenseRecord record) async {
    setState(() {
      _customExpenses.insert(0, record);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_customExpenses.map((e) => e.toJson()).toList());
      await prefs.setString(_kExpenseStorageKey, encoded);
    } catch (_) {}
    unawaited(FirebaseSyncService.instance.syncExpense(record));
  }

  Future<void> _syncFromCloud() async {
    try {
      final cloudTrips = await FirebaseSyncService.instance.fetchTrips();
      final cloudExpenses = await FirebaseSyncService.instance.fetchExpenses();
      if (mounted && (cloudTrips.isNotEmpty || cloudExpenses.isNotEmpty)) {
        bool tripsAdded = false;
        bool expAdded = false;
        setState(() {
          final existingTripIds = _trips.map((t) => t.id).toSet();
          for (final t in cloudTrips) {
            if (!existingTripIds.contains(t.id) && !_sampleTripIds.contains(t.id)) {
              _trips.add(t);
              tripsAdded = true;
            }
          }
          final existingExpIds = _customExpenses.map((e) => e.id).toSet();
          for (final e in cloudExpenses) {
            if (!existingExpIds.contains(e.id) && !_sampleExpenseIds.contains(e.id)) {
              _customExpenses.add(e);
              expAdded = true;
            }
          }
        });

        // Persist restored cloud items to local storage so they remain available offline
        if (tripsAdded || expAdded) {
          try {
            final prefs = await SharedPreferences.getInstance();
            if (tripsAdded) {
              final encoded = jsonEncode(_trips.map((t) => t.toJson()).toList());
              await prefs.setString(_kTripsStorageKey, encoded);
            }
            if (expAdded) {
              final encoded = jsonEncode(_customExpenses.map((e) => e.toJson()).toList());
              await prefs.setString(_kExpenseStorageKey, encoded);
            }
            debugPrint('[TripsLogbook] Restored cloud records cached to offline storage');
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _saveTrip(TripRecord trip) async {
    setState(() {
      _trips.insert(0, trip);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_trips.map((t) => t.toJson()).toList());
      await prefs.setString(_kTripsStorageKey, encoded);
    } catch (_) {}
    unawaited(FirebaseSyncService.instance.syncTrip(trip));
  }

  DateTime _recordTime(String id) => recordTimeFromId(id);

  bool _isInViewMonth(DateTime when) => when.year == _viewMonth.year && when.month == _viewMonth.month;

  List<TripRecord> get _monthTrips => _trips.where((t) => _isInViewMonth(_recordTime(t.id))).toList();

  List<ExpenseRecord> get _monthExpenses => _customExpenses.where((e) => _isInViewMonth(_recordTime(e.id))).toList();

  bool get _isViewingCurrentMonth {
    final now = DateTime.now();
    return _viewMonth.year == now.year && _viewMonth.month == now.month;
  }

  void _shiftViewMonth(int delta) {
    setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta));
  }

  /// Trips and expenses for the viewed month, newest first.
  List<_LogEntry> get _monthEntries {
    final entries = <_LogEntry>[
      for (final t in _monthTrips)
        _LogEntry(
          when: _recordTime(t.id),
          title: t.title,
          detail: [
            '${_formatKm(t.distanceKm)} km',
            '${t.evRatio.round()}% EV',
            if (t.electricKwh > 0) '${t.electricKwh.toStringAsFixed(1)} kWh',
            if (t.petrolLitres > 0) '${t.petrolLitres.toStringAsFixed(1)} L',
          ].join(' · '),
          value: '${_formatKm(t.distanceKm)} km',
          isEv: t.evRatio >= 50,
        ),
      for (final e in _monthExpenses)
        _LogEntry(
          when: _recordTime(e.id),
          title: e.title,
          detail: '${e.units.toStringAsFixed(1)} ${e.type == 'petrol' ? 'L' : 'kWh'} @ RM ${e.unitPrice.toStringAsFixed(2)}',
          value: 'RM ${e.amountRm.toStringAsFixed(2)}',
          isEv: e.type != 'petrol',
        ),
    ];
    entries.sort((a, b) => b.when.compareTo(a.when));
    return entries;
  }

  String _formatKm(double km) => km.toStringAsFixed(km % 1 == 0 ? 0 : 1);

  String _formatEntryDate(DateTime when) => '${when.day} ${_monthNames[when.month - 1].substring(0, 3)}';

  // Monthly Aggregates
  double get _totalDistanceKm {
    return _monthTrips.fold(0.0, (acc, t) => acc + t.distanceKm);
  }

  double get _totalEvDistanceKm {
    return _monthTrips.fold(0.0, (acc, t) => acc + t.evDistanceKm);
  }

  double get _homeAcSpend {
    return _monthExpenses.where((e) => e.type == 'home_ac').fold(0.0, (acc, e) => acc + e.amountRm);
  }

  double get _petrolSpend {
    return _monthExpenses.where((e) => e.type == 'petrol').fold(0.0, (acc, e) => acc + e.amountRm);
  }

  double get _publicEvSpend {
    return _monthExpenses.where((e) => e.type == 'public_ev').fold(0.0, (acc, e) => acc + e.amountRm);
  }

  double get _totalSpend => _homeAcSpend + _petrolSpend + _publicEvSpend;

  // Real-world comparison vs equivalent 1.5L Turbo ICE SUV running 7.8 L/100km at RM 2.05/L
  double get _monthlySavings {
    if (_totalDistanceKm <= 0) return 0.0;
    final iceLitres = (_totalDistanceKm / 100.0) * 7.8;
    final iceCost = iceLitres * widget.fuelPrice;
    final diff = iceCost - _totalSpend;
    return diff > 0 ? diff : 0.0;
  }

  void _showAddTripPresetModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.resolvedContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl)),
      ),
      builder: (ctx) => _AddTripPresetSheet(
        onSelectPreset: (preset) {
          final newTrip = TripRecord(
            id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
            title: preset.title,
            timestamp: 'Just now',
            distanceKm: preset.distanceKm,
            durationMinutes: preset.durationMinutes,
            evDistanceKm: preset.evDistanceKm,
            hevDistanceKm: preset.hevDistanceKm,
            electricKwh: preset.electricKwh,
            petrolLitres: preset.petrolLitres,
            costRm: preset.costRm,
            avgSpeedKmh: preset.avgSpeedKmh,
            highwayNote: preset.highwayNote,
            routePoints: preset.routePoints,
            evPointCount: preset.evPointCount,
          );
          _saveTrip(newTrip);
          AppNotification.show(
            context,
            message: 'Added Trip: ${newTrip.title} (${newTrip.distanceKm} km)',
            type: NotificationType.success,
            icon: Icons.add_road_rounded,
          );
        },
      ),
    );
  }

  void _showLogModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.resolvedContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl)),
      ),
      builder: (ctx) => _SmartExpenseSheet(
        fuelPrice: widget.fuelPrice,
        tnbTariff: widget.tnbTariff,
        currentOdometer: widget.currentOdometerKm,
        currentBatteryPct: widget.currentBatteryPct,
        myTnbRepo: widget.myTnbRepo,
        onSave: (rec) {
          _saveExpense(rec);
          AppNotification.show(
            context,
            message: 'Logged ${rec.title} (RM ${rec.amountRm.toStringAsFixed(2)})',
            type: NotificationType.success,
            icon: Icons.receipt_long_rounded,
          );
        },
      ),
    );
  }

  void _showExportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.resolvedContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl)),
      ),
      builder: (ctx) => _ExportLogbookModal(
        selectedMonth: _selectedMonth,
        totalDistanceKm: _totalDistanceKm,
        totalSpend: _totalSpend,
        homeAcSpend: _homeAcSpend,
        petrolSpend: _petrolSpend,
        publicEvSpend: _publicEvSpend,
        monthlySavings: _monthlySavings,
        trips: _monthTrips,
        expenses: _monthExpenses,
      ),
    );
  }

  int _cyberEntryFilter = 0; // 0: ALL, 1: EV, 2: FUEL

  @override
  Widget build(BuildContext context) {
    return _buildCyberLogbook(context);
  }

  Widget _buildCyberLogbook(BuildContext context) {
    final t = context.tokens;
    final bgCol = t.bg;
    final cardCol = t.resolvedContainerLow;
    final borderCol = t.border;
    final textMuted = t.ink2;
    final textPrimary = t.ink;
    final limeAccent = t.accent;
    const orangeAccent = Color(0xFFFF6E40);

    final totalKm = _totalDistanceKm;
    final distanceText = totalKm.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
    final spendText = _totalSpend.toStringAsFixed(_totalSpend < 10 ? 2 : 0);
    final evShareText = totalKm > 0 ? '${(_totalEvDistanceKm / totalKm * 100).round()}%' : '--';

    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final dailyEvKm = List<double>.filled(daysInMonth, 0.0);
    final dailyFuelKm = List<double>.filled(daysInMonth, 0.0);
    for (final t in _monthTrips) {
      final dayIndex = _recordTime(t.id).day - 1;
      dailyEvKm[dayIndex] += t.evDistanceKm;
      dailyFuelKm[dayIndex] += t.hevDistanceKm;
    }

    final visibleEntries = _monthEntries.where((e) {
      if (_cyberEntryFilter == 1) return e.isEv;
      if (_cyberEntryFilter == 2) return !e.isEv;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: [
            // 1. TOP HEADER: LOG + October 2026 + Month Switcher + Export
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOG',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedMonth,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'CAN-BUS AUTO TRIP & CHARGE ACTIVE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: textMuted, size: 22),
                      tooltip: 'Previous month',
                      onPressed: () => _shiftViewMonth(-1),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: textMuted, size: 22),
                      tooltip: 'Next month',
                      onPressed: _isViewingCurrentMonth ? null : () => _shiftViewMonth(1),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(Icons.south_rounded, color: textMuted, size: 18),
                      tooltip: 'Export CSV / PDF',
                      onPressed: _showExportModal,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. 3 KPI TILES: DISTANCE | SPEND | EV SHARE
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DISTANCE', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, fontWeight: FontWeight.w600, color: textMuted)),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
                            children: [
                              TextSpan(text: distanceText),
                              const TextSpan(text: ' km', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SPEND', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, fontWeight: FontWeight.w600, color: textMuted)),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
                            children: [
                              const TextSpan(text: 'RM '),
                              TextSpan(text: spendText),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EV SHARE', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, fontWeight: FontWeight.w600, color: textMuted)),
                        const SizedBox(height: 4),
                        Text(evShareText, style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800, color: limeAccent)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. DAILY KM STACKED BAR CHART
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DAILY KM',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: textMuted,
                  ),
                ),
                Row(
                  children: [
                    Container(width: 7, height: 7, color: limeAccent),
                    const SizedBox(width: 4),
                    Text('EV', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: textMuted)),
                    const SizedBox(width: 12),
                    Container(width: 7, height: 7, color: orangeAccent),
                    const SizedBox(width: 4),
                    Text('Fuel', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chart Canvas using DailyKmBarPainter
            SizedBox(
              height: 110,
              child: CustomPaint(
                painter: DailyKmBarPainter(
                  dailyEvKm: dailyEvKm,
                  dailyFuelKm: dailyFuelKm,
                  limeAccent: limeAccent,
                  orangeAccent: orangeAccent,
                  gridLineColor: borderCol,
                  textMuted: textMuted,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 4. QUICK ACTION BUTTONS: [ + Trip ] [ + Fuel ] [ + Charge ]
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showAddTripPresetModal,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderCol),
                      backgroundColor: cardCol,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('+ Trip', style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showLogModal,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderCol),
                      backgroundColor: cardCol,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('+ Fuel', style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showLogModal,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderCol),
                      backgroundColor: cardCol,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('+ Charge', style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // 5. ENTRIES HEADER & FILTER PILLS: ALL · EV · FUEL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ENTRIES',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: textMuted,
                  ),
                ),
                Row(
                  children: [
                    _buildLogFilterPill('ALL', 0, limeAccent, textPrimary, textMuted),
                    Text(' · ', style: TextStyle(color: textMuted, fontSize: 11)),
                    _buildLogFilterPill('EV', 1, limeAccent, textPrimary, textMuted),
                    Text(' · ', style: TextStyle(color: textMuted, fontSize: 11)),
                    _buildLogFilterPill('FUEL', 2, limeAccent, textPrimary, textMuted),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 6. LOG ENTRIES LIST
            if (visibleEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No entries this month',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: textMuted),
                ),
              ),
            for (final entry in visibleEntries)
              _buildCyberEntryItem(
                date: _formatEntryDate(entry.when),
                title: entry.title,
                detail: entry.detail,
                value: entry.value,
                isEv: entry.isEv,
                limeAccent: limeAccent,
                orangeAccent: orangeAccent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                cardCol: cardCol,
                borderCol: borderCol,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogFilterPill(String label, int index, Color limeAccent, Color textPrimary, Color textMuted) {
    final isSel = _cyberEntryFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _cyberEntryFilter = index),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
          color: isSel ? limeAccent : textMuted,
        ),
      ),
    );
  }

  Widget _buildCyberEntryItem({
    required String date,
    required String title,
    required String detail,
    required String value,
    required bool isEv,
    required Color limeAccent,
    required Color orangeAccent,
    required Color textPrimary,
    required Color textMuted,
    required Color cardCol,
    required Color borderCol,
  }) {
    if (_cyberEntryFilter == 1 && !isEv) return const SizedBox.shrink();
    if (_cyberEntryFilter == 2 && isEv) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Date
          SizedBox(
            width: 52,
            child: Text(
              date,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: textMuted),
            ),
          ),
          // Dot
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEv ? limeAccent : orangeAccent,
              ),
            ),
          ),
          // Title + Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Value (Right)
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- 1-TAP MALAYSIAN TRIP PRESET SHEET ----------------
class _AddTripPresetSheet extends StatelessWidget {
  final Function(TripRecord) onSelectPreset;

  const _AddTripPresetSheet({required this.onSelectPreset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Trip from Malaysian Presets',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.tokens.ink,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.tokens.ink3, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            'Tap any route to immediately record the trip with zero manual entry.',
            style: TextStyle(fontSize: 11.5, color: context.tokens.ink3),
          ),
          const SizedBox(height: 14),

          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: kMalaysianTripPresets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final preset = kMalaysianTripPresets[idx];
                final isPureEv = preset.evRatio >= 99.0;
                return InkWell(
                  onTap: () {
                    onSelectPreset(preset);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.tokens.resolvedContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.tokens.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isPureEv ? context.tokens.accent.withValues(alpha: 0.15) : const Color(0xFFFF9F1C).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPureEv ? Icons.bolt : Icons.alt_route,
                            color: isPureEv ? context.tokens.accent : const Color(0xFFFF9F1C),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preset.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: context.tokens.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${preset.distanceKm} km • ${preset.durationMinutes} min • ${preset.highwayNote}',
                                style: TextStyle(fontSize: 11, color: context.tokens.ink3),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('RM ${preset.costRm.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.tokens.accent)),
                            Text(isPureEv ? '100% EV' : '${preset.evRatio.toStringAsFixed(0)}% EV', style: TextStyle(fontSize: 10, color: context.tokens.ink3)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ---------------- ZERO-MANUAL-ENTRY SMART EXPENSE SHEET ----------------
class _SmartExpenseSheet extends StatefulWidget {
  final double fuelPrice;
  final double tnbTariff;
  final int currentOdometer;
  final int currentBatteryPct;
  final MyTnbRepository? myTnbRepo;
  final Function(ExpenseRecord) onSave;

  const _SmartExpenseSheet({
    required this.fuelPrice,
    required this.tnbTariff,
    required this.currentOdometer,
    required this.currentBatteryPct,
    this.myTnbRepo,
    required this.onSave,
  });

  @override
  State<_SmartExpenseSheet> createState() => _SmartExpenseSheetState();
}

class _SmartExpenseSheetState extends State<_SmartExpenseSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Petrol State (1-Tap Selection)
  String _selectedStationBrand = "Petronas Primax 95";
  double _selectedPetrolAmountRm = 50.0;
  double _petrolLitres = 24.39;
  late int _petrolOdometer;

  // Home AC State (Battery Deficit Aware)
  bool _isOffPeak = false;
  late double _homeKwhToCharge;
  late double _homeAcCost;

  // Public EV State
  PublicChargingPreset _selectedPublicStation = kMalaysianChargingStations[0];
  String _networkFilter = "All";

  final List<String> _stationBrands = [
    "Petronas Primax 95",
    "Shell FuelSave 95",
    "Caltex with Techron",
    "BHPetrol Infiniti 95",
    "Petron Blaze 95",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _petrolOdometer = widget.currentOdometer;
    _updatePetrolLitres(50.0);

    // Calculate battery deficit: Tiggo 7 has 18.3 kWh pack
    final deficitPct = (100 - widget.currentBatteryPct).clamp(0, 100);
    _homeKwhToCharge = (deficitPct / 100.0) * 18.3;
    if (_homeKwhToCharge < 2.0) _homeKwhToCharge = 15.0; // fallback default
    _updateHomeAcCost();
  }

  void _updatePetrolLitres(double amountRm) {
    setState(() {
      _selectedPetrolAmountRm = amountRm;
      _petrolLitres = amountRm / widget.fuelPrice;
    });
  }

  void _updateHomeAcCost() {
    final effectiveNormal = widget.myTnbRepo?.selectedAccountNotifier.value?.effectiveTariff ?? widget.tnbTariff;
    final rate = _isOffPeak ? 0.28 : effectiveNormal;
    _homeAcCost = _homeKwhToCharge * rate;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _savePetrol() {
    final rec = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'petrol',
      title: _selectedStationBrand,
      date: 'Today',
      amountRm: _selectedPetrolAmountRm,
      units: _petrolLitres,
      unitPrice: widget.fuelPrice,
      odometerKm: _petrolOdometer,
    );
    widget.onSave(rec);
    Navigator.of(context).pop();
  }

  void _saveHomeAc() {
    final effectiveNormal = widget.myTnbRepo?.selectedAccountNotifier.value?.effectiveTariff ?? widget.tnbTariff;
    final rate = _isOffPeak ? 0.28 : effectiveNormal;
    final isSmartMeter = widget.myTnbRepo?.selectedAccountNotifier.value?.isSmartMeter ?? false;
    final rec = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'home_ac',
      title: _isOffPeak
          ? 'Home AC (TNB Off-Peak)'
          : (isSmartMeter ? 'Home AC (myTNB Smart Meter)' : 'Home AC (TNB Normal)'),
      date: 'Today',
      amountRm: _homeAcCost,
      units: _homeKwhToCharge,
      unitPrice: rate,
    );
    widget.onSave(rec);
    Navigator.of(context).pop();
  }

  void _savePublicEv() {
    final rec = ExpenseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'public_ev',
      title: '${_selectedPublicStation.network} • ${_selectedPublicStation.stationName}',
      date: 'Today',
      amountRm: _selectedPublicStation.defaultCostRm,
      units: _selectedPublicStation.defaultKwh,
      unitPrice: _selectedPublicStation.defaultCostRm / _selectedPublicStation.defaultKwh,
    );
    widget.onSave(rec);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.tokens.accent;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1-Tap Fuel & Charge Logger',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.tokens.ink,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.tokens.ink3, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            'Auto-calculates volume and cost using official Malaysian rates.',
            style: TextStyle(fontSize: 11.5, color: context.tokens.ink3),
          ),
          const SizedBox(height: 12),

          // Tab Selector
          Container(
            decoration: BoxDecoration(
              color: context.tokens.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.2 : 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent),
              ),
              labelColor: accent,
              unselectedLabelColor: context.tokens.ink3,
              labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: '⛽ Petrol RON95'),
                Tab(text: '⚡ Home AC'),
                Tab(text: '🔌 Public EV'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          SizedBox(
            height: 360,
            child: TabBarView(
              controller: _tabController,
              children: [
                // ---------------- 1. 1-TAP PETROL TAB ----------------
                ListView(
                  children: [
                    Text(
                      'Select Station Brand:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.ink3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _stationBrands.map((brand) {
                        final isSel = brand == _selectedStationBrand;
                        return ChoiceChip(
                          label: Text(
                            brand,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSel ? Colors.black : (context.tokens.ink2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFFFF9F1C),
                          backgroundColor: context.tokens.surface2,
                          side: BorderSide(
                            color: isSel ? const Color(0xFFFF9F1C) : (context.tokens.border),
                          ),
                          onSelected: (val) => setState(() => _selectedStationBrand = brand),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Quick Fill Amount (Ceiling RM 2.05 / L):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.ink3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildPresetAmountBtn('Full 51L', 51.0 * widget.fuelPrice, (51.0 * widget.fuelPrice).toStringAsFixed(0), isDark),
                        const SizedBox(width: 6),
                        _buildPresetAmountBtn('RM 50', 50.0, '24.4L', isDark),
                        const SizedBox(width: 6),
                        _buildPresetAmountBtn('RM 30', 30.0, '14.6L', isDark),
                        const SizedBox(width: 6),
                        _buildPresetAmountBtn('RM 20', 20.0, '9.8L', isDark),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Auto-Odometer Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.tokens.resolvedContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.tokens.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.speed, size: 16, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                'Auto Odometer from Vehicle',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.tokens.ink2,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$_petrolOdometer km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.tokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    ElevatedButton(
                      onPressed: _savePetrol,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9F1C),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        'Save Fill-up: RM ${_selectedPetrolAmountRm.toStringAsFixed(2)} (${_petrolLitres.toStringAsFixed(1)} L)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),

                // ---------------- 2. SMART HOME AC CHARGE TAB ----------------
                ListView(
                  children: [
                    // myTNB Smart Meter Status Banner
                    if (widget.myTnbRepo != null)
                      ValueListenableBuilder<MyTnbAccount?>(
                        valueListenable: widget.myTnbRepo!.selectedAccountNotifier,
                        builder: (context, account, _) {
                          final isLinked = account != null;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isLinked
                                  ? accent.withValues(alpha: isDark ? 0.12 : 0.08)
                                  : (context.tokens.resolvedContainerLow),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isLinked
                                    ? accent.withValues(alpha: 0.4)
                                    : (context.tokens.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLinked ? Icons.sensors : Icons.electric_bolt_outlined,
                                  color: isLinked ? accent : (context.tokens.ink3),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isLinked
                                            ? 'myTNB Smart Meter: ${account.accountDesc}'
                                            : 'myTNB Smart Meter Not Connected',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isLinked ? accent : (context.tokens.ink2),
                                        ),
                                      ),
                                      Text(
                                        isLinked
                                            ? 'Month: ${account.currentUsageKwh.toStringAsFixed(1)} kWh • Dynamic Tariff: RM ${account.effectiveTariff.toStringAsFixed(3)}/kWh'
                                            : 'Sync directly to calculate charging costs using your actual domestic tariff tier.',
                                        style: TextStyle(fontSize: 10.5, color: context.tokens.ink3),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => MyTnbConnectDialog(
                                        repository: widget.myTnbRepo!,
                                        currentTariff: widget.tnbTariff,
                                        onTariffUpdated: (rate, account) {
                                          setState(() {
                                            _updateHomeAcCost();
                                          });
                                        },
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    isLinked ? 'Manage' : 'Connect',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isLinked ? accent : const Color(0xFF58A6FF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    // Battery Deficit Callout Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withValues(alpha: isDark ? 0.5 : 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: accent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Current Battery: ${widget.currentBatteryPct}% SoC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
                                Text(
                                  'Deficit to 100%: ${(100 - widget.currentBatteryPct)}% (~${((100 - widget.currentBatteryPct) / 100 * 18.3).toStringAsFixed(1)} kWh needed)',
                                  style: TextStyle(fontSize: 11, color: context.tokens.ink2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Select Charge Preset:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.ink3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildHomeChargePresetBtn(
                          'Top to 100%',
                          ((100 - widget.currentBatteryPct) / 100 * 18.3).clamp(3.0, 18.3),
                          isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildHomeChargePresetBtn('Full 18.3 kWh', 18.3, isDark),
                        const SizedBox(width: 6),
                        _buildHomeChargePresetBtn('+ 10.0 kWh', 10.0, isDark),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // TNB Tariff Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.tokens.resolvedContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.tokens.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isOffPeak
                                    ? 'TNB Off-Peak / Solar (RM 0.28 / kWh)'
                                    : 'TNB Normal Rate (RM ${(widget.myTnbRepo?.selectedAccountNotifier.value?.effectiveTariff ?? widget.tnbTariff).toStringAsFixed(3)} / kWh)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.tokens.ink,
                                ),
                              ),
                              Text(
                                '10:00 PM – 08:00 AM off-peak rate',
                                style: TextStyle(fontSize: 9.5, color: context.tokens.ink3),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOffPeak,
                            activeThumbColor: accent,
                            onChanged: (val) {
                              setState(() {
                                _isOffPeak = val;
                                _updateHomeAcCost();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    ElevatedButton(
                      onPressed: _saveHomeAc,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: context.tokens.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        'Save Home Charge: RM ${_homeAcCost.toStringAsFixed(2)} (${_homeKwhToCharge.toStringAsFixed(1)} kWh)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),

                // ---------------- 3. PUBLIC EV CHARGER STATION LIST ----------------
                ListView(
                  children: [
                    // Network Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Gentari', 'ChargEV', 'JomCharge', 'DC Handal'].map((net) {
                          final isSel = net == _networkFilter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                net,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSel ? Colors.black : (context.tokens.ink2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: accent,
                              backgroundColor: context.tokens.surface2,
                              side: BorderSide(
                                color: isSel ? accent : (context.tokens.border),
                              ),
                              onSelected: (val) => setState(() => _networkFilter = net),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Station List
                    ...kMalaysianChargingStations.where((s) => _networkFilter == 'All' || s.network == _networkFilter).map((station) {
                      final isSel = station.stationName == _selectedPublicStation.stationName;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () => setState(() => _selectedPublicStation = station),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? context.tokens.resolvedAccentContainer
                                  : context.tokens.resolvedContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? accent : (context.tokens.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.ev_station, color: accent, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${station.network} • ${station.stationName}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: context.tokens.ink,
                                        ),
                                      ),
                                      Text(
                                        station.rateDescription,
                                        style: TextStyle(fontSize: 10, color: context.tokens.ink3),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'RM ${station.defaultCostRm.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.navigation_outlined, size: 16, color: accent),
                                  tooltip: 'Open in Maps',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    final query = Uri.encodeComponent('${station.network} ${station.stationName} Malaysia');
                                    final geoUri = Uri.parse('geo:0,0?q=$query');
                                    final webMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                                    launchUrl(geoUri, mode: LaunchMode.externalApplication).catchError((_) {
                                      return launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: _savePublicEv,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: context.tokens.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        'Confirm: ${_selectedPublicStation.network} (RM ${_selectedPublicStation.defaultCostRm.toStringAsFixed(2)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetAmountBtn(String label, double amountRm, String subtext, bool isDark) {
    final isSel = (_selectedPetrolAmountRm - amountRm).abs() < 0.1;
    return Expanded(
      child: InkWell(
        onTap: () => _updatePetrolLitres(amountRm),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel
                ? const Color(0xFFFF9F1C)
                : (context.tokens.surface2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? const Color(0xFFFF9F1C) : (context.tokens.border),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.black : (context.tokens.ink),
                ),
              ),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isSel ? Colors.black87 : (context.tokens.ink3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeChargePresetBtn(String label, double kwh, bool isDark) {
    final isSel = (_homeKwhToCharge - kwh).abs() < 0.5;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _homeKwhToCharge = kwh;
            _updateHomeAcCost();
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel
                ? context.tokens.accent
                : (context.tokens.surface2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? context.tokens.accent : (context.tokens.border),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.black : (context.tokens.ink),
                ),
              ),
              Text(
                '${kwh.toStringAsFixed(1)} kWh',
                style: TextStyle(
                  fontSize: 9.5,
                  color: isSel ? Colors.black87 : (context.tokens.ink3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------
/// LOGBOOK EXPORT MODAL (WhatsApp Summary & CSV Spreadsheet)
/// -------------------------------------------------------------
class _ExportLogbookModal extends StatefulWidget {
  final String selectedMonth;
  final double totalDistanceKm;
  final double totalSpend;
  final double homeAcSpend;
  final double petrolSpend;
  final double publicEvSpend;
  final double monthlySavings;
  final List<TripRecord> trips;
  final List<ExpenseRecord> expenses;

  const _ExportLogbookModal({
    required this.selectedMonth,
    required this.totalDistanceKm,
    required this.totalSpend,
    required this.homeAcSpend,
    required this.petrolSpend,
    required this.publicEvSpend,
    required this.monthlySavings,
    required this.trips,
    required this.expenses,
  });

  @override
  State<_ExportLogbookModal> createState() => _ExportLogbookModalState();
}

class _ExportLogbookModalState extends State<_ExportLogbookModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _whatsAppReport {
    final buffer = StringBuffer();
    buffer.writeln('🚗 *CHERY TIGGO 7 PHEV — MONTHLY LOGBOOK*');
    buffer.writeln('📅 *Month:* ${widget.selectedMonth}');
    buffer.writeln('🛣️ *Total Distance:* ${widget.totalDistanceKm.toStringAsFixed(1)} km');
    buffer.writeln('------------------------------------------');
    buffer.writeln('💰 *EXPENDITURE SUMMARY:*');
    buffer.writeln('• 🏠 Home AC Charging (TNB): RM ${widget.homeAcSpend.toStringAsFixed(2)}');
    buffer.writeln('• ⛽ Petrol (RON95): RM ${widget.petrolSpend.toStringAsFixed(2)}');
    if (widget.publicEvSpend > 0) {
      buffer.writeln('• 🔌 Public Charging: RM ${widget.publicEvSpend.toStringAsFixed(2)}');
    }
    buffer.writeln('👉 *Total Fuel & Power Cost:* RM ${widget.totalSpend.toStringAsFixed(2)}');
    final costPerKm = widget.totalDistanceKm > 0 ? (widget.totalSpend / widget.totalDistanceKm) : 0.0;
    buffer.writeln('📊 *Running Cost:* RM ${costPerKm.toStringAsFixed(2)} / km');
    buffer.writeln('💡 *PHEV Savings vs ICE SUV:* +RM ${widget.monthlySavings.toStringAsFixed(2)} Saved');
    buffer.writeln('------------------------------------------');
    buffer.writeln('📋 *RECENT RECORDED TRIPS:*');
    for (int i = 0; i < widget.trips.take(5).length; i++) {
      final t = widget.trips[i];
      buffer.writeln('• ${t.title} (${t.distanceKm} km, RM ${t.costRm.toStringAsFixed(2)}, ${t.evRatio.toStringAsFixed(0)}% EV)');
    }
    buffer.writeln('\nGenerated via TiggoMate App');
    return buffer.toString();
  }

  String _csvDate(String id) => recordTimeFromId(id).toIso8601String().substring(0, 10);

  String get _csvReport {
    final buffer = StringBuffer();
    buffer.writeln('Date,Entry,Type,Distance_km,EV_km,HEV_km,Electric_kWh,Petrol_L,Cost_MYR');
    for (final t in widget.trips) {
      buffer.writeln('"${_csvDate(t.id)}","${t.title.replaceAll('"', '""')}","Drive",${t.distanceKm},${t.evDistanceKm},${t.hevDistanceKm},${t.electricKwh},${t.petrolLitres},${t.costRm}');
    }
    for (final e in widget.expenses) {
      buffer.writeln('"${_csvDate(e.id)}","${e.title.replaceAll('"', '""')}","Expense",0,0,0,${e.type.contains("ac") || e.type.contains("ev") ? e.units : 0},${e.type == "petrol" ? e.units : 0},${e.amountRm}');
    }
    return buffer.toString();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    AppNotification.show(
      context,
      message: '$label copied to clipboard!',
      type: NotificationType.success,
      icon: Icons.copy_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.82,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: context.tokens.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.ios_share, color: context.tokens.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Export Logbook & Expenses',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.tokens.ink,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: context.tokens.accent,
            unselectedLabelColor: context.tokens.ink3,
            indicatorColor: context.tokens.accent,
            tabs: const [
              Tab(icon: Icon(Icons.chat, size: 16), text: 'WhatsApp / Summary'),
              Tab(icon: Icon(Icons.table_chart, size: 16), text: 'CSV Spreadsheet'),
            ],
          ),
          const SizedBox(height: 12),

          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // WhatsApp Report Tab
                _buildReportPreview(
                  text: _whatsAppReport,
                  isDark: isDark,
                  onCopy: () => _copyToClipboard(_whatsAppReport, 'Executive summary'),
                  buttonLabel: 'Copy WhatsApp Message',
                  buttonIcon: Icons.copy,
                ),

                // CSV Spreadsheet Tab
                _buildReportPreview(
                  text: _csvReport,
                  isDark: isDark,
                  onCopy: () => _copyToClipboard(_csvReport, 'CSV spreadsheet'),
                  buttonLabel: 'Copy CSV Data',
                  buttonIcon: Icons.file_download,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportPreview({
    required String text,
    required bool isDark,
    required VoidCallback onCopy,
    required String buttonLabel,
    required IconData buttonIcon,
  }) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.resolvedContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.tokens.border),
            ),
            child: SingleChildScrollView(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: context.tokens.ink2,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onCopy,
            icon: Icon(buttonIcon, size: 18),
            label: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.tokens.accent,
              foregroundColor: context.tokens.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}

