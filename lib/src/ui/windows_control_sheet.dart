import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';
import 'sage_widgets.dart';

/// Power Windows controller (4-door vent / open / close).
///
/// Previously this sheet also carried sunroof and sunshade controls; those
/// now live in their own dedicated [SunroofControlSheet] so the "Windows"
/// and "Sunroof" Control Center pods each open a focused, single-purpose
/// screen instead of one shared "Windows & Sunroof" sheet.
class WindowsControlSheet extends StatefulWidget {
  final VehicleRepository repository;
  final VehicleTelemetry telemetry;
  final bool initialWindowsVented;
  final ValueChanged<bool>? onWindowsChanged;

  const WindowsControlSheet({
    super.key,
    required this.repository,
    required this.telemetry,
    required this.initialWindowsVented,
    this.onWindowsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleRepository repository,
    required VehicleTelemetry telemetry,
    required bool initialWindowsVented,
    ValueChanged<bool>? onWindowsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WindowsControlSheet(
        repository: repository,
        telemetry: telemetry,
        initialWindowsVented: initialWindowsVented,
        onWindowsChanged: onWindowsChanged,
      ),
    );
  }

  @override
  State<WindowsControlSheet> createState() => _WindowsControlSheetState();
}

class _WindowsControlSheetState extends State<WindowsControlSheet> {
  late bool _isVented;

  bool _isTransmitting = false;
  String? _activeAction;
  String? _statusFeedback;
  bool? _lastSuccess;

  @override
  void initState() {
    super.initState();
    _isVented = widget.initialWindowsVented;
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
    final t = context.tokens;
    final evAccent = t.accent; // single lime/accent colour, same as the dashboard

    return SageSheetContainer(
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
                      color: evAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                    ),
                    child: Icon(Icons.sensor_window_rounded, size: 22, color: evAccent),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Windows',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: t.ink,
                        ),
                      ),
                      Text(
                        '4-door power glass',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: t.ink2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: t.ink3),
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
                    ? t.resolvedOkContainer
                    : (_lastSuccess == false)
                        ? t.resolvedDangerContainer
                        : t.resolvedContainerHigh,
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                border: Border.all(
                  color: (_lastSuccess == true)
                      ? t.ok.withValues(alpha: 0.45)
                      : (_lastSuccess == false)
                          ? t.danger.withValues(alpha: 0.45)
                          : t.border,
                ),
              ),
              child: Row(
                children: [
                  if (_isTransmitting) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: evAccent),
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
                            ? t.ok
                            : (_lastSuccess == false)
                                ? t.danger
                                : t.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. 4-Door Power Windows Section
          Text(
            'WINDOWS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: t.ink3,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: SageControlTile(
                  title: 'Vent',
                  subtitle: '20mm gap',
                  icon: Icons.air_rounded,
                  activeColor: evAccent,
                  isSelected: _isVented,
                  isBusy: _isTransmitting && _activeAction == 'win_vent',
                  onTap: () {
                    final prev = _isVented;
                    _fireCommand(
                      action: 'win_vent',
                      opcode: CarLinkoOpcodes.windowsVent,
                      label: 'Vent windows',
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
                child: SageControlTile(
                  title: 'Open all',
                  subtitle: 'Lower 4x',
                  icon: Icons.vertical_align_bottom_rounded,
                  activeColor: t.danger,
                  isSelected: false,
                  isBusy: _isTransmitting && _activeAction == 'win_open',
                  onTap: () {
                    final prev = _isVented;
                    _fireCommand(
                      action: 'win_open',
                      opcode: CarLinkoOpcodes.windowsOpen,
                      label: 'Open windows',
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
                child: SageControlTile(
                  title: 'Close all',
                  subtitle: 'Sealed',
                  icon: Icons.vertical_align_top_rounded,
                  activeColor: evAccent,
                  isSelected: !_isVented,
                  isBusy: _isTransmitting && _activeAction == 'win_close',
                  onTap: () {
                    final prev = _isVented;
                    _fireCommand(
                      action: 'win_close',
                      opcode: CarLinkoOpcodes.windowsClose,
                      label: 'Close windows',
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
          const SizedBox(height: 16),

          // Informational Tip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: t.resolvedContainerHigh,
              borderRadius: BorderRadius.circular(AppTokens.rMd),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: evAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Each panel sends an instant command directly to the vehicle.',
                    style: TextStyle(fontSize: 11.5, color: t.ink2),
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

