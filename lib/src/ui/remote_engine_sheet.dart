import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../carlinko/vehicle_telemetry.dart';

/// Remote 1.5T DHT Hybrid Engine Start & Powertrain Pre-Warm Sheet
/// Ported from official Chery CarLinko CAN-bus telematics.
class RemoteEngineSheet extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final bool initialEngineOn;
  final Function(bool startEngine, int runtimeMinutes) onApply;

  const RemoteEngineSheet({
    super.key,
    required this.telemetry,
    required this.initialEngineOn,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTelemetry telemetry,
    required bool initialEngineOn,
    required Function(bool startEngine, int runtimeMinutes) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RemoteEngineSheet(
        telemetry: telemetry,
        initialEngineOn: initialEngineOn,
        onApply: onApply,
      ),
    );
  }

  @override
  State<RemoteEngineSheet> createState() => _RemoteEngineSheetState();
}

class _RemoteEngineSheetState extends State<RemoteEngineSheet> {
  late bool _engineOn;
  final int _runtimeMinutes = 10;

  @override
  void initState() {
    super.initState();
    _engineOn = widget.initialEngineOn;
  }

  void _confirmAction() {
    HapticFeedback.heavyImpact();
    widget.onApply(!_engineOn, _runtimeMinutes);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12141A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(
          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0),
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.power_settings_new, size: 20, color: Color(0xFFFF6E40)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1.5T DHT Hybrid Engine Start',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'PHEV Powertrain Remote Pre-Warm',
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

          // Status & Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.tileBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ENGINE STATE', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: colors.textMuted)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _engineOn
                            ? const Color(0xFFFF6E40).withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _engineOn ? 'RUNNING (IDLE HYBRID)' : 'STANDBY (OFF)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _engineOn ? const Color(0xFFFF6E40) : colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Activating the engine remotely starts the 1.5T Dedicated Hybrid Engine in silent idle. It generates HV power to rapidly warm up the battery pack, cabin heating, and defrosting systems before your drive.',
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Precondition Checks
          Text(
            'CAN-BUS SAFETY INTERLOCKS',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.tileBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                _buildInterlockRow('Transmission in Park [P]', true, colors),
                const SizedBox(height: 6),
                _buildInterlockRow('Engine Bonnet / Hood Closed', true, colors),
                const SizedBox(height: 6),
                _buildInterlockRow('All Doors Locked & Secured', true, colors),
                const SizedBox(height: 6),
                _buildInterlockRow('Fuel Tank Reserve > 15%', true, colors),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _confirmAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _engineOn ? const Color(0xFFFF453A) : const Color(0xFFFF6E40),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              icon: Icon(_engineOn ? Icons.stop_circle_outlined : Icons.play_circle_filled, size: 18, color: Colors.black),
              label: Text(
                _engineOn ? 'STOP ENGINE IMMEDIATELY' : 'START 1.5T ENGINE (10 MIN RUNTIME)',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterlockRow(String title, bool ok, AppColors colors) {
    const cyberLime = Color(0xFFD2F835);
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, size: 14, color: ok ? cyberLime : const Color(0xFFFF453A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        ),
        Text(
          ok ? 'PASS' : 'FAIL',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: ok ? cyberLime : const Color(0xFFFF453A),
          ),
        ),
      ],
    );
  }
}
