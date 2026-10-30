import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../theme/app_tokens.dart';

/// Screen 3: ENERGY · HOME AC (Smart Home AC Charging Plan & TNB Optimizer)
class EnergyScreen extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final bool isCharging;
  final bool scheduledCharging;
  final double tnbTariff;
  final double fuelPrice;
  final ValueChanged<bool>? onToggleCharge;
  final Function(bool isScheduled, TimeOfDay startTime, TimeOfDay endTime, int targetSoc, double powerKw)? onSaveSchedule;

  const EnergyScreen({
    super.key,
    required this.telemetry,
    this.isCharging = false,
    this.scheduledCharging = true,
    this.tnbTariff = 0.28,
    this.fuelPrice = 2.05,
    this.onToggleCharge,
    this.onSaveSchedule,
  });

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  int _targetSoc = 80; // 80% daily, 90% extended, 100% trip
  final double _powerKw = 3.3;

  // Tiggo 7 PHEV Battery Size in Malaysia
  static const double batteryCapacityKwh = 19.27;

  int get currentSoc => widget.telemetry.batteryPct > 0 ? widget.telemetry.batteryPct : 24;

  double get addsKwh {
    final deficit = math.max(0, _targetSoc - currentSoc);
    return (deficit / 100.0) * batteryCapacityKwh;
  }

  double get chargingHours => addsKwh > 0 ? addsKwh / _powerKw : 0.0;

  // Calculations for cost comparison
  double get offPeakCost => addsKwh * 0.280; // TNB off-peak residential rate
  double get peakCost => addsKwh * 0.570;    // TNB peak block rate
  double get ron95Cost {
    // 19.27 kWh gives ~90 km EV range. 90 km on petrol (5.5L/100km) = 4.95L * RM 2.05 = ~RM 10.15
    final equivKm = (addsKwh / batteryCapacityKwh) * 90.0;
    final petrolLitres = (equivKm / 100.0) * 5.5;
    return petrolLitres * widget.fuelPrice;
  }

  String get doneTimeStr {
    final startMinutes = 22 * 60; // 22:00
    final durationMinutes = (chargingHours * 60).round();
    final totalMinutes = (startMinutes + durationMinutes) % (24 * 60);
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF6F8FA);
    final cardCol = isDark ? const Color(0xFF12141A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);
    final limeAccent = context.tokens.accent;
    const orangeAccent = Color(0xFFFF6E40);

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ENERGY · HOME AC',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Charge plan',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderCol),
                    ),
                    child: Text(
                      widget.isCharging ? 'CHARGING 3.3 kW' : 'PLUGGED · IDLE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: widget.isCharging ? limeAccent : textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Big SoC Display & Target
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                      children: [
                        TextSpan(text: '$currentSoc'),
                        TextSpan(
                          text: '%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '→ $_targetSoc% target',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 3. Hatched Charging Progress Bar
              CustomPaint(
                size: const Size(double.infinity, 32),
                painter: _HatchedChargeBarPainter(
                  currentPct: currentSoc / 100.0,
                  targetPct: _targetSoc / 100.0,
                  accentColor: limeAccent,
                  trackColor: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0),
                  borderColor: borderCol,
                ),
              ),
              const SizedBox(height: 6),

              // Scale ticks: 0, 25, 50, 75, 100
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _TickText('0'),
                  _TickText('25'),
                  _TickText('50'),
                  _TickText('75'),
                  _TickText('100'),
                ],
              ),
              const SizedBox(height: 18),

              // 4. Target Preset Buttons (80% daily, 90% extended, 100% trip)
              Row(
                children: [
                  Expanded(
                    child: _PresetPill(
                      label: '80% daily',
                      isSelected: _targetSoc == 80,
                      accentColor: limeAccent,
                      cardCol: cardCol,
                      borderCol: borderCol,
                      textMuted: textMuted,
                      textPrimary: textPrimary,
                      onTap: () => setState(() => _targetSoc = 80),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PresetPill(
                      label: '90% extended',
                      isSelected: _targetSoc == 90,
                      accentColor: limeAccent,
                      cardCol: cardCol,
                      borderCol: borderCol,
                      textMuted: textMuted,
                      textPrimary: textPrimary,
                      onTap: () => setState(() => _targetSoc = 90),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PresetPill(
                      label: '100% trip',
                      isSelected: _targetSoc == 100,
                      accentColor: limeAccent,
                      cardCol: cardCol,
                      borderCol: borderCol,
                      textMuted: textMuted,
                      textPrimary: textPrimary,
                      onTap: () => setState(() => _targetSoc = 100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. 24-Hour Timeline Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TONIGHT · 24 H',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                  Text(
                    'off-peak 22:00–08:00',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Visual 24-Hour Timeline Bar Canvas
              CustomPaint(
                size: const Size(double.infinity, 44),
                painter: _Timeline24hPainter(
                  accentColor: limeAccent,
                  isDark: isDark,
                  offPeakStart: 22.0,
                  offPeakEnd: 8.0,
                  chargingStart: 22.0,
                  chargingDurationHours: chargingHours,
                ),
              ),
              const SizedBox(height: 6),

              // Timeline Hour Labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _TickText('12:00'),
                  _TickText('18:00'),
                  _TickText('00:00'),
                  _TickText('06:00'),
                  _TickText('12:00'),
                ],
              ),
              const SizedBox(height: 18),

              // 6. Metrics Row: START | DONE | ADDS
              Container(
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('START', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: textMuted)),
                            const SizedBox(height: 3),
                            Text('22:00', style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 40, color: borderCol),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DONE', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: textMuted)),
                            const SizedBox(height: 3),
                            Text(doneTimeStr, style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 40, color: borderCol),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ADDS', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: textMuted)),
                            const SizedBox(height: 3),
                            Text('${addsKwh.toStringAsFixed(1)} kWh', style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 7. Cost of this charge section
              Text(
                'COST OF THIS CHARGE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 12),

              // Off-peak row
              _CostBarRow(
                label: 'Off-peak',
                amount: 'RM ${offPeakCost.toStringAsFixed(2)}',
                barFactor: 0.45,
                barColor: limeAccent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                trackColor: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 10),

              // Peak row
              _CostBarRow(
                label: 'Peak',
                amount: 'RM ${peakCost.toStringAsFixed(2)}',
                barFactor: 0.85,
                barColor: isDark ? const Color(0xFF333B4A) : const Color(0xFF94A3B8),
                textPrimary: textPrimary,
                textMuted: textMuted,
                trackColor: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 10),

              // RON95 equiv row
              _CostBarRow(
                label: 'RON95 equiv.',
                amount: 'RM ${ron95Cost.toStringAsFixed(2)}',
                barFactor: 0.90,
                barColor: orangeAccent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                trackColor: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 8),

              Text(
                '3.3 kW wallbox · TNB RM 0.280/kWh off-peak',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 28),

              // 8. Dual Action Buttons: [ Charge now ] and [ Schedule for 22:00 ]
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onToggleCharge?.call(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Immediate AC charge started.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderCol),
                        backgroundColor: cardCol,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Charge now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onSaveSchedule?.call(
                          true,
                          const TimeOfDay(hour: 22, minute: 0),
                          const TimeOfDay(hour: 8, minute: 0),
                          _targetSoc,
                          _powerKw,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Smart Schedule confirmed for 22:00 (Target: $_targetSoc%).')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: limeAccent,
                        foregroundColor: const Color(0xFF0A0B0E),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Schedule for 22:00',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A0B0E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickText extends StatelessWidget {
  final String text;
  const _TickText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF717684) : const Color(0xFF64748B),
      ),
    );
  }
}

class _PresetPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final Color cardCol;
  final Color borderCol;
  final Color textMuted;
  final Color textPrimary;
  final VoidCallback onTap;

  const _PresetPill({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.cardCol,
    required this.borderCol,
    required this.textMuted,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : borderCol,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? accentColor : textMuted,
          ),
        ),
      ),
    );
  }
}

