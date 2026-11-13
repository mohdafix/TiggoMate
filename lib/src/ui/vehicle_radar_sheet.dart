import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../carlinko/vehicle_repository.dart';
import '../service/phone_parking_location.dart';
import '../service/trip_planner_service.dart';
import '../theme/app_theme.dart';
import 'app_notification.dart';
import 'apple_design_widgets.dart';

/// A charging location saved in the app. Live availability and prices are not known.
class _SavedCharger {
  final String name;
  final String plugs;
  final double lat;
  final double lon;

  const _SavedCharger({
    required this.name,
    required this.plugs,
    required this.lat,
    required this.lon,
  });
}

const List<_SavedCharger> _savedChargers = [
  _SavedCharger(
    name: 'Gentari - KL Gateway Mall',
    plugs: '2x Type 2 AC (22 kW) • 1x 60 kW DC',
    lat: 3.1182,
    lon: 101.6644,
  ),
  _SavedCharger(
    name: 'ChargEV - Nexus Bangsar South',
    plugs: '4x Type 2 AC (11 kW)',
    lat: 3.1197,
    lon: 101.6669,
  ),
  _SavedCharger(
    name: 'Shell Recharge - Pantai Sentral',
    plugs: '2x Type 2 AC (7.4 kW) • 1x 120 kW DC',
    lat: 3.1091,
    lon: 101.6612,
  ),
];

class _SavedPetrolStation {
  final String name;
  final String brand;
  final String fuels;
  final double lat;
  final double lon;

  const _SavedPetrolStation({
    required this.name,
    required this.brand,
    required this.fuels,
    required this.lat,
    required this.lon,
  });
}

const List<_SavedPetrolStation> _savedPetrolStations = [
  _SavedPetrolStation(
    name: 'Petronas - Bangsar South',
    brand: 'Petronas',
    fuels: 'RON95 (RM2.05) • RON97 • Dynamic Diesel • Mesra Mart • ATM',
    lat: 3.1165,
    lon: 101.6672,
  ),
  _SavedPetrolStation(
    name: 'Shell - Federal Highway (Pantai)',
    brand: 'Shell',
    fuels: 'FuelSave 95 • V-Power 97 • V-Power Racing • Shell Select',
    lat: 3.1145,
    lon: 101.6628,
  ),
  _SavedPetrolStation(
    name: 'Petronas - Jalan Maarof, Bangsar',
    brand: 'Petronas',
    fuels: 'RON95 • RON97 • Euro 5 Diesel • Mesra Shop • Surau',
    lat: 3.1298,
    lon: 101.6715,
  ),
  _SavedPetrolStation(
    name: 'BHPetrol - Jalan Klang Lama',
    brand: 'BHPetrol',
    fuels: 'Infiniti 95 • Infiniti 97 • Infiniti Diesel • BHPetromart',
    lat: 3.0988,
    lon: 101.6738,
  ),
  _SavedPetrolStation(
    name: 'Caltex - Mid Valley / Federal Highway',
    brand: 'Caltex',
    fuels: 'Techron 95 • Techron 97 • Diesel with Techron D • Star Mart',
    lat: 3.1189,
    lon: 101.6781,
  ),
  _SavedPetrolStation(
    name: 'Petron - Jalan Universiti, PJ',
    brand: 'Petron',
    fuels: 'Blaze 95 • Blaze 97 • Blaze 100 • Turbo Diesel • Treats Mart',
    lat: 3.1180,
    lon: 101.6520,
  ),
  _SavedPetrolStation(
    name: 'Shell - Jalan Ampang / KLCC',
    brand: 'Shell',
    fuels: 'FuelSave 95 • V-Power 97 • Shell Select • Costa Coffee',
    lat: 3.1595,
    lon: 101.7160,
  ),
  _SavedPetrolStation(
    name: 'Petronas - Ampang Jaya / MRR2',
    brand: 'Petronas',
    fuels: 'RON95 • RON97 • Dynamic Diesel • Mesra Mart • Tealive',
    lat: 3.1530,
    lon: 101.7580,
  ),
  _SavedPetrolStation(
    name: 'Petronas Solaris Serdang (SBE Highway)',
    brand: 'Petronas',
    fuels: 'RON95 • RON97 • Diesel Euro 5 • Mesra Mart • Starbucks',
    lat: 3.0135,
    lon: 101.7180,
  ),
  _SavedPetrolStation(
    name: 'Shell - Subang Jaya SS15',
    brand: 'Shell',
    fuels: 'FuelSave 95 • V-Power 97 • Shell Select • ATM',
    lat: 3.0760,
    lon: 101.5910,
  ),
];

/// Interactive Circular Radar HUD & Vehicle Locator Sheet (Phase 1)
/// Inspired by tactical automotive radar and official Chery CarLinko Find My Car.
class VehicleRadarSheet extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final VoidCallback onHornFlash;
  final VehicleRepository? repository;

  const VehicleRadarSheet({
    super.key,
    required this.telemetry,
    required this.onHornFlash,
    this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTelemetry telemetry,
    required VoidCallback onHornFlash,
    VehicleRepository? repository,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1219) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => VehicleRadarSheet(
        telemetry: telemetry,
        onHornFlash: onHornFlash,
        repository: repository,
      ),
    );
  }

  @override
  State<VehicleRadarSheet> createState() => _VehicleRadarSheetState();
}

