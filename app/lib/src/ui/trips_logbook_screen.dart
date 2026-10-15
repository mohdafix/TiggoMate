import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../mytnb/mytnb_api.dart';
import 'mytnb_connect_dialog.dart';

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

class _TripsLogbookScreenState extends State<TripsLogbookScreen> {
  final String _selectedMonth = "October 2026";
  late TripRecord _featuredTrip;
  List<TripRecord> _trips = [];
  List<ExpenseRecord> _customExpenses = [];

  static const String _kExpenseStorageKey = 'tm_logged_expenses_v2';
  static const String _kTripsStorageKey = 'tm_logged_trips_v2';

  @override
  void initState() {
    super.initState();
    _initDefaultTrips();
    _loadStoredData();
  }

  void _initDefaultTrips() {
    _trips = [
      TripRecord(
        id: 'trip_1',
        title: 'Bangsar ➔ Putrajaya Sentral',
        timestamp: 'Today 08:15 AM',
        distanceKm: 34.2,
        durationMinutes: 36,
        evDistanceKm: 26.5,
        hevDistanceKm: 7.7,
        electricKwh: 4.8,
        petrolLitres: 0.5,
        costRm: 3.15,
        avgSpeedKmh: 58.0,
        highwayNote: 'MEX Highway • 77% EV Ratio',
        routePoints: const [
          Offset(0.18, 0.22),
          Offset(0.24, 0.24),
          Offset(0.35, 0.28),
          Offset(0.48, 0.32),
          Offset(0.56, 0.44),
          Offset(0.58, 0.60),
          Offset(0.54, 0.72),
          Offset(0.52, 0.84),
        ],
        evPointCount: 5,
      ),
      kMalaysianTripPresets[0], // Office Commute
      kMalaysianTripPresets[4], // Weekend Roadtrip Ipoh
      kMalaysianTripPresets[3], // Mid Valley Shopping
    ];
    _featuredTrip = _trips[0];
  }

  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawExpenses = prefs.getString(_kExpenseStorageKey);
      if (rawExpenses != null && rawExpenses.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawExpenses);
        setState(() {
          _customExpenses = decoded.map((e) => ExpenseRecord.fromJson(e as Map<String, dynamic>)).toList();
        });
      }

      final rawTrips = prefs.getString(_kTripsStorageKey);
      if (rawTrips != null && rawTrips.isNotEmpty) {
        final List<dynamic> decodedTrips = jsonDecode(rawTrips);
        final loaded = decodedTrips.map((t) => TripRecord.fromJson(t as Map<String, dynamic>)).toList();
        setState(() {
          _trips = [...loaded, ..._trips];
          if (_trips.isNotEmpty) _featuredTrip = _trips[0];
        });
      }
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
  }

  Future<void> _saveTrip(TripRecord trip) async {
    setState(() {
      _trips.insert(0, trip);
      _featuredTrip = trip;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_trips.map((t) => t.toJson()).toList());
      await prefs.setString(_kTripsStorageKey, encoded);
    } catch (_) {}
  }

  // Monthly Aggregates
  double get _totalDistanceKm {
    return _trips.fold(0.0, (acc, t) => acc + t.distanceKm) + 1152.6;
  }

  double get _homeAcSpend {
    final custom = _customExpenses.where((e) => e.type == 'home_ac').fold(0.0, (acc, e) => acc + e.amountRm);
    return 42.10 + custom;
  }

  double get _petrolSpend {
    final custom = _customExpenses.where((e) => e.type == 'petrol').fold(0.0, (acc, e) => acc + e.amountRm);
    return 106.40 + custom;
  }

  double get _publicEvSpend {
    return _customExpenses.where((e) => e.type == 'public_ev').fold(0.0, (acc, e) => acc + e.amountRm);
  }

  double get _totalSpend => _homeAcSpend + _petrolSpend + _publicEvSpend;

  // Real-world comparison vs equivalent 1.5L Turbo ICE SUV running 7.8 L/100km at RM 2.05/L
  double get _monthlySavings {
    final iceLitres = (_totalDistanceKm / 100.0) * 7.8;
    final iceCost = iceLitres * widget.fuelPrice;
    final diff = iceCost - _totalSpend;
    return diff > 0 ? diff : 185.00;
  }

  void _showAddTripPresetModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1219) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added Trip: ${newTrip.title} (${newTrip.distanceKm} km)'),
              backgroundColor: const Color(0xFF00D2AA),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showLogModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1219) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SmartExpenseSheet(
        fuelPrice: widget.fuelPrice,
        tnbTariff: widget.tnbTariff,
        currentOdometer: widget.currentOdometerKm,
        currentBatteryPct: widget.currentBatteryPct,
        myTnbRepo: widget.myTnbRepo,
        onSave: (rec) {
          _saveExpense(rec);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged ${rec.title} (RM ${rec.amountRm.toStringAsFixed(2)})'),
              backgroundColor: const Color(0xFF00D2AA),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ---------------- TOP HEADER ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trips &',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Expense Log',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Month Picker Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131922) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedMonth,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 16, color: isDark ? Colors.white70 : const Color(0xFF374151)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Action Buttons Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // + Add Trip Pill
                      InkWell(
                        onTap: _showAddTripPresetModal,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F81F7).withValues(alpha: isDark ? 0.15 : 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF2F81F7)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.add_road, size: 13, color: Color(0xFF2F81F7)),
                              SizedBox(width: 4),
                              Text(
                                'Add Trip',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2F81F7)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // + Log Fuel/Charge Pill Button
                      InkWell(
                        onTap: _showLogModal,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.15 : 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF00D2AA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.add, size: 13, color: Color(0xFF00D2AA)),
                              SizedBox(width: 4),
                              Text(
                                'Log Fuel/Charge',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---------------- MONTHLY SUMMARY CARD ----------------
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF0D1219) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        ),
                      ),
                      // Glowing Saved Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.18 : 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00D2AA)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.25 : 0.15),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          '+ RM ${_monthlySavings.toStringAsFixed(0)} Saved',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D2AA),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Traveled
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _totalDistanceKm.toStringAsFixed(0).replaceAllMapped(
                                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                        (Match m) => '${m[1]},',
                                      ),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'km',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text('Traveled', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF))),
                            const SizedBox(height: 2),
                            Text('Total Spend', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),

                      Container(width: 1, height: 48, color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                      const SizedBox(width: 16),

                      // Spend Breakdown
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RM ${_totalSpend.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Home AC', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
                                Text(
                                  'RM ${_homeAcSpend.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Petrol', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
                                Text(
                                  'RM ${_petrolSpend.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9F1C)),
                                ),
                              ],
                            ),
                            if (_publicEvSpend > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Public EV', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
                                  Text(
                                    'RM ${_publicEvSpend.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2F81F7)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- FEATURED RECENT TRIP CARD WITH VECTOR MAP ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Trip',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                ),
              ),
              Text(
                _featuredTrip.highwayNote,
                style: const TextStyle(fontSize: 11, color: Color(0xFF00D2AA), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF0D1219) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${_featuredTrip.title} • ${_featuredTrip.timestamp}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stylized Route Map Canvas
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF090E15) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF1C2636) : const Color(0xFFE5E7EB)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: const Size(double.infinity, 140),
                            painter: _DarkVectorMapPainter(
                              routePoints: _featuredTrip.routePoints,
                              evPointCount: _featuredTrip.evPointCount,
                              isDark: isDark,
                            ),
                          ),
                          // Route Legend Overlay
                          Positioned(
                            bottom: 8,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00D2AA))),
                                  const SizedBox(width: 4),
                                  Text(
                                    'EV Drive',
                                    style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white70 : const Color(0xFF374151), fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF9F1C))),
                                  const SizedBox(width: 4),
                                  Text(
                                    '1.5T Hybrid',
                                    style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white70 : const Color(0xFF374151), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Trip Telemetry Quad
                  Row(
                    children: [
                      _buildTripStatCol(
                        value: '${_featuredTrip.distanceKm} km',
                        subtext: '${_featuredTrip.evDistanceKm} km EV',
                        isDark: isDark,
                      ),
                      _buildStatDivider(isDark),
                      _buildTripStatCol(
                        value: '${_featuredTrip.durationMinutes} min',
                        subtext: 'Avg ${_featuredTrip.avgSpeedKmh.toStringAsFixed(0)} km/h',
                        isDark: isDark,
                      ),
                      _buildStatDivider(isDark),
                      _buildTripStatCol(
                        value: '${_featuredTrip.electricKwh} kWh',
                        subtext: _featuredTrip.petrolLitres > 0 ? '+ ${_featuredTrip.petrolLitres}L' : '0L Petrol',
                        highlightColor: const Color(0xFF00D2AA),
                        isDark: isDark,
                      ),
                      _buildStatDivider(isDark),
                      _buildTripStatCol(
                        value: 'RM ${_featuredTrip.costRm.toStringAsFixed(2)}',
                        subtext: 'RM ${(_featuredTrip.costRm / (_featuredTrip.distanceKm > 0 ? _featuredTrip.distanceKm : 1)).toStringAsFixed(2)}/km',
                        highlightColor: isDark ? Colors.white : const Color(0xFF111827),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---------------- RECENT TRIPS LIST ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Trips',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                ),
              ),
              InkWell(
                onTap: _showAddTripPresetModal,
                child: Row(
                  children: const [
                    Icon(Icons.playlist_add, size: 14, color: Color(0xFF2F81F7)),
                    SizedBox(width: 4),
                    Text('Select Preset', style: TextStyle(fontSize: 11, color: Color(0xFF2F81F7), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._trips.map((t) {
            final isSelected = t.id == _featuredTrip.id;
            final isPureEv = t.evRatio >= 99.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _featuredTrip = t),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF131D2A) : const Color(0xFFF0FDF4))
                        : (isDark ? const Color(0xFF0D1219) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00D2AA).withValues(alpha: 0.6)
                          : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Indicator Dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPureEv ? const Color(0xFF00D2AA) : const Color(0xFFFF9F1C),
                          boxShadow: [
                            BoxShadow(
                              color: (isPureEv ? const Color(0xFF00D2AA) : const Color(0xFFFF9F1C)).withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t.distanceKm} km • ${isPureEv ? "100% Pure EV" : "${t.evRatio.toStringAsFixed(0)}% EV / ${(100 - t.evRatio).toStringAsFixed(0)}% Hybrid"} • RM ${t.costRm.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),

                      Icon(Icons.chevron_right, size: 18, color: isDark ? Colors.white30 : const Color(0xFF9CA3AF)),
                    ],
                  ),
                ),
              ),
            );
          }),

          // ---------------- CUSTOM LOGGED EXPENSES SECTION (IF ANY) ----------------
          if (_customExpenses.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Logged Expenses & Fill-ups',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 10),
            ..._customExpenses.map((rec) {
              final isPetrol = rec.type == 'petrol';
              final isHomeAc = rec.type == 'home_ac';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1219) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPetrol ? Icons.local_gas_station : (isHomeAc ? Icons.bolt : Icons.ev_station),
                        size: 20,
                        color: isPetrol ? const Color(0xFFFF9F1C) : const Color(0xFF00D2AA),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${rec.date} • ${rec.units.toStringAsFixed(1)} ${isPetrol ? "L" : "kWh"} @ RM ${rec.unitPrice.toStringAsFixed(2)}${rec.odometerKm != null ? " • Odo: ${rec.odometerKm} km" : ""}',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'RM ${rec.amountRm.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isPetrol ? const Color(0xFFFF9F1C) : const Color(0xFF00D2AA),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTripStatCol({required String value, required String subtext, Color? highlightColor, required bool isDark}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? (isDark ? Colors.white : const Color(0xFF111827)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : const Color(0xFF6B7280), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(width: 1, height: 26, color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB));
  }
}

// ---------------- STYLIZED DARK VECTOR MAP PAINTER ----------------
class _DarkVectorMapPainter extends CustomPainter {
  final List<Offset> routePoints;
  final int evPointCount;
  final bool isDark;

  _DarkVectorMapPainter({
    required this.routePoints,
    required this.evPointCount,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF090E15) : const Color(0xFFF3F4F6);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF182230) : const Color(0xFFD1D5DB)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final minorRoadPaint = Paint()
      ..color = isDark ? const Color(0xFF131B26) : const Color(0xFFE5E7EB)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double y = 20; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 10), minorRoadPaint);
    }
    for (double x = 30; x < size.width; x += 45) {
      canvas.drawLine(Offset(x, 0), Offset(x - 15, size.height), minorRoadPaint);
    }

    final arterialPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.2, size.width * 0.9, size.height * 0.4);
    canvas.drawPath(arterialPath, roadPaint);

    if (routePoints.length < 2) return;

    final pixelPoints = routePoints.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

    // EV driving segment
    final evPath = Path()..moveTo(pixelPoints[0].dx, pixelPoints[0].dy);
    final evEndIdx = (evPointCount < pixelPoints.length) ? evPointCount : pixelPoints.length - 1;
    for (int i = 1; i <= evEndIdx; i++) {
      evPath.lineTo(pixelPoints[i].dx, pixelPoints[i].dy);
    }

    canvas.drawPath(
      evPath,
      Paint()
        ..color = const Color(0xFF00D2AA).withValues(alpha: 0.35)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      evPath,
      Paint()
        ..color = const Color(0xFF00D2AA)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Hybrid segment
    if (evEndIdx < pixelPoints.length - 1) {
      final hevPath = Path()..moveTo(pixelPoints[evEndIdx].dx, pixelPoints[evEndIdx].dy);
      for (int i = evEndIdx + 1; i < pixelPoints.length; i++) {
        hevPath.lineTo(pixelPoints[i].dx, pixelPoints[i].dy);
      }

      canvas.drawPath(
        hevPath,
        Paint()
          ..color = const Color(0xFFFF9F1C).withValues(alpha: 0.35)
          ..strokeWidth = 8.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        hevPath,
        Paint()
          ..color = const Color(0xFFFF9F1C)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Pins
    final startPt = pixelPoints.first;
    canvas.drawCircle(startPt, 6.0, Paint()..color = const Color(0xFF00D2AA).withValues(alpha: 0.3));
    canvas.drawCircle(startPt, 4.0, Paint()..color = const Color(0xFF00D2AA));
    canvas.drawCircle(startPt, 2.0, Paint()..color = Colors.white);

    final endPt = pixelPoints.last;
    canvas.drawCircle(endPt, 7.0, Paint()..color = const Color(0xFFFF9F1C).withValues(alpha: 0.35));
    canvas.drawCircle(endPt, 4.5, Paint()..color = const Color(0xFFFF9F1C));
    canvas.drawCircle(endPt, 2.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DarkVectorMapPainter oldDelegate) => true;
}

// ---------------- 1-TAP MALAYSIAN TRIP PRESET SHEET ----------------
class _AddTripPresetSheet extends StatelessWidget {
  final Function(TripRecord) onSelectPreset;

  const _AddTripPresetSheet({required this.onSelectPreset});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white54 : const Color(0xFF6B7280), size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            'Tap any route to immediately record the trip with zero manual entry.',
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
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
                      color: isDark ? const Color(0xFF131922) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isPureEv ? const Color(0xFF00D2AA).withValues(alpha: 0.15) : const Color(0xFFFF9F1C).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPureEv ? Icons.bolt : Icons.alt_route,
                            color: isPureEv ? const Color(0xFF00D2AA) : const Color(0xFFFF9F1C),
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
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${preset.distanceKm} km • ${preset.durationMinutes} min • ${preset.highwayNote}',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('RM ${preset.costRm.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA))),
                            Text(isPureEv ? '100% EV' : '${preset.evRatio.toStringAsFixed(0)}% EV', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF))),
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

    // Calculate battery deficit: Tiggo 7 has 19.27 kWh pack
    final deficitPct = (100 - widget.currentBatteryPct).clamp(0, 100);
    _homeKwhToCharge = (deficitPct / 100.0) * 19.27;
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
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white54 : const Color(0xFF6B7280), size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            'Auto-calculates volume and cost using official Malaysian rates.',
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),

          // Tab Selector
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.2 : 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00D2AA)),
              ),
              labelColor: const Color(0xFF00D2AA),
              unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF6B7280),
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
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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
                              color: isSel ? Colors.black : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: const Color(0xFFFF9F1C),
                          backgroundColor: isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6),
                          side: BorderSide(
                            color: isSel ? const Color(0xFFFF9F1C) : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
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
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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
                        color: isDark ? const Color(0xFF131922) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.speed, size: 16, color: Color(0xFF00D2AA)),
                              const SizedBox(width: 8),
                              Text(
                                'Auto Odometer from Vehicle',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$_petrolOdometer km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF111827),
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
                                  ? const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.12 : 0.08)
                                  : (isDark ? const Color(0xFF131922) : const Color(0xFFF9FAFB)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isLinked
                                    ? const Color(0xFF00D2AA).withValues(alpha: 0.4)
                                    : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLinked ? Icons.sensors : Icons.electric_bolt_outlined,
                                  color: isLinked ? const Color(0xFF00D2AA) : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
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
                                          color: isLinked ? const Color(0xFF00D2AA) : (isDark ? Colors.white70 : const Color(0xFF374151)),
                                        ),
                                      ),
                                      Text(
                                        isLinked
                                            ? 'Month: ${account.currentUsageKwh.toStringAsFixed(1)} kWh • Dynamic Tariff: RM ${account.effectiveTariff.toStringAsFixed(3)}/kWh'
                                            : 'Sync directly to calculate charging costs using your actual domestic tariff tier.',
                                        style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
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
                                      color: isLinked ? const Color(0xFF00D2AA) : const Color(0xFF58A6FF),
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
                        color: const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: isDark ? 0.5 : 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: Color(0xFF00D2AA), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Current Battery: ${widget.currentBatteryPct}% SoC', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA))),
                                Text(
                                  'Deficit to 100%: ${(100 - widget.currentBatteryPct)}% (~${((100 - widget.currentBatteryPct) / 100 * 19.27).toStringAsFixed(1)} kWh needed)',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
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
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildHomeChargePresetBtn(
                          'Top to 100%',
                          ((100 - widget.currentBatteryPct) / 100 * 19.27).clamp(3.0, 19.27),
                          isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildHomeChargePresetBtn('Full 19.3 kWh', 19.27, isDark),
                        const SizedBox(width: 6),
                        _buildHomeChargePresetBtn('+ 10.0 kWh', 10.0, isDark),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // TNB Tariff Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131922) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
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
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              Text(
                                '10:00 PM – 08:00 AM off-peak rate',
                                style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white38 : const Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOffPeak,
                            activeThumbColor: const Color(0xFF00D2AA),
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
                        backgroundColor: const Color(0xFF00D2AA),
                        foregroundColor: Colors.black87,
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
                                  color: isSel ? Colors.black : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: const Color(0xFF2F81F7),
                              backgroundColor: isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6),
                              side: BorderSide(
                                color: isSel ? const Color(0xFF2F81F7) : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
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
                                  ? (isDark ? const Color(0xFF1A2638) : const Color(0xFFEFF6FF))
                                  : (isDark ? const Color(0xFF131922) : const Color(0xFFF9FAFB)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? const Color(0xFF2F81F7) : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2F81F7).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.ev_station, color: Color(0xFF2F81F7), size: 16),
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
                                          color: isDark ? Colors.white : const Color(0xFF111827),
                                        ),
                                      ),
                                      Text(
                                        station.rateDescription,
                                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'RM ${station.defaultCostRm.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2F81F7)),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.navigation_outlined, size: 16, color: Color(0xFF2F81F7)),
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
                        backgroundColor: const Color(0xFF2F81F7),
                        foregroundColor: Colors.white,
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
                : (isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? const Color(0xFFFF9F1C) : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.black : (isDark ? Colors.white : const Color(0xFF111827)),
                ),
              ),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isSel ? Colors.black87 : (isDark ? Colors.white38 : const Color(0xFF6B7280)),
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
                ? const Color(0xFF00D2AA)
                : (isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? const Color(0xFF00D2AA) : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.black : (isDark ? Colors.white : const Color(0xFF111827)),
                ),
              ),
              Text(
                '${kwh.toStringAsFixed(1)} kWh',
                style: TextStyle(
                  fontSize: 9.5,
                  color: isSel ? Colors.black87 : (isDark ? Colors.white38 : const Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
