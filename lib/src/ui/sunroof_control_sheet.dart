import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';

/// Dedicated Panoramic Sunroof & Motorized Sunshade Controller Sheet.
/// Provides independent 1-tap controls for roof glass and shade curtain.
class SunroofControlSheet extends StatefulWidget {
  final VehicleRepository repository;
  final VehicleTelemetry telemetry;
  final bool initialSunroofOpen;
  final ValueChanged<bool> onSunroofChanged;

  const SunroofControlSheet({
    super.key,
    required this.repository,
    required this.telemetry,
    required this.initialSunroofOpen,
    required this.onSunroofChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleRepository repository,
    required VehicleTelemetry telemetry,
    required bool initialSunroofOpen,
    required ValueChanged<bool> onSunroofChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SunroofControlSheet(
        repository: repository,
        telemetry: telemetry,
        initialSunroofOpen: initialSunroofOpen,
        onSunroofChanged: onSunroofChanged,
      ),
    );
  }

  @override
  State<SunroofControlSheet> createState() => _SunroofControlSheetState();
}

class _SunroofControlSheetState extends State<SunroofControlSheet> {
  late bool _isOpen;
  String _activeGlassMode = 'closed'; // 'open', 'tilt', 'closed'
  bool _sunshadeCurtainClosed = false;
  bool _isTransmitting = false;
  String? _activeAction;
  String? _statusFeedback;
  bool? _lastSuccess;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.initialSunroofOpen;
    _activeGlassMode = widget.initialSunroofOpen ? 'open' : 'closed';
  }

  Future<void> _fireSunroofCommand({
    required String action,
    required String opcode,
    required String label,
    required bool resultingOpenState,
  }) async {
    if (_isTransmitting) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isTransmitting = true;
      _activeAction = action;
      _statusFeedback = 'Sending $label to car…';
      _lastSuccess = null;
    });

    try {
      final res = await widget.repository.sendRemoteCommandWithResult(opcode);
      if (!mounted) return;

      if (res.success) {
        setState(() {
          _activeGlassMode = action;
          _isOpen = resultingOpenState;
          _statusFeedback = '✓ $label executed successfully';
          _lastSuccess = true;
        });
        widget.onSunroofChanged(resultingOpenState);
      } else {
        final errDetail = (res.code != null && res.code!.isNotEmpty)
            ? ' [${res.code}: ${res.message ?? "Error"}]'
            : (res.message != null ? ' (${res.message})' : '');
        setState(() {
          _statusFeedback = '⚠️ $label failed$errDetail';
          _lastSuccess = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusFeedback = '⚠️ Error sending $label: $e';
        _lastSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTransmitting = false;
          _activeAction = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12141A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
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
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, size: 22, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panoramic Sunroof & Shade',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Independent Glass & Electric Curtain Control',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Feedback Banner if transmitting / finished
          if (_statusFeedback != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: (_lastSuccess == true)
                    ? Colors.green.withValues(alpha: 0.15)
                    : (_lastSuccess == false)
                        ? Colors.red.withValues(alpha: 0.15)
                        : colors.tileBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_lastSuccess == true)
                      ? Colors.green.withValues(alpha: 0.4)
                      : (_lastSuccess == false)
                          ? Colors.red.withValues(alpha: 0.4)
                          : colors.border,
                ),
              ),
              child: Row(
                children: [
                  if (_isTransmitting) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _statusFeedback!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (_lastSuccess == true)
                            ? const Color(0xFF39FF14)
                            : (_lastSuccess == false)
                                ? Colors.redAccent
                                : colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. Panoramic Glass Section
          Text(
            'PANORAMIC GLASS ROOF',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildActionCard(
                actionKey: 'open',
                title: 'Slide Open',
                subtitle: 'Full Sky View',
                icon: Icons.open_in_browser_rounded,
                activeColor: Colors.amber,
                isCurrent: _activeGlassMode == 'open',
                colors: colors,
                onTap: () => _fireSunroofCommand(
                  action: 'open',
                  opcode: CarLinkoOpcodes.sunroofOpen,
                  label: 'Open Panoramic Sunroof',
                  resultingOpenState: true,
                ),
              ),
              const SizedBox(width: 8),
              _buildActionCard(
                actionKey: 'tilt',
                title: 'Tilt / Vent',
                subtitle: 'Aero Ventilation',
                icon: Icons.open_in_full_rounded,
                activeColor: Colors.orange,
                isCurrent: _activeGlassMode == 'tilt',
                colors: colors,
                onTap: () => _fireSunroofCommand(
                  action: 'tilt',
                  opcode: CarLinkoOpcodes.sunroofTilt,
                  label: 'Tilt Sunroof',
                  resultingOpenState: true,
                ),
              ),
              const SizedBox(width: 8),
              _buildActionCard(
                actionKey: 'closed',
                title: 'Close Glass',
                subtitle: 'Weather Sealed',
                icon: Icons.wb_twilight_rounded,
                activeColor: colors.evTeal,
                isCurrent: _activeGlassMode == 'closed',
                colors: colors,
                onTap: () => _fireSunroofCommand(
                  action: 'closed',
                  opcode: CarLinkoOpcodes.sunroofClose,
                  label: 'Close Sunroof',
                  resultingOpenState: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Motorized Sunshade Curtain
          Text(
            'ELECTRIC SUNSHADE CURTAIN',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.tileBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _sunshadeCurtainClosed
                          ? Icons.curtains_closed_rounded
                          : Icons.curtains_rounded,
                      size: 20,
                      color: colors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sunshade Fabric Curtain',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          _sunshadeCurtainClosed ? 'Curtain drawn (Max UV Block)' : 'Curtain retracted (Open sky)',
                          style: TextStyle(fontSize: 10, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _sunshadeCurtainClosed,
                  activeColor: colors.evTeal,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _sunshadeCurtainClosed = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Informational Tip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.tileBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: colors.evTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Instant 1-Tap: Operates independently without altering door windows.',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String actionKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
    required bool isCurrent,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    final isBusy = _isTransmitting && _activeAction == actionKey;

    return Expanded(
      child: InkWell(
        onTap: _isTransmitting ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? activeColor.withValues(alpha: colors.isDark ? 0.20 : 0.12)
                : colors.tileBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent ? activeColor : colors.border,
              width: isCurrent ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: activeColor),
                )
              else
                Icon(
                  icon,
                  size: 26,
                  color: isCurrent ? activeColor : colors.textPrimary,
                ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? activeColor : colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
