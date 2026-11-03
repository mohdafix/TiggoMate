import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../service/phone_parking_location.dart';
import '../theme/app_theme.dart';
import 'app_notification.dart';

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

/// Interactive Circular Radar HUD & Vehicle Locator Sheet (Phase 1)
/// Inspired by tactical automotive radar and official Chery CarLinko Find My Car.
class VehicleRadarSheet extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final VoidCallback onHornFlash;

  const VehicleRadarSheet({
    super.key,
    required this.telemetry,
    required this.onHornFlash,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTelemetry telemetry,
    required VoidCallback onHornFlash,
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
      ),
    );
  }

  @override
  State<VehicleRadarSheet> createState() => _VehicleRadarSheetState();
}

class _VehicleRadarSheetState extends State<VehicleRadarSheet> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  bool _isFlashing = false;
  int _activeRadarTab = 0; // 0: Radar Map, 1: Nearby Chargers
  PhoneParkedLocation? _phoneFallback;

  bool get _usingPhoneFallback => !widget.telemetry.hasLocation && _phoneFallback != null;
  bool get _hasAnyLocation => widget.telemetry.hasLocation || _phoneFallback != null;
  double get _effectiveLat => _usingPhoneFallback ? _phoneFallback!.latitude : widget.telemetry.latitude;
  double get _effectiveLon => _usingPhoneFallback ? _phoneFallback!.longitude : widget.telemetry.longitude;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    if (!widget.telemetry.hasLocation) {
      PhoneParkingLocationService.loadLast().then((loc) {
        if (mounted && loc != null) setState(() => _phoneFallback = loc);
      });
    }
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  /// Real dark-tile map centered on the car (or the phone-parked fallback),
  /// locked and non-interactive so it reads as a radar/minimap rather than
  /// a pannable map -- the scanning overlay from _CircularRadarMapPainter
  /// draws on top of this. Falls back to a plain placeholder when there's
  /// no coordinate at all to center on.
  Widget _buildRadarMapLayer(double lat, double lon, bool hasAnyLocation) {
    if (!hasAnyLocation) {
      return Container(
        color: const Color(0xFF1E2632),
        alignment: Alignment.center,
        child: const Icon(Icons.location_off_outlined, color: Color(0xFF4B5563), size: 32),
      );
    }
    // CARTO's free basemap tiles now require an API key, so this uses
    // standard OpenStreetMap tiles (genuinely free, no signup) with a
    // color inversion to approximate the dark map style instead.
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
          initialZoom: 17,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.tiggomate.tiggomate_app',
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

  double _distanceToCarMetres(_SavedCharger charger) {
    return Geolocator.distanceBetween(
      _effectiveLat,
      _effectiveLon,
      charger.lat,
      charger.lon,
    );
  }

  String _formatDistance(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    final km = metres / 1000;
    return '${km.toStringAsFixed(km < 100 ? 1 : 0)} km';
  }

  /// Saved chargers, nearest to the car first when its position is known.
  List<_SavedCharger> get _chargersByDistance {
    final chargers = List<_SavedCharger>.of(_savedChargers);
    if (_hasAnyLocation) {
      chargers.sort((a, b) => _distanceToCarMetres(a).compareTo(_distanceToCarMetres(b)));
    }
    return chargers;
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

              // Sub-Tab Switcher: 0: Radar Map, 1: Nearby EV Chargers
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.explore_outlined,
                                size: 15,
                                color: _activeRadarTab == 0 ? colors.evTeal : colors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Circular Radar HUD',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _activeRadarTab == 0 ? FontWeight.bold : FontWeight.normal,
                                  color: _activeRadarTab == 0 ? colors.textPrimary : colors.textMuted,
                                ),
                              ),
                            ],
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.ev_station,
                                size: 15,
                                color: _activeRadarTab == 1 ? colors.evTeal : colors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Nearby Chargers',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _activeRadarTab == 1 ? FontWeight.bold : FontWeight.normal,
                                  color: _activeRadarTab == 1 ? colors.textPrimary : colors.textMuted,
                                ),
                              ),
                            ],
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
                            children: [
                              _buildRadarMapLayer(lat, lon, usingPhoneFallback || widget.telemetry.hasLocation),
                              AnimatedBuilder(
                                animation: _radarController,
                                builder: (context, child) {
                                  return CustomPaint(
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
                                  color: colors.evTeal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                usingPhoneFallback ? 'Last known (phone)' : 'GPS Locked • Range 200m',
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
                                Icon(Icons.place, color: colors.evTeal, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    usingPhoneFallback
                                        ? (_phoneFallback!.address ?? 'Phone location (approx.)')
                                        : widget.telemetry.locationName,
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
                            color: colors.evTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.smartphone, size: 11, color: colors.evTeal),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'From phone · ${_relativeTime(_phoneFallback!.timestamp)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.evTeal),
                                ),
                              ),
                            ],
                          ),
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
              ] else ...[
                // ---------------- 4. EV CHARGING NEAR THE CAR ----------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (widget.telemetry.hasLocation || usingPhoneFallback) ? () => _launchChargerSearch(lat, lon) : null,
                    icon: const Icon(Icons.ev_station, size: 16),
                    label: Text(
                      (widget.telemetry.hasLocation || usingPhoneFallback) ? 'Find Chargers Near Car' : 'Car location unavailable',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Saved Chargers (Bangsar South)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  (widget.telemetry.hasLocation || usingPhoneFallback)
                      ? 'Distance from your car. Check availability and prices in Maps.'
                      : 'Check availability and prices in Maps.',
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
                const SizedBox(height: 10),
                for (final charger in _chargersByDistance) ...[
                  _buildChargerTile(
                    name: charger.name,
                    distance: (widget.telemetry.hasLocation || usingPhoneFallback) ? _formatDistance(_distanceToCarMetres(charger)) : '--',
                    plugs: charger.plugs,
                    lat: charger.lat,
                    lon: charger.lon,
                    colors: colors,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        );
      },
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
                child: Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                ),
              ),
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
          const SizedBox(height: 2),
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
              const SizedBox(width: 8),
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
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Concentric Distance Grid Rings (50m, 100m, 180m)
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F)).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.35, gridPaint);
    canvas.drawCircle(center, radius * 0.65, gridPaint);
    canvas.drawCircle(center, radius * 0.92, gridPaint);

    // Crosshair axes (subtle tactical radar azimuth markers)
    final axisPaint = Paint()
      ..color = (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F)).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(center.dx, center.dy - radius * 0.92), Offset(center.dx, center.dy + radius * 0.92), axisPaint);
    canvas.drawLine(Offset(center.dx - radius * 0.92, center.dy), Offset(center.dx + radius * 0.92, center.dy), axisPaint);

    // 2. Continuous Expanding Sonar Pulse Waves (radiating outward across the map)
    for (int i = 0; i < 2; i++) {
      final waveProgress = (animValue + (i * 0.5)) % 1.0;
      final waveRadius = waveProgress * radius * 0.92;
      final waveAlpha = (1.0 - waveProgress).clamp(0.0, 1.0) * (isDark ? 0.35 : 0.22);
      if (waveRadius > 10) {
        canvas.drawCircle(
          center,
          waveRadius,
          Paint()
            ..color = (isDark ? const Color(0xFF39FF14) : const Color(0xFF43A047)).withValues(alpha: waveAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
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
      startAngle: radarAngle - fanAngle,
      endAngle: radarAngle,
      colors: [
        Colors.transparent,
        (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00ACC1)).withValues(alpha: 0.06),
        (isDark ? const Color(0xFF39FF14) : const Color(0xFF43A047)).withValues(alpha: 0.32),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(sweepPath, Paint()..shader = sweepShader);

    // 4. Sharp Glowing Radar Scanner Leading Edge (Rotating Needle)
    final lineEnd = center + Offset(math.cos(radarAngle) * radius, math.sin(radarAngle) * radius);

    // Outer soft glow
    canvas.drawLine(
      center,
      lineEnd,
      Paint()
        ..color = (isDark ? const Color(0xFF39FF14) : const Color(0xFF2E7D32)).withValues(alpha: 0.45)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Crisp high-contrast scan line
    canvas.drawLine(
      center,
      lineEnd,
      Paint()
        ..color = isDark ? const Color(0xFFE8FFD8) : const Color(0xFF1B5E20)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // 5. Flash wave pulse if horn/flash triggered
    if (isFlashing) {
      final pulsePaint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(center, 40, pulsePaint);
    }

    // 6. ANIMATED RADAR DOT IN THE MIDDLE (Vehicle / Transponder Blip)
    // Dynamic pulsing ripples originating from the center dot
    for (int i = 0; i < 2; i++) {
      final dotPulseProgress = ((animValue * 2.0) + (i * 0.5)) % 1.0;
      final dotPulseRadius = 4.0 + (dotPulseProgress * 16.0);
      final dotPulseAlpha = (1.0 - dotPulseProgress).clamp(0.0, 1.0) * 0.65;
      canvas.drawCircle(
        center,
        dotPulseRadius,
        Paint()
          ..color = (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F)).withValues(alpha: dotPulseAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Center glow halo
    canvas.drawCircle(
      center,
      8.0,
      Paint()
        ..color = (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F)).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Center solid radar blip core dot
    canvas.drawCircle(
      center,
      5.0,
      Paint()
        ..color = isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F)
        ..style = PaintingStyle.fill,
    );

    // Specular highlight on center dot
    canvas.drawCircle(
      center + const Offset(-1.2, -1.2),
      1.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill,
    );

    // 7. Tactical Vehicle Compass Arrow Pointer (Rotated around the center dot)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(headingAngle);

    // Contact drop shadow under pointer
    final arrowShadow = Path()
      ..moveTo(0, -18)
      ..lineTo(11, 10)
      ..lineTo(0, 4)
      ..lineTo(-11, 10)
      ..close();
    canvas.drawPath(
      arrowShadow.shift(const Offset(1, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Amber vehicle pointer matching Chery reference styling
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
