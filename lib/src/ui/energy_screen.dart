import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../carlinko/vehicle_repository.dart';
import '../theme/app_tokens.dart';

/// Screen 3: ENERGY · HOME AC (Smart Home AC Charging Plan & TNB Optimizer)
class EnergyScreen extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final bool isCharging;
  final bool scheduledCharging;
  final double tnbTariff;
  final double fuelPrice;
  final VehicleRepository? repository;
  final ValueChanged<bool>? onToggleCharge;
  final Function(bool isScheduled, TimeOfDay startTime, TimeOfDay endTime, int targetSoc, double powerKw)? onSaveSchedule;

  const EnergyScreen({
    super.key,
    required this.telemetry,
    this.isCharging = false,
    this.scheduledCharging = true,
    this.tnbTariff = 0.28,
    this.fuelPrice = 2.05,
    this.repository,
    this.onToggleCharge,
    this.onSaveSchedule,
  });

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  int _targetSoc = 80; // 80% daily, 90% extended, 100% trip
  final double _powerKw = 3.3;

  // Tiggo 7 PHEV Battery Size in Malaysia
  static const double batteryCapacityKwh = 18.3;

  // Schedule parameters
  TimeOfDay _startTime = const TimeOfDay(hour: 22, minute: 0);
  int _durationMinutes = 360; // 6 hours
  String _repeatMode = 'Everyday';
  bool _isScheduledChargingEnabled = true;
  bool _reminderEnabled = false;

  @override
  void initState() {
    super.initState();
    _isScheduledChargingEnabled = widget.scheduledCharging;
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _targetSoc = prefs.getInt('tm_charge_target_soc') ?? 80;
      _reminderEnabled = prefs.getBool('tm_charge_reminder_enabled') ?? false;
      _isScheduledChargingEnabled = prefs.getBool('tm_charge_schedule_enabled') ?? widget.scheduledCharging;
      final hour = prefs.getInt('tm_charge_schedule_hour') ?? 22;
      final min = prefs.getInt('tm_charge_schedule_minute') ?? 0;
      _startTime = TimeOfDay(hour: hour, minute: min);
      _durationMinutes = prefs.getInt('tm_charge_schedule_duration_min') ?? 360;
      _repeatMode = prefs.getString('tm_charge_schedule_repeat') ?? 'Everyday';
    });

    final repo = widget.repository;
    if (repo != null) {
      try {
        final cfg = await repo.getTerminalNoticeConfig();
        if (!mounted || cfg.isEmpty) return;
        final cloudTarget = (cfg['targetSoc'] as num?)?.toInt();
        final sched = cfg['batteryScheduleParsed'];
        setState(() {
          if (cloudTarget != null && cloudTarget >= 50 && cloudTarget <= 100) {
            _targetSoc = cloudTarget;
          }
          if (sched is Map<String, dynamic>) {
            if (sched.containsKey('enabled')) {
              _isScheduledChargingEnabled = sched['enabled'] == true;
            }
            final h = (sched['hour'] as num?)?.toInt();
            final m = (sched['minute'] as num?)?.toInt();
            if (h != null && m != null) {
              _startTime = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
            }
            final durHours = (sched['duration'] as num?)?.toInt();
            if (durHours != null && durHours > 0) {
              _durationMinutes = durHours * 60;
            }
            final wk = sched['week'];
            if (wk is List && wk.length == 7) {
              final bools = wk.map((e) => e == true || e == 1).toList();
              if (bools.every((b) => b)) {
                _repeatMode = 'Everyday';
              } else if (!bools[0] && bools.sublist(1, 6).every((b) => b) && !bools[6]) {
                _repeatMode = 'Monday to Friday';
              } else if (bools[0] && bools.sublist(1, 6).every((b) => !b) && bools[6]) {
                _repeatMode = 'Saturday to Sunday';
              } else {
                _repeatMode = 'Once';
              }
            }
          }
        });
      } catch (e) {
        debugPrint('getTerminalNoticeConfig hydrate error: $e');
      }
    }
  }

  List<bool> _weekMaskForRepeat(String repeat) {
    final r = repeat.toLowerCase();
    if (r.contains('everyday') || r.contains('every day')) {
      return List<bool>.filled(7, true);
    }
    if (r.contains('monday') || r.contains('weekday')) {
      return [false, true, true, true, true, true, false];
    }
    if (r.contains('saturday') || r.contains('weekend')) {
      return [true, false, false, false, false, false, true];
    }
    return List<bool>.filled(7, false);
  }

  Future<void> _setTargetSoc(int soc) async {
    setState(() => _targetSoc = soc);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tm_charge_target_soc', soc);
    if (widget.repository != null) {
      await widget.repository!.setTargetSoc(soc);
    }
  }

  Future<void> _persistSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tm_charge_target_soc', _targetSoc);
    await prefs.setBool('tm_charge_reminder_enabled', _reminderEnabled);
    await prefs.setBool('tm_charge_schedule_enabled', _isScheduledChargingEnabled);
    await prefs.setInt('tm_charge_schedule_hour', _startTime.hour);
    await prefs.setInt('tm_charge_schedule_minute', _startTime.minute);
    await prefs.setInt('tm_charge_schedule_duration_min', _durationMinutes);
    await prefs.setString('tm_charge_schedule_repeat', _repeatMode);

    if (widget.repository != null) {
      try {
        await widget.repository!.setTargetSoc(_targetSoc);
        await widget.repository!.setBatterySchedule({
          'enabled': _isScheduledChargingEnabled,
          'hour': _startTime.hour,
          'minute': _startTime.minute,
          'duration': (_durationMinutes <= 0 ? 480 : _durationMinutes) ~/ 60,
          'week': _weekMaskForRepeat(_repeatMode),
        });
      } catch (e) {
        debugPrint('setBatterySchedule error: $e');
      }
    }
  }

  /// Null when the car has not reported a battery level.
  int? get currentSoc =>
      widget.telemetry.isBound || widget.telemetry.batteryPct > 0 ? widget.telemetry.batteryPct : null;

  double get addsKwh {
    final soc = currentSoc;
    if (soc == null) return 0.0;
    final deficit = math.max(0, _targetSoc - soc);
    return (deficit / 100.0) * batteryCapacityKwh;
  }

  double get chargingHours => addsKwh > 0 ? addsKwh / _powerKw : 0.0;

  // Calculations for cost comparison
  double get offPeakCost => addsKwh * 0.280; // TNB off-peak residential rate
  double get peakCost => addsKwh * 0.570;    // TNB peak block rate
  double get ron95Cost {
    final equivKm = (addsKwh / batteryCapacityKwh) * 90.0;
    final petrolLitres = (equivKm / 100.0) * 5.5;
    return petrolLitres * widget.fuelPrice;
  }

  String get doneTimeStr {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final durationMinutes = (chargingHours * 60).round();
    final totalMinutes = (startMinutes + durationMinutes) % (24 * 60);
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDuration(int minutes) {
    if (minutes <= 0) return 'Until target SoC';
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h h $m min';
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.tokens.accent,
            surface: const Color(0xFF131722),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
      await _persistSettings();
    }
  }

  Future<void> _pickDuration() async {
    final durations = [
      {'label': 'Until target SoC (${_targetSoc}%)', 'min': 0},
      {'label': '02 h 00 min', 'min': 120},
      {'label': '04 h 00 min', 'min': 240},
      {'label': '06 h 00 min', 'min': 360},
      {'label': '08 h 00 min', 'min': 480},
    ];

    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.tokens.resolvedContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CHARGING DURATION',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: context.tokens.accent,
                ),
              ),
              const SizedBox(height: 12),
              ...durations.map((d) {
                final isSelected = _durationMinutes == d['min'];
                return ListTile(
                  title: Text(
                    d['label'] as String,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: isSelected ? context.tokens.accent : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: context.tokens.accent, size: 18)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(d['min'] as int),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (chosen != null) {
      setState(() => _durationMinutes = chosen);
      await _persistSettings();
    }
  }

  Future<void> _pickRepeat() async {
    final repeats = ['Everyday', 'Monday to Friday', 'Saturday to Sunday', 'Once'];

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.tokens.resolvedContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'REPEAT SCHEDULE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: context.tokens.accent,
                ),
              ),
              const SizedBox(height: 12),
              ...repeats.map((r) {
                final isSelected = _repeatMode == r;
                return ListTile(
                  title: Text(
                    r,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: isSelected ? context.tokens.accent : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: context.tokens.accent, size: 18)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(r),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (chosen != null) {
      setState(() => _repeatMode = chosen);
      await _persistSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = context.tokens;
    final bgCol = t.bg;
    final cardCol = t.resolvedContainerLow;
    final borderCol = t.border;
    final textMuted = t.ink2;
    final textPrimary = t.ink;
    final limeAccent = t.accent;
    const orangeAccent = Color(0xFFFF6E40);

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Row with Back Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: cardCol,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderCol),
                          ),
                          child: Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ENERGY · HOME AC',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Charge plan',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderCol),
                    ),
                    child: Text(
                      widget.telemetry.chargePowerKw > 0
                          ? 'CHARGING ${widget.telemetry.chargePowerKw.toStringAsFixed(1)} kW'
                          : (widget.isCharging ? 'CHARGING 3.3 kW' : 'PLUGGED · IDLE'),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: widget.isCharging ? limeAccent : textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1.5 Chery PHEV Dual-Power Range Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.electric_bolt, size: 12, color: limeAccent),
                              const SizedBox(width: 4),
                              Text(
                                'EV ${widget.telemetry.electricRangeKm} km',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: limeAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '19.27 kWh LFP',
                            style: TextStyle(fontSize: 10, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: borderCol),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_gas_station, size: 12, color: Color(0xFFFF9F1C)),
                                const SizedBox(width: 4),
                                Text(
                                  'Fuel ${widget.telemetry.fuelRangeKm} km',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF9F1C),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '60L Tank • Hybrid',
                              style: TextStyle(fontSize: 10, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 28, color: borderCol),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${widget.telemetry.totalRangeKm} km',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'TOTAL RANGE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Big SoC Display & Target
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                      children: [
                        TextSpan(text: '${currentSoc ?? '--'}'),
                        TextSpan(
                          text: '%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '→ $_targetSoc% target',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: limeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 3. Hatched Charging Progress Bar
              CustomPaint(
                size: const Size(double.infinity, 32),
                painter: _HatchedChargeBarPainter(
                  currentPct: (currentSoc ?? 0) / 100.0,
                  targetPct: _targetSoc / 100.0,
                  accentColor: limeAccent,
                  trackColor: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0),
                  borderColor: borderCol,
                ),
              ),
              const SizedBox(height: 6),

              // Scale ticks: 0, 25, 50, 75, 100
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _TickText('0'),
                  _TickText('25'),
                  _TickText('50'),
                  _TickText('75'),
                  _TickText('100'),
                ],
              ),
              const SizedBox(height: 18),

              // 4. Target Preset Buttons (80% daily, 90% extended, 100% trip)
              Row(
                children: [
                  Expanded(
                    child: _PresetPill(
                      label: '80% daily',
                      isSelected: _targetSoc == 80,
                      accentColor: limeAccent,
                      cardCol: cardCol,
                      borderCol: borderCol,
                      textMuted: textMuted,
                      textPrimary: textPrimary,
                      onTap: () => _setTargetSoc(80),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PresetPill(
                      label: '90% extended',
                      isSelected: _targetSoc == 90,
                      accentColor: limeAccent,
                      cardCol: cardCol,
                      borderCol: borderCol,
                      textMuted: textMuted,
                      textPrimary: textPrimary,
                      onTap: () => _setTargetSoc(90),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PresetPill(
                      label: '100% trip',
                      isSelected: _targetSoc == 100,
                      accentColor: limeAccent,
                      cardCol: cardCol,
                      borderCol: borderCol,
                      textMuted: textMuted,
                      textPrimary: textPrimary,
                      onTap: () => _setTargetSoc(100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. 24-Hour Timeline Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TONIGHT · 24 H',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                  Text(
                    'off-peak 22:00–08:00',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Visual 24-Hour Timeline Bar Canvas
              CustomPaint(
                size: const Size(double.infinity, 44),
                painter: _Timeline24hPainter(
                  accentColor: limeAccent,
                  isDark: isDark,
                  offPeakStart: 22.0,
                  offPeakEnd: 8.0,
                  chargingStart: _startTime.hour + _startTime.minute / 60.0,
                  chargingDurationHours: chargingHours,
                ),
              ),
              const SizedBox(height: 6),

              // Timeline Hour Labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _TickText('12:00'),
                  _TickText('18:00'),
                  _TickText('00:00'),
                  _TickText('06:00'),
                  _TickText('12:00'),
                ],
              ),
              const SizedBox(height: 18),

              // 6. Metrics Row: START (TAPPABLE TO EDIT) | DONE | ADDS
              Container(
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    // START (Tappable with edit icon)
                    Expanded(
                      child: InkWell(
                        onTap: _pickStartTime,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('START', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: textMuted)),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit_outlined, size: 10, color: limeAccent),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatTime(_startTime),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: limeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 40, color: borderCol),
                    // DONE
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DONE', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: textMuted)),
                            const SizedBox(height: 3),
                            Text(currentSoc == null ? '--:--' : doneTimeStr, style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 40, color: borderCol),
                    // ADDS
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ADDS', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: textMuted)),
                            const SizedBox(height: 3),
                            Text(currentSoc == null ? '-- kWh' : '${addsKwh.toStringAsFixed(1)} kWh', style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 7. Interactive Charging Schedule & Settings Card
              Container(
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  children: [
                    // Row 1: Scheduled charging toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 16, color: limeAccent),
                              const SizedBox(width: 8),
                              Text(
                                'Scheduled charging',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isScheduledChargingEnabled,
                            activeColor: limeAccent,
                            onChanged: (val) {
                              setState(() => _isScheduledChargingEnabled = val);
                              _persistSettings();
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: borderCol),
                    // Row 2: Time, Duration & Repeat Pickers
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          // Time chip
                          Expanded(
                            child: InkWell(
                              onTap: _pickStartTime,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF161A24) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderCol),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TIME', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTime(_startTime),
                                      style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Duration chip
                          Expanded(
                            child: InkWell(
                              onTap: _pickDuration,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF161A24) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderCol),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('DURATION', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDuration(_durationMinutes),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Repeat chip
                          Expanded(
                            child: InkWell(
                              onTap: _pickRepeat,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF161A24) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderCol),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('REPEAT', style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _repeatMode,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: borderCol),
                    // Row 3: Overstay Reminder switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Charger Occupancy Reminder',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                              Text(
                                'Alert hourly if vehicle stays plugged after 100%',
                                style: TextStyle(fontSize: 10, color: textMuted),
                              ),
                            ],
                          ),
                          Switch(
                            value: _reminderEnabled,
                            activeColor: limeAccent,
                            onChanged: (val) {
                              setState(() => _reminderEnabled = val);
                              _persistSettings();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 8. Cost of this charge section
              Text(
                'COST OF THIS CHARGE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 12),

              // Off-peak row
              _CostBarRow(
                label: 'Off-peak',
                amount: currentSoc == null ? 'RM --' : 'RM ${offPeakCost.toStringAsFixed(2)}',
                barFactor: 0.45,
                barColor: limeAccent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                trackColor: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 10),

              // Peak row
              _CostBarRow(
                label: 'Peak',
                amount: currentSoc == null ? 'RM --' : 'RM ${peakCost.toStringAsFixed(2)}',
                barFactor: 0.85,
                barColor: isDark ? const Color(0xFF333B4A) : const Color(0xFF94A3B8),
                textPrimary: textPrimary,
                textMuted: textMuted,
                trackColor: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 10),

              // RON95 equiv row
              _CostBarRow(
                label: 'RON95 equiv.',
                amount: currentSoc == null ? 'RM --' : 'RM ${ron95Cost.toStringAsFixed(2)}',
                barFactor: 0.90,
                barColor: orangeAccent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                trackColor: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 8),

              Text(
                '3.3 kW wallbox · TNB RM 0.280/kWh off-peak',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 28),

              // 9. Dual Action Buttons: [ Charge now ] and [ Schedule for XX:XX ]
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onToggleCharge?.call(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Immediate AC charge started.')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderCol),
                        backgroundColor: cardCol,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Charge now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() => _isScheduledChargingEnabled = true);
                        await _persistSettings();
                        widget.onSaveSchedule?.call(
                          true,
                          _startTime,
                          const TimeOfDay(hour: 8, minute: 0),
                          _targetSoc,
                          _powerKw,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF131722),
                              content: Text(
                                'Smart Schedule set for ${_formatTime(_startTime)} ($_repeatMode, target $_targetSoc%)',
                                style: TextStyle(color: limeAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: limeAccent,
                        foregroundColor: const Color(0xFF0A0B0E),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Schedule for ${_formatTime(_startTime)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A0B0E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TickText extends StatelessWidget {
  final String text;
  const _TickText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF717684) : const Color(0xFF64748B),
      ),
    );
  }
}

class _PresetPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final Color cardCol;
  final Color borderCol;
  final Color textMuted;
  final Color textPrimary;
  final VoidCallback onTap;

  const _PresetPill({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.cardCol,
    required this.borderCol,
    required this.textMuted,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : borderCol,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? accentColor : textMuted,
          ),
        ),
      ),
    );
  }
}

class _CostBarRow extends StatelessWidget {
  final String label;
  final String amount;
  final double barFactor;
  final Color barColor;
  final Color textPrimary;
  final Color textMuted;
  final Color trackColor;

  const _CostBarRow({
    required this.label,
    required this.amount,
    required this.barFactor,
    required this.barColor,
    required this.textPrimary,
    required this.textMuted,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: textPrimary),
          ),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: barFactor.clamp(0.05, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 65,
          child: Text(
            amount,
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
          ),
        ),
      ],
    );
  }
}

class _HatchedChargeBarPainter extends CustomPainter {
  final double currentPct;
  final double targetPct;
  final Color accentColor;
  final Color trackColor;
  final Color borderColor;

  _HatchedChargeBarPainter({
    required this.currentPct,
    required this.targetPct,
    required this.accentColor,
    required this.trackColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(6),
    );

    // Track
    final trackPaint = Paint()..color = trackColor;
    canvas.drawRRect(rrect, trackPaint);

    final currentW = size.width * currentPct.clamp(0.0, 1.0);
    final targetW = size.width * targetPct.clamp(0.0, 1.0);

    // Solid filled current charge
    if (currentW > 0) {
      final solidRect = Rect.fromLTWH(0, 0, currentW, size.height);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(solidRect, Paint()..color = accentColor);
      canvas.restore();
    }

    // Hatched pattern from currentW to targetW
    if (targetW > currentW) {
      final hatchRect = Rect.fromLTWH(currentW, 0, targetW - currentW, size.height);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.clipRect(hatchRect);

      // Darker backdrop for hatched section
      canvas.drawRect(hatchRect, Paint()..color = accentColor.withValues(alpha: 0.15));

      // Diagonal lines
      final linePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.45)
        ..strokeWidth = 2.0;

      const spacing = 8.0;
      for (double x = currentW - size.height; x < targetW + size.height; x += spacing) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          linePaint,
        );
      }
      canvas.restore();
    }

    // Vertical line tick at target
    if (targetW > 0 && targetW < size.width) {
      final tickPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(targetW, 0), Offset(targetW, size.height), tickPaint);
    }

    // Border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HatchedChargeBarPainter oldDelegate) {
    return oldDelegate.currentPct != currentPct ||
        oldDelegate.targetPct != targetPct ||
        oldDelegate.accentColor != accentColor;
  }
}

