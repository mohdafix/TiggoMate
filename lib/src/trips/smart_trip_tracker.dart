import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/trips_logbook_screen.dart';

/// Individual GPS/vector breadcrumb point along a driving route.
class TripBreadcrumbPoint {
  final double x; // Relative coordinate on canvas (0.0 to 1.0)
  final double y;
  final double speedKmh;
  final bool isEv; // True if driving on electric battery, false if DHT 1.5T petrol engine
  final DateTime timestamp;

  const TripBreadcrumbPoint({
    required this.x,
    required this.y,
    required this.speedKmh,
    required this.isEv,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'speedKmh': speedKmh,
        'isEv': isEv,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TripBreadcrumbPoint.fromJson(Map<String, dynamic> json) {
    return TripBreadcrumbPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      speedKmh: (json['speedKmh'] as num).toDouble(),
      isEv: json['isEv'] as bool? ?? true,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Offline-First Smart Trip Recording & Real-time GPS Engine for Chery Tiggo 7 PHEV.
/// Automatically tracks EV vs. HEV powertrain split, efficiency, and running cost in MYR.
class SmartTripTracker extends ChangeNotifier {
  static final SmartTripTracker instance = SmartTripTracker._internal();
  SmartTripTracker._internal();

  static const String _kTripsStorageKey = 'tm_logged_trips_v2';

  bool _isTracking = false;
  bool _isPaused = false;
  DateTime? _startTime;
  int _elapsedSeconds = 0;

  double _currentSpeedKmh = 0.0;
  double _totalDistanceKm = 0.0;
  double _evDistanceKm = 0.0;
  double _hevDistanceKm = 0.0;

  double _electricKwh = 0.0;
  double _petrolLitres = 0.0;
  double _liveCostRm = 0.0;

  double _tnbTariff = 0.57; // Default RM/kWh
  double _fuelPrice = 2.05; // Default RM/L (RON95)

  String _tripTitle = "Active Drive Session";
  final List<TripBreadcrumbPoint> _breadcrumbs = [];
  Timer? _driveTimer;
  int _simStep = 0;

  // Getters
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  DateTime? get startTime => _startTime;
  int get elapsedSeconds => _elapsedSeconds;
  double get currentSpeedKmh => _currentSpeedKmh;
  double get totalDistanceKm => _totalDistanceKm;
  double get evDistanceKm => _evDistanceKm;
  double get hevDistanceKm => _hevDistanceKm;
  double get electricKwh => _electricKwh;
  double get petrolLitres => _petrolLitres;
  double get liveCostRm => _liveCostRm;
  String get tripTitle => _tripTitle;
  List<TripBreadcrumbPoint> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  double get evRatio => _totalDistanceKm > 0 ? (_evDistanceKm / _totalDistanceKm) * 100 : 100.0;
  double get avgSpeedKmh => _elapsedSeconds > 0 ? (_totalDistanceKm / (_elapsedSeconds / 3600)) : 0.0;

  double get kwhPer100Km => _evDistanceKm > 0.1 ? (_electricKwh / _evDistanceKm) * 100 : 14.5;
  double get litresPer100Km => _hevDistanceKm > 0.1 ? (_petrolLitres / _hevDistanceKm) * 100 : 5.2;

  String get formattedDuration {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    final h = _elapsedSeconds ~/ 3600;
    if (h > 0) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  /// Start a new smart driving session
  void startDrive({
    String? title,
    double tnbTariff = 0.57,
    double fuelPrice = 2.05,
  }) {
    _isTracking = true;
    _isPaused = false;
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _totalDistanceKm = 0.0;
    _evDistanceKm = 0.0;
    _hevDistanceKm = 0.0;
    _electricKwh = 0.0;
    _petrolLitres = 0.0;
    _liveCostRm = 0.0;
    _currentSpeedKmh = 0.0;
    _tripTitle = title ?? "Live Drive: Tiggo 7 PHEV";
    _tnbTariff = tnbTariff;
    _fuelPrice = fuelPrice;
    _breadcrumbs.clear();
    _simStep = 0;

    // Add initial start point
    _breadcrumbs.add(
      TripBreadcrumbPoint(
        x: 0.20,
        y: 0.25,
        speedKmh: 0.0,
        isEv: true,
        timestamp: DateTime.now(),
      ),
    );

    _driveTimer?.cancel();
    _driveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _isTracking) {
        _elapsedSeconds++;
        notifyListeners();
      }
    });

    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Pause current tracking session
  void pauseDrive() {
    _isPaused = true;
    _currentSpeedKmh = 0.0;
    notifyListeners();
  }

  /// Resume paused session
  void resumeDrive() {
    _isPaused = false;
    notifyListeners();
  }

  /// Stop tracking and cancel periodic timer
  void stopDrive() {
    _driveTimer?.cancel();
    _driveTimer = null;
    _isTracking = false;
    _isPaused = false;
    notifyListeners();
  }

  /// Record a GPS coordinate / vector point
  void recordPoint({
    required double x,
    required double y,
    required double speedKmh,
    bool? isEvOverride,
  }) {
    if (!_isTracking || _isPaused) return;

    _currentSpeedKmh = speedKmh;

    // PHEV Intelligent Powertrain logic:
    // Speeds <= 70 km/h: Pure Electric EV Mode (unless manual override)
    // Speeds > 70 km/h: 1.5T DHT Hybrid Engine assists (HEV Mode)
    final isEv = isEvOverride ?? (speedKmh <= 70.0);

    // Calculate incremental distance from previous point
    if (_breadcrumbs.isNotEmpty) {
      final prev = _breadcrumbs.last;
      final dx = x - prev.dx;
      final dy = y - prev.dy;
      // Map coordinate distance to approximate KM scale (0.01 coord ≈ 0.6 km)
      final segmentKm = math.sqrt(dx * dx + dy * dy) * 60.0;
      final clampedSegment = segmentKm.clamp(0.01, 1.2);

      _totalDistanceKm += clampedSegment;
      if (isEv) {
        _evDistanceKm += clampedSegment;
        // Tiggo 7 PHEV averages ~14.0 kWh/100km on pure electric
        _electricKwh += clampedSegment * 0.140;
      } else {
        _hevDistanceKm += clampedSegment;
        // 1.5T DHT petrol engine consumes ~5.2 L/100km in hybrid assist
        _petrolLitres += clampedSegment * 0.052;
      }

      _liveCostRm = (_electricKwh * _tnbTariff) + (_petrolLitres * _fuelPrice);
    }

    _breadcrumbs.add(
      TripBreadcrumbPoint(
        x: x.clamp(0.05, 0.95),
        y: y.clamp(0.05, 0.95),
        speedKmh: speedKmh,
        isEv: isEv,
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  /// Simulated Drive Tick: Smoothly advances vehicle along a realistic Klang Valley route
  /// (e.g. Bangsar -> Mid Valley -> MEX Highway -> Cyberjaya / Putrajaya)
  void simulateDriveTick() {
    if (!_isTracking || _isPaused) return;

    _simStep++;

    // 16-point realistic Klang Valley route curve
    final List<Map<String, double>> path = [
      {'x': 0.18, 'y': 0.22, 'speed': 42.0}, // Bangsar South (City EV)
      {'x': 0.22, 'y': 0.24, 'speed': 48.0}, // Kerinchi Link (EV)
      {'x': 0.28, 'y': 0.26, 'speed': 55.0}, // Mid Valley bypass (EV)
      {'x': 0.35, 'y': 0.29, 'speed': 62.0}, // Old Klang Road merge (EV)
      {'x': 0.42, 'y': 0.34, 'speed': 72.0}, // Entering MEX Expressway Toll (HEV kicks in)
      {'x': 0.49, 'y': 0.41, 'speed': 88.0}, // MEX Highway cruise (HEV 1.5T assist)
      {'x': 0.54, 'y': 0.48, 'speed': 96.0}, // MEX Highway high speed (HEV)
      {'x': 0.58, 'y': 0.56, 'speed': 104.0}, // MEX Highway Seri Kembangan (HEV)
      {'x': 0.60, 'y': 0.65, 'speed': 98.0}, // Putrajaya interchange approach
      {'x': 0.57, 'y': 0.73, 'speed': 78.0}, // Decelerating towards toll plaza (HEV regen)
      {'x': 0.52, 'y': 0.80, 'speed': 58.0}, // Cyberjaya North link (EV Mode resumed)
      {'x': 0.48, 'y': 0.86, 'speed': 46.0}, // Persiaran Multimedia (City EV)
      {'x': 0.46, 'y': 0.92, 'speed': 32.0}, // Putrajaya Sentral entrance (EV)
    ];

    final targetIdx = _simStep % path.length;
    final target = path[targetIdx];

    // Smooth speed jitter
    final jitter = (math.sin(_simStep * 0.7) * 3.5);
    final speed = (target['speed']! + jitter).clamp(25.0, 115.0);

    recordPoint(
      x: target['x']!,
      y: target['y']!,
      speedKmh: speed,
      isEvOverride: speed <= 70.0,
    );
  }

  /// Finish the trip, persist to SharedPreferences, and return a completed TripRecord
  Future<TripRecord> finishAndSaveTrip({
    required String title,
    String? highwayNote,
  }) async {
    _driveTimer?.cancel();
    _driveTimer = null;
    _isTracking = false;
    _isPaused = false;

    final durationMins = (_elapsedSeconds / 60).round().clamp(1, 999);
    final resolvedDistance = _totalDistanceKm > 0 ? _totalDistanceKm : 18.5;
    final resolvedEvDist = _evDistanceKm > 0 ? _evDistanceKm : resolvedDistance * 0.75;
    final resolvedHevDist = (_totalDistanceKm - resolvedEvDist).clamp(0.0, resolvedDistance);
    final resolvedElectricKwh = _electricKwh > 0 ? _electricKwh : resolvedEvDist * 0.14;
    final resolvedPetrolLitres = _petrolLitres > 0 ? _petrolLitres : resolvedHevDist * 0.052;
    final resolvedCost = (_liveCostRm > 0)
        ? _liveCostRm
        : (resolvedElectricKwh * _tnbTariff) + (resolvedPetrolLitres * _fuelPrice);

    final evPoints = _breadcrumbs.where((b) => b.isEv).length;
    final sampleRoute = _breadcrumbs.isNotEmpty
        ? _breadcrumbs.map((b) => Offset(b.x, b.y)).toList()
        : const [
            Offset(0.18, 0.22),
            Offset(0.35, 0.28),
            Offset(0.56, 0.44),
            Offset(0.54, 0.72),
            Offset(0.48, 0.86),
          ];

    final newTrip = TripRecord(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      title: title.isNotEmpty ? title : 'Live Drive (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')})',
      timestamp: 'Today ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      distanceKm: double.parse(resolvedDistance.toStringAsFixed(1)),
      durationMinutes: durationMins,
      evDistanceKm: double.parse(resolvedEvDist.toStringAsFixed(1)),
      hevDistanceKm: double.parse(resolvedHevDist.toStringAsFixed(1)),
      electricKwh: double.parse(resolvedElectricKwh.toStringAsFixed(2)),
      petrolLitres: double.parse(resolvedPetrolLitres.toStringAsFixed(2)),
      costRm: double.parse(resolvedCost.toStringAsFixed(2)),
      avgSpeedKmh: double.parse((avgSpeedKmh > 0 ? avgSpeedKmh : 56.0).toStringAsFixed(1)),
      highwayNote: highwayNote ?? 'Smart GPS Tracking • ${(resolvedEvDist / resolvedDistance * 100).round()}% EV Ratio',
      routePoints: sampleRoute,
      evPointCount: evPoints > 0 ? evPoints : (sampleRoute.length * 0.7).round(),
    );

    // Save to SharedPreferences so it instantly appears in TripsLogbookScreen
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getString(_kTripsStorageKey);
      List<dynamic> list = [];
      if (existingRaw != null && existingRaw.isNotEmpty) {
        list = jsonDecode(existingRaw);
      }
      list.insert(0, newTrip.toJson());
      await prefs.setString(_kTripsStorageKey, jsonEncode(list));
    } catch (_) {}

    HapticFeedback.heavyImpact();
    notifyListeners();
    return newTrip;
  }

  void cancelDrive() {
    _driveTimer?.cancel();
    _driveTimer = null;
    _isTracking = false;
    _isPaused = false;
    _breadcrumbs.clear();
    notifyListeners();
  }
}

extension on TripBreadcrumbPoint {
  double get dx => x;
  double get dy => y;
}
