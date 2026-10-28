import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../mytnb/mytnb_api.dart';
import '../theme/app_theme.dart';

/// Phase 2: Smart Charging & TNB Cost Optimizer Sheet for Chery Tiggo 7 PHEV
/// Features:
/// - Target SoC limit slider (80% battery saver to 100% roadtrip)
/// - TNB Time-of-Use (ToU) Off-Peak scheduler (10:00 PM – 08:00 AM)
/// - Real-time marginal TNB cost vs RON95 petrol savings calculator
/// - Live AC charging curve canvas (3.3 kW / 6.6 kW / 2.2 kW)
/// - Battery State of Health (SOH) and degradation advisor
class SmartChargingSheet extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final bool isCharging;
  final bool scheduledCharging;
  final ValueChanged<bool> onToggleCharge;
  final Function(bool isScheduled, TimeOfDay startTime, TimeOfDay endTime, int targetSoc, double powerKw) onSaveSchedule;

  const SmartChargingSheet({
    super.key,
    required this.telemetry,
    required this.isCharging,
    required this.scheduledCharging,
    required this.onToggleCharge,
    required this.onSaveSchedule,
  });

  static Future<void> show(
    BuildContext context, {
    required VehicleTelemetry telemetry,
    required bool isCharging,
    required bool scheduledCharging,
    required ValueChanged<bool> onToggleCharge,
    required Function(bool isScheduled, TimeOfDay startTime, TimeOfDay endTime, int targetSoc, double powerKw) onSaveSchedule,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1219) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SmartChargingSheet(
        telemetry: telemetry,
        isCharging: isCharging,
        scheduledCharging: scheduledCharging,
        onToggleCharge: onToggleCharge,
        onSaveSchedule: onSaveSchedule,
      ),
    );
  }

  @override
  State<SmartChargingSheet> createState() => _SmartChargingSheetState();
}

class _SmartChargingSheetState extends State<SmartChargingSheet> {
  // Configurable settings
  late double _targetSoc;
  late bool _isScheduled;
  TimeOfDay _startTime = const TimeOfDay(hour: 22, minute: 0); // 10:00 PM (TNB Off-Peak start)
  TimeOfDay _endTime = const TimeOfDay(hour: 6, minute: 0);   // 06:00 AM
  double _selectedPowerKw = 3.3; // Default Tiggo 7 PHEV OBC speed (16A 3.3 kW)
  int _activeTab = 0; // 0: Optimizer & Schedule, 1: Power Curve & SOH, 2: Tariff Breakdown

  // Constants for Tiggo 7 PHEV
  static const double batteryCapacityKwh = 19.27; // Chery Tiggo 7 PHEV battery size
  static const double pureEvRangeKm = 95.0;       // Rated pure EV range
  static const double petrolLitersPer100Km = 5.5; // Equivalent hybrid petrol consumption
  static const double ron95PricePerLiter = 2.05;  // Malaysian standard subsidized RON95

  @override
  void initState() {
    super.initState();
    _targetSoc = 80.0; // Default optimal 80% daily charge limit
    _isScheduled = widget.scheduledCharging;
  }

  // Energy needed to reach target SoC from current SoC
  double get _currentKwh => batteryCapacityKwh * (widget.telemetry.batteryPct / 100.0);
  double get _targetKwh => batteryCapacityKwh * (_targetSoc / 100.0);
  double get _energyNeededKwh => math.max(0.0, _targetKwh - _currentKwh);

  // Estimated charging duration in hours
  double get _chargingDurationHours => _energyNeededKwh > 0 ? _energyNeededKwh / _selectedPowerKw : 0.0;

  // Costs
  double get _offPeakCost => TnbTariffCalculator.calculatePhevChargeCost(
        phevKwh: _energyNeededKwh,
        isOffPeak: true,
      );

  double get _normalPeakCost => TnbTariffCalculator.calculatePhevChargeCost(
        phevKwh: _energyNeededKwh,
        isOffPeak: false,
      );