class _CostBarRow extends StatelessWidget {
  final String label;
  final String amount;
  final double barFactor;
  final Color barColor;
  final Color textPrimary;
  final Color textMuted;
  final Color trackColor;

  const _CostBarRow({
    required this.label,
    required this.amount,
    required this.barFactor,
    required this.barColor,
    required this.textPrimary,
    required this.textMuted,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: textPrimary),
          ),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: barFactor.clamp(0.05, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 65,
          child: Text(
            amount,
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
          ),
        ),
      ],
    );
  }
}

class _HatchedChargeBarPainter extends CustomPainter {
  final double currentPct;
  final double targetPct;
  final Color accentColor;
  final Color trackColor;
  final Color borderColor;

  _HatchedChargeBarPainter({
    required this.currentPct,
    required this.targetPct,
    required this.accentColor,
    required this.trackColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(6),
    );

    // Track
    final trackPaint = Paint()..color = trackColor;
    canvas.drawRRect(rrect, trackPaint);

    final currentW = size.width * currentPct.clamp(0.0, 1.0);
    final targetW = size.width * targetPct.clamp(0.0, 1.0);

    // Solid filled current charge
    if (currentW > 0) {
      final solidRect = Rect.fromLTWH(0, 0, currentW, size.height);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(solidRect, Paint()..color = accentColor);
      canvas.restore();
    }

    // Hatched pattern from currentW to targetW
    if (targetW > currentW) {
      final hatchRect = Rect.fromLTWH(currentW, 0, targetW - currentW, size.height);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.clipRect(hatchRect);

      // Darker backdrop for hatched section
      canvas.drawRect(hatchRect, Paint()..color = accentColor.withValues(alpha: 0.15));

      // Diagonal lines
      final linePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.45)
        ..strokeWidth = 2.0;

      const spacing = 8.0;
      for (double x = currentW - size.height; x < targetW + size.height; x += spacing) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          linePaint,
        );
      }
      canvas.restore();
    }

    // Vertical line tick at target
    if (targetW > 0 && targetW < size.width) {
      final tickPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(targetW, 0), Offset(targetW, size.height), tickPaint);
    }

    // Border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HatchedChargeBarPainter oldDelegate) {
    return oldDelegate.currentPct != currentPct ||
        oldDelegate.targetPct != targetPct ||
        oldDelegate.accentColor != accentColor;
  }
}

