import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../theme/app_theme.dart';
import 'app_notification.dart';

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

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _launchWaze(double lat, double lon) async {
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
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('Could not open Google Maps');
    }
  }

  void _copyGps() {
    final coords = '${widget.telemetry.latitude.toStringAsFixed(5)}, ${widget.telemetry.longitude.toStringAsFixed(5)}';
    Clipboard.setData(ClipboardData(text: coords));
    _showToast('GPS coordinates copied to clipboard: $coords');
  }

  void _triggerHornFlash() {
    setState(() => _isFlashing = true);
    widget.onHornFlash();
    _showToast('📢 CarLinko: Sounding horn & flashing headlights...');
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
    final lat = widget.telemetry.latitude;
    final lon = widget.telemetry.longitude;

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
                            'Live GPS Tracking • CarLinko Telematics',
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

                      // Vector Map Canvas inside Circular Radar Viewport
                      ClipOval(
                        child: SizedBox(
                          width: 236,
                          height: 236,
                          child: AnimatedBuilder(
                            animation: _radarController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _CircularRadarMapPainter(
                                  isDark: isDark,
                                  radarAngle: _radarController.value * 2 * math.pi,
                                  headingAngle: widget.telemetry.headingDegrees * (math.pi / 180),
                                  isFlashing: _isFlashing,
                                ),
                              );
                            },
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
                                'GPS Locked • Range 200m',
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
                                    widget.telemetry.locationName,
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
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.evTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '120 m away (2m)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colors.evTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Coordinates: ${lat.toStringAsFixed(4)}° N, ${lon.toStringAsFixed(4)}° E • Bearing: ${widget.telemetry.headingDegrees.toStringAsFixed(0)}° NE',
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
                          Icon(Icons.lock, size: 12, color: colors.evTeal),
                          const SizedBox(width: 4),
                          Text(
                            'Secured & Stationary',
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
                // ---------------- 4. NEARBY MALAYSIAN EV CHARGING HUBS ----------------
                Text(
                  'Nearby AC/DC Chargers (Bangsar South)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                const SizedBox(height: 10),
                _buildChargerTile(
                  name: 'Gentari - KL Gateway Mall',
                  operator: 'Gentari',
                  distance: '450 m',
                  plugs: '2x Type 2 AC (22 kW) • 1x 60 kW DC',
                  price: 'RM 0.90 / kWh',
                  status: '2 of 3 Available',
                  statusColor: const Color(0xFFD2F835),
                  lat: 3.1182,
                  lon: 101.6644,
                  colors: colors,
                ),
                const SizedBox(height: 10),
                _buildChargerTile(
                  name: 'ChargEV - Nexus Bangsar South',
                  operator: 'ChargEV',
                  distance: '320 m',
                  plugs: '4x Type 2 AC (11 kW)',
                  price: 'RM 0.80 / kWh',
                  status: '3 of 4 Available',
                  statusColor: const Color(0xFFD2F835),
                  lat: 3.1197,
                  lon: 101.6669,
                  colors: colors,
                ),
                const SizedBox(height: 10),
                _buildChargerTile(
                  name: 'Shell Recharge - Pantai Sentral',
                  operator: 'Shell Recharge',
                  distance: '1.2 km',
                  plugs: '2x Type 2 AC (7.4 kW) • 1x 120 kW DC',
                  price: 'RM 1.20 / kWh',
                  status: 'Busy (1 Available)',
                  statusColor: Colors.amber,
                  lat: 3.1091,
                  lon: 101.6612,
                  colors: colors,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChargerTile({
    required String name,
    required String operator,
    required String distance,
    required String plugs,
    required String price,
    required String status,
    required Color statusColor,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$price • $status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              Row(
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
        ],
      ),
    );
  }
}

/// Custom Vector Painter recreating the circular radar map from user reference screenshot.
class _CircularRadarMapPainter extends CustomPainter {
  final bool isDark;
  final double radarAngle;
  final double headingAngle;
  final bool isFlashing;

  _CircularRadarMapPainter({
    required this.isDark,
    required this.radarAngle,
    required this.headingAngle,
    required this.isFlashing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Base Terrain Background (Urban Grey)
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E2632) : const Color(0xFFE2E4E8);
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Green Park Zones (Matching user reference layout)
    final parkPaint = Paint()
      ..color = isDark ? const Color(0xFF283F30) : const Color(0xFF8FA876)
      ..style = PaintingStyle.fill;

    // Top-right green parcel
    final parkPath1 = Path()
      ..moveTo(size.width * 0.55, size.height * 0.12)
      ..lineTo(size.width * 0.95, size.height * 0.18)
      ..lineTo(size.width * 0.88, size.height * 0.35)
      ..lineTo(size.width * 0.72, size.height * 0.32)
      ..close();
    canvas.drawPath(parkPath1, parkPaint);

    // Far-right green reserve
    final parkPath2 = Path()
      ..moveTo(size.width * 0.78, size.height * 0.48)
      ..lineTo(size.width * 0.98, size.height * 0.48)
      ..lineTo(size.width * 0.92, size.height * 0.82)
      ..lineTo(size.width * 0.72, size.height * 0.78)
      ..close();
    canvas.drawPath(parkPath2, parkPaint);

    // Top-left small green zone
    final parkPath3 = Path()
      ..moveTo(size.width * 0.18, size.height * 0.28)
      ..lineTo(size.width * 0.32, size.height * 0.26)
      ..lineTo(size.width * 0.34, size.height * 0.38)
      ..lineTo(size.width * 0.19, size.height * 0.39)
      ..close();
    canvas.drawPath(parkPath3, parkPaint);

    // Center-left green parcel
    final parkPath4 = Path()
      ..moveTo(size.width * 0.38, size.height * 0.40)
      ..lineTo(size.width * 0.48, size.height * 0.41)
      ..lineTo(size.width * 0.47, size.height * 0.53)
      ..lineTo(size.width * 0.36, size.height * 0.48)
      ..close();
    canvas.drawPath(parkPath4, parkPaint);

    // 3. Blue River / Canal Curve (Matching user reference screenshot)
    final riverPaint = Paint()
      ..color = isDark ? const Color(0xFF2F81F7) : const Color(0xFF4A90E2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(size.width * 0.72, size.height * 0.18)
      ..cubicTo(
        size.width * 0.69, size.height * 0.35,
        size.width * 0.63, size.height * 0.55,
        size.width * 0.73, size.height * 0.88,
      );
    canvas.drawPath(riverPath, riverPaint);

    // 4. Building Footprints (Geometric Grey Blocks)
    final bldgPaint = Paint()
      ..color = isDark ? const Color(0xFF283546) : const Color(0xFFAEB4BE)
      ..style = PaintingStyle.fill;

    final buildings = [
      Rect.fromLTWH(size.width * 0.38, size.height * 0.20, size.width * 0.08, size.height * 0.04),
      Rect.fromLTWH(size.width * 0.53, size.height * 0.29, size.width * 0.09, size.height * 0.035),
      Rect.fromLTWH(size.width * 0.54, size.height * 0.36, size.width * 0.04, size.height * 0.09),
      Rect.fromLTWH(size.width * 0.35, size.height * 0.52, size.width * 0.12, size.height * 0.055),
      Rect.fromLTWH(size.width * 0.26, size.height * 0.68, size.width * 0.15, size.height * 0.06),
      Rect.fromLTWH(size.width * 0.20, size.height * 0.61, size.width * 0.09, size.height * 0.05),
      Rect.fromLTWH(size.width * 0.55, size.height * 0.76, size.width * 0.08, size.height * 0.07),
    ];
    for (final b in buildings) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(2)), bldgPaint);
    }

    // 5. White City Roads & Streets Network
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF38475C) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.square;

    // Main Vertical Spine Road (Through center where car is)
    final mainRoad = Path()
      ..moveTo(size.width * 0.51, 0)
      ..lineTo(size.width * 0.50, size.height * 0.48)
      ..lineTo(size.width * 0.60, size.height);
    canvas.drawPath(mainRoad, roadPaint);

    // Top horizontal cross road
    final road2 = Path()
      ..moveTo(0, size.height * 0.24)
      ..lineTo(size.width, size.height * 0.31);
    canvas.drawPath(road2, roadPaint);

    // Left diagonal avenue
    final road3 = Path()
      ..moveTo(size.width * 0.12, size.height * 0.43)
      ..lineTo(size.width * 0.50, size.height * 0.48);
    canvas.drawPath(road3, roadPaint);

    final road4 = Path()
      ..moveTo(size.width * 0.24, size.height * 0.82)
      ..lineTo(size.width * 0.37, size.height * 0.46);
    canvas.drawPath(road4, roadPaint);

    // Right curved alley
    final road5 = Path()
      ..moveTo(size.width * 0.52, size.height * 0.61)
      ..lineTo(size.width * 0.78, size.height * 0.58);
    canvas.drawPath(road5, roadPaint);

    // 6. Subtle Concentric Radar Grid Rings (50m, 100m, 180m)
    final ringPaint = Paint()
      ..color = (isDark ? const Color(0xFFD2F835) : const Color(0xFF65A30D)).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.35, ringPaint);
    canvas.drawCircle(center, radius * 0.65, ringPaint);
    canvas.drawCircle(center, radius * 0.92, ringPaint);

    // 7. Rotating Radar Sweep Beam (Sonar / Scanner Effect)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          (isDark ? const Color(0xFFD2F835) : const Color(0xFF65A30D)).withValues(alpha: 0.28),
          Colors.transparent,
        ],
        transform: GradientRotation(radarAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);

    // 8. Vehicle Position Cursor (Exact Orange Arrow from Reference Screenshot)
    final carPoint = Offset(size.width * 0.495, size.height * 0.49);

    // Flash wave pulse if horn/flash triggered
    if (isFlashing) {
      final pulsePaint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(carPoint, 36, pulsePaint);
    }

    // Vehicle Compass Arrow Pointer
    canvas.save();
    canvas.translate(carPoint.dx, carPoint.dy);
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

    // Amber vehicle pointer matching screenshot
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
        oldDelegate.headingAngle != headingAngle ||
        oldDelegate.isFlashing != isFlashing ||
        oldDelegate.isDark != isDark;
  }
}
