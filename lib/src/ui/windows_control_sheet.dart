import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';
import 'apple_design_widgets.dart';

/// Full-Featured Windows, Panoramic Sunroof & Electric Sunshade Controller Sheet.
/// Provides independent 1-tap controls for Windows, Sunroof Glass, and Electric Curtain.
class WindowsControlSheet extends StatefulWidget {
  final VehicleRepository repository;
  final VehicleTelemetry telemetry;
  final bool initialWindowsVented;
  final bool initialSunroofOpen;
  final ValueChanged<bool>? onWindowsChanged;
  final ValueChanged<bool>? onSunroofChanged;

  const WindowsControlSheet({
    super.key,
    required this.repository,
    required this.telemetry,
    required this.initialWindowsVented,
    this.initialSunroofOpen = false,
    this.onWindowsChanged,
    this.onSunroofChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleRepository repository,
    required VehicleTelemetry telemetry,
    required bool initialWindowsVented,
    bool initialSunroofOpen = false,
    ValueChanged<bool>? onWindowsChanged,
    ValueChanged<bool>? onSunroofChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WindowsControlSheet(
        repository: repository,
        telemetry: telemetry,
        initialWindowsVented: initialWindowsVented,
        initialSunroofOpen: initialSunroofOpen,
        onWindowsChanged: onWindowsChanged,
        onSunroofChanged: onSunroofChanged,
      ),
    );
  }

  @override
  State<WindowsControlSheet> createState() => _WindowsControlSheetState();
}

class _WindowsControlSheetState extends State<WindowsControlSheet> {
  late bool _isVented;
  late bool _isSunroofOpen;
  String _activeSunroofMode = 'closed'; // 'open', 'tilt', 'closed'
  bool _sunshadeCurtainClosed = false;

  bool _isTransmitting = false;
  String? _activeAction;
  String? _statusFeedback;
  bool? _lastSuccess;

  @override
  void initState() {
    super.initState();
    _isVented = widget.initialWindowsVented;
    _isSunroofOpen = widget.initialSunroofOpen;
    _activeSunroofMode = widget.initialSunroofOpen ? 'open' : 'closed';
  }