class _Timeline24hPainter extends CustomPainter {
  final Color accentColor;
  final bool isDark;
  final double offPeakStart;
  final double offPeakEnd;
  final double chargingStart;
  final double chargingDurationHours;

  _Timeline24hPainter({
    required this.accentColor,
    required this.isDark,
    required this.offPeakStart,
    required this.offPeakEnd,
    required this.chargingStart,
    required this.chargingDurationHours,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackCol = isDark ? const Color(0xFF141720) : const Color(0xFFE2E8F0);
    final offPeakCol = isDark ? const Color(0xFF1C2230) : const Color(0xFFCBD5E1);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 10, size.width, size.height - 10),
      const Radius.circular(6),
    );
    canvas.drawRRect(rrect, Paint()..color = trackCol);

    canvas.save();
    canvas.clipRRect(rrect);

    // Timeline spans from 12:00 noon (0.0) to next day 12:00 noon (24.0)
    // 22:00 is 10 hours from 12:00 (fraction = 10 / 24)
    // 08:00 is 20 hours from 12:00 (fraction = 20 / 24)
    final offPeakX1 = size.width * (10.0 / 24.0);
    final offPeakX2 = size.width * (20.0 / 24.0);

    // Draw shaded off-peak block
    canvas.drawRect(
      Rect.fromLTWH(offPeakX1, 10, offPeakX2 - offPeakX1, size.height - 10),
      Paint()..color = offPeakCol,
    );

    // Draw charging duration block in lime
    final chargeDurationFraction = chargingDurationHours / 24.0;
    final chargeW = size.width * chargeDurationFraction;
    canvas.drawRect(
      Rect.fromLTWH(offPeakX1, 10, chargeW, size.height - 10),
      Paint()..color = accentColor,
    );
    canvas.restore();

    // NOW indicator at top of bar (around 20:00 = 8h from 12:00)
    final nowX = size.width * (8.5 / 24.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'NOW',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(nowX - textPainter.width / 2, 0));

    // Vertical line under NOW
    canvas.drawLine(
      Offset(nowX, 10),
      Offset(nowX, size.height),
      Paint()
        ..color = isDark ? Colors.white54 : Colors.black45
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _Timeline24hPainter oldDelegate) {
    return true;
  }
}
