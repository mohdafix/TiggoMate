import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../trips/smart_trip_tracker.dart';
import 'app_notification.dart';
import 'trips_logbook_screen.dart';

/// Full-Screen Automotive Drive HUD & Real-time GPS Cockpit.
class SmartDriveHudSheet extends StatefulWidget {
  final double tnbTariff;
  final double fuelPrice;
  final Function(TripRecord savedTrip)? onTripSaved;

  const SmartDriveHudSheet({
    super.key,
    this.tnbTariff = 0.571,
    this.fuelPrice = 2.05,
    this.onTripSaved,
  });

  static Future<void> show(
    BuildContext context, {
    double tnbTariff = 0.571,
    double fuelPrice = 2.05,
    Function(TripRecord savedTrip)? onTripSaved,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF090D12) : const Color(0xFFF7F8FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SmartDriveHudSheet(
        tnbTariff: tnbTariff,
        fuelPrice: fuelPrice,
        onTripSaved: onTripSaved,
      ),
    );
  }

  @override
  State<SmartDriveHudSheet> createState() => _SmartDriveHudSheetState();
}

class _SmartDriveHudSheetState extends State<SmartDriveHudSheet> with SingleTickerProviderStateMixin {
  final SmartTripTracker _tracker = SmartTripTracker.instance;
  Timer? _simulationTimer;
  bool _isAutoSimulating = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // If tracker is not yet active, automatically start drive session
    if (!_tracker.isTracking) {
      _tracker.startDrive(
        title: 'Klang Valley Commute (Live)',
        tnbTariff: widget.tnbTariff,
        fuelPrice: widget.fuelPrice,
      );
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleAutoSimulation() {
    setState(() {
      _isAutoSimulating = !_isAutoSimulating;
      if (_isAutoSimulating) {
        _simulationTimer?.cancel();
        _simulationTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
          if (mounted && _tracker.isTracking && !_tracker.isPaused) {
            _tracker.simulateDriveTick();
          }
        });
        AppNotification.show(
          context,
          title: 'Test Drive Active',
          message: 'Live GPS simulation traversing MEX Expressway route.',
          type: NotificationType.info,
          icon: Icons.navigation_rounded,
        );
      } else {
        _simulationTimer?.cancel();
      }
    });
  }

  void _showFinishTripDialog() {
    final titleController = TextEditingController(
      text: 'Drive: Bangsar ➔ Putrajaya (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')})',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        title: Row(
          children: [
            Icon(Icons.flag_circle_rounded, color: colors.evTeal, size: 24),
            const SizedBox(width: 8),
            Text(
              'Finish & Save Drive',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Summary:',
              style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.tileBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Distance:', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      Text('${_tracker.totalDistanceKm > 0 ? _tracker.totalDistanceKm.toStringAsFixed(1) : "24.5"} km',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Powertrain:', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      Text('${_tracker.evRatio.round()}% Pure EV Split',
                          style: TextStyle(color: colors.evTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Cost:', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      Text('RM ${_tracker.liveCostRm > 0 ? _tracker.liveCostRm.toStringAsFixed(2) : "2.40"}',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Trip Label:',
              style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: titleController,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.tileBg,
                hintText: 'e.g. Office Commute, Weekend Getaway',
                hintStyle: TextStyle(color: colors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Driving', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              final saved = await _tracker.finishAndSaveTrip(
                title: titleController.text.trim(),
                highwayNote: 'Smart Live GPS • ${_tracker.evRatio.round()}% EV Split',
              );

              if (mounted) {
                Navigator.pop(context); // Close HUD
                widget.onTripSaved?.call(saved);
                AppNotification.show(
                  context,
                  title: 'Drive Recorded Successfully',
                  message: '${saved.title} (${saved.distanceKm} km • RM ${saved.costRm.toStringAsFixed(2)}) saved to Logbook.',
                  type: NotificationType.success,
                  icon: Icons.check_circle_rounded,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.evTeal,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save to Logbook', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;

    return ListenableBuilder(
      listenable: _tracker,
      builder: (context, _) {
        final speed = _tracker.currentSpeedKmh;
        final isEv = speed <= 70.0;
        final speedColor = isEv ? colors.evTeal : colors.petrolAmber;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Pill
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Title & Duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: speedColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.navigation_rounded, color: speedColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Drive HUD',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            _tracker.isPaused ? 'Drive Paused' : 'Live GPS & Powertrain Tracking',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Live Timer Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.tileBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: colors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          _tracker.formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Digital Speedometer HUD & Active Powertrain Pill
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: speedColor.withValues(alpha: isDark ? 0.12 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Large Speedometer Number
                    Column(
                      children: [
                        Text(
                          speed.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: speedColor,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'KM / H',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    // Divider
                    Container(width: 1, height: 48, color: colors.border),

                    // Intelligent Powertrain State Badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: speedColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: speedColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEv ? Icons.electric_bolt_rounded : Icons.local_gas_station_rounded,
                                size: 14,
                                color: speedColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isEv ? '⚡ PURE EV' : '⛽ 1.5T DHT HEV',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: speedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isEv ? 'Quiet zero-emission electric' : 'Hybrid engine assist engaged',
                          style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Interactive Real-Time Vector Map Route Canvas
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Vector Breadcrumb Canvas
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LiveRouteCanvasPainter(
                            breadcrumbs: _tracker.breadcrumbs,
                            isDark: isDark,
                            evColor: colors.evTeal,
                            hevColor: colors.petrolAmber,
                            pulseVal: _pulseController.value,
                          ),
                        ),
                      ),

                      // Overlay Map Tags
                      Positioned(
                        top: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.cardBg.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: colors.evTeal, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text('EV Path', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                              const SizedBox(width: 10),
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: colors.petrolAmber, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text('HEV Path', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            ],
                          ),
                        ),
                      ),

                      // Route waypoint preview badge
                      Positioned(
                        bottom: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.cardBg.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: Text(
                            'MEX Expressway corridor • ${_tracker.breadcrumbs.length} GPS Breadcrumbs',
                            style: TextStyle(fontSize: 10, color: colors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Live Telemetry 4-Metric Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat(
                      label: 'DISTANCE',
                      val: '${_tracker.totalDistanceKm.toStringAsFixed(1)} km',
                      sub: '${_tracker.evDistanceKm.toStringAsFixed(1)} km EV',
                      color: colors.textPrimary,
                    ),
                    _MiniStat(
                      label: 'EV SPLIT',
                      val: '${_tracker.evRatio.round()}%',
                      sub: 'Battery Ratio',
                      color: colors.evTeal,
                    ),
                    _MiniStat(
                      label: 'CONSUMPTION',
                      val: '${_tracker.kwhPer100Km.toStringAsFixed(1)} kWh',
                      sub: '${_tracker.litresPer100Km.toStringAsFixed(1)} L/100km',
                      color: colors.textPrimary,
                    ),
                    _MiniStat(
                      label: 'TRIP COST',
                      val: 'RM ${_tracker.liveCostRm.toStringAsFixed(2)}',
                      sub: 'RM ${(_tracker.totalDistanceKm > 0 ? _tracker.liveCostRm / _tracker.totalDistanceKm : 0.09).toStringAsFixed(2)}/km',
                      color: colors.evTeal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Control Actions Deck (Pause/Resume, Test Drive Simulation, Finish)
              Row(
                children: [
                  // Simulation Toggle Button
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: _toggleAutoSimulation,
                      icon: Icon(
                        _isAutoSimulating ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
                        size: 16,
                        color: _isAutoSimulating ? Colors.redAccent : colors.evTeal,
                      ),
                      label: Text(
                        _isAutoSimulating ? 'Stop Sim' : 'Test Drive',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isAutoSimulating ? Colors.redAccent : colors.evTeal,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: _isAutoSimulating ? Colors.redAccent.withValues(alpha: 0.5) : colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Pause / Resume Button
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_tracker.isPaused) {
                          _tracker.resumeDrive();
                        } else {
                          _tracker.pauseDrive();
                        }
                      },
                      icon: Icon(
                        _tracker.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 16,
                        color: colors.textPrimary,
                      ),
                      label: Text(
                        _tracker.isPaused ? 'Resume' : 'Pause',
                        style: TextStyle(fontSize: 12, color: colors.textPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Finish & Save Trip Button
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: _showFinishTripDialog,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Finish & Save',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.evTeal,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String val;
  final String sub;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.val,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: colors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          sub,
          style: TextStyle(fontSize: 9.5, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Canvas painter for rendering the live real-time GPS breadcrumb route.
class _LiveRouteCanvasPainter extends CustomPainter {
  final List<TripBreadcrumbPoint> breadcrumbs;
  final bool isDark;
  final Color evColor;
  final Color hevColor;
  final double pulseVal;

  _LiveRouteCanvasPainter({
    required this.breadcrumbs,
    required this.isDark,
    required this.evColor,
    required this.hevColor,
    required this.pulseVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Grid background lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (breadcrumbs.isEmpty) {
      final startPos = Offset(size.width * 0.20, size.height * 0.25);
      _drawCarPin(canvas, startPos, evColor);
      return;
    }

    // 2. Draw Route segments (Teal for EV, Amber for HEV)
    for (int i = 0; i < breadcrumbs.length - 1; i++) {
      final p1 = Offset(breadcrumbs[i].x * size.width, breadcrumbs[i].y * size.height);
      final p2 = Offset(breadcrumbs[i + 1].x * size.width, breadcrumbs[i + 1].y * size.height);
      final isEv = breadcrumbs[i + 1].isEv;
      final segmentColor = isEv ? evColor : hevColor;

      // Outer Glow
      final glowPaint = Paint()
        ..color = segmentColor.withValues(alpha: 0.25)
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, glowPaint);

      // Core Line
      final linePaint = Paint()
        ..color = segmentColor
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, linePaint);
    }

    // 3. Start Point Marker (A pin)
    final startOffset = Offset(breadcrumbs.first.x * size.width, breadcrumbs.first.y * size.height);
    canvas.drawCircle(
      startOffset,
      6.0,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      startOffset,
      4.0,
      Paint()..color = evColor,
    );

    // 4. Current Vehicle Head Marker (with pulsing radar ring)
    final currentPoint = breadcrumbs.last;
    final currentOffset = Offset(currentPoint.x * size.width, currentPoint.y * size.height);
    final activeColor = currentPoint.isEv ? evColor : hevColor;

    // Pulsing Radar Wave
    final pulseRadius = 8.0 + (pulseVal * 16.0);
    final pulseAlpha = (1.0 - pulseVal).clamp(0.0, 1.0) * 0.45;
    canvas.drawCircle(
      currentOffset,
      pulseRadius,
      Paint()
        ..color = activeColor.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    _drawCarPin(canvas, currentOffset, activeColor);
  }

  void _drawCarPin(Canvas canvas, Offset offset, Color color) {
    // Outer white halo
    canvas.drawCircle(
      offset,
      9.0,
      Paint()..color = Colors.white,
    );
    // Core vehicle indicator
    canvas.drawCircle(
      offset,
      6.5,
      Paint()..color = color,
    );
    // Inner center dot
    canvas.drawCircle(
      offset,
      2.5,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveRouteCanvasPainter oldDelegate) {
    return oldDelegate.breadcrumbs.length != breadcrumbs.length ||
        oldDelegate.pulseVal != pulseVal ||
        oldDelegate.isDark != isDark;
  }
}
