import 'package:flutter/material.dart';
import '../carlinko/vehicle_telemetry.dart';

/// Cyber Minimalist Top-Down Blueprint Car Canvas with TPMS Callouts (full card)
class BlueprintCarCanvas extends StatelessWidget {
  final VehicleTelemetry telemetry;
  final bool isBound;
  final Color accentColor;
  final VoidCallback? onTap;

  const BlueprintCarCanvas({
    super.key,
    required this.telemetry,
    required this.isBound,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF12141A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);

    final headerStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      letterSpacing: 1.2,
      color: textMuted,
    );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOP VIEW · TPMS COLD', style: headerStyle.copyWith(fontWeight: FontWeight.w700)),
              Text('SPEC 230 KPA', style: headerStyle.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          BlueprintCarStage(
            telemetry: telemetry,
            isBound: isBound,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }
}

/// The bare 180 px blueprint stage (painter + 4 TPMS readouts), no card chrome.
/// Used by [BlueprintCarCanvas] and by the dashboard's CarViewCarousel.
class BlueprintCarStage extends StatelessWidget {
  final VehicleTelemetry telemetry;
  final bool isBound;
  final Color accentColor;
  final double height;

  const BlueprintCarStage({
    super.key,
    required this.telemetry,
    required this.isBound,
    required this.accentColor,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);

    final flKpa = isBound && telemetry.tyreFlPressureKpa > 0 ? telemetry.tyreFlPressureKpa.round() : 232;
    final frKpa = isBound && telemetry.tyreFrPressureKpa > 0 ? telemetry.tyreFrPressureKpa.round() : 231;
    final rlKpa = isBound && telemetry.tyreRlPressureKpa > 0 ? telemetry.tyreRlPressureKpa.round() : 228;
    final rrKpa = isBound && telemetry.tyreRrPressureKpa > 0 ? telemetry.tyreRrPressureKpa.round() : 229;

    final flTemp = isBound && telemetry.tyreFlTempC > 0 ? telemetry.tyreFlTempC.round() : 31;
    final frTemp = isBound && telemetry.tyreFrTempC > 0 ? telemetry.tyreFrTempC.round() : 31;
    final rlTemp = isBound && telemetry.tyreRlTempC > 0 ? telemetry.tyreRlTempC.round() : 30;
    final rrTemp = isBound && telemetry.tyreRrTempC > 0 ? telemetry.tyreRrTempC.round() : 30;

    Widget readout(String label, int kpa, int temp, bool alignRight) => _TpmsCornerReadout(
          label: label,
          kpa: kpa,
          tempC: temp,
          alignRight: alignRight,
          textMuted: textMuted,
          textPrimary: textPrimary,
        );

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CarBlueprintPainter(
                accent: accentColor,
                lineColor: isDark ? const Color(0xFF2A313D) : const Color(0xFFCBD5E1),
                bodyFill: isDark ? const Color(0xFF0F1117) : const Color(0xFFF1F5F9),
              ),
            ),
          ),
          Positioned(top: 4, left: 4, child: readout('FL', flKpa, flTemp, false)),
          Positioned(top: 4, right: 4, child: readout('FR', frKpa, frTemp, true)),
          Positioned(bottom: 4, left: 4, child: readout('RL', rlKpa, rlTemp, false)),
          Positioned(bottom: 4, right: 4, child: readout('RR', rrKpa, rrTemp, true)),
        ],
      ),
    );
  }
}

class _TpmsCornerReadout extends StatelessWidget {
  final String label;
  final int kpa;
  final int tempC;
  final bool alignRight;
  final Color textMuted;
  final Color textPrimary;

  const _TpmsCornerReadout({
    required this.label,
    required this.kpa,
    required this.tempC,
    required this.alignRight,
    required this.textMuted,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textMuted,
          ),
        ),
        Text(
          '$kpa',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: textPrimary,
          ),
        ),
        Text(
          'kPa · $tempC°',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
      ],
    );
  }
}

class _CarBlueprintPainter extends CustomPainter {
  final Color accent;
  final Color lineColor;
  final Color bodyFill;

  _CarBlueprintPainter({
    required this.accent,
    required this.lineColor,
    required this.bodyFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final carW = 68.0;
    final carH = 150.0;
    final carLeft = cx - carW / 2;
    final carTop = cy - carH / 2;
    final carRight = cx + carW / 2;
    final carBottom = cy + carH / 2;

    final fillPaint = Paint()
      ..color = bodyFill
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final accentGlowPaint = Paint()
      ..color = accent
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final leaderPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    // 1. Draw Car Body Silhouette
    final bodyRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(carLeft, carTop, carW, carH),
      const Radius.circular(22),
    );
    canvas.drawRRect(bodyRRect, fillPaint);
    canvas.drawRRect(bodyRRect, outlinePaint);

    // 2. Draw Windshield & Roof Glass Outlines
    final frontGlassRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(carLeft + 8, carTop + 28, carW - 16, 26),
      const Radius.circular(6),
    );
    canvas.drawRRect(frontGlassRect, outlinePaint);

