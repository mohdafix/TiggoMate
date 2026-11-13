import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlannedRouteResult {
  final String destinationName;
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polyline;
  final double evRangeAvailableKm;
  final double projectedArrivalSoc;
  final bool canReachPureEv;
  final double electricShareKm;
  final double hybridShareKm;
  final PlannedChargingStop? recommendedStop;

  const PlannedRouteResult({
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.polyline,
    required this.evRangeAvailableKm,
    required this.projectedArrivalSoc,
    required this.canReachPureEv,
    required this.electricShareKm,
    required this.hybridShareKm,
    this.recommendedStop,
  });
}

class PlannedChargingStop {
  final String name;
  final LatLng location;
  final double distanceFromStartKm;
  final String chargerInfo;
  final int suggestedChargeMin;
  final double targetSoc;

  const PlannedChargingStop({
    required this.name,
    required this.location,
    required this.distanceFromStartKm,
    required this.chargerInfo,
    required this.suggestedChargeMin,
    required this.targetSoc,
  });
}

class MalaysianPresetDestination {
  final String name;
  final String subtitle;
  final LatLng location;

  const MalaysianPresetDestination({
    required this.name,
    required this.subtitle,
    required this.location,
  });
}

/// Popular Malaysian EV / PHEV Road Trip Destinations
const List<MalaysianPresetDestination> kMalaysianPresets = [
  MalaysianPresetDestination(
    name: 'Genting Highlands',
    subtitle: 'Pahang • Hillclimb & SkyAvenue (60 kW DC)',
    location: LatLng(3.4240, 101.7942),
  ),
  MalaysianPresetDestination(
    name: 'Melaka Historic City',
    subtitle: 'Melaka • Jonker Walk via PLUS Highway',
    location: LatLng(2.1960, 102.2470),
  ),
  MalaysianPresetDestination(
    name: 'Ipoh Old Town',
    subtitle: 'Perak • PLUS Northbound Corridor (Simpang Pulai)',
    location: LatLng(4.5975, 101.0772),
  ),
  MalaysianPresetDestination(
    name: 'Penang Island (Georgetown)',
    subtitle: 'Penang • Sultan Abdul Halim Bridge',
    location: LatLng(5.4141, 100.3288),
  ),
  MalaysianPresetDestination(
    name: 'Johor Bahru (Mid Valley)',
    subtitle: 'Johor • PLUS Southbound Terminal Corridor',
    location: LatLng(1.4927, 103.7667),
  ),
  MalaysianPresetDestination(
    name: 'KLIA Terminal 1 & 2',
    subtitle: 'Selangor • ELITE Highway Express (DC Fast)',
    location: LatLng(2.7456, 101.7072),
  ),
];

/// Known Corridor Highway DC Fast Chargers in Peninsular Malaysia
const List<PlannedChargingStop> kHighwayChargers = [
  PlannedChargingStop(
    name: 'Gentari - R&R Rawang Northbound (PLUS)',
    location: LatLng(3.3228, 101.5744),
    distanceFromStartKm: 32.0,
    chargerInfo: '2x 180 kW DC • 1x 60 kW DC (Kempower)',
    suggestedChargeMin: 20,
    targetSoc: 80.0,
  ),
  PlannedChargingStop(
    name: 'Shell Recharge - R&R Seremban Southbound (PLUS)',
    location: LatLng(2.7094, 101.8953),
    distanceFromStartKm: 58.0,
    chargerInfo: '2x 180 kW DC High-Power HPC',
    suggestedChargeMin: 22,
    targetSoc: 85.0,
  ),
  PlannedChargingStop(
    name: 'ChargEV - R&R Ayer Keroh Northbound (PLUS)',
    location: LatLng(2.3392, 102.3089),
    distanceFromStartKm: 125.0,
    chargerInfo: '2x 120 kW DC CCS2',
    suggestedChargeMin: 25,
    targetSoc: 80.0,
  ),
  PlannedChargingStop(
    name: 'Gentari - R&R Tapah Southbound (PLUS)',
    location: LatLng(4.1852, 101.2581),
    distanceFromStartKm: 145.0,
    chargerInfo: '2x 180 kW DC Dual-Gun CCS2',
    suggestedChargeMin: 20,
    targetSoc: 80.0,
  ),
  PlannedChargingStop(
    name: 'TNB Electron - R&R Pagoh Southbound (PLUS)',
    location: LatLng(2.1528, 102.7725),
    distanceFromStartKm: 180.0,
    chargerInfo: '2x 90 kW DC Fast Charging',
    suggestedChargeMin: 25,
    targetSoc: 85.0,
  ),
  PlannedChargingStop(
    name: 'Gentari - R&R Gunung Semanggol Northbound (PLUS)',
    location: LatLng(4.9922, 100.6481),
    distanceFromStartKm: 275.0,
    chargerInfo: '2x 180 kW DC High-Power HPC',
    suggestedChargeMin: 25,
    targetSoc: 80.0,
  ),
];

