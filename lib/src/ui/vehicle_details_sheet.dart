import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../theme/app_tokens.dart';

/// Equinox-style Vehicle Details Screen (Screen 2 of Chevy Equinox Reference)
/// Features:
/// - Realistic top-down Tiggo 7 Pro telemetry graphic
/// - 4 Corner TPMS pressure and temperature callouts pinned directly to the wheels
/// - Circular door open/closed and locked/unlocked status tags flanking the vehicle
/// - Health Overview cards for Fuel, Battery, 12V Aux Voltage, Oil Life, and Brake Pads
class VehicleDetailsSheet extends StatelessWidget {
  final VehicleTelemetry telemetry;
  final String carPlateNumber;
  final String vehicleNickname;
  final VoidCallback? onOpenTPMSSettings;

  const VehicleDetailsSheet({
    super.key,
    required this.telemetry,
    required this.carPlateNumber,
    required this.vehicleNickname,
    this.onOpenTPMSSettings,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTelemetry telemetry,
    required String carPlateNumber,
    required String vehicleNickname,
    VoidCallback? onOpenTPMSSettings,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: VehicleDetailsSheet(
          telemetry: telemetry,
          carPlateNumber: carPlateNumber,
          vehicleNickname: vehicleNickname,
          onOpenTPMSSettings: onOpenTPMSSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = context.tokens;
    final bgCol = t.bg;
    final cardCol = t.surface;
    final borderCol = t.border;
    final textPrimary = t.ink;
    final textMuted = t.ink2;
    final limeAccent = t.accent;
    const alertRed = Color(0xFFEF4444);

    final flKpa = telemetry.tyreFlPressureKpa;
    final frKpa = telemetry.tyreFrPressureKpa;
    final rlKpa = telemetry.tyreRlPressureKpa;
    final rrKpa = telemetry.tyreRrPressureKpa;

    final flTemp = telemetry.tyreFlTempC;
    final frTemp = telemetry.tyreFrTempC;
    final rlTemp = telemetry.tyreRlTempC;
    final rrTemp = telemetry.tyreRrTempC;

    return Container(
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 25, offset: Offset(0, -5)),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF333B4D) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicleNickname.isNotEmpty ? vehicleNickname : 'Chery Tiggo 7 Pro PHEV',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B202C) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderCol),
                  ),
                  child: Text(
                    carPlateNumber.isNotEmpty ? carPlateNumber : 'VRT 3342',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: limeAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0x1FFFFFFF)),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                // ---------------- 1. TOP-DOWN VEHICLE TELEMETRY STAGE ----------------
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: cardCol,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      // Subtitle row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TIRE PRESSURE & SECURITY',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: textMuted,
                            ),
                          ),
                          Text(
                            'TARGET SPEC: 230 KPA',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: limeAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Central Vehicle Graphic with 4 Pinned Tires + 2 Doors
                      SizedBox(
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient radial shadow
                            Container(
                              width: 140,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isDark ? Colors.black : Colors.black12).withValues(alpha: 0.4),
                              ),
                            ),

                            // Top-down car image
                            Image.asset(
                              'assets/images/car_top.png',
                              height: 230,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.directions_car,
                                size: 120,
                                color: Colors.grey,
                              ),
                            ),

                            // Front Left Callout
                            Positioned(
                              left: 6,
                              top: 28,
                              child: _buildTireCallout(
                                position: 'FL',
                                pressureKpa: flKpa,
                                tempC: flTemp.round(),
                                isDark: isDark,
                                isLeft: true,
                                okColor: limeAccent,
                              ),
                            ),

                            // Front Right Callout
                            Positioned(
                              right: 6,
                              top: 28,
                              child: _buildTireCallout(
                                position: 'FR',
                                pressureKpa: frKpa,
                                tempC: frTemp.round(),
                                isDark: isDark,
                                isLeft: false,
                                okColor: limeAccent,
                              ),
                            ),

                            // Rear Left Callout
                            Positioned(
                              left: 6,
                              bottom: 28,
                              child: _buildTireCallout(
                                position: 'RL',
                                pressureKpa: rlKpa,
                                tempC: rlTemp.round(),
                                isDark: isDark,
                                isLeft: true,
                                okColor: limeAccent,
                              ),
                            ),

                            // Rear Right Callout
                            Positioned(
                              right: 6,
                              bottom: 28,
                              child: _buildTireCallout(
                                position: 'RR',
                                pressureKpa: rrKpa,
                                tempC: rrTemp.round(),
                                isDark: isDark,
                                isLeft: false,
                                okColor: limeAccent,
                              ),
                            ),

                            // Left Door Pill
                            Positioned(
                              left: 20,
                              top: 110,
                              child: _buildDoorPill(
                                label: telemetry.doorsOpen ? 'Door Ajar' : 'Doors Closed',
                                icon: Icons.meeting_room_outlined,
                                isActive: telemetry.doorsOpen,
                                isDark: isDark,
                              ),
                            ),

                            // Right Door Lock Pill
                            Positioned(
                              right: 20,
                              top: 110,
                              child: _buildDoorPill(
                                label: telemetry.doorsLocked ? 'Locked' : 'Unlocked',
                                icon: telemetry.doorsLocked ? Icons.lock : Icons.lock_open,
                                isActive: telemetry.doorsLocked,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- 2. HEALTH OVERVIEW SECTION ----------------
                Text(
                  'Health Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // 2x2 Grid of Health Metrics
                Row(
                  children: [
                    // Fuel Level Card
                    Expanded(
                      child: _buildHealthCard(
                        icon: Icons.local_gas_station_outlined,
                        iconColor: const Color(0xFFFFB300),
                        title: 'Fuel Level',
                        primaryValue: '${telemetry.fuelCapacityPct}%',
                        subtitle: '${telemetry.fuelRangeKm} km until empty',
                        progress: telemetry.fuelCapacityPct / 100.0,
                        progressColor: const Color(0xFFFFB300),
                        cardCol: cardCol,
                        borderCol: borderCol,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // EV Battery Card
                    Expanded(
                      child: _buildHealthCard(
                        icon: Icons.electric_bolt_rounded,
                        iconColor: const Color(0xFF00E5FF),
                        title: 'EV Battery (SoC)',
                        primaryValue: '${telemetry.batteryPct}%',
                        subtitle: '${telemetry.electricRangeKm} km pure electric',
                        progress: telemetry.batteryPct / 100.0,
                        progressColor: const Color(0xFF00E5FF),
                        cardCol: cardCol,
                        borderCol: borderCol,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    // 12V Aux Battery Card
                    Expanded(
                      child: _buildHealthCard(
                        icon: Icons.battery_charging_full_rounded,
                        iconColor: const Color(0xFF58A6FF),
                        title: '12V Aux Battery',
                        primaryValue: telemetry.volt12 > 0 ? '${telemetry.volt12.toStringAsFixed(2)} V' : '-- V',
                        subtitle: telemetry.volt12 >= 12.2 ? 'Healthy Condition' : 'Low Voltage Alert',
                        progress: (telemetry.volt12 / 14.5).clamp(0.0, 1.0),
                        progressColor: telemetry.volt12 >= 12.2 ? const Color(0xFF58A6FF) : alertRed,
                        cardCol: cardCol,
                        borderCol: borderCol,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Oil Life / Maintenance Card
                    Expanded(
                      child: _buildHealthCard(
                        icon: Icons.oil_barrel_outlined,
                        iconColor: const Color(0xFF4ADE80),
                        title: 'Engine Oil Life',
                        primaryValue: '72%',
                        subtitle: 'No oil change needed',
                        progress: 0.72,
                        progressColor: const Color(0xFF4ADE80),
                        cardCol: cardCol,
                        borderCol: borderCol,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Brake Pads & Powertrain Status Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardCol,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: limeAccent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.verified_user_outlined, size: 20, color: limeAccent),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Brake Pads & Powertrain',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'All systems optimal • Normal wear',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Optimal',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTireCallout({
    required String position,
    required double pressureKpa,
    required int tempC,
    required bool isDark,
    required bool isLeft,
    required Color okColor,
  }) {
    final hasReading = pressureKpa > 0;
    final isLow = hasReading && pressureKpa < 215.0;
    final isAmber = hasReading && pressureKpa < 225.0;
    final color = !hasReading
        ? const Color(0xFF9CA3AF)
        : (isLow ? const Color(0xFFEF4444) : (isAmber ? const Color(0xFFFFB300) : okColor));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1B202D) : Colors.white).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasReading ? '${pressureKpa.round()}' : '--',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              const Text(
                'kPa',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            '$position • ${tempC > 0 ? '$tempC°C' : '--'}',
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildDoorPill({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF11141B) : Colors.white).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF00E5FF).withValues(alpha: 0.6) : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isActive ? const Color(0xFF00E5FF) : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String primaryValue,
    required String subtitle,
    required double progress,
    required Color progressColor,
    required Color cardCol,
    required Color borderCol,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: iconColor),
              Text(
                primaryValue,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9.5, color: textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