    final rearGlassRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(carLeft + 8, carBottom - 48, carW - 16, 22),
      const Radius.circular(6),
    );
    canvas.drawRRect(rearGlassRect, outlinePaint);

    // Panoramic sunroof line
    canvas.drawLine(
      Offset(carLeft + 12, carTop + 62),
      Offset(carRight - 12, carTop + 62),
      outlinePaint,
    );
    canvas.drawLine(
      Offset(carLeft + 12, carTop + 90),
      Offset(carRight - 12, carTop + 90),
      outlinePaint,
    );

    // 3. Draw 4 Wheels
    final wheelW = 7.0;
    final wheelH = 22.0;

    void drawWheel(double x, double y) {
      final wRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - wheelW / 2, y - wheelH / 2, wheelW, wheelH),
        const Radius.circular(3),
      );
      canvas.drawRRect(wRRect, fillPaint);
      canvas.drawRRect(wRRect, outlinePaint);
    }

    final flWheelCenter = Offset(carLeft - 1, carTop + 34);
    final frWheelCenter = Offset(carRight + 1, carTop + 34);
    final rlWheelCenter = Offset(carLeft - 1, carBottom - 34);
    final rrWheelCenter = Offset(carRight + 1, carBottom - 34);

    drawWheel(flWheelCenter.dx, flWheelCenter.dy);
    drawWheel(frWheelCenter.dx, frWheelCenter.dy);
    drawWheel(rlWheelCenter.dx, rlWheelCenter.dy);
    drawWheel(rrWheelCenter.dx, rrWheelCenter.dy);

    // 4. Headlights (Cyber Lime Glowing Arcs)
    canvas.drawLine(
      Offset(carLeft + 8, carTop + 2),
      Offset(carLeft + 22, carTop + 1),
      accentGlowPaint,
    );
    canvas.drawLine(
      Offset(carRight - 22, carTop + 1),
      Offset(carRight - 8, carTop + 2),
      accentGlowPaint,
    );

    // Taillights (Cyber Lime Glowing Accents)
    canvas.drawLine(
      Offset(carLeft + 8, carBottom - 2),
      Offset(carLeft + 20, carBottom - 1),
      accentGlowPaint,
    );
    canvas.drawLine(
      Offset(carRight - 20, carBottom - 1),
      Offset(carRight - 8, carBottom - 2),
      accentGlowPaint,
    );

    // 5. Leader lines to 4 TPMS corners with accent anchor dot
    // Front-Left Leader
    canvas.drawCircle(flWheelCenter, 2.5, dotPaint);
    final pathFl = Path()
      ..moveTo(flWheelCenter.dx, flWheelCenter.dy)
      ..lineTo(flWheelCenter.dx - 22, flWheelCenter.dy - 12)
      ..lineTo(62, flWheelCenter.dy - 12);
    canvas.drawPath(pathFl, leaderPaint);

    // Front-Right Leader
    canvas.drawCircle(frWheelCenter, 2.5, dotPaint);
    final pathFr = Path()
      ..moveTo(frWheelCenter.dx, frWheelCenter.dy)
      ..lineTo(frWheelCenter.dx + 22, frWheelCenter.dy - 12)
      ..lineTo(size.width - 62, frWheelCenter.dy - 12);
    canvas.drawPath(pathFr, leaderPaint);

    // Rear-Left Leader
    canvas.drawCircle(rlWheelCenter, 2.5, dotPaint);
    final pathRl = Path()
      ..moveTo(rlWheelCenter.dx, rlWheelCenter.dy)
      ..lineTo(rlWheelCenter.dx - 22, rlWheelCenter.dy + 12)
      ..lineTo(62, rlWheelCenter.dy + 12);
    canvas.drawPath(pathRl, leaderPaint);

    // Rear-Right Leader
    canvas.drawCircle(rrWheelCenter, 2.5, dotPaint);
    final pathRr = Path()
      ..moveTo(rrWheelCenter.dx, rrWheelCenter.dy)
      ..lineTo(rrWheelCenter.dx + 22, rrWheelCenter.dy + 12)
      ..lineTo(size.width - 62, rrWheelCenter.dy + 12);
    canvas.drawPath(pathRr, leaderPaint);
  }

  @override
  bool shouldRepaint(covariant _CarBlueprintPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.bodyFill != bodyFill;
  }
}