  Future<void> _fireCommand({
    required String action,
    required String opcode,
    required String label,
    VoidCallback? onOptimistic,
    VoidCallback? onRevert,
    VoidCallback? onSuccess,
  }) async {
    if (_isTransmitting) return;
    HapticFeedback.lightImpact();

    onOptimistic?.call();

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
        HapticFeedback.mediumImpact();
        setState(() {
          _statusFeedback = '✓ $label executed successfully';
          _lastSuccess = true;
          onSuccess?.call();
        });
      } else {
        HapticFeedback.heavyImpact();
        onRevert?.call();
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
      HapticFeedback.heavyImpact();
      onRevert?.call();
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
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sensor_window_rounded, size: 22, color: Color(0xFF00E5FF)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Windows & Panoramic Sunroof',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Individual 1-Tap Actuation • Glazing & Shade',
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
          const SizedBox(height: 14),

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

          // 1. 4-Door Power Windows Section
          Text(
            '4-DOOR POWER WINDOWS',
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
                  title: 'Vent (20mm)',
                  subtitle: 'Heat Escape',
                  icon: Icons.air_rounded,
                  activeColor: const Color(0xFF00E5FF),
                  isSelected: _isVented,
                  isBusy: _isTransmitting && _activeAction == 'win_vent',
                  onTap: () {
                    final prev = _isVented;
                    _fireCommand(
                      action: 'win_vent',
                      opcode: CarLinkoOpcodes.windowsVent,
                      label: 'Vent (20mm)',
                      onOptimistic: () => setState(() => _isVented = true),
                      onRevert: () => setState(() => _isVented = prev),
                      onSuccess: () {
                        _isVented = true;
                        widget.onWindowsChanged?.call(true);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppleControlTile(
                  title: 'Open All',
                  subtitle: 'Lower 4x',
                  icon: Icons.vertical_align_bottom_rounded,
                  activeColor: const Color(0xFFFF9F1C),
                  isSelected: false,
                  isBusy: _isTransmitting && _activeAction == 'win_open',
                  onTap: () {
                    final prev = _isVented;
                    _fireCommand(
                      action: 'win_open',
                      opcode: CarLinkoOpcodes.windowsOpen,
                      label: 'Open Windows',
                      onOptimistic: () => setState(() => _isVented = true),
                      onRevert: () => setState(() => _isVented = prev),
                      onSuccess: () {
                        _isVented = true;
                        widget.onWindowsChanged?.call(true);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppleControlTile(
                  title: 'Close All',
                  subtitle: 'Sealed Flush',
                  icon: Icons.vertical_align_top_rounded,
                  activeColor: colors.evTeal,
                  isSelected: !_isVented,
                  isBusy: _isTransmitting && _activeAction == 'win_close',
                  onTap: () {
                    final prev = _isVented;
                    _fireCommand(
                      action: 'win_close',
                      opcode: CarLinkoOpcodes.windowsClose,
                      label: 'Close Windows',
                      onOptimistic: () => setState(() => _isVented = false),
                      onRevert: () => setState(() => _isVented = prev),
                      onSuccess: () {
                        _isVented = false;
                        widget.onWindowsChanged?.call(false);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Panoramic Glass Roof Section
          Text(
            'PANORAMIC SUNROOF GLASS',
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
                  isSelected: _activeSunroofMode == 'open',
                  isBusy: _isTransmitting && _activeAction == 'roof_open',
                  onTap: () {
                    final prevMode = _activeSunroofMode;
                    final prevOpen = _isSunroofOpen;
                    _fireCommand(
                      action: 'roof_open',
                      opcode: CarLinkoOpcodes.sunroofOpen,
                      label: 'Open Sunroof',
                      onOptimistic: () => setState(() {
                        _activeSunroofMode = 'open';
                        _isSunroofOpen = true;
                      }),
                      onRevert: () => setState(() {
                        _activeSunroofMode = prevMode;
                        _isSunroofOpen = prevOpen;
                      }),
                      onSuccess: () {
                        _activeSunroofMode = 'open';
                        _isSunroofOpen = true;
                        widget.onSunroofChanged?.call(true);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppleControlTile(
                  title: 'Tilt / Vent',
                  subtitle: 'Highway Aero',
                  icon: Icons.open_in_full_rounded,
                  activeColor: Colors.amber,
                  isSelected: _activeSunroofMode == 'tilt',
                  isBusy: _isTransmitting && _activeAction == 'roof_tilt',
                  onTap: () {
                    final prevMode = _activeSunroofMode;
                    final prevOpen = _isSunroofOpen;
                    _fireCommand(
                      action: 'roof_tilt',
                      opcode: CarLinkoOpcodes.sunroofTilt,
                      label: 'Tilt Sunroof',
                      onOptimistic: () => setState(() {
                        _activeSunroofMode = 'tilt';
                        _isSunroofOpen = true;
                      }),
                      onRevert: () => setState(() {
                        _activeSunroofMode = prevMode;
                        _isSunroofOpen = prevOpen;
                      }),
                      onSuccess: () {
                        _activeSunroofMode = 'tilt';
                        _isSunroofOpen = true;
                        widget.onSunroofChanged?.call(true);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppleControlTile(
                  title: 'Close Glass',
                  subtitle: 'Weather Sealed',
                  icon: Icons.wb_twilight_rounded,
                  activeColor: colors.evTeal,
                  isSelected: _activeSunroofMode == 'closed',
                  isBusy: _isTransmitting && _activeAction == 'roof_close',
                  onTap: () {
                    final prevMode = _activeSunroofMode;
                    final prevOpen = _isSunroofOpen;
                    _fireCommand(
                      action: 'roof_close',
                      opcode: CarLinkoOpcodes.sunroofClose,
                      label: 'Close Sunroof',
                      onOptimistic: () => setState(() {
                        _activeSunroofMode = 'closed';
                        _isSunroofOpen = false;
                      }),
                      onRevert: () => setState(() {
                        _activeSunroofMode = prevMode;
                        _isSunroofOpen = prevOpen;
                      }),
                      onSuccess: () {
                        _activeSunroofMode = 'closed';
                        _isSunroofOpen = false;
                        widget.onSunroofChanged?.call(false);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. Electric Sunshade Curtain Section
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
                    'Instant 1-Tap: Directly communicates with your Tiggo 7 PHEV CAN gateway.',
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