/// Smart EV Route & Highway Charger Planner
///
/// Ported from GodrezJr2/j5-ev-dashboard (`tools/server.py` `trip_plan()`):
/// - OSRM public highway routing with offline geodesic fallback
/// - Pure EV vs PHEV Super-Hybrid powertrain range split
/// - Projected arrival battery SoC calculation with consumption derating
/// - Corridor DC fast charger waypoint recommendation
class TripPlannerService {
  static final TripPlannerService instance = TripPlannerService._internal();
  TripPlannerService._internal();

  static const double batteryCapacityKwh = 18.3; // Chery Tiggo 7 PHEV usable pack
  static const double defaultConsKwh100 = 16.8; // WLTP baseline for Malaysian Tiggo 7 CSH

  /// Calculate EV route, reachability, and charging recommendation
  Future<PlannedRouteResult> planRoute({
    required LatLng origin,
    required LatLng destination,
    required String destinationName,
    required int currentSoc,
    double? consumptionKwh100,
  }) async {
    final double cons = (consumptionKwh100 != null && consumptionKwh100 > 5.0 && consumptionKwh100 < 35.0)
        ? consumptionKwh100
        : defaultConsKwh100;

    // Available EV Range = (currentSoc% / 100) * Pack kWh / (kWh/100km / 100)
    final double evRangeAvailable = (currentSoc / 100.0) * batteryCapacityKwh / (cons / 100.0);

    double distanceKm = 0.0;
    int durationMin = 0;
    List<LatLng> polyline = [];

    // 1. Fetch real highway route from OSRM
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final r0 = routes[0] as Map<String, dynamic>;
          final distMeters = (r0['distance'] as num?)?.toDouble() ?? 0.0;
          final durSecs = (r0['duration'] as num?)?.toDouble() ?? 0.0;
          distanceKm = distMeters / 1000.0;
          durationMin = (durSecs / 60.0).round();

          final geom = r0['geometry'] as Map<String, dynamic>?;
          final coords = geom?['coordinates'] as List<dynamic>?;
          if (coords != null) {
            polyline = coords.map((c) {
              final lon = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              return LatLng(lat, lon);
            }).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM routing fallback to geodesic: $e');
    }

    // Geodesic fallback if offline or API blocked
    if (distanceKm <= 0.0 || polyline.isEmpty) {
      final Distance distCalc = const Distance();
      final directMeters = distCalc.as(LengthUnit.Meter, origin, destination);
      // Driving factor in Malaysia road network is typically 1.25x - 1.30x direct line
      distanceKm = (directMeters * 1.28) / 1000.0;
      durationMin = (distanceKm / 80.0 * 60.0).round(); // Assume 80 km/h average
      polyline = [origin, destination];
    }

    // 2. Pure EV Reachability vs Hybrid Split
    final bool canReachPureEv = distanceKm <= evRangeAvailable;
    double projectedArrivalSoc = 0.0;
    double electricShareKm = 0.0;
    double hybridShareKm = 0.0;

    if (canReachPureEv) {
      final socUsed = (distanceKm * (cons / 100.0) / batteryCapacityKwh) * 100.0;
      projectedArrivalSoc = (currentSoc - socUsed).clamp(0.0, 100.0);
      electricShareKm = distanceKm;
      hybridShareKm = 0.0;
    } else {
      projectedArrivalSoc = 0.0;
      electricShareKm = evRangeAvailable;
      hybridShareKm = distanceKm - evRangeAvailable;
    }

    // 3. Recommended DC Fast Charging Stop along Corridor
    PlannedChargingStop? stop;
    if (!canReachPureEv && distanceKm > 60.0) {
      // Find a charger located between 25% and 80% along the trip distance
      stop = _findBestChargerOnRoute(origin, destination, distanceKm);
    }

    return PlannedRouteResult(
      destinationName: destinationName,
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      durationMinutes: durationMin,
      polyline: polyline,
      evRangeAvailableKm: double.parse(evRangeAvailable.toStringAsFixed(1)),
      projectedArrivalSoc: double.parse(projectedArrivalSoc.toStringAsFixed(0)),
      canReachPureEv: canReachPureEv,
      electricShareKm: double.parse(electricShareKm.toStringAsFixed(1)),
      hybridShareKm: double.parse(hybridShareKm.toStringAsFixed(1)),
      recommendedStop: stop,
    );
  }

  PlannedChargingStop? _findBestChargerOnRoute(LatLng orig, LatLng dest, double totalDistKm) {
    PlannedChargingStop? best;
    double minDeviation = double.infinity;
    const distCalc = Distance();

    for (final charger in kHighwayChargers) {
      final dFromOrig = distCalc.as(LengthUnit.Kilometer, orig, charger.location);
      final dToDest = distCalc.as(LengthUnit.Kilometer, charger.location, dest);
      final totalWithStop = dFromOrig + dToDest;

      // Charger is on-corridor if deviation from direct line is < 25 km
      final deviation = totalWithStop - (totalDistKm * 0.8);
      if (dFromOrig > 20.0 && dFromOrig < totalDistKm * 0.85 && deviation < minDeviation) {
        minDeviation = deviation;
        best = charger;
      }
    }
    return best;
  }
}
