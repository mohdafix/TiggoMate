import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../carlinko/vehicle_telemetry.dart';

/// Full-featured Climate & Seat Comfort Control Sheet
/// Ported from official Chery CarLinko CAN-bus and T-Box control protocols.
class ClimateControlSheet extends StatefulWidget {
  final VehicleTelemetry telemetry;
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
    required this.initialAcOn,
    required this.initialTempC,
    required this.initialDurationMin,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTelemetry telemetry,
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

  @override
  void initState() {
    super.initState();
    _acOn = widget.initialAcOn;
    _targetTemp = widget.initialTempC.clamp(18.0, 32.0);
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
  }

  void _adjustTemp(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _targetTemp = (_targetTemp + delta).clamp(18.0, 32.0);
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12141A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(
          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),

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
                InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _acOn = !_acOn);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _acOn
                          ? const Color(0xFFD2F835).withValues(alpha: 0.2)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(6),
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
                            enabled: _targetTemp > 18.0,
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
                                          : colors.textPrimary,
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
                                _targetTemp <= 18.0
                                    ? 'MAX COOL (LO)'
                                    : (_targetTemp >= 32.0 ? 'MAX HEAT (HI)' : 'Normal Dual-Zone Climate'),
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
                            enabled: _targetTemp < 32.0,
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
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _targetTemp = t;
                                  _rapidCool = false;
                                  _quickWarm = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFD2F835)
                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                  borderRadius: BorderRadius.circular(6),
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
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _durationMin = m);
                                },
                                borderRadius: BorderRadius.circular(6),
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
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _fanGear = i);
                                },
                                borderRadius: BorderRadius.circular(6),
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
              color: isDark ? const Color(0xFF12141A) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _applyChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD2F835),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.send_rounded, size: 16, color: Colors.black),
                label: Text(
                  _acOn
                      ? 'TRANSMIT CLIMATE (${_targetTemp.toStringAsFixed(1)}°C · ${_durationMin}M)'
                      : 'TRANSMIT CLIMATE SHUTDOWN',
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
          ),
        ],
      ),
    );
  }

  Widget _buildTempStepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
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
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
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
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onVentChange(lvl);
                      },
                      borderRadius: BorderRadius.circular(6),
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
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onHeatChange(lvl);
                      },
                      borderRadius: BorderRadius.circular(6),
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
}
