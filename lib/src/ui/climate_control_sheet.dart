import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../carlinko/vehicle_repository.dart';
import 'apple_design_widgets.dart';

/// Full-featured Climate & Seat Comfort Control Sheet
/// Ported from official Chery CarLinko CAN-bus and T-Box control protocols.
class ClimateControlSheet extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final VehicleRepository? repository;
  final bool initialAcOn;
  final double initialTempC;
  final int initialDurationMin;
  final Function(bool acOn, double tempC, int durationMin, {
    bool rapidCool,
    bool frontDefrost,
    bool rearDefrost,
    bool airPurifier,
    int fanGear,
    int seatHeatDriver,
    int seatVentDriver,
    int seatHeatPass,
    int seatVentPass,
    bool steeringHeat,
  }) onApply;

  const ClimateControlSheet({
    super.key,
    required this.telemetry,
    this.repository,
    required this.initialAcOn,
    required this.initialTempC,
    required this.initialDurationMin,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTelemetry telemetry,
    VehicleRepository? repository,
    required bool initialAcOn,
    required double initialTempC,
    int initialDurationMin = 10,
    required Function(bool acOn, double tempC, int durationMin, {
      bool rapidCool,
      bool frontDefrost,
      bool rearDefrost,
      bool airPurifier,
      int fanGear,
      int seatHeatDriver,
      int seatVentDriver,
      int seatHeatPass,
      int seatVentPass,
      bool steeringHeat,
    }) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClimateControlSheet(
        telemetry: telemetry,
        repository: repository,
        initialAcOn: initialAcOn,
        initialTempC: initialTempC,
        initialDurationMin: initialDurationMin,
        onApply: onApply,
      ),
    );
  }

  @override
  State<ClimateControlSheet> createState() => _ClimateControlSheetState();
}

class _ClimateControlSheetState extends State<ClimateControlSheet> {
  late bool _acOn;
  late double _targetTemp;
  late int _durationMin;

  bool _rapidCool = false;
  bool _quickWarm = false;
  bool _frontDefrost = false;
  bool _rearDefrost = false;
  bool _airPurifier = true;
  int _fanGear = 0; // 0 = Auto, 1..7

  int _seatHeatDriver = 0; // 0..3
  int _seatVentDriver = 0; // 0..3
  int _seatHeatPass = 0;   // 0..3
  int _seatVentPass = 0;   // 0..3
  bool _steeringHeat = false;

  // Advance Travel (Scheduled Departure / STARTUP_APPOINTMENT)
  bool _schedTravelEnabled = false;
  TimeOfDay _schedTravelTime = const TimeOfDay(hour: 8, minute: 0);
  List<bool> _schedTravelWeek = [false, true, true, true, true, true, false];
  bool _schedTravelSaving = false;

  double get _minTemp => widget.repository?.vehicleCapabilities.minAcTemp ?? 16.0;
  double get _maxTemp => widget.repository?.vehicleCapabilities.maxAcTemp ?? 32.0;

  @override
  void initState() {
    super.initState();
    _acOn = widget.initialAcOn;
    _targetTemp = widget.initialTempC.clamp(_minTemp, _maxTemp);
    _durationMin = widget.initialDurationMin;
    _rapidCool = widget.telemetry.rapidCool;
    _frontDefrost = widget.telemetry.frontDefrost;
    _rearDefrost = widget.telemetry.rearDefrost;
    _airPurifier = widget.telemetry.airPurifier;
    _fanGear = widget.telemetry.fanGear;
    _seatHeatDriver = widget.telemetry.seatHeatDriver;
    _seatVentDriver = widget.telemetry.seatVentDriver;
    _seatHeatPass = widget.telemetry.seatHeatPass;
    _seatVentPass = widget.telemetry.seatVentPass;
    _steeringHeat = widget.telemetry.steeringHeat;
    _loadScheduledTravel();
  }

