import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';
import 'apple_design_widgets.dart';

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

    return AppleSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, size: 22, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panoramic Sunroof',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Independent Glass & Electric Curtain',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: (_lastSuccess == true)
                    ? Colors.green.withValues(alpha: 0.16)
                    : (_lastSuccess == false)
                        ? Colors.red.withValues(alpha: 0.16)
                        : colors.tileBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_lastSuccess == true)
                      ? Colors.green.withValues(alpha: 0.45)
                      : (_lastSuccess == false)
                          ? Colors.red.withValues(alpha: 0.45)
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
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _statusFeedback!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: AppleControlTile(
                  title: 'Slide Open',
                  subtitle: 'Full Sky View',
                  icon: Icons.open_in_browser_rounded,
                  activeColor: Colors.amber,
                  isSelected: _activeGlassMode == 'open',
                  isBusy: _isTransmitting && _activeAction == 'open',
                  onTap: () => _fireSunroofCommand(
                    action: 'open',
                    opcode: CarLinkoOpcodes.sunroofOpen,
                    label: 'Open Sunroof',
                    resultingOpenState: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppleControlTile(
                  title: 'Tilt / Vent',
                  subtitle: 'Aero Flow',
                  icon: Icons.open_in_full_rounded,
                  activeColor: Colors.orange,
                  isSelected: _activeGlassMode == 'tilt',
                  isBusy: _isTransmitting && _activeAction == 'tilt',
                  onTap: () => _fireSunroofCommand(
                    action: 'tilt',
                    opcode: CarLinkoOpcodes.sunroofTilt,
                    label: 'Tilt Sunroof',
                    resultingOpenState: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppleControlTile(
                  title: 'Close Glass',
                  subtitle: 'Weather Sealed',
                  icon: Icons.wb_twilight_rounded,
                  activeColor: colors.evTeal,
                  isSelected: _activeGlassMode == 'closed',
                  isBusy: _isTransmitting && _activeAction == 'closed',
                  onTap: () => _fireSunroofCommand(
                    action: 'closed',
                    opcode: CarLinkoOpcodes.sunroofClose,
                    label: 'Close Sunroof',
                    resultingOpenState: false,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Motorized Sunshade Curtain
          Text(
            'ELECTRIC SUNSHADE CURTAIN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    Icon(
                      _sunshadeCurtainClosed
                          ? Icons.curtains_closed_rounded
                          : Icons.curtains_rounded,
                      size: 22,
                      color: colors.textPrimary,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sunshade Fabric Curtain',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          _sunshadeCurtainClosed ? 'Curtain drawn (Max UV Block)' : 'Curtain retracted (Open sky)',
                          style: TextStyle(fontSize: 10.5, color: colors.textMuted),
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
          const SizedBox(height: 16),

          // Informational Tip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: colors.tileBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: colors.evTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Instant 1-Tap: Operates independently without altering door windows.',
                    style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
