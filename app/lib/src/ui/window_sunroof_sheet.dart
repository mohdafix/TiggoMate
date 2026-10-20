import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../carlinko/vehicle_telemetry.dart';

/// Full-featured Windows & Panoramic Sunroof Control Sheet
/// Ported from official Chery CarLinko CAN-bus telematics.
class WindowSunroofSheet extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final bool initialWindowsVented;
  final bool initialSunroofOpen;
  final Function(String windowAction, String sunroofAction) onApply;

  const WindowSunroofSheet({
    super.key,
    required this.telemetry,
    required this.initialWindowsVented,
    required this.initialSunroofOpen,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTelemetry telemetry,
    required bool initialWindowsVented,
    required bool initialSunroofOpen,
    required Function(String windowAction, String sunroofAction) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WindowSunroofSheet(
        telemetry: telemetry,
        initialWindowsVented: initialWindowsVented,
        initialSunroofOpen: initialSunroofOpen,
        onApply: onApply,
      ),
    );
  }

  @override
  State<WindowSunroofSheet> createState() => _WindowSunroofSheetState();
}

class _WindowSunroofSheetState extends State<WindowSunroofSheet> {
  late String _windowMode; // 'closed', 'vent', 'open'
  late String _sunroofMode; // 'closed', 'tilt', 'open'
  bool _sunshadeClosed = false;

  @override
  void initState() {
    super.initState();
    _windowMode = widget.initialWindowsVented ? 'vent' : 'closed';
    _sunroofMode = widget.initialSunroofOpen ? 'open' : 'closed';
  }

  void _applyChanges() {
    HapticFeedback.mediumImpact();
    widget.onApply(_windowMode, _sunroofMode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C111A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? const Color(0xFF233044) : Colors.black12,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.evTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sensor_window_outlined, size: 20, color: colors.evTeal),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Windows & Panoramic Sunroof',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Remote Glazing Control & Anti-Pinch',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Windows Controls
          Text(
            '4-DOOR POWER WINDOWS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildWindowOption(
                label: 'Close All',
                desc: 'Sealed & Secured',
                icon: Icons.compress,
                isSelected: _windowMode == 'closed',
                activeColor: colors.evTeal,
                colors: colors,
                onTap: () => setState(() => _windowMode = 'closed'),
              ),
              const SizedBox(width: 8),
              _buildWindowOption(
                label: 'Vent (20mm)',
                desc: 'Heat Escape',
                icon: Icons.air,
                isSelected: _windowMode == 'vent',
                activeColor: const Color(0xFF2F81F7),
                colors: colors,
                onTap: () => setState(() => _windowMode = 'vent'),
              ),
              const SizedBox(width: 8),
              _buildWindowOption(
                label: 'Open All',
                desc: 'Fully Lowered',
                icon: Icons.vertical_align_bottom,
                isSelected: _windowMode == 'open',
                activeColor: Colors.amber,
                colors: colors,
                onTap: () => setState(() => _windowMode = 'open'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Panoramic Sunroof Controls
          Text(
            'PANORAMIC SUNROOF & SHADE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildWindowOption(
                label: 'Close Glass',
                desc: 'Flush Sealed',
                icon: Icons.wb_twilight,
                isSelected: _sunroofMode == 'closed',
                activeColor: colors.evTeal,
                colors: colors,
                onTap: () => setState(() => _sunroofMode = 'closed'),
              ),
              const SizedBox(width: 8),
              _buildWindowOption(
                label: 'Tilt / Vent',
                desc: 'Highway Aero',
                icon: Icons.open_in_full,
                isSelected: _sunroofMode == 'tilt',
                activeColor: const Color(0xFF2F81F7),
                colors: colors,
                onTap: () => setState(() => _sunroofMode = 'tilt'),
              ),
              const SizedBox(width: 8),
              _buildWindowOption(
                label: 'Slide Open',
                desc: 'Full Sky View',
                icon: Icons.open_in_browser,
                isSelected: _sunroofMode == 'open',
                activeColor: Colors.amber,
                colors: colors,
                onTap: () => setState(() => _sunroofMode = 'open'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Motorized Sunshade Curtain
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.tileBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.curtains_closed_outlined, size: 18, color: colors.textPrimary),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Motorized Sunshade Curtain', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                        Text('High UV solar rejection fabric', style: TextStyle(fontSize: 10, color: colors.textMuted)),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _sunshadeClosed,
                  activeThumbColor: colors.evTeal,
                  onChanged: (v) => setState(() => _sunshadeClosed = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Transmit Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _applyChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D2AA),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text(
                'Transmit Glazing Commands to T-Box',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowOption({
    required String label,
    required String desc,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: colors.isDark ? 0.2 : 0.15)
                : colors.tileBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? activeColor : colors.textMuted,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? activeColor : colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 9,
                  color: colors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