  Future<void> _loadScheduledTravel() async {
    final repo = widget.repository;
    if (repo == null) return;
    try {
      final cfg = await repo.getTerminalNoticeConfig();
      if (!mounted || cfg.isEmpty) return;
      final extra = cfg['extraParsed'];
      setState(() {
        if (cfg.containsKey('startupAppointment')) {
          _schedTravelEnabled = cfg['startupAppointment'] == true;
        }
        if (extra is Map<String, dynamic>) {
          final h = int.tryParse(extra['hour']?.toString() ?? '') ?? _schedTravelTime.hour;
          final m = int.tryParse(extra['minute']?.toString() ?? '') ?? _schedTravelTime.minute;
          _schedTravelTime = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
          final wk = extra['week'];
          if (wk is List && wk.length == 7) {
            _schedTravelWeek = wk.map((e) => e == true || e == 1).toList();
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _saveScheduledTravel({bool? overrideEnabled}) async {
    final repo = widget.repository;
    if (repo == null) return;
    final nextEnabled = overrideEnabled ?? _schedTravelEnabled;
    setState(() {
      _schedTravelEnabled = nextEnabled;
      _schedTravelSaving = true;
    });
    final ok = await repo.setScheduledTravel(
      enabled: nextEnabled,
      hour: _schedTravelTime.hour,
      minute: _schedTravelTime.minute,
      week: _schedTravelWeek,
    );
    if (!mounted) return;
    setState(() => _schedTravelSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '🗓️ Scheduled Travel ${nextEnabled ? 'enabled for ${_schedTravelTime.format(context)}' : 'disabled'}'
              : '⚠️ Failed to update Scheduled Travel on CarLinko cloud',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _adjustTemp(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _targetTemp = (_targetTemp + delta).clamp(_minTemp, _maxTemp);
      _rapidCool = false;
      _quickWarm = false;
    });
  }

  void _applyChanges() {
    HapticFeedback.mediumImpact();
    widget.onApply(
      _acOn,
      _targetTemp,
      _durationMin,
      rapidCool: _rapidCool,
      frontDefrost: _frontDefrost,
      rearDefrost: _rearDefrost,
      airPurifier: _airPurifier,
      fanGear: _fanGear,
      seatHeatDriver: _seatHeatDriver,
      seatVentDriver: _seatVentDriver,
      seatHeatPass: _seatHeatPass,
      seatVentPass: _seatVentPass,
      steeringHeat: _steeringHeat,
    );
    Navigator.of(context).pop();
  }

  Widget _buildMiniToggle({
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: value
              ? activeColor
              : (isDark ? const Color(0xFF262C36) : const Color(0xFFCBD5E1)),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? Colors.black : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE611151F) : const Color(0xF2FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0x80FFFFFF),
                width: 1.2,
              ),
              left: BorderSide(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                width: 0.8,
              ),
              right: BorderSide(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Apple Pull Handle Pill
              Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x4DFFFFFF) : const Color(0x33000000),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _acOn
                            ? const Color(0xFFD2F835).withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.ac_unit,
                        size: 20,
                        color: _acOn ? const Color(0xFFD2F835) : colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Climate & Seat Comfort',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Chery CarLinko CAN-bus Telematics',
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                // Master Power Pill
                ApplePressable(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _acOn = !_acOn);
                  },
                  pressedScale: 0.93,
                  enableHaptics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _acOn
                          ? const Color(0xFFD2F835).withValues(alpha: 0.2)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _acOn ? const Color(0xFFD2F835) : colors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.power_settings_new,
                          size: 14,
                          color: _acOn ? const Color(0xFFD2F835) : colors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _acOn ? 'A/C ON' : 'A/C OFF',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _acOn ? const Color(0xFFD2F835) : colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colors.borderSubtle),

          // Scrollable Control Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                // 1. Digital Temperature Display with Minus / Plus
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'CABIN TARGET TEMPERATURE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Minus 0.5°C
                          _buildTempStepButton(
                            icon: Icons.remove,
                            enabled: _targetTemp > _minTemp,
                            onTap: () => _adjustTemp(-0.5),
                            colors: colors,
                          ),
                          const SizedBox(width: 24),

                          // Large Temperature Readout
                          Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _targetTemp.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      color: _acOn
                                          ? (_targetTemp < 22.0
                                              ? const Color(0xFFD2F835)
                                              : (_targetTemp > 25.0 ? const Color(0xFFFF6E40) : const Color(0xFFD2F835)))
                                          : colors.textMuted,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, left: 4),
                                    child: Text(
                                      '°C',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                !_acOn
                                    ? 'Climate is off -- turn on to apply'
                                    : (_targetTemp <= _minTemp
                                        ? 'MAX COOL (LO)'
                                        : (_targetTemp >= _maxTemp ? 'MAX HEAT (HI)' : 'Normal Dual-Zone Climate')),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 24),
                          // Plus 0.5°C
                          _buildTempStepButton(
                            icon: Icons.add,
                            enabled: _targetTemp < _maxTemp,
                            onTap: () => _adjustTemp(0.5),
                            colors: colors,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quick Preset Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [18.0, 20.0, 22.0, 24.0, 26.0].map((t) {
                          final isSelected = (_targetTemp - t).abs() < 0.2;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ApplePressable(
                              onTap: () {
                                setState(() {
                                  _targetTemp = t;
                                  _rapidCool = false;
                                  _quickWarm = false;
                                });
                              },
                              pressedScale: 0.92,
                              enableHaptics: true,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFD2F835)
                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFD2F835) : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  t == 18.0 ? 'LO' : '${t.toInt()}°C',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.black : colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Rapid Climate Modes & Defrosters (CarLinko Quick Actions)
                Text(
                  'RAPID MODES & DEFROST',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildToggleFeatureCard(
                      icon: Icons.ac_unit,
                      label: 'Rapid Cool',
                      active: _rapidCool,
                      activeColor: const Color(0xFFD2F835),
                      colors: colors,
                      onTap: () {
                        setState(() {
                          _rapidCool = !_rapidCool;
                          if (_rapidCool) {
                            _acOn = true;
                            _targetTemp = 18.0;
                            _fanGear = 7;
                            _quickWarm = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildToggleFeatureCard(
                      icon: Icons.whatshot,
                      label: 'Quick Warm',
                      active: _quickWarm,
                      activeColor: const Color(0xFFFF6E40),
                      colors: colors,
                      onTap: () {
                        setState(() {
                          _quickWarm = !_quickWarm;
                          if (_quickWarm) {
                            _acOn = true;
                            _targetTemp = 28.0;
                            _fanGear = 5;
                            _rapidCool = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildToggleFeatureCard(
                      icon: Icons.lens_blur,
                      label: 'Front Defrost',
                      active: _frontDefrost,
                      activeColor: const Color(0xFFD2F835),
                      colors: colors,
                      onTap: () => setState(() => _frontDefrost = !_frontDefrost),
                    ),
                    const SizedBox(width: 8),
                    _buildToggleFeatureCard(
                      icon: Icons.window,
                      label: 'Rear Heat',
                      active: _rearDefrost,
                      activeColor: const Color(0xFFFF6E40),
                      colors: colors,
                      onTap: () => setState(() => _rearDefrost = !_rearDefrost),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Pre-run Duration Selector (/user/device/manage/airDuration) - Bulletproof Responsive Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: const Color(0xFFD2F835)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Auto Shutoff Timer',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              'CAN-bus setting',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: colors.textMuted),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [5, 10, 15, 20].map((m) {
                            final isSel = _durationMin == m;
                            return Padding(
                              padding: const EdgeInsets.only(left: 3),
                              child: ApplePressable(
                                onTap: () => setState(() => _durationMin = m),
                                pressedScale: 0.92,
                                enableHaptics: true,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFFD2F835) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${m}m',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                      color: isSel ? Colors.black : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Blower / Fan Speed (AcGearControlStatusBean)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.air, size: 17, color: const Color(0xFFD2F835)),
                              const SizedBox(width: 8),
                              Text('Blower Fan Speed', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                            ],
                          ),
                          Text(
                            _fanGear == 0 ? 'AUTO' : 'GEAR $_fanGear / 7',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD2F835)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(8, (i) {
                          final isSel = _fanGear == i;
                          final label = i == 0 ? 'Auto' : '$i';
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ApplePressable(
                                onTap: () => setState(() => _fanGear = i),
                                pressedScale: 0.92,
                                enableHaptics: true,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFFD2F835) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                        color: isSel ? Colors.black : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Front Seat Comfort (Ventilation & Heating)
                Text(
                  'SEAT COMFORT (VENTILATION & HEATING)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: colors.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Driver Seat
                    Expanded(
                      child: _buildSeatControlCard(
                        title: 'Driver Seat',
                        ventLevel: _seatVentDriver,
                        heatLevel: _seatHeatDriver,
                        onVentChange: (v) => setState(() => _seatVentDriver = v),
                        onHeatChange: (h) => setState(() => _seatHeatDriver = h),
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Passenger Seat
                    Expanded(
                      child: _buildSeatControlCard(
                        title: 'Passenger Seat',
                        ventLevel: _seatVentPass,
                        heatLevel: _seatHeatPass,
                        onVentChange: (v) => setState(() => _seatVentPass = v),
                        onHeatChange: (h) => setState(() => _seatHeatPass = h),
                        colors: colors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 6. Air Purifier & Heated Steering Wheel
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.tileBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.filter_vintage_outlined, size: 15, color: Color(0xFFD2F835)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'PM2.5 Purifier',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildMiniToggle(
                              value: _airPurifier,
                              activeColor: const Color(0xFFD2F835),
                              onChanged: (v) => setState(() => _airPurifier = v),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.tileBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.radio_button_checked, size: 15, color: Color(0xFFFF6E40)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Heated Wheel',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildMiniToggle(
                              value: _steeringHeat,
                              activeColor: const Color(0xFFFF6E40),
                              onChanged: (v) => setState(() => _steeringHeat = v),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (widget.repository != null) ...[
                  _buildScheduledTravelCard(colors, isDark),
                  const SizedBox(height: 12),
                ],

                // 7. CAN-bus Pre-conditions Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B26) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.evTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 15, color: colors.evTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'T-Box Safety Checks: Gear in [P] • Doors Locked • HV SoC > 20%',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: colors.evTeal),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xE611151F) : Colors.white.withValues(alpha: 0.9),
              border: Border(top: BorderSide(color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ApplePressable(
                onTap: _applyChanges,
                pressedScale: 0.97,
                enableHaptics: true,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2F835),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD2F835).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 16, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        _acOn
                            ? 'TURN ON CLIMATE (${_targetTemp.toStringAsFixed(1)}°C)'
                            : 'TURN OFF CLIMATE',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildTempStepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return ApplePressable(
      onTap: enabled ? onTap : null,
      pressedScale: 0.90,
      enableHaptics: true,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? (colors.isDark ? const Color(0xFF1B2433) : const Color(0xFFE5E7EB))
              : (colors.isDark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 22,
            color: enabled ? colors.textPrimary : colors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleFeatureCard({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ApplePressable(
        onTap: onTap,
        pressedScale: 0.93,
        enableHaptics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: colors.isDark ? 0.2 : 0.15)
                : colors.tileBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? activeColor : colors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? activeColor : colors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.bold : FontWeight.w600,
                  color: active ? activeColor : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatControlCard({
    required String title,
    required int ventLevel,
    required int heatLevel,
    required ValueChanged<int> onVentChange,
    required ValueChanged<int> onHeatChange,
    required AppColors colors,
  }) {
    final isDark = colors.isDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.airline_seat_recline_extra_outlined, size: 15, color: colors.textPrimary),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),

          // Ventilation (Cooling)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cooling', style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
              Row(
                children: List.generate(4, (lvl) {
                  final isSel = ventLevel == lvl;
                  return Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: ApplePressable(
                      onTap: () => onVentChange(lvl),
                      pressedScale: 0.90,
                      enableHaptics: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFFD2F835)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lvl == 0 ? 'OFF' : '$lvl',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.black : colors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Heating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Heating', style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
              Row(
                children: List.generate(4, (lvl) {
                  final isSel = heatLevel == lvl;
                  return Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: ApplePressable(
                      onTap: () => onHeatChange(lvl),
                      pressedScale: 0.90,
                      enableHaptics: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFFFF6E40)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lvl == 0 ? 'OFF' : '$lvl',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.black : colors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledTravelCard(AppColors colors, bool isDark) {
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final timeLabel =
        '${_schedTravelTime.hour.toString().padLeft(2, '0')}:${_schedTravelTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _schedTravelEnabled
              ? const Color(0xFFD2F835).withValues(alpha: 0.45)
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_repeat_rounded,
                size: 16,
                color: _schedTravelEnabled ? const Color(0xFFD2F835) : colors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advance Travel (Scheduled Departure)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Pre-condition cabin automatically at $timeLabel',
                      style: TextStyle(fontSize: 10, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_schedTravelSaving)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _buildMiniToggle(
                  value: _schedTravelEnabled,
                  activeColor: const Color(0xFFD2F835),
                  onChanged: (v) => _saveScheduledTravel(overrideEnabled: v),
                  isDark: isDark,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _schedTravelTime,
                  );
                  if (picked != null && mounted) {
                    setState(() => _schedTravelTime = picked);
                    await _saveScheduledTravel();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (idx) {
                    final active = _schedTravelWeek[idx];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _schedTravelWeek[idx] = !active;
                        });
                        _saveScheduledTravel();
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? const Color(0xFFD2F835)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Text(
                          dayLabels[idx],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: active ? Colors.black : colors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