  // Equivalent petrol cost to cover the same EV range added
  double get _petrolEquivalentCost {
    final rangeAddedKm = (_energyNeededKwh / batteryCapacityKwh) * pureEvRangeKm;
    final litersNeeded = (rangeAddedKm / 100.0) * petrolLitersPer100Km;
    return litersNeeded * ron95PricePerLiter;
  }

  // Savings
  double get _savingsVsPetrol => math.max(0.0, _petrolEquivalentCost - _offPeakCost);
  double get _savingsVsPeakTnb => math.max(0.0, _normalPeakCost - _offPeakCost);

  String _formatDuration(double hours) {
    if (hours <= 0.05) return 'Full / Reached';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'SELECT OFF-PEAK START TIME' : 'SELECT OFF-PEAK END TIME',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.90),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: colors.isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
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
                        color: colors.evTeal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bolt, color: colors.evTeal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Charging & TNB Optimizer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: widget.isCharging ? colors.evTeal : colors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isCharging
                                  ? 'Active Charging (${_selectedPowerKw.toStringAsFixed(1)} kW AC)'
                                  : (_isScheduled ? 'Scheduled (10:00 PM Off-Peak)' : 'Standby / Plugged In'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: widget.isCharging ? colors.evTeal : colors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colors.tileBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, 'Optimizer & Limit', Icons.tune, colors),
                  _buildTabButton(1, 'Power Curve & SOH', Icons.show_chart, colors),
                  _buildTabButton(2, 'TNB Tariff', Icons.receipt_long, colors),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _activeTab == 0
                  ? _buildOptimizerTab(colors)
                  : (_activeTab == 1 ? _buildPowerCurveTab(colors) : _buildTariffBreakdownTab(colors)),
            ),
          ),

          // Bottom Action Deck
          _buildBottomActionDeck(colors),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon, dynamic colors) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (colors.isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? colors.evTeal : colors.textMuted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 1. OPTIMIZER & LIMIT TAB ----------------
  Widget _buildOptimizerTab(dynamic colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target SoC Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(20),
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
                      Icon(Icons.battery_charging_full, size: 18, color: colors.evTeal),
                      const SizedBox(width: 8),
                      Text(
                        'Target Charge Limit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.evTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_targetSoc.round()}% SoC',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.evTeal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Visual Gauge / Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: colors.evTeal,
                  inactiveTrackColor: colors.border,
                  thumbColor: colors.evTeal,
                  overlayColor: colors.evTeal.withValues(alpha: 0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: _targetSoc,
                  min: 50.0,
                  max: 100.0,
                  divisions: 10,
                  label: '${_targetSoc.round()}%',
                  onChanged: (val) {
                    setState(() => _targetSoc = val);
                  },
                ),
              ),

              // Quick Preset Chips
              Row(
                children: [
                  _buildSocPresetChip(80, '80% (Daily Saver)', Icons.verified, colors),
                  const SizedBox(width: 8),
                  _buildSocPresetChip(90, '90% (Extended)', Icons.battery_std, colors),
                  const SizedBox(width: 8),
                  _buildSocPresetChip(100, '100% (Roadtrip)', Icons.directions_car, colors),
                ],
              ),
              const SizedBox(height: 14),

              // Telemetry Summary Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CURRENT BATTERY', style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${widget.telemetry.batteryPct}% (${_currentKwh.toStringAsFixed(1)} kWh)',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 26, color: colors.border),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ENERGY TO ADD', style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('+${_energyNeededKwh.toStringAsFixed(1)} kWh',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.evTeal)),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 26, color: colors.border),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('EST. DURATION', style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(_formatDuration(_chargingDurationHours),
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // TNB Off-Peak Scheduler Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(20),
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
                      Icon(Icons.schedule, size: 18, color: colors.evTeal),
                      const SizedBox(width: 8),
                      Text(
                        'TNB Off-Peak Scheduler',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isScheduled,
                    activeThumbColor: colors.evTeal,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setState(() => _isScheduled = val);
                    },
                  ),
                ],
              ),
              Text(
                'Automatically delay charging to TNB off-peak hours (10:00 PM – 08:00 AM) to cut charging costs by over 50%.',
                style: TextStyle(fontSize: 11.5, color: colors.textMuted, height: 1.35),
              ),
              const SizedBox(height: 14),

              // Time Range Selectors
              Row(
                children: [
                  Expanded(
                    child: _buildTimePickerTile(
                      label: 'START CHARGING',
                      time: _startTime,
                      enabled: _isScheduled,
                      onTap: () => _pickTime(isStart: true),
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward, size: 16, color: colors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTimePickerTile(
                      label: 'STOP CHARGING',
                      time: _endTime,
                      enabled: _isScheduled,
                      onTap: () => _pickTime(isStart: false),
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AC Charging Speed / Wallbox Selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AC Charging Power / Charger Rate',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildPowerSelectorCard(
                    powerKw: 2.2,
                    name: '3-Pin Portable',
                    amps: '10A ~2.2 kW',
                    colors: colors,
                  ),
                  const SizedBox(width: 8),
                  _buildPowerSelectorCard(
                    powerKw: 3.3,
                    name: 'Home Wallbox',
                    amps: '16A ~3.3 kW (Std)',
                    colors: colors,
                  ),
                  const SizedBox(width: 8),
                  _buildPowerSelectorCard(
                    powerKw: 6.6,
                    name: 'Fast AC Station',
                    amps: '32A ~6.6 kW',
                    colors: colors,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cost & Petrol Savings Callout Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.evTeal.withValues(alpha: 0.16),
                colors.evTeal.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.evTeal.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.evTeal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.savings, color: colors.evTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Cost: RM ${_offPeakCost.toStringAsFixed(2)} (Off-Peak)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Saves RM ${_savingsVsPetrol.toStringAsFixed(2)} vs RON95 Petrol • RM ${_savingsVsPeakTnb.toStringAsFixed(2)} vs Daytime Peak',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.evTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocPresetChip(int soc, String label, IconData icon, dynamic colors) {
    final isSelected = (_targetSoc.round() == soc);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _targetSoc = soc.toDouble());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.evTeal.withValues(alpha: 0.15) : colors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? colors.evTeal : colors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 14, color: isSelected ? colors.evTeal : colors.textMuted),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? colors.evTeal : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay time,
    required bool enabled,
    required VoidCallback onTap,
    required dynamic colors,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: enabled ? colors.evTeal : colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  _formatTimeOfDay(time),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: enabled ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerSelectorCard({
    required double powerKw,
    required String name,
    required String amps,
    required dynamic colors,
  }) {
    final isSelected = (_selectedPowerKw == powerKw);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPowerKw = powerKw);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.evTeal.withValues(alpha: 0.15) : colors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.evTeal : colors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? colors.evTeal : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                amps,
                style: TextStyle(
                  fontSize: 9.5,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 2. POWER CURVE & SOH TAB ----------------
  Widget _buildPowerCurveTab(dynamic colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Power Curve Canvas Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PHEV AC Charging Curve',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_selectedPowerKw.toStringAsFixed(1)} kW Max',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.evTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Constant Current (CC) stage tapering smoothly into Constant Voltage (CV) saturation above 90% SoC.',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
              const SizedBox(height: 16),

              // Visual Graph Canvas
              Container(
                height: 160,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: CustomPaint(
                  painter: _ChargingCurvePainter(
                    startSoc: widget.telemetry.batteryPct.toDouble(),
                    targetSoc: _targetSoc,
                    evTeal: colors.evTeal,
                    gridColor: colors.border,
                    textColor: colors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Start: ${widget.telemetry.batteryPct}% SoC',
                      style: TextStyle(fontSize: 10.5, color: colors.textMuted)),
                  Text('Target: ${_targetSoc.round()}% SoC (Est. ${_formatDuration(_chargingDurationHours)})',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.evTeal)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CATL Battery Health & Degradation Monitor Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.health_and_safety, size: 18, color: colors.evTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Battery Health & Diagnostics (SOH)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.evTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Grade A+',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.evTeal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4 Metrics Grid
              Row(
                children: [
                  _buildHealthMetricTile('STATE OF HEALTH', '99.2%', 'Optimal', colors.evTeal, colors),
                  const SizedBox(width: 10),
                  _buildHealthMetricTile('PACK TEMP', '28.4°C', 'Ideal (20-35°C)', colors.evTeal, colors),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildHealthMetricTile('CYCLE COUNT', '142', 'Est. ~1,500 Full', colors.textPrimary, colors),
                  const SizedBox(width: 10),
                  _buildHealthMetricTile('PACK VOLTAGE', '352.4 V', 'Balanced Cells', colors.textPrimary, colors),
                ],
              ),
              const SizedBox(height: 14),

              // Health Tip Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates, size: 16, color: colors.evTeal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Limiting daily charging to 80% SoC reduces lithium dendritic plating and extends pack lifespan by over 2.4x. Reserve 100% charging for road trips.',
                        style: TextStyle(fontSize: 11.5, color: colors.textSecondary, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMetricTile(String label, String value, String subtitle, Color valColor, dynamic colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valColor)),
            const SizedBox(height: 1),
            Text(subtitle, style: TextStyle(fontSize: 10, color: colors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ---------------- 3. TARIFF BREAKDOWN TAB ----------------
  Widget _buildTariffBreakdownTab(dynamic colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Malaysia Tariff Matrix
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TNB Domestic Tariff A (Malaysia)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Energy cost comparison for charging ${_energyNeededKwh.toStringAsFixed(1)} kWh into your Chery Tiggo 7 PHEV.',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
              const SizedBox(height: 14),

              // Rate 1: TNB Off-Peak
              _buildTariffRow(
                title: 'TNB EV Off-Peak (10 PM – 8 AM)',
                rate: 'RM 0.280 / kWh',
                totalCost: 'RM ${_offPeakCost.toStringAsFixed(2)}',
                isBest: true,
                colors: colors,
              ),
              const SizedBox(height: 8),

              // Rate 2: TNB Standard Tier (Marginal)
              _buildTariffRow(
                title: 'TNB Daytime Peak (Tier 5)',
                rate: 'RM 0.571 / kWh',
                totalCost: 'RM ${_normalPeakCost.toStringAsFixed(2)}',
                isBest: false,
                colors: colors,
              ),
              const SizedBox(height: 8),

              // Rate 3: Subsidized RON95 Petrol Equivalent
              _buildTariffRow(
                title: 'RON95 Petrol Equivalent',
                rate: 'RM 2.05 / Liter',
                totalCost: 'RM ${_petrolEquivalentCost.toStringAsFixed(2)}',
                isBest: false,
                isPetrol: true,
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tariff Schedule Reference Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.tileBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Official TNB Domestic Tiers',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              _buildTierItem('1 – 200 kWh', 'RM 0.218 / kWh', colors),
              _buildTierItem('201 – 300 kWh', 'RM 0.334 / kWh', colors),
              _buildTierItem('301 – 600 kWh', 'RM 0.516 / kWh', colors),
              _buildTierItem('601 – 900 kWh', 'RM 0.546 / kWh', colors),
              _buildTierItem('> 900 kWh', 'RM 0.571 / kWh', colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTariffRow({
    required String title,
    required String rate,
    required String totalCost,
    required bool isBest,
    bool isPetrol = false,
    required dynamic colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isBest ? colors.evTeal.withValues(alpha: 0.12) : colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBest ? colors.evTeal : colors.border,
          width: isBest ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isPetrol ? Icons.local_gas_station : (isBest ? Icons.stars : Icons.bolt),
                  size: 16,
                  color: isPetrol ? const Color(0xFFF59E0B) : (isBest ? colors.evTeal : colors.textMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (isBest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: colors.evTeal,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'BEST',
                                style: TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(rate, style: TextStyle(fontSize: 10, color: colors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            totalCost,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isBest ? colors.evTeal : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierItem(String range, String rate, dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(range, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          Text(rate, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        ],
      ),
    );
  }

  // ---------------- BOTTOM ACTION DECK ----------------
  Widget _buildBottomActionDeck(dynamic colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Instant Start / Stop Charge Button
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onToggleCharge(!widget.isCharging);
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: widget.isCharging ? Colors.redAccent : colors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: Icon(
                  widget.isCharging ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  size: 16,
                  color: widget.isCharging ? Colors.redAccent : colors.textPrimary,
                ),
                label: Text(
                  widget.isCharging ? 'Stop Now' : 'Charge Now',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: widget.isCharging ? Colors.redAccent : colors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Save Schedule Button
            Expanded(
              flex: 5,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  widget.onSaveSchedule(
                    _isScheduled,
                    _startTime,
                    _endTime,
                    _targetSoc.round(),
                    _selectedPowerKw,
                  );
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.isDark ? Colors.white : const Color(0xFF111827),
                  foregroundColor: colors.isDark ? Colors.black87 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                icon: Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: colors.isDark ? Colors.black87 : Colors.white,
                ),
                label: const Text(
                  'Apply & Save',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Vector Canvas Painter rendering the CC/CV AC Charging curve
class _ChargingCurvePainter extends CustomPainter {
  final double startSoc;
  final double targetSoc;
  final Color evTeal;
  final Color gridColor;
  final Color textColor;

  _ChargingCurvePainter({
    required this.startSoc,
    required this.targetSoc,
    required this.evTeal,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines (50%, 75%, 100%)
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw Curve
    final path = Path();
    final fillPath = Path();

    final startY = size.height * (1.0 - (startSoc / 100.0).clamp(0.0, 1.0));
    final targetY = size.height * (1.0 - (targetSoc / 100.0).clamp(0.0, 1.0));

    path.moveTo(0, startY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, startY);

    // CC Phase (linear steep climb) up to 85%, then CV tapering
    final midX = size.width * 0.65;
    final midSoc = startSoc + (targetSoc - startSoc) * 0.75;
    final midY = size.height * (1.0 - (midSoc / 100.0).clamp(0.0, 1.0));

    path.cubicTo(
      size.width * 0.25,
      startY - (startY - midY) * 0.7,
      midX * 0.8,
      midY,
      midX,
      midY,
    );
    path.cubicTo(
      midX + (size.width - midX) * 0.5,
      midY - 2,
      size.width * 0.85,
      targetY + 2,
      size.width,
      targetY,
    );

    fillPath.cubicTo(
      size.width * 0.25,
      startY - (startY - midY) * 0.7,
      midX * 0.8,
      midY,
      midX,
      midY,
    );
    fillPath.cubicTo(
      midX + (size.width - midX) * 0.5,
      midY - 2,
      size.width * 0.85,
      targetY + 2,
      size.width,
      targetY,
    );
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Gradient Fill under curve
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        evTeal.withValues(alpha: 0.35),
        evTeal.withValues(alpha: 0.0),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Curve Line
    final linePaint = Paint()
      ..color = evTeal
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Marker Points
    final dotPaint = Paint()..color = Colors.white;
    final dotRingPaint = Paint()
      ..color = evTeal
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Start point
    canvas.drawCircle(Offset(0, startY), 4, dotPaint);
    canvas.drawCircle(Offset(0, startY), 4, dotRingPaint);

    // End point
    canvas.drawCircle(Offset(size.width, targetY), 5, dotPaint);
    canvas.drawCircle(Offset(size.width, targetY), 5, dotRingPaint);
  }

  @override
  bool shouldRepaint(covariant _ChargingCurvePainter oldDelegate) {
    return oldDelegate.startSoc != startSoc ||
        oldDelegate.targetSoc != targetSoc ||
        oldDelegate.evTeal != evTeal;
  }
}