class _VehicleRadarSheetState extends State<VehicleRadarSheet> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  bool _isFlashing = false;
  int _activeRadarTab = 0; // 0: Radar Map, 1: Nearby Chargers, 2: Geofence Guard
  PhoneParkedLocation? _phoneFallback;
  bool _showPhoneFallbackOnRadar = false;
  Position? _phonePosition;
  int _stationLocationSource = 0; // 0: Phone Location (default when available), 1: Car Location
  int _selectedStationCategory = 0; // 0: EV Chargers, 1: Petrol Stations, 2: All Energy

  // Geofence Guard State
  List<Map<String, dynamic>> _geofences = [];
  bool _isLoadingGeofences = false;
  double _selectedFenceRadius = 500; // 200m, 500m, 1000m, 2000m
  int _selectedAlarmType = 2; // 2: Exit (googleDriveOut), 1: Entry (googleDriveIn)
  final TextEditingController _fenceNameCtrl = TextEditingController(text: 'Home Perimeter');
  LatLng? _customFenceCenter;
  final MapController _geofenceMapController = MapController();

  // Tab 3: Smart EV Route & Highway Charger Planner
  MalaysianPresetDestination? _selectedPreset;
  PlannedRouteResult? _plannedRoute;
  bool _isCalculatingRoute = false;
  final MapController _plannerMapController = MapController();

  Timer? _liveLocateTimer;

  bool get _isCarActive => widget.telemetry.engineOn || widget.telemetry.speedKmH > 0;
  bool get _usingPhoneFallback => _showPhoneFallbackOnRadar && !_isCarActive && !widget.telemetry.hasLocation && _phoneFallback != null;
  bool get _hasAnyLocation => widget.telemetry.hasLocation || _usingPhoneFallback;
  double get _effectiveLat => _usingPhoneFallback ? _phoneFallback!.latitude : widget.telemetry.latitude;
  double get _effectiveLon => _usingPhoneFallback ? _phoneFallback!.longitude : widget.telemetry.longitude;

  (double, double)? get _stationReferenceCoords {
    if (_stationLocationSource == 1) {
      if (widget.telemetry.hasLocation && widget.telemetry.latitude != 0.0) {
        return (widget.telemetry.latitude, widget.telemetry.longitude);
      }
      return null;
    }
    if (_phonePosition != null && _phonePosition!.latitude != 0.0) {
      return (_phonePosition!.latitude, _phonePosition!.longitude);
    }
    if (widget.telemetry.hasLocation && widget.telemetry.latitude != 0.0) {
      return (widget.telemetry.latitude, widget.telemetry.longitude);
    }
    if (_phoneFallback != null && _phoneFallback!.latitude != 0.0) {
      return (_phoneFallback!.latitude, _phoneFallback!.longitude);
    }
    return null;
  }

  bool get _isStationUsingCar =>
      _stationLocationSource == 1 || (_phonePosition == null && widget.telemetry.hasLocation);

  LatLng get _effectiveFenceCenter {
    if (_customFenceCenter != null) return _customFenceCenter!;
    if (_hasAnyLocation && _effectiveLat != 0.0 && _effectiveLon != 0.0) {
      return LatLng(_effectiveLat, _effectiveLon);
    }
    return const LatLng(3.1390, 101.6869);
  }
  bool get _hasActiveGeofence => _geofences.any((f) => f['status'] == 1 || f['status'] == '1' || f['status'] == true);

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fetchPhoneLocation();

    if (!_isCarActive && !widget.telemetry.hasLocation) {
      PhoneParkingLocationService.loadLast(requireBluetoothVerification: true).then((loc) {
        if (mounted && loc != null) setState(() => _phoneFallback = loc);
      });
    }

    if (widget.repository != null) {
      _loadGeofences();
      // Periodically refresh vehicle GPS and telemetry while the radar sheet is active
      _liveLocateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted && widget.repository != null) {
          widget.repository!.refresh();
        }
      });
    }
  }

  Future<void> _fetchPhoneLocation() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (mounted && last != null && last.latitude != 0.0) {
        setState(() => _phonePosition = last);
      }
      final cur = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      if (mounted && cur.latitude != 0.0) {
        setState(() => _phonePosition = cur);
      }
    } catch (_) {}
  }

  Future<void> _loadGeofences() async {
    if (widget.repository == null) return;
    setState(() => _isLoadingGeofences = true);
    try {
      final list = await widget.repository!.getGeofences();
      if (mounted) {
        setState(() {
          _geofences = list;
          _isLoadingGeofences = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGeofences = false);
    }
  }

  Future<void> _snapToPhoneLocation() async {
    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(timeLimit: Duration(seconds: 4)),
          );
      if (mounted && pos != null) {
        final point = LatLng(pos.latitude, pos.longitude);
        setState(() => _customFenceCenter = point);
        _geofenceMapController.move(point, 15.5);
        _showToast('📍 Center set to Phone Location');
      }
    } catch (_) {
      _showToast('Unable to get phone GPS fix');
    }
  }

  void _snapToCarLocation() {
    if (_hasAnyLocation && _effectiveLat != 0.0 && _effectiveLon != 0.0) {
      final point = LatLng(_effectiveLat, _effectiveLon);
      setState(() => _customFenceCenter = point);
      _geofenceMapController.move(point, 15.5);
      _showToast('🚗 Center set to Vehicle Location');
    } else {
      _showToast('Vehicle GPS coordinates unavailable');
    }
  }

  Future<void> _createGeofence() async {
    if (widget.repository == null) {
      _showToast('Vehicle service not connected');
      return;
    }
    final target = _effectiveFenceCenter;
    if (target.latitude == 0.0 && target.longitude == 0.0) {
      _showToast('Please select a location on the map');
      return;
    }
    final name = _fenceNameCtrl.text.trim().isEmpty ? 'Zone' : _fenceNameCtrl.text.trim();
    _showToast('📡 Registering geofence with Chery T-Box...');

    // If an existing fence is already registered on Chery cloud, update it instead of adding
    final existingFence = _geofences.isNotEmpty ? _geofences.first : null;
    final existingId = existingFence != null ? existingFence['id']?.toString() : null;

    final result = (existingId != null && existingId.isNotEmpty)
        ? await widget.repository!.updateGeofenceWithResult(
            fenceId: existingId,
            name: name,
            lat: target.latitude,
            lng: target.longitude,
            radius: _selectedFenceRadius,
            alarmType: _selectedAlarmType,
          )
        : await widget.repository!.addGeofenceWithResult(
            name: name,
            lat: target.latitude,
            lng: target.longitude,
            radius: _selectedFenceRadius,
            alarmType: _selectedAlarmType,
          );

    if (result.success) {
      _showToast('🛡️ Geofence "$name" (${_selectedFenceRadius.toInt()}m) active on T-Box!');
      await _loadGeofences();
    } else {
      // If Chery cloud rejected (e.g. 50054: cloud fencing not supported in Malaysia),
      // activate TiggoMate Local Smart Perimeter Guard client-side!
      final prefs = await SharedPreferences.getInstance();
      final localFence = {
        'id': 'local_guard',
        'vehicleId': 'local',
        'name': '$name (Local Guard)',
        'lat': target.latitude,
        'lng': target.longitude,
        'radius': _selectedFenceRadius.round(),
        'alarmType': _selectedAlarmType,
        'status': 1,
        'isLocal': true,
      };
      await prefs.setString('tm_local_geofence', json.encode(localFence));
      await prefs.remove('tm_fence_was_outside');

      _showToast('🛡️ Local Smart Perimeter Guard activated!');
      await VehicleAlertsManager.instance.addAlert(
        VehicleAlertItem(
          id: 'local_guard_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Local Smart Perimeter Guard Active',
          message: 'Chery cloud hardware fencing is not enabled in Malaysia. TiggoMate client engine is now guarding "$name" (${_selectedFenceRadius.toInt()}m radius).',
          timestamp: DateTime.now(),
          type: NotificationType.info,
          icon: Icons.shield_outlined,
        ),
      );
      await _loadGeofences();
    }
  }

  Future<void> _toggleGeofenceStatus(String id, dynamic currentStatus) async {
    final statusInt = (currentStatus == 1 || currentStatus == '1' || currentStatus == true) ? 1 : 0;
    final newStatus = statusInt == 1 ? 0 : 1;
    final ok = await widget.repository!.updateGeofenceStatus(id, newStatus);
    if (ok) {
      _showToast(newStatus == 1 ? '🛡️ Geofence enabled' : '⏸ Geofence paused');
      await _loadGeofences();
    }
  }

  Future<void> _deleteGeofence(String id) async {
    final ok = await widget.repository!.deleteGeofence(id);
    if (ok) {
      _showToast('🗑️ Geofence deleted');
      await _loadGeofences();
    }
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _calculateRouteForPreset(MalaysianPresetDestination preset) async {
    setState(() {
      _selectedPreset = preset;
      _isCalculatingRoute = true;
    });

    final double startLat = (widget.telemetry.latitude.abs() > 0.01)
        ? widget.telemetry.latitude
        : (_phonePosition?.latitude ?? 3.1390);
    final double startLon = (widget.telemetry.longitude.abs() > 0.01)
        ? widget.telemetry.longitude
        : (_phonePosition?.longitude ?? 101.6869);

    final res = await TripPlannerService.instance.planRoute(
      origin: LatLng(startLat, startLon),
      destination: preset.location,
      destinationName: preset.name,
      currentSoc: widget.telemetry.batteryPct > 0 ? widget.telemetry.batteryPct : 80,
      consumptionKwh100: widget.telemetry.energyConsumptionKwh100km > 0
          ? widget.telemetry.energyConsumptionKwh100km
          : 16.8,
    );

    if (mounted) {
      setState(() {
        _plannedRoute = res;
        _isCalculatingRoute = false;
      });
      try {
        _plannerMapController.move(
          LatLng((startLat + preset.location.latitude) / 2, (startLon + preset.location.longitude) / 2),
          8.0,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _liveLocateTimer?.cancel();
    _radarController.dispose();
    _fenceNameCtrl.dispose();
    super.dispose();
  }

  Widget _buildRadarMapLayer(double lat, double lon, bool hasAnyLocation) {
    if (!hasAnyLocation || (lat == 0.0 && lon == 0.0)) {
      return Container(
        color: const Color(0xFF131923),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.satellite_alt_rounded, color: Color(0xFF9CA3AF), size: 36),
            const SizedBox(height: 8),
            const Text(
              'Awaiting Vehicle GPS Fix',
              style: TextStyle(color: Color(0xFFD2F835), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chery T-Box pending lock',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 9.5),
            ),
          ],
        ),
      );
    }
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lon),
          initialZoom: 16,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.tiggomate.tiggomate_app',
          ),
          if (_hasActiveGeofence || _activeRadarTab == 2)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: LatLng(lat, lon),
                  radius: _selectedFenceRadius,
                  useRadiusInMeter: true,
                  color: const Color(0xFFD2F835).withValues(alpha: 0.14),
                  borderColor: const Color(0xFFD2F835),
                  borderStrokeWidth: 2.0,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _launchWaze(double lat, double lon) async {
    if (lat == 0.0 && lon == 0.0) {
      _showToast('Car location unavailable');
      return;
    }
    final nativeUri = Uri.parse('waze://?ll=$lat,$lon&navigate=yes');
    final webUri = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('Could not open Waze');
    }
  }

  Future<void> _launchGoogleMaps(double lat, double lon) async {
    if (lat == 0.0 && lon == 0.0) {
      _showToast('Car location unavailable');
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('Could not open Google Maps');
    }
  }

  Future<void> _launchChargerSearch(double lat, double lon) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=EV+charging+station+near+$lat%2C$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('Could not open Google Maps');
    }
  }

  Future<void> _launchPetrolSearch(double lat, double lon) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=petrol+station+near+$lat%2C$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('Could not open Google Maps');
    }
  }

  double _distanceToCoords(double stationLat, double stationLon) {
    final coords = _stationReferenceCoords;
    if (coords == null) return -1;
    return Geolocator.distanceBetween(
      coords.$1,
      coords.$2,
      stationLat,
      stationLon,
    );
  }

  double _distanceToCarMetres(_SavedCharger charger) =>
      _distanceToCoords(charger.lat, charger.lon);

  String _formatDistance(double metres) {
    if (metres < 0) return '--';
    if (metres < 1000) return '${metres.round()} m';
    final km = metres / 1000;
    return '${km.toStringAsFixed(km < 100 ? 1 : 0)} km';
  }

  /// Saved chargers, nearest to the anchor first when position is known.
  List<_SavedCharger> get _chargersByDistance {
    final chargers = List<_SavedCharger>.of(_savedChargers);
    if (_stationReferenceCoords != null) {
      chargers.sort((a, b) => _distanceToCoords(a.lat, a.lon).compareTo(_distanceToCoords(b.lat, b.lon)));
    }
    return chargers;
  }

  /// Saved petrol stations, nearest to anchor first.
  List<_SavedPetrolStation> get _petrolStationsByDistance {
    final stations = List<_SavedPetrolStation>.of(_savedPetrolStations);
    if (_stationReferenceCoords != null) {
      stations.sort((a, b) => _distanceToCoords(a.lat, a.lon).compareTo(_distanceToCoords(b.lat, b.lon)));
    }
    return stations;
  }

  /// Combined energy stations (EV + Petrol)
  List<dynamic> get _allStationsByDistance {
    final list = <dynamic>[..._savedChargers, ..._savedPetrolStations];
    if (_stationReferenceCoords != null) {
      list.sort((a, b) {
        final aLat = a is _SavedCharger ? a.lat : (a as _SavedPetrolStation).lat;
        final aLon = a is _SavedCharger ? a.lon : (a as _SavedPetrolStation).lon;
        final bLat = b is _SavedCharger ? b.lat : (b as _SavedPetrolStation).lat;
        final bLon = b is _SavedCharger ? b.lon : (b as _SavedPetrolStation).lon;
        return _distanceToCoords(aLat, aLon).compareTo(_distanceToCoords(bLat, bLon));
      });
    }
    return list;
  }

  String _compassPoint(double degrees) {
    const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return points[((degrees % 360) / 45).round() % 8];
  }

  void _copyGps() {
    if (!_hasAnyLocation) {
      _showToast('Car location unavailable');
      return;
    }
    final coords = '${_effectiveLat.toStringAsFixed(5)}, ${_effectiveLon.toStringAsFixed(5)}';
    Clipboard.setData(ClipboardData(text: coords));
    _showToast('GPS coordinates copied to clipboard: $coords');
  }

  void _triggerHornFlash() {
    setState(() => _isFlashing = true);
    widget.onHornFlash();
    _showToast('📢 Sounding horn & flashing headlights...');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isFlashing = false);
    });
  }

  void _showToast(String msg) {
    AppNotification.show(
      context,
      message: msg,
      type: NotificationType.info,
      icon: Icons.radar_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;
    final usingPhoneFallback = !widget.telemetry.hasLocation && _phoneFallback != null;
    final lat = usingPhoneFallback ? _phoneFallback!.latitude : widget.telemetry.latitude;
    final lon = usingPhoneFallback ? _phoneFallback!.longitude : widget.telemetry.longitude;
    final coords = _stationReferenceCoords;
    final hasCoords = coords != null;
    final refLat = coords?.$1 ?? 3.1390;
    final refLon = coords?.$2 ?? 101.6869;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // Pull Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.evTeal.withValues(alpha: 0.15),
                        ),
                        child: Icon(Icons.radar, color: colors.evTeal, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle Radar & Finder',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Live GPS Tracking • Vehicle Telematics',
                            style: TextStyle(fontSize: 11, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sub-Tab Switcher: 0: Radar Map, 1: Nearby EV Chargers, 2: Geofence Guard
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeRadarTab = 0),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeRadarTab == 0
                                ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _activeRadarTab == 0 && !isDark
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.explore_outlined,
                                    size: 14,
                                    color: _activeRadarTab == 0 ? colors.evTeal : colors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Circular Radar HUD',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _activeRadarTab == 0 ? FontWeight.bold : FontWeight.normal,
                                      color: _activeRadarTab == 0 ? colors.textPrimary : colors.textMuted,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeRadarTab = 1),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeRadarTab == 1
                                ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _activeRadarTab == 1 && !isDark
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.ev_station,
                                    size: 14,
                                    color: _activeRadarTab == 1 ? colors.evTeal : colors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Nearby Chargers',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _activeRadarTab == 1 ? FontWeight.bold : FontWeight.normal,
                                      color: _activeRadarTab == 1 ? colors.textPrimary : colors.textMuted,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeRadarTab = 2),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeRadarTab == 2
                                ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _activeRadarTab == 2 && !isDark
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 14,
                                    color: _activeRadarTab == 2 ? const Color(0xFFD2F835) : colors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Geofence Guard',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _activeRadarTab == 2 ? FontWeight.bold : FontWeight.normal,
                                      color: _activeRadarTab == 2 ? colors.textPrimary : colors.textMuted,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _activeRadarTab = 3);
                          if (_selectedPreset == null && kMalaysianPresets.isNotEmpty) {
                            _calculateRouteForPreset(kMalaysianPresets.first);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeRadarTab == 3
                                ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _activeRadarTab == 3 && !isDark
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.alt_route_rounded,
                                    size: 14,
                                    color: _activeRadarTab == 3 ? const Color(0xFF00E5FF) : colors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Trip Planner',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _activeRadarTab == 3 ? FontWeight.bold : FontWeight.normal,
                                      color: _activeRadarTab == 3 ? colors.textPrimary : colors.textMuted,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_activeRadarTab == 0) ...[
                // ---------------- 1. CIRCULAR RADAR HUD ----------------
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Compass Cardinal Rim
                      Container(
                        width: 270,
                        height: 270,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                        ),
                      ),

                      // Cardinal Labels (N, S, E, W)
                      Positioned(
                        top: 2,
                        child: Text(
                          'N',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.evTeal,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        child: Text(
                          'S',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        child: Text(
                          'E',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 4,
                        child: Text(
                          'W',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.textMuted,
                          ),
                        ),
                      ),

                      // Real Map + Radar HUD Overlay inside Circular Viewport
                      ClipOval(
                        child: SizedBox(
                          width: 236,
                          height: 236,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildRadarMapLayer(lat, lon, usingPhoneFallback || widget.telemetry.hasLocation),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _radarController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        size: const Size(236, 236),
                                        painter: _CircularRadarMapPainter(
                                          isDark: isDark,
                                          radarAngle: _radarController.value * 2 * math.pi,
                                          animValue: _radarController.value,
                                          headingAngle: widget.telemetry.headingDegrees * (math.pi / 180),
                                          isFlashing: _isFlashing,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Outer circular bezel matching reference screenshot
                      IgnorePointer(
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF4B5563) : const Color(0xFF6B7280),
                              width: 3.5,
                            ),
                          ),
                        ),
                      ),

                      // Scanning live badge
                      Positioned(
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black87 : Colors.white).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: widget.telemetry.hasLocation
                                      ? colors.evTeal
                                      : (usingPhoneFallback ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B)),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.telemetry.hasLocation
                                    ? 'GPS Locked • Range 200m'
                                    : (usingPhoneFallback
                                        ? 'Phone Parked Spot (Not Car Live GPS)'
                                        : 'Awaiting Car GPS Fix • Range 200m'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ---------------- 2. LOCATION TELEMETRY CARD ----------------
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  widget.telemetry.hasLocation ? Icons.place : (usingPhoneFallback ? Icons.smartphone : Icons.satellite_alt_outlined),
                                  color: widget.telemetry.hasLocation ? colors.evTeal : (usingPhoneFallback ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B)),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.telemetry.hasLocation
                                        ? widget.telemetry.locationName
                                        : (usingPhoneFallback
                                            ? (_phoneFallback!.address ?? 'Phone location (approx.)')
                                            : (widget.telemetry.locationName.isNotEmpty && widget.telemetry.locationName != 'Pending Car Bind'
                                                ? widget.telemetry.locationName
                                                : 'Vehicle GPS Signal Pending')),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (usingPhoneFallback) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.smartphone, size: 11, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'From Phone Bluetooth · ${_relativeTime(_phoneFallback!.timestamp)} (Driver may be elsewhere)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF38BDF8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!widget.telemetry.hasLocation && !usingPhoneFallback && widget.repository?.lastLocateStatus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.repository!.lastLocateStatus!,
                          style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        widget.telemetry.hasLocation || usingPhoneFallback
                            ? 'Coordinates: ${lat.toStringAsFixed(4)}° N, ${lon.toStringAsFixed(4)}° E${usingPhoneFallback ? '' : ' • Bearing: ${widget.telemetry.headingDegrees.toStringAsFixed(0)}° ${_compassPoint(widget.telemetry.headingDegrees)}'}'
                            : 'Coordinates unavailable',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: colors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            widget.telemetry.parkedDurationText,
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          Icon(widget.telemetry.doorsOpen ? Icons.lock_open : Icons.lock, size: 12, color: colors.evTeal),
                          const SizedBox(width: 4),
                          Text(
                            widget.telemetry.doorsOpen ? 'Doors open' : 'Doors closed',
                            style: TextStyle(fontSize: 11, color: colors.evTeal, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_phoneFallback != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.smartphone_rounded, size: 15, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Phone Bluetooth Parking Spot',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                              ),
                            ),
                            Text(
                              _relativeTime(_phoneFallback!.timestamp),
                              style: TextStyle(fontSize: 10, color: colors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _phoneFallback!.address ?? 'Saved Location',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Recorded when this phone disconnected from car Bluetooth. If someone else (e.g. spouse) is driving, the car is elsewhere.',
                          style: TextStyle(fontSize: 10, color: colors.textMuted, height: 1.25),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _showPhoneFallbackOnRadar = !_showPhoneFallbackOnRadar);
                              },
                              icon: Icon(
                                _showPhoneFallbackOnRadar ? Icons.directions_car : Icons.radar_rounded,
                                size: 13,
                                color: const Color(0xFF38BDF8),
                              ),
                              label: Text(
                                _showPhoneFallbackOnRadar ? 'Show Car Status' : 'View on Radar',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF38BDF8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () async {
                                await PhoneParkingLocationService.clear();
                                if (mounted) {
                                  setState(() {
                                    _phoneFallback = null;
                                    _showPhoneFallbackOnRadar = false;
                                  });
                                }
                              },
                              icon: Icon(Icons.delete_outline, size: 13, color: colors.textMuted),
                              label: Text(
                                'Clear Memory',
                                style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ---------------- 3. INSTANT ACTION BUTTONS ----------------
                Row(
                  children: [
                    // Waze Direct Route
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchWaze(lat, lon),
                        icon: const Icon(Icons.navigation, size: 15),
                        label: const Text('Waze Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF33CCFF),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Google Maps Direct Route
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchGoogleMaps(lat, lon),
                        icon: const Icon(Icons.map_outlined, size: 15),
                        label: const Text('Google Maps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34A853),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // Flash & Horn (for parking garage)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _triggerHornFlash,
                        icon: Icon(
                          _isFlashing ? Icons.flash_on : Icons.notifications_active_outlined,
                          size: 15,
                          color: colors.petrolAmber,
                        ),
                        label: Text(
                          _isFlashing ? 'Flashing...' : 'Horn & Flash',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Copy GPS
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyGps,
                        icon: Icon(Icons.copy, size: 14, color: colors.textSecondary),
                        label: Text(
                          'Copy GPS',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_activeRadarTab == 1) ...[
                // ---------------- 4. EV & PETROL ENERGY STATIONS ----------------

                // 1. Location Source Indicator Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !_isStationUsingCar ? Icons.my_location : Icons.directions_car,
                        size: 15,
                        color: colors.evTeal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              !_isStationUsingCar
                                  ? (_phonePosition != null ? 'My Phone Current Location' : 'Current Phone GPS')
                                  : (widget.telemetry.hasLocation ? 'Vehicle Telematics Location' : 'Vehicle GPS (Awaiting fix)'),
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                            Text(
                              hasCoords
                                  ? '${refLat.toStringAsFixed(4)}° N, ${refLon.toStringAsFixed(4)}° E • Live distance anchor'
                                  : 'Location unavailable • Tap refresh to acquire GPS',
                              style: TextStyle(fontSize: 10, color: colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (widget.telemetry.hasLocation) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _stationLocationSource = _stationLocationSource == 0 ? 1 : 0;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              _stationLocationSource == 0 ? 'Use Car' : 'Use Phone',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.evTeal),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      InkWell(
                        onTap: () {
                          _fetchPhoneLocation();
                          _showToast('Updating phone location...');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: colors.cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.border),
                          ),
                          child: Icon(Icons.refresh, size: 13, color: colors.evTeal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Energy Category Filter Pills
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      _buildStationCategoryPill(0, '⚡ EV Chargers (${_savedChargers.length})', colors),
                      _buildStationCategoryPill(1, '⛽ Petrol (${_savedPetrolStations.length})', colors),
                      _buildStationCategoryPill(2, '⭐ All Energy', colors),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Search Action Button
                if (_selectedStationCategory == 0) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: hasCoords ? () => _launchChargerSearch(refLat, refLon) : null,
                      icon: const Icon(Icons.ev_station, size: 16),
                      label: Text(
                        hasCoords ? 'Find Chargers Near Car' : 'Car location unavailable',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else if (_selectedStationCategory == 1) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: hasCoords ? () => _launchPetrolSearch(refLat, refLon) : null,
                      icon: const Icon(Icons.local_gas_station, size: 16),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black87,
                      ),
                      label: Text(
                        hasCoords ? 'Find Petrol Stations Near Me' : 'Location unavailable',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasCoords ? () => _launchChargerSearch(refLat, refLon) : null,
                          icon: const Icon(Icons.ev_station, size: 15),
                          label: const Text('Find Chargers', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasCoords ? () => _launchPetrolSearch(refLat, refLon) : null,
                          icon: const Icon(Icons.local_gas_station, size: 15),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black87,
                          ),
                          label: const Text('Find Petrol', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // 4. Section Title
                Text(
                  _selectedStationCategory == 0
                      ? 'Saved Chargers (Bangsar South)'
                      : (_selectedStationCategory == 1
                          ? 'Popular Petrol Stations (RON95 / RON97)'
                          : 'Nearby Energy Stations (EV & Petrol)'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  hasCoords
                      ? (_isStationUsingCar
                          ? 'Distance from your car. Check availability and prices in Maps.'
                          : 'Distance from your phone location. Check availability in Maps.')
                      : 'Check availability and prices in Maps.',
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
                const SizedBox(height: 10),

                // 5. Stations List
                if (_selectedStationCategory == 0) ...[
                  for (final charger in _chargersByDistance) ...[
                    _buildChargerTile(
                      name: charger.name,
                      distance: hasCoords ? _formatDistance(_distanceToCarMetres(charger)) : '--',
                      plugs: charger.plugs,
                      lat: charger.lat,
                      lon: charger.lon,
                      colors: colors,
                    ),
                    const SizedBox(height: 10),
                  ],
                ] else if (_selectedStationCategory == 1) ...[
                  for (final station in _petrolStationsByDistance) ...[
                    _buildPetrolStationTile(
                      station: station,
                      distance: hasCoords ? _formatDistance(_distanceToCoords(station.lat, station.lon)) : '--',
                      colors: colors,
                    ),
                    const SizedBox(height: 10),
                  ],
                ] else ...[
                  for (final item in _allStationsByDistance) ...[
                    item is _SavedCharger
                        ? _buildChargerTile(
                            name: item.name,
                            distance: hasCoords ? _formatDistance(_distanceToCarMetres(item)) : '--',
                            plugs: item.plugs,
                            lat: item.lat,
                            lon: item.lon,
                            colors: colors,
                          )
                        : _buildPetrolStationTile(
                            station: item as _SavedPetrolStation,
                            distance: hasCoords ? _formatDistance(_distanceToCoords((item).lat, (item).lon)) : '--',
                            colors: colors,
                          ),
                    const SizedBox(height: 10),
                  ],
                ],
              ] else if (_activeRadarTab == 2) ...[
                // ---------------- 5. CHERY T-BOX GEOFENCE GUARD ----------------
                _buildGeofenceTab(colors, isDark, lat, lon),
              ] else ...[
                // ---------------- 6. SMART TRIP & CHARGER PLANNER --------------
                _buildTripPlannerTab(colors, isDark, lat, lon),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripPlannerTab(AppColors colors, bool isDark, double lat, double lon) {
    final route = _plannedRoute;
    final isCalc = _isCalculatingRoute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Destination Preset Selector Chips
        Text(
          'DESTINATION CORRIDOR (MALAYSIA)',
          style: TextStyle(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: kMalaysianPresets.map((preset) {
              final isSel = _selectedPreset?.name == preset.name;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(preset.name),
                  selected: isSel,
                  onSelected: (val) => _calculateRouteForPreset(preset),
                  selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF00E5FF),
                  backgroundColor: colors.tileBg,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? const Color(0xFF00E5FF) : colors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSel ? const Color(0xFF00E5FF) : colors.border,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // 2. Interactive Route Polyline Map
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _plannerMapController,
                options: MapOptions(
                  initialCenter: _selectedPreset != null
                      ? LatLng((lat + _selectedPreset!.location.latitude) / 2, (lon + _selectedPreset!.location.longitude) / 2)
                      : LatLng(lat != 0 ? lat : 3.1390, lon != 0 ? lon : 101.6869),
                  initialZoom: 8.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tiggomate.tiggomate_app',
                  ),
                  if (route != null && route.polyline.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route.polyline,
                          strokeWidth: 4.5,
                          color: const Color(0xFF00E5FF),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // Car start marker
                      Marker(
                        point: LatLng(lat != 0 ? lat : 3.1390, lon != 0 ? lon : 101.6869),
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.directions_car, color: Color(0xFF00E5FF), size: 18),
                        ),
                      ),
                      // Destination marker
                      if (_selectedPreset != null)
                        Marker(
                          point: _selectedPreset!.location,
                          width: 32,
                          height: 32,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFE11D48),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      // Recommended DC Fast Charger Marker
                      if (route?.recommendedStop != null)
                        Marker(
                          point: route!.recommendedStop!.location,
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB300),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.bolt, color: Colors.black, size: 22),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (isCalc)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Trip Feasibility & Powertrain Breakdown Card
        if (route != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.tileBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: route.canReachPureEv ? const Color(0xFF00E5FF).withValues(alpha: 0.5) : colors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.destinationName,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        Text(
                          '${route.distanceKm} km • ~${route.durationMinutes} min drive',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (route.canReachPureEv ? const Color(0xFF00E5FF) : const Color(0xFFFFB300)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        route.canReachPureEv ? '🟢 PURE EV' : '⚡ HYBRID CRUISE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: route.canReachPureEv ? const Color(0xFF00E5FF) : const Color(0xFFFFB300),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, thickness: 0.6, color: colors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available EV Range', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                          const SizedBox(height: 2),
                          Text('${route.evRangeAvailableKm} km', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(route.canReachPureEv ? 'Arrival Battery' : 'Pure EV Share', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            route.canReachPureEv ? '${route.projectedArrivalSoc.toStringAsFixed(0)}%' : '${route.electricShareKm} km',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hybrid Share', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            route.canReachPureEv ? '0 km' : '${route.hybridShareKm} km',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  route.canReachPureEv
                      ? '⚡ 100% Zero-Emissions Trip! You will arrive at ${route.destinationName} with approximately ${route.projectedArrivalSoc.toStringAsFixed(0)}% battery remaining.'
                      : '🔋 Pure EV for the first ${route.electricShareKm} km. Beyond that, the Chery 1.5L Turbo Dedicated Hybrid Transmission engages automatically. Combined petrol + EV range exceeds 1,000 km.',
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Highway DC Fast Charger Recommendation
          if (route.recommendedStop != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.tileBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt, color: Color(0xFFFFB300), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RECOMMENDED HIGHWAY CHARGER',
                              style: TextStyle(fontSize: 9.5, letterSpacing: 0.6, fontWeight: FontWeight.bold, color: colors.textMuted),
                            ),
                            Text(
                              route.recommendedStop!.name,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${route.recommendedStop!.chargerInfo} • Stop for ~${route.recommendedStop!.suggestedChargeMin} min to reach ${route.recommendedStop!.targetSoc.toStringAsFixed(0)}% SoC.',
                    style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ApplePressable(
                          onTap: () async {
                            final lat = route.recommendedStop!.location.latitude;
                            final lon = route.recommendedStop!.location.longitude;
                            final uri = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                          pressedScale: 0.95,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF33CCFF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF33CCFF).withValues(alpha: 0.4)),
                            ),
                            child: const Center(
                              child: Text('Open in Waze', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF33CCFF))),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ApplePressable(
                          onTap: () async {
                            final lat = route.recommendedStop!.location.latitude;
                            final lon = route.recommendedStop!.location.longitude;
                            final uri = Uri.parse('geo:$lat,$lon?q=$lat,$lon');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                          pressedScale: 0.95,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.evTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.evTeal.withValues(alpha: 0.4)),
                            ),
                            child: Center(
                              child: Text('Google Maps', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.evTeal)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildGeofenceTab(AppColors colors, bool isDark, double lat, double lon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Status Banner Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasActiveGeofence
                  ? const Color(0xFFD2F835).withValues(alpha: 0.5)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_hasActiveGeofence ? const Color(0xFFD2F835) : colors.textMuted)
                      .withValues(alpha: 0.15),
                ),
                child: Icon(
                  _hasActiveGeofence ? Icons.security : Icons.shield_outlined,
                  color: _hasActiveGeofence ? const Color(0xFFD2F835) : colors.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Chery T-Box Geofence',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _hasActiveGeofence
                                ? const Color(0xFFD2F835)
                                : (isDark ? Colors.white10 : Colors.black12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _hasActiveGeofence ? 'ACTIVE' : 'IDLE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: _hasActiveGeofence ? Colors.black : colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _hasActiveGeofence
                          ? 'Perimeter armed on vehicle hardware. Instant alarm push on exit/entry.'
                          : 'Set a boundary to alert you if your car moves outside your safe zone.',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Interactive Map Picker
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PERIMETER LOCATION',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
            ),
            Text(
              _customFenceCenter != null ? 'Custom Pin Selected' : 'Locked to Vehicle',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: _customFenceCenter != null ? const Color(0xFFD2F835) : colors.evTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 230,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _geofenceMapController,
                options: MapOptions(
                  initialCenter: _effectiveFenceCenter,
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                  onTap: (tapPosition, point) {
                    setState(() => _customFenceCenter = point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tiggomate.tiggomate_app',
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _effectiveFenceCenter,
                        radius: _selectedFenceRadius,
                        useRadiusInMeter: true,
                        color: const Color(0xFFD2F835).withValues(alpha: 0.18),
                        borderColor: const Color(0xFFD2F835),
                        borderStrokeWidth: 2.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Vehicle Pin if location known
                      if (_hasAnyLocation && _effectiveLat != 0.0 && _effectiveLon != 0.0)
                        Marker(
                          point: LatLng(_effectiveLat, _effectiveLon),
                          width: 32,
                          height: 32,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.directions_car, color: Color(0xFF38BDF8), size: 16),
                          ),
                        ),
                      // Geofence Center Pin
                      Marker(
                        point: _effectiveFenceCenter,
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD2F835),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD2F835).withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.shield, color: Colors.black, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Top instructions pill
              Positioned(
                top: 8,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app, color: Color(0xFFD2F835), size: 13),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _customFenceCenter != null
                              ? 'Center: ${_effectiveFenceCenter.latitude.toStringAsFixed(4)}, ${_effectiveFenceCenter.longitude.toStringAsFixed(4)}'
                              : 'Tap anywhere on map to reposition fence center',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom floating quick-snap buttons
              Positioned(
                bottom: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ApplePressable(
                      onTap: _snapToCarLocation,
                      pressedScale: 0.92,
                      enableHaptics: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car, color: Color(0xFF38BDF8), size: 13),
                            SizedBox(width: 4),
                            Text('Car', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ApplePressable(
                      onTap: _snapToPhoneLocation,
                      pressedScale: 0.92,
                      enableHaptics: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD2F835).withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location, color: Color(0xFFD2F835), size: 13),
                            SizedBox(width: 4),
                            Text('Phone', style: TextStyle(color: Color(0xFFD2F835), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Perimeter Radius Selector
        Text(
          'PERIMETER RADIUS',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [200.0, 500.0, 1000.0, 2000.0].map((r) {
            final isSel = _selectedFenceRadius == r;
            final label = r >= 1000 ? '${(r / 1000).toStringAsFixed(r % 1000 == 0 ? 0 : 1)} km' : '${r.toInt()}m';
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ApplePressable(
                  onTap: () => setState(() => _selectedFenceRadius = r),
                  pressedScale: 0.94,
                  enableHaptics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFFD2F835)
                          : (isDark ? const Color(0xFF1E2632) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? const Color(0xFFD2F835) : colors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? Colors.black : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // 3. Alert Trigger Condition
        Text(
          'TRIGGER NOTIFICATION',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              _buildTriggerOption(2, 'On Exit (Drive Out)', Icons.exit_to_app, colors, isDark),
              _buildTriggerOption(1, 'On Entry (Drive In)', Icons.login, colors, isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Fence Label & Action
        TextField(
          controller: _fenceNameCtrl,
          style: TextStyle(fontSize: 13, color: colors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Geofence Label',
            labelStyle: TextStyle(fontSize: 12, color: colors.textMuted),
            hintText: 'e.g. Home, Office, Airport, Workshop',
            hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
            prefixIcon: Icon(Icons.label_outline, size: 18, color: colors.evTeal),
            filled: true,
            fillColor: colors.tileBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD2F835))),
          ),
        ),
        const SizedBox(height: 14),

        // Action Button: Arm / Create Geofence
        ApplePressable(
          onTap: _createGeofence,
          pressedScale: 0.97,
          enableHaptics: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD2F835), Color(0xFFBCE32A)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD2F835).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield, color: Colors.black, size: 18),
                const SizedBox(width: 8),
                Text(
                  _customFenceCenter != null
                      ? 'Arm Geofence at Selected Location (${_selectedFenceRadius.toInt()}m)'
                      : 'Arm Geofence at Car Location (${_selectedFenceRadius.toInt()}m)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 5. Registered Geofences List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'REGISTERED GEOFENCES (${_geofences.length})',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
            ),
            if (_isLoadingGeofences)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              GestureDetector(
                onTap: _loadGeofences,
                child: Text('Refresh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.evTeal)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_geofences.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.tileBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.fence_outlined, size: 28, color: colors.textMuted),
                const SizedBox(height: 6),
                Text(
                  'No Geofences Active',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap above to lock your car\'s current location with a virtual boundary.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          )
        else
          ..._geofences.map((fence) {
            final id = fence['id']?.toString() ?? '';
            final name = fence['name']?.toString() ?? fence['fenceName']?.toString() ?? 'Perimeter';
            final radius = fence['radius']?.toString() ?? fence['radiusMeters']?.toString() ?? '500';
            final status = fence['status'] == 1 || fence['status'] == '1' || fence['status'] == true;
            final isLocal = fence['isLocal'] == true || id == 'local_guard';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.tileBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status ? const Color(0xFFD2F835).withValues(alpha: 0.4) : colors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (status ? const Color(0xFFD2F835) : colors.textMuted).withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      isLocal ? Icons.shield_outlined : Icons.fmd_good,
                      size: 16,
                      color: status ? const Color(0xFFD2F835) : colors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                              ),
                            ),
                            if (isLocal) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                                ),
                                child: const Text(
                                  'LOCAL GUARD',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF00E5FF),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          isLocal
                              ? 'Radius: ${radius}m • TiggoMate Local Smart Guard'
                              : 'Radius: ${radius}m • T-Box Hardware Alert',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: status,
                    activeColor: const Color(0xFFD2F835),
                    onChanged: (val) => _toggleGeofenceStatus(id, fence['status']),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: colors.textMuted),
                    onPressed: () => _deleteGeofence(id),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTriggerOption(int type, String label, IconData icon, AppColors colors, bool isDark) {
    final isSel = _selectedAlarmType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedAlarmType = type);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel
                ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isSel ? const Color(0xFFD2F835) : colors.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel ? colors.textPrimary : colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationCategoryPill(int index, String label, AppColors colors) {
    final selected = _selectedStationCategory == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStationCategory = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? (colors.isDark ? const Color(0xFF232D3B) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected && !colors.isDark
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? colors.textPrimary : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChargerTile({
    required String name,
    required String distance,
    required String plugs,
    required double lat,
    required double lon,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.ev_station_rounded, size: 16, color: colors.evTeal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.evTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  distance,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.evTeal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(plugs, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _launchWaze(lat, lon),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Waze', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF33CCFF))),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _launchGoogleMaps(lat, lon),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Maps', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF34A853))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPetrolStationTile({
    required _SavedPetrolStation station,
    required String distance,
    required AppColors colors,
  }) {
    Color brandColor = const Color(0xFFF59E0B);
    if (station.brand == 'Petronas') brandColor = const Color(0xFF00A19C);
    if (station.brand == 'Shell') brandColor = const Color(0xFFFFD100);
    if (station.brand == 'BHPetrol') brandColor = const Color(0xFFFF6600);
    if (station.brand == 'Caltex') brandColor = const Color(0xFFE21836);
    if (station.brand == 'Petron') brandColor = const Color(0xFF005BA6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.local_gas_station_rounded, size: 16, color: brandColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        station.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  distance,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: brandColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(station.fuels, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _launchWaze(station.lat, station.lon),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Waze', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF33CCFF))),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _launchGoogleMaps(station.lat, station.lon),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Maps', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF34A853))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom Vector Painter recreating an authentic tactical circular radar HUD.
class _CircularRadarMapPainter extends CustomPainter {
  final bool isDark;
  final double radarAngle;
  final double animValue;
  final double headingAngle;
  final bool isFlashing;

  _CircularRadarMapPainter({
    required this.isDark,
    required this.radarAngle,
    required this.animValue,
    required this.headingAngle,
    required this.isFlashing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width > 10 ? size.width : 236.0;
    final double h = size.height > 10 ? size.height : 236.0;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // 1. Concentric Distance Grid Rings (50m, 100m, 180m)
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.35, gridPaint);
    canvas.drawCircle(center, radius * 0.65, gridPaint);
    canvas.drawCircle(center, radius * 0.92, gridPaint);

    // Crosshair axes (subtle tactical radar azimuth markers)
    final axisPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(center.dx, center.dy - radius * 0.92), Offset(center.dx, center.dy + radius * 0.92), axisPaint);
    canvas.drawLine(Offset(center.dx - radius * 0.92, center.dy), Offset(center.dx + radius * 0.92, center.dy), axisPaint);

    // 2. Continuous Expanding Sonar Pulse Waves (radiating outward across the map)
    for (int i = 0; i < 2; i++) {
      final waveProgress = (animValue + (i * 0.5)) % 1.0;
      final waveRadius = waveProgress * radius * 0.92;
      final waveAlpha = (1.0 - waveProgress).clamp(0.0, 1.0) * 0.45;
      if (waveRadius > 10) {
        canvas.drawCircle(
          center,
          waveRadius,
          Paint()
            ..color = const Color(0xFF39FF14).withValues(alpha: waveAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    // 3. Rotating Radar Sweep Beam (Trailing Phosphor Wedge)
    final fanAngle = math.pi / 3.0; // 60 degrees trailing cone
    final sweepPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        radarAngle - fanAngle,
        fanAngle,
        false,
      )
      ..close();

    final sweepShader = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: fanAngle,
      colors: const [
        Colors.transparent,
        Color(0x3300E5FF),
        Color(0x6639FF14),
      ],
      stops: const [0.0, 0.45, 1.0],
      transform: GradientRotation(radarAngle - fanAngle),
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(sweepPath, Paint()..shader = sweepShader);

    // 4. Sharp Glowing Radar Scanner Leading Edge (Rotating Needle)
    final lineEnd = center + Offset(math.cos(radarAngle) * radius, math.sin(radarAngle) * radius);

    // Outer needle glow
    canvas.drawLine(
      center,
      lineEnd,
      Paint()
        ..color = const Color(0xFF39FF14).withValues(alpha: 0.70)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Crisp high-contrast scan line
    canvas.drawLine(
      center,
      lineEnd,
      Paint()
        ..color = const Color(0xFFE8FFD8)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // 5. Flash wave pulse if horn/flash triggered
    if (isFlashing) {
      final pulsePaint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(center, 40, pulsePaint);
    }

    // 6. ANIMATED RADAR DOT IN THE MIDDLE (Vehicle / Transponder Blip)
    // Dynamic pulsing ripples originating from the center dot
    for (int i = 0; i < 2; i++) {
      final dotPulseProgress = ((animValue * 2.0) + (i * 0.5)) % 1.0;
      final dotPulseRadius = 4.0 + (dotPulseProgress * 20.0);
      final dotPulseAlpha = (1.0 - dotPulseProgress).clamp(0.0, 1.0) * 0.80;
      canvas.drawCircle(
        center,
        dotPulseRadius,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: dotPulseAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // Center glow halo
    canvas.drawCircle(
      center,
      9.0,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.50),
    );

    // Center solid radar blip core dot
    canvas.drawCircle(
      center,
      5.5,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.fill,
    );

    // Specular highlight on center dot
    canvas.drawCircle(
      center + const Offset(-1.2, -1.2),
      2.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // 7. Tactical Vehicle Compass Arrow Pointer (Rotated around the center dot)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(headingAngle);

    final arrowShadow = Path()
      ..moveTo(0, -18)
      ..lineTo(11, 10)
      ..lineTo(0, 4)
      ..lineTo(-11, 10)
      ..close();
    canvas.drawPath(
      arrowShadow.shift(const Offset(1, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.50)
        ..style = PaintingStyle.fill,
    );

    final arrowPaint = Paint()
      ..color = const Color(0xFFFFA000)
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowShadow, arrowPaint);

    final arrowBorder = Paint()
      ..color = const Color(0xFF8D4A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(arrowShadow, arrowBorder);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CircularRadarMapPainter oldDelegate) {
    return oldDelegate.radarAngle != radarAngle ||
        oldDelegate.animValue != animValue ||
        oldDelegate.headingAngle != headingAngle ||
        oldDelegate.isFlashing != isFlashing ||
        oldDelegate.isDark != isDark;
  }
}
