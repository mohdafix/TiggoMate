import 'package:flutter/material.dart';

/// Screen 4: Cyber Minimalist Daily Stacked EV/Fuel Bar Graph
class DailyKmBarPainter extends CustomPainter {
  final Color limeAccent;
  final Color orangeAccent;
  final Color gridLineColor;
  final Color textMuted;

  DailyKmBarPainter({
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

    // 16 daily columns matching Screen 4 in TiggoMate_Revamp.pdf
    final dayData = [
      {'day': '01', 'ev': 18.0, 'fuel': 0.0},
      {'day': '', 'ev': 12.0, 'fuel': 0.0},
      {'day': '', 'ev': 15.0, 'fuel': 4.0},
      {'day': '', 'ev': 22.0, 'fuel': 0.0},
      {'day': '', 'ev': 0.0, 'fuel': 0.0},
      {'day': '08', 'ev': 14.0, 'fuel': 0.0},
      {'day': '', 'ev': 16.0, 'fuel': 0.0},
      {'day': '', 'ev': 38.0, 'fuel': 32.0},
      {'day': '15', 'ev': 20.0, 'fuel': 0.0},
      {'day': '', 'ev': 14.0, 'fuel': 0.0},
      {'day': '', 'ev': 30.0, 'fuel': 60.0},
      {'day': '22', 'ev': 18.0, 'fuel': 0.0},
      {'day': '', 'ev': 15.0, 'fuel': 0.0},
      {'day': '', 'ev': 16.0, 'fuel': 0.0},
      {'day': '', 'ev': 24.0, 'fuel': 0.0},
      {'day': '31', 'ev': 12.0, 'fuel': 0.0},
    ];

    const maxVal = 95.0;
    final colCount = dayData.length;
    final colW = (size.width / colCount).clamp(6.0, 16.0);
    final totalW = colCount * colW;
    final startX = (size.width - totalW) / 2;

    for (int i = 0; i < colCount; i++) {
      final item = dayData[i];
      final evVal = item['ev'] as double;
      final fuelVal = item['fuel'] as double;
      final dayLabel = item['day'] as String;

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
  bool shouldRepaint(covariant DailyKmBarPainter oldDelegate) => false;
}
