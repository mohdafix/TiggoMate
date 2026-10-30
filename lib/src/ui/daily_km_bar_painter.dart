import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Screen 4: Cyber Minimalist Daily Stacked EV/Fuel Bar Graph
class DailyKmBarPainter extends CustomPainter {
  /// Kilometres per day of the month, index 0 being the 1st.
  final List<double> dailyEvKm;
  final List<double> dailyFuelKm;
  final Color limeAccent;
  final Color orangeAccent;
  final Color gridLineColor;
  final Color textMuted;

  DailyKmBarPainter({
    required this.dailyEvKm,
    required this.dailyFuelKm,
    required this.limeAccent,
    required this.orangeAccent,
    required this.gridLineColor,
    required this.textMuted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bottomY = size.height - 18;
    final chartH = bottomY - 10;

    // Subtle horizontal baseline
    final linePaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, bottomY), Offset(size.width, bottomY), linePaint);

    final colCount = dailyEvKm.length;
    if (colCount == 0) return;

    // Scale to the busiest day; a month with no driving just shows the baseline
    double maxVal = 1.0;
    for (int i = 0; i < colCount; i++) {
      final total = dailyEvKm[i] + dailyFuelKm[i];
      if (total > maxVal) maxVal = total;
    }

    final colW = (size.width / colCount).clamp(2.0, 16.0);
    final totalW = colCount * colW;
    final startX = (size.width - totalW) / 2;

    for (int i = 0; i < colCount; i++) {
      final evVal = dailyEvKm[i];
      final fuelVal = dailyFuelKm[i];
      final day = i + 1;
      final dayLabel = (day == 1 || day == 8 || day == 15 || day == 22 || day == colCount)
          ? day.toString().padLeft(2, '0')
          : '';

      final x = startX + i * colW + colW * 0.15;
      final barW = colW * 0.7;

      final evH = (evVal / maxVal) * chartH;
      final fuelH = (fuelVal / maxVal) * chartH;

      // Draw EV (lime base)
      if (evH > 0) {
        final evRect = Rect.fromLTWH(x, bottomY - evH, barW, evH);
        canvas.drawRect(evRect, Paint()..color = limeAccent);
      }

      // Draw Fuel (orange top)
      if (fuelH > 0) {
        final fuelRect = Rect.fromLTWH(x, bottomY - evH - fuelH, barW, fuelH);
        canvas.drawRect(fuelRect, Paint()..color = orangeAccent);
      }

      // Label below bar
      if (dayLabel.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: dayLabel,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, bottomY + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant DailyKmBarPainter oldDelegate) =>
      !listEquals(oldDelegate.dailyEvKm, dailyEvKm) ||
      !listEquals(oldDelegate.dailyFuelKm, dailyFuelKm) ||
      oldDelegate.limeAccent != limeAccent ||
      oldDelegate.orangeAccent != orangeAccent ||
      oldDelegate.gridLineColor != gridLineColor ||
      oldDelegate.textMuted != textMuted;
}