class _Timeline24hPainter extends CustomPainter {
  final Color accentColor;
  final bool isDark;
  final double offPeakStart;
  final double offPeakEnd;
  final double chargingStart;
  final double chargingDurationHours;

  _Timeline24hPainter({
    required this.accentColor,
    required this.isDark,
    required this.offPeakStart,
    required this.offPeakEnd,
    required this.chargingStart,
    required this.chargingDurationHours,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackCol = isDark ? const Color(0xFF141720) : const Color(0xFFE2E8F0);
    final offPeakCol = isDark ? const Color(0xFF1C2230) : const Color(0xFFCBD5E1);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 10, size.width, size.height - 10),
      const Radius.circular(6),
    );
    canvas.drawRRect(rrect, Paint()..color = trackCol);

    canvas.save();
    canvas.clipRRect(rrect);

    // Timeline spans from 12:00 noon (0.0) to next day 12:00 noon (24.0)
    // 22:00 is 10 hours from 12:00 (fraction = 10 / 24)
    // 08:00 is 20 hours from 12:00 (fraction = 20 / 24)
    final offPeakX1 = size.width * (10.0 / 24.0);
    final offPeakX2 = size.width * (20.0 / 24.0);

    // Draw shaded off-peak block
    canvas.drawRect(
      Rect.fromLTWH(offPeakX1, 10, offPeakX2 - offPeakX1, size.height - 10),
      Paint()..color = offPeakCol,
    );

    // Draw charging duration block in lime starting from chargingStart
    // Hours from 12:00
    double startHoursFrom12 = chargingStart - 12.0;
    if (startHoursFrom12 < 0) startHoursFrom12 += 24.0;
    final startX = size.width * (startHoursFrom12 / 24.0);
    final chargeDurationFraction = chargingDurationHours / 24.0;
    final chargeW = size.width * chargeDurationFraction;

    canvas.drawRect(
      Rect.fromLTWH(startX, 10, chargeW, size.height - 10),
      Paint()..color = accentColor,
    );
    canvas.restore();

    // NOW indicator at top of bar (around current local hour from 12:00)
    final now = DateTime.now();
    double nowHoursFrom12 = (now.hour + now.minute / 60.0) - 12.0;
    if (nowHoursFrom12 < 0) nowHoursFrom12 += 24.0;
    final nowX = size.width * (nowHoursFrom12 / 24.0);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'NOW',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(nowX - textPainter.width / 2, 0));

    // Vertical line under NOW
    canvas.drawLine(
      Offset(nowX, 10),
      Offset(nowX, size.height),
      Paint()
        ..color = isDark ? Colors.white54 : Colors.black45
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _Timeline24hPainter oldDelegate) {
    return true;
  }
}
