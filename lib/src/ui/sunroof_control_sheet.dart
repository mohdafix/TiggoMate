import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';
import 'sage_widgets.dart';

/// Panoramic Sunroof & Electric Sunshade controller.
///
/// Split out from the former combined "Windows & Sunroof" sheet so the
/// "Sunroof" Control Center pod opens a focused, single-purpose screen
/// for the roof glass (open/tilt/close) and the fabric sunshade curtain.
class SunroofControlSheet extends StatefulWidget {
  final VehicleRepository repository;
  final VehicleTelemetry telemetry;
  final bool initialSunroofOpen;
  final ValueChanged<bool>? onSunroofChanged;

  const SunroofControlSheet({
    super.key,
    required this.repository,
    required this.telemetry,
    this.initialSunroofOpen = false,
    this.onSunroofChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleRepository repository,
    required VehicleTelemetry telemetry,
    bool initialSunroofOpen = false,
    ValueChanged<bool>? onSunroofChanged,
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
    final t = context.tokens;
    final evAccent = t.accent;
    final sunroofAccent = t.warn; // warm amber, reserved for sunroof glass states

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
                      color: sunroofAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                    ),
                    child: Icon(Icons.wb_twilight_rounded, size: 22, color: sunroofAccent),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sunroof',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: t.ink,
                        ),
                      ),
                      Text(
                        'Panoramic glass & sunshade',
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: sunroofAccent),
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

          // 1. Panoramic Glass Roof Section
          Text(
            'SUNROOF GLASS',
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
                  title: 'Open',
                  subtitle: 'Full sky',
                  icon: Icons.open_in_browser_rounded,
                  activeColor: sunroofAccent,
                  isSelected: _activeSunroofMode == 'open',
                  isBusy: _isTransmitting && _activeAction == 'roof_open',
                  onTap: () {
                    final prevMode = _activeSunroofMode;
                    final prevOpen = _isSunroofOpen;
                    _fireCommand(
                      action: 'roof_open',
                      opcode: CarLinkoOpcodes.sunroofOpen,
                      label: 'Open sunroof',
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
                child: SageControlTile(
                  title: 'Tilt',
                  subtitle: 'Vent only',
                  icon: Icons.open_in_full_rounded,
                  activeColor: sunroofAccent,
                  isSelected: _activeSunroofMode == 'tilt',
                  isBusy: _isTransmitting && _activeAction == 'roof_tilt',
                  onTap: () {
                    final prevMode = _activeSunroofMode;
                    final prevOpen = _isSunroofOpen;
                    _fireCommand(
                      action: 'roof_tilt',
                      opcode: CarLinkoOpcodes.sunroofTilt,
                      label: 'Tilt sunroof',
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
                child: SageControlTile(
                  title: 'Close',
                  subtitle: 'Sealed',
                  icon: Icons.wb_twilight_rounded,
                  activeColor: evAccent,
                  isSelected: _activeSunroofMode == 'closed',
                  isBusy: _isTransmitting && _activeAction == 'roof_close',
                  onTap: () {
                    final prevMode = _activeSunroofMode;
                    final prevOpen = _isSunroofOpen;
                    _fireCommand(
                      action: 'roof_close',
                      opcode: CarLinkoOpcodes.sunroofClose,
                      label: 'Close sunroof',
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

          // 2. Electric Sunshade Curtain Section
          Text(
            'SUNSHADE CURTAIN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: t.ink3,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.resolvedContainerHigh,
              borderRadius: BorderRadius.circular(AppTokens.rLg),
              border: Border.all(color: t.border),
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
                      color: t.ink,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fabric curtain',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: t.ink,
                          ),
                        ),
                        Text(
                          _sunshadeCurtainClosed ? 'Drawn · blocks UV' : 'Retracted · open sky',
                          style: TextStyle(fontSize: 10.5, color: t.ink3),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _sunshadeCurtainClosed,
                  activeThumbColor: evAccent,
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

