import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_telemetry.dart';
import '../auth/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_sheet.dart';
import 'carlinko_connect_dialog.dart';
import 'chery_service_centres_screen.dart';
import 'vehicle_radar_sheet.dart';

class NeoDashboard extends StatefulWidget {
  final VehicleRepository repository;
  final String ownerName;
  final String carPlateNumber;
  final String vehicleNickname;
  final double tnbTariff;
  final double fuelPrice;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAssistant;

  const NeoDashboard({
    super.key,
    required this.repository,
    required this.ownerName,
    required this.carPlateNumber,
    required this.vehicleNickname,
    required this.tnbTariff,
    required this.fuelPrice,
    required this.onOpenSettings,
    required this.onOpenAssistant,
  });

  @override
  State<NeoDashboard> createState() => _NeoDashboardState();
}

class _NeoDashboardState extends State<NeoDashboard> with SingleTickerProviderStateMixin {
  late VehicleTelemetry _telemetry;
  bool _scheduledCharging = true;
  bool _isAdvancedView = false;
  bool _is3DView = false;
  bool _isDoorsLocked = true;
  bool _isAcActive = false;
  bool _isWindowsVented = false;
  bool _isTrunkOpen = false;
  bool _spendingExpanded = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _telemetry = widget.repository.currentTelemetry;
    _isDoorsLocked = !_telemetry.doorsOpen;
    _isAcActive = _telemetry.acOn;
    _isTrunkOpen = _telemetry.trunkOpen;
    _isWindowsVented = _telemetry.windowsOpen;

    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _isAdvancedView = prefs.getBool('tiggomate_ui_mode_advanced') ?? false;
        });
      }
    });

    widget.repository.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _telemetry = data;
          _isDoorsLocked = !data.doorsOpen;
          _isAcActive = data.acOn;
          _isTrunkOpen = data.trunkOpen;
          _isWindowsVented = data.windowsOpen;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleComponentTap(String part) {
    if (part == 'fl_tyre') {
      _showTyreModal('Front-Left (FL)', 'FL Tire Pressure', _telemetry.tyreFlPressureKpa, _telemetry.tyreFlTempC);
    } else if (part == 'rl_tyre') {
      _showTyreModal('Rear-Left (RL)', 'RL Tire Pressure', _telemetry.tyreRlPressureKpa, _telemetry.tyreRlTempC);
    } else if (part == 'fr_tyre') {
      _showTyreModal('Front-Right (FR)', 'FR Tire Pressure', _telemetry.tyreFrPressureKpa, _telemetry.tyreFrTempC);
    } else if (part == 'rr_tyre') {
      _showTyreModal('Rear-Right (RR)', 'RR Tire Pressure', _telemetry.tyreRrPressureKpa, _telemetry.tyreRrTempC);
    } else if (part == 'charging_port') {
      _showChargingPortModal();
    } else if (part == 'engine') {
      _showPowertrainModal();
    }
  }

  void _showTyreModal(String position, String name, double kpa, double tempC) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colors = AppColors(context);
        final psi = VehicleTelemetry.kpaToPsi(kpa);
        const coldTargetKpa = 230.0;
        final diff = kpa - coldTargetKpa;
        final isOptimal = diff.abs() <= 10;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.evTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tire_repair, color: colors.evTeal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              Text('Direct TPMS Sensor • $position', style: TextStyle(fontSize: 12, color: colors.textSecondary), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOptimal ? colors.evTeal.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOptimal ? 'OPTIMAL' : 'CHECK PRESSURE',
                      style: TextStyle(
                        color: isOptimal ? colors.evTeal : Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.tileBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PRESSURE', style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${kpa.toStringAsFixed(0)} kPa',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.evTeal),
                          ),
                          Text('${psi.toStringAsFixed(1)} PSI (Cold Spec 33.4 PSI)', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.tileBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TEMPERATURE', style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${tempC.toStringAsFixed(0)}°C',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          Text('Normal Malaysian Operating Range', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Direct internal valve sensor transmits real-time telemetry over Chery CarLinko CAN-bus.',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showChargingPortModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colors = AppColors(context);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.evTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.electrical_services, color: colors.evTeal, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AC Type 2 Charging Port', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Rear-Left Quarter Panel', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _telemetry.isCharging
                          ? colors.evTeal.withValues(alpha: 0.15)
                          : (colors.isDark ? Colors.white12 : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _telemetry.isCharging ? 'PLUGGED IN' : 'READY',
                      style: TextStyle(
                        color: _telemetry.isCharging ? colors.evTeal : colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Max Onboard Charger (OBC)', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        Text('6.6 kW AC (Single Phase)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      ],
                    ),
                    Divider(height: 20, color: colors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Battery Pack Size', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        Text('19.27 kWh LFP (${_telemetry.batteryPct}% SoC)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.evTeal)),
                      ],
                    ),
                    Divider(height: 20, color: colors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Full Charge Time (0-100%)', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        Text('~3.0 Hours (via 7kW Wallbox)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showPowertrainModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colors = AppColors(context);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F81F7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bolt, color: Color(0xFF2F81F7), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Chery Super Hybrid (CSH)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('1.5T Turbocharged PHEV + Dual Electric Motors', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Combined System Output', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        Text('326 PS • 510 Nm Torque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.evTeal)),
                      ],
                    ),
                    Divider(height: 18, color: colors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Dedicated Hybrid Transmission', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        Text('3-Speed Dual-Motor DHT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      ],
                    ),
                    Divider(height: 18, color: colors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Combined Driving Range', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        const Text('1,060+ km (WLTC)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2F81F7))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _toggleUiMode(bool advanced) {
    setState(() => _isAdvancedView = advanced);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('tiggomate_ui_mode_advanced', advanced);
    });
  }

  void _openAuthSheet() {
    AuthSheet.show(context, onProfileUpdated: () {
      if (mounted) setState(() {});
    });
  }

  void _openCarlinkoConnect() {
    showDialog(
      context: context,
      builder: (context) => CarlinkoConnectDialog(
        repository: widget.repository,
        currentAccount: widget.ownerName,
        onConnected: () => setState(() {}),
      ),
    );
  }

  void _showNotification(String message) {
    final colors = AppColors(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border),
        ),
        elevation: colors.isDark ? 4 : 2,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleRemoteCommand(String action) {
    if (action == 'lock') {
      setState(() => _isDoorsLocked = !_isDoorsLocked);
      _showNotification(_isDoorsLocked ? '🔒 CarLinko: Doors Locked' : '🔓 CarLinko: Doors Unlocked');
    } else if (action == 'climate') {
      setState(() => _isAcActive = !_isAcActive);
      _showNotification(_isAcActive ? '❄️ Cabin Pre-cooling started (22°C)' : '❄️ Climate Pre-conditioning OFF');
    } else if (action == 'windows') {
      setState(() => _isWindowsVented = !_isWindowsVented);
      _showNotification(_isWindowsVented ? '🪟 Windows vented (20mm)' : '🪟 All Windows closed');
    } else if (action == 'trunk') {
      setState(() => _isTrunkOpen = !_isTrunkOpen);
      _showNotification(_isTrunkOpen ? '🚗 Power Tailgate opened' : '🚗 Tailgate closed');
    } else if (action == 'locate') {
      VehicleRadarSheet.show(
        context,
        telemetry: _telemetry,
        onHornFlash: () {
          _showNotification('📢 CarLinko: Lights flashing & horn sounding');
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final double homeAcCost = 84.5 * widget.tnbTariff;
    final double petrolCost = 28.7 * widget.fuelPrice;
    final double totalSpend = homeAcCost + petrolCost;
    const double iceEquivalent = 165.40;
    final double savings = iceEquivalent - totalSpend;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ---------------- 1. HEADER: VEHICLE & STATUS ----------------
        // Top Utility Bar: Driver Profile & Quick Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Driver & Connectivity Pill
            GestureDetector(
              onTap: _openAuthSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AuthService().currentUser.isAuthenticated
                        ? colors.evTeal.withValues(alpha: 0.5)
                        : const Color(0xFF2F81F7).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _telemetry.isCharging
                            ? colors.evTeal
                            : (AuthService().currentUser.isAuthenticated ? colors.evTeal : const Color(0xFF2F81F7)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      AuthService().currentUser.isAuthenticated
                          ? Icons.account_circle_outlined
                          : Icons.login_rounded,
                      size: 15,
                      color: AuthService().currentUser.isAuthenticated
                          ? colors.evTeal
                          : const Color(0xFF2F81F7),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      AuthService().currentUser.isAuthenticated
                          ? AuthService().currentUser.displayName
                          : 'Log In',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AuthService().currentUser.isAuthenticated
                            ? colors.evTeal
                            : const Color(0xFF2F81F7),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _telemetry.isCharging
                            ? colors.evTeal.withValues(alpha: 0.2)
                            : (!_telemetry.isSimulated ? colors.evTeal.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _telemetry.isCharging
                            ? '⚡ 3.3kW'
                            : (_telemetry.isSimulated ? 'Simulated' : 'Connected'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _telemetry.isCharging
                              ? colors.evTeal
                              : (!_telemetry.isSimulated ? colors.evTeal : Colors.orangeAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right: Action Icons Dock (Location, Telematics, Theme Toggle, Settings)
            Container(
              decoration: BoxDecoration(
                color: colors.dockBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.dockShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Chery Service Centres',
                    icon: Icon(Icons.location_on_outlined, size: 18, color: colors.dockBtnIcon),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CheryServiceCentresScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'CarLinko Cloud Sync',
                    icon: Icon(Icons.cell_tower, size: 18, color: colors.evTeal),
                    onPressed: _openCarlinkoConnect,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: colors.isDark ? 'Switch to Tesla Light Theme' : 'Switch to Obsidian Dark Theme',
                    icon: Icon(
                      colors.isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                      size: 18,
                      color: colors.isDark ? const Color(0xFFFF9F1C) : const Color(0xFF111827),
                    ),
                    onPressed: () => AppThemeController.instance.toggleTheme(context),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Settings',
                    icon: Icon(Icons.settings_outlined, size: 18, color: colors.dockBtnIcon),
                    onPressed: widget.onOpenSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Vehicle Title & Identification Row (Full Width - No Truncation)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.vehicleNickname.isNotEmpty ? widget.vehicleNickname : 'Chery Tiggo 7 PHEV CSH',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                // Car Plate Badge (Malaysian Black & Silver plate aesthetic)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0xFF090D12) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.isDark ? const Color(0xFF2F81F7).withValues(alpha: 0.6) : const Color(0xFF475569),
                    ),
                  ),
                  child: Text(
                    widget.carPlateNumber.isNotEmpty ? widget.carPlateNumber : 'VRT 3342',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.ownerName} • Chery Tiggo 7 PHEV CSH • 1.5T DHT',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Simulated Badge if active
        if (_telemetry.isSimulated)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CheryServiceCentresScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: colors.isDark
                    ? const Color(0xFFF1B343).withValues(alpha: 0.12)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.isDark
                      ? const Color(0xFFF1B343).withValues(alpha: 0.35)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: colors.isDark ? const Color(0xFFFFB74D) : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SIMULATED DATA (CarLinko activates at 1,000 km service • Tap to find centres)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: colors.isDark ? const Color(0xFFFFB74D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colors.isDark ? const Color(0xFFFFB74D) : const Color(0xFFB45309),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),

        // ---------------- 1.5 DUAL UI MODE SWITCHER (BASIC vs ADVANCED) ----------------
        _buildModeSwitcher(),
        const SizedBox(height: 10),

        // ---------------- 2. HERO VEHICLE STAGE (2D Studio or 3D Orbit) ----------------
        Card(
          color: colors.cardBg,
          elevation: colors.isDark ? 0 : 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_isAdvancedView) ...[
                  // Top Stage Header: View Switcher (2D Studio vs 3D Orbit)
                  Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _is3DView ? Icons.view_in_ar : Icons.radar,
                          size: 15,
                          color: const Color(0xFF00D2AA),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _is3DView ? '3D INTERACTIVE ORBIT' : '2D STUDIO RADAR',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161E2E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF283548)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() => _is3DView = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_is3DView ? const Color(0xFF00D2AA) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.photo_size_select_actual_outlined,
                                    size: 13,
                                    color: !_is3DView ? Colors.black : Colors.white60,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '2D',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !_is3DView ? Colors.black : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() => _is3DView = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _is3DView ? const Color(0xFF00D2AA) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.view_in_ar,
                                    size: 13,
                                    color: _is3DView ? Colors.black : Colors.white60,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '3D',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _is3DView ? Colors.black : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Canvas Area: 3D ModelViewer OR 2D Studio Hotspot Stack
              if (_isAdvancedView && _is3DView)
                  SizedBox(
                    height: 240,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          ModelViewer(
                            src: 'assets/models/tiggo7.glb',
                            alt: 'Chery Tiggo 7 PHEV CSH 3D Model',
                            ar: false,
                            autoRotate: true,
                            cameraControls: true,
                            shadowIntensity: 1.0,
                            backgroundColor: const Color(0xFF0D1219),
                            innerModelViewerHtml: '''
                              <button class="hotspot" slot="hotspot-fl" data-position="-0.0133 0.0036 0.009" data-normal="0 0 1" data-part="fl_tyre">
                                <div class="pin-dot"></div>
                                <div class="pin-label">FL Tyre</div>
                              </button>
                              <button class="hotspot" slot="hotspot-rl" data-position="0.0131 0.0036 0.009" data-normal="0 0 1" data-part="rl_tyre">
                                <div class="pin-dot"></div>
                                <div class="pin-label">RL Tyre</div>
                              </button>
                              <button class="hotspot" slot="hotspot-port" data-position="0.012 0.011 0.0085" data-normal="0 0 1" data-part="charging_port">
                                <div class="pin-dot"></div>
                                <div class="pin-label">AC Port</div>
                              </button>
                              <button class="hotspot" slot="hotspot-engine" data-position="-0.018 0.0095 0" data-normal="0 1 0" data-part="engine">
                                <div class="pin-dot" style="background:#2F81F7; box-shadow: 0 0 6px #2F81F7;"></div>
                                <div class="pin-label">1.5T CSH</div>
                              </button>
                            ''',
                            relatedCss: '''
                              .hotspot {
                                background: rgba(9, 13, 18, 0.88);
                                border-radius: 20px;
                                border: 1px solid rgba(0, 210, 170, 0.7);
                                box-shadow: 0 0 10px rgba(0, 210, 170, 0.4);
                                box-sizing: border-box;
                                cursor: pointer;
                                height: 24px;
                                padding: 0 8px;
                                display: flex;
                                align-items: center;
                                gap: 5px;
                                transition: transform 0.2s, background-color 0.2s;
                              }
                              .hotspot:hover {
                                transform: scale(1.08);
                                background: rgba(0, 210, 170, 0.25);
                              }
                              .pin-dot {
                                width: 8px;
                                height: 8px;
                                border-radius: 50%;
                                background: #00D2AA;
                                box-shadow: 0 0 6px #00D2AA;
                              }
                              .pin-label {
                                color: #FFFFFF;
                                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                                font-size: 10px;
                                font-weight: 700;
                                letter-spacing: 0.3px;
                              }
                            ''',
                          ),
                          // Subtle 3D hint overlay
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '360° Drag • Pinch to Zoom • Tap Hotspots',
                                  style: TextStyle(fontSize: 10, color: Colors.white70),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 200,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient radial background glow (Obsidian dark mode only)
                            if (colors.isDark)
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.75,
                                      colors: [
                                        colors.evTeal.withValues(alpha: 0.09),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Floor shadow reflection (soft radial gradient)
                            Positioned(
                              bottom: 12,
                              child: Container(
                                width: constraints.maxWidth * 0.75,
                                height: 16,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                    Radius.elliptical(constraints.maxWidth * 0.75, 16),
                                  ),
                                  gradient: RadialGradient(
                                    colors: [
                                      colors.isDark
                                          ? Colors.black.withValues(alpha: 0.75)
                                          : Colors.black.withValues(alpha: 0.22),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Vehicle Render (Lunar White Tiggo 7 PHEV CSH)
                            Positioned(
                              top: 8,
                              bottom: 20,
                              child: Image.asset(
                                'assets/images/car_hero.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.directions_car, size: 100, color: colors.textMuted);
                                },
                              ),
                            ),

                            if (_isAdvancedView) ...[
                              // 1. Front-Left Wheel Hotspot
                              Positioned(
                                left: constraints.maxWidth * 0.48,
                                bottom: 26,
                                child: _buildRadarPin(
                                  'FL Tyre',
                                  () => _handleComponentTap('fl_tyre'),
                                ),
                              ),

                              // 2. Rear-Left Wheel Hotspot
                              Positioned(
                                right: constraints.maxWidth * 0.17,
                                bottom: 40,
                                child: _buildRadarPin(
                                  'RL Tyre',
                                  () => _handleComponentTap('rl_tyre'),
                                ),
                              ),

                              // 3. Charging Port Hotspot
                              Positioned(
                                right: constraints.maxWidth * 0.15,
                                top: 52,
                                child: _buildRadarPin(
                                  'AC Port',
                                  () => _handleComponentTap('charging_port'),
                                  accentColor: const Color(0xFF00D2AA),
                                  icon: Icons.electrical_services,
                                ),
                              ),

                              // 4. Front Hybrid Engine Hotspot
                              Positioned(
                                left: constraints.maxWidth * 0.22,
                                top: 60,
                                child: _buildRadarPin(
                                  '1.5T CSH',
                                  () => _handleComponentTap('engine'),
                                  accentColor: const Color(0xFF2F81F7),
                                  icon: Icons.bolt,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),

                // ---------------- 3. CARLINKO DUAL-ENERGY GLANCE DOCK ----------------
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      // Electric Side (Teal)
                      Expanded(
                        child: InkWell(
                          onTap: _showChargingPortModal,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.bolt, size: 14, color: colors.evTeal),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_telemetry.batteryPct}% EV',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.evTeal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_telemetry.electricRangeKm} km',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
                              ),
                              Text('EV RANGE', style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),

                      // Center Divider & Total Combined Range Callout
                      Container(width: 1, height: 38, color: colors.border),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${_telemetry.totalRangeKm} km',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'TOTAL RANGE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: colors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Dual split mini progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 28, height: 3, color: colors.evTeal),
                                  const SizedBox(width: 2),
                                  Container(width: 48, height: 3, color: colors.petrolAmber),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 38, color: colors.border),

                      // Petrol Fuel Side (Amber)
                      Expanded(
                        child: InkWell(
                          onTap: _showPowertrainModal,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.local_gas_station, size: 14, color: colors.petrolAmber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '82% Fuel',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.petrolAmber,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_telemetry.fuelRangeKm} km',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary),
                              ),
                              Text('PETROL RANGE', style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---------------- 4. CARLINKO 5-BUTTON CIRCULAR REMOTE CONTROL DECK ----------------
        Card(
          elevation: colors.isDark ? 0 : 0.5,
          color: colors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularRemoteButton(
                  icon: _isDoorsLocked ? Icons.lock : Icons.lock_open,
                  label: _isDoorsLocked ? 'Locked' : 'Unlocked',
                  sublabel: 'Doors',
                  isActive: _isDoorsLocked,
                  activeColor: const Color(0xFF00D2AA),
                  onTap: () => _handleRemoteCommand('lock'),
                ),
                _buildCircularRemoteButton(
                  icon: Icons.ac_unit,
                  label: _isAcActive ? '22°C ON' : 'A/C OFF',
                  sublabel: 'Climate',
                  isActive: _isAcActive,
                  activeColor: const Color(0xFF2F81F7),
                  onTap: () => _handleRemoteCommand('climate'),
                ),
                _buildCircularRemoteButton(
                  icon: Icons.air,
                  label: _isWindowsVented ? 'Vented' : 'Closed',
                  sublabel: 'Windows',
                  isActive: _isWindowsVented,
                  activeColor: Colors.tealAccent,
                  onTap: () => _handleRemoteCommand('windows'),
                ),
                _buildCircularRemoteButton(
                  icon: Icons.luggage_outlined,
                  label: _isTrunkOpen ? 'Open' : 'Closed',
                  sublabel: 'Trunk',
                  isActive: _isTrunkOpen,
                  activeColor: Colors.amber,
                  onTap: () => _handleRemoteCommand('trunk'),
                ),
                _buildCircularRemoteButton(
                  icon: Icons.radar,
                  label: 'Find Car',
                  sublabel: 'Locate',
                  isActive: false,
                  activeColor: const Color(0xFF00D2AA),
                  onTap: () => _handleRemoteCommand('locate'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ---------------- 4.5 LIVE VEHICLE LOCATION & RADAR GLANCE ----------------
        _buildVehicleLocationRadarCard(),
        const SizedBox(height: 14),

        if (!_isAdvancedView)
          _buildBasicStatusSummaryCard()
        else ...[
          // ---------------- 5. SMART CHARGING & BATTERY MODULE ----------------
          Card(
            elevation: 0,
            color: colors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt, size: 18, color: colors.evTeal),
                          const SizedBox(width: 8),
                          Text(
                            'Smart Charging Management',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ],
                      ),
                      Text(
                        _telemetry.isCharging ? '3.3 kW AC' : 'Standby',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _telemetry.isCharging ? colors.evTeal : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3-Stat Metric Row inside Charging Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.tileBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SESSION COST', style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                _telemetry.isCharging ? 'RM 7.87' : 'RM 0.00',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.evTeal),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 28, color: colors.border),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TIME REMAINING', style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  _telemetry.isCharging ? '1h 45m' : 'Full / Ready',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 1, height: 28, color: colors.border),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('PLUG STATUS', style: TextStyle(fontSize: 9, color: colors.textMuted, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                _telemetry.isCharging ? 'Connected' : 'Ready',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scheduled Charging Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 15, color: colors.textMuted),
                          const SizedBox(width: 8),
                          Text('Scheduled Charging', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                        ],
                      ),
                      Switch(
                        value: _scheduledCharging,
                        activeThumbColor: colors.evTeal,
                        onChanged: (val) => setState(() => _scheduledCharging = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (widget.repository is MockVehicleRepository) {
                              (widget.repository as MockVehicleRepository).toggleCharging(!_telemetry.isCharging);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            _telemetry.isCharging ? 'Pause Charging' : 'Start AC Charge',
                            style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showNotification('⏰ Off-Peak TNB charging timer scheduled: 10:00 PM – 06:00 AM.');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.isDark ? Colors.white : const Color(0xFF111827),
                            foregroundColor: colors.isDark ? Colors.black87 : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: Icon(Icons.calendar_today, size: 15, color: colors.isDark ? Colors.black87 : Colors.white),
                          label: const Text('Set Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // ---------------- 6. VEHICLE HEALTH & DIRECT TPMS CARD ----------------
        Card(
          elevation: 0,
          color: colors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.health_and_safety_outlined, size: 18, color: colors.evTeal),
                        const SizedBox(width: 8),
                        Text('Vehicle Health & TPMS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                      ],
                    ),
                    InkWell(
                      onTap: () => _showTyreModal('Front-Left (FL)', 'FL Tire Pressure', _telemetry.tyreFlPressureKpa, _telemetry.tyreFlTempC),
                      child: Row(
                        children: [
                          Text('Tyres', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.evTeal)),
                          Icon(Icons.chevron_right, size: 16, color: colors.evTeal),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Visual Bird's-Eye Vehicle TPMS Inspector (Official CarLinko Top Render)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      // Left Column: FL & RL Tyres
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildTpmsMiniTile(
                              label: 'FL',
                              kpa: _telemetry.tyreFlPressureKpa,
                              tempC: _telemetry.tyreFlTempC,
                              onTap: () => _showTyreModal('Front-Left (FL)', 'FL Tire Pressure', _telemetry.tyreFlPressureKpa, _telemetry.tyreFlTempC),
                            ),
                            const SizedBox(height: 12),
                            _buildTpmsMiniTile(
                              label: 'RL',
                              kpa: _telemetry.tyreRlPressureKpa,
                              tempC: _telemetry.tyreRlTempC,
                              onTap: () => _showTyreModal('Rear-Left (RL)', 'RL Tire Pressure', _telemetry.tyreRlPressureKpa, _telemetry.tyreRlTempC),
                            ),
                          ],
                        ),
                      ),

                      // Center: Official Top-Down Vehicle Diagram
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 145,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/images/car_top.png',
                                height: 140,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.directions_car, size: 80, color: colors.textMuted),
                              ),
                              Positioned(
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: colors.evTeal.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_isDoorsLocked ? Icons.lock : Icons.lock_open, size: 10, color: colors.evTeal),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isDoorsLocked ? 'SECURED' : 'UNLOCKED',
                                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: colors.evTeal),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right Column: FR & RR Tyres
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildTpmsMiniTile(
                              label: 'FR',
                              kpa: _telemetry.tyreFrPressureKpa,
                              tempC: _telemetry.tyreFrTempC,
                              onTap: () => _showTyreModal('Front-Right (FR)', 'FR Tire Pressure', _telemetry.tyreFrPressureKpa, _telemetry.tyreFrTempC),
                            ),
                            const SizedBox(height: 12),
                            _buildTpmsMiniTile(
                              label: 'RR',
                              kpa: _telemetry.tyreRrPressureKpa,
                              tempC: _telemetry.tyreRrTempC,
                              onTap: () => _showTyreModal('Rear-Right (RR)', 'RR Tire Pressure', _telemetry.tyreRrPressureKpa, _telemetry.tyreRrTempC),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Health Row: 12V Battery + Odometer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.tileBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.battery_charging_full, size: 16, color: colors.evTeal),
                          const SizedBox(width: 6),
                          Text('12V Aux: ${_telemetry.volt12.toStringAsFixed(2)}V (Healthy)', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.speed, size: 16, color: colors.textMuted),
                          const SizedBox(width: 6),
                          Text('Odo: ${_telemetry.odometerKm} km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---------------- 7. HYBRID ECONOMICS & SPENDING ACCORDION ----------------
        Card(
          elevation: 0,
          color: colors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => _spendingExpanded = !_spendingExpanded),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pie_chart_outline, size: 18, color: colors.evTeal),
                          const SizedBox(width: 8),
                          Text('Monthly Spending Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('RM ${totalSpend.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.evTeal)),
                          const SizedBox(width: 4),
                          Icon(_spendingExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: colors.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_spendingExpanded) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Donut Ring Visual
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const CircularProgressIndicator(
                              value: 0.45,
                              strokeWidth: 7,
                              backgroundColor: Color(0xFF2F81F7),
                              color: Color(0xFF00D2AA),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('RM ${totalSpend.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary)),
                                Text('Total', style: TextStyle(fontSize: 9, color: colors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Legend
                      Expanded(
                        child: Column(
                          children: [
                            _buildLegendRow('⚡ Home AC (TNB)', 'RM ${homeAcCost.toStringAsFixed(2)}', const Color(0xFF00D2AA)),
                            const SizedBox(height: 4),
                            _buildLegendRow('⛽ Petrol (RON95)', 'RM ${petrolCost.toStringAsFixed(2)}', const Color(0xFF2F81F7)),
                            const SizedBox(height: 4),
                            _buildLegendRow('🔌 Public DC EV', 'RM 0.00', Colors.purpleAccent),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: colors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Hybrid Efficiency Savings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.evTeal)),
                      ),
                      Text('RM ${savings.toStringAsFixed(2)} saved', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.evTeal)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCircularRemoteButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final colors = AppColors(context);
    final isLockedBtn = label == 'Locked';
    final bool useNeutralLocked = isLockedBtn && !colors.isDark;
    final Color buttonColor = useNeutralLocked
        ? colors.dockBtnBg
        : (isActive
            ? activeColor.withValues(alpha: colors.isDark ? 0.2 : 0.15)
            : colors.dockBtnBg);
    final Color borderColor = useNeutralLocked
        ? colors.border
        : (isActive ? activeColor : colors.border);
    final Color iconColor = useNeutralLocked
        ? colors.textPrimary
        : (isActive ? activeColor : colors.dockBtnIcon);
    final Color labelColor = useNeutralLocked
        ? colors.textPrimary
        : (isActive ? activeColor : colors.textPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: buttonColor,
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
              boxShadow: (isActive && !useNeutralLocked)
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: colors.isDark ? 0.35 : 0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : [
                      if (!colors.isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: 22,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(fontSize: 9.5, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTpmsMiniTile({
    required String label,
    required double kpa,
    required double tempC,
    required VoidCallback onTap,
  }) {
    final colors = AppColors(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.tileBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              kpa.toStringAsFixed(0),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.evTeal),
            ),
            Text('kPa', style: TextStyle(fontSize: 9, color: colors.textMuted)),
            const SizedBox(height: 2),
            Text('${tempC.toStringAsFixed(0)}°C', style: TextStyle(fontSize: 9.5, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarPin(String label, VoidCallback onTap, {Color accentColor = const Color(0xFF00D2AA), IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.25),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 10 * _pulseAnimation.value,
                  spreadRadius: 2 * _pulseAnimation.value,
                ),
              ],
            ),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
              ),
              child: icon != null
                  ? Icon(icon, size: 9, color: Colors.black87)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendRow(String title, String val, Color dotColor) {
    final colors = AppColors(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          ],
        ),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textPrimary)),
      ],
    );
  }

  Widget _buildModeSwitcher() {
    final colors = AppColors(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toggleUiMode(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isAdvancedView ? colors.evTeal.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !_isAdvancedView ? colors.evTeal.withValues(alpha: 0.5) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.dashboard_outlined,
                      size: 15,
                      color: !_isAdvancedView ? colors.evTeal : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Basic Glance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: !_isAdvancedView ? FontWeight.bold : FontWeight.normal,
                        color: !_isAdvancedView ? colors.evTeal : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toggleUiMode(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isAdvancedView ? const Color(0xFF2F81F7).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAdvancedView ? const Color(0xFF2F81F7).withValues(alpha: 0.5) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 15,
                      color: _isAdvancedView ? const Color(0xFF2F81F7) : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Advanced Telemetry',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _isAdvancedView ? FontWeight.bold : FontWeight.normal,
                        color: _isAdvancedView ? const Color(0xFF2F81F7) : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleLocationRadarCard() {
    final colors = AppColors(context);
    final isDark = colors.isDark;

    return Card(
      elevation: isDark ? 0 : 0.5,
      color: colors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: () => _handleRemoteCommand('locate'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Mini Circular Radar Badge Preview
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E2632) : const Color(0xFFE2E4E8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFF6B7280),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Faint radar concentric ring
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.evTeal.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                    ),
                    // Directional Vehicle Pointer
                    Transform.rotate(
                      angle: _telemetry.headingDegrees * (3.141592653589793 / 180),
                      child: const Icon(
                        Icons.navigation,
                        size: 18,
                        color: Color(0xFFFFA000),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Location Telemetry Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'VEHICLE LOCATION',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.evTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'GPS Locked',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: colors.evTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _telemetry.locationName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '120 m away • ${_telemetry.parkedDurationText}',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Radar Action Pill Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.evTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.evTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar, size: 14, color: colors.evTeal),
                    const SizedBox(width: 4),
                    Text(
                      'Radar',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: colors.evTeal,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 14, color: colors.evTeal),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicStatusSummaryCard() {
    final colors = AppColors(context);
    return Card(
      elevation: colors.isDark ? 0 : 0.5,
      color: colors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 18, color: colors.evTeal),
                    const SizedBox(width: 8),
                    const Text('Vehicle Quick Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.evTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('ALL OPTIMAL', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colors.evTeal)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Row 1: TPMS
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showTyreModal('Tyres', 'Tire Pressure (TPMS)', _telemetry.tyreFlPressureKpa, _telemetry.tyreFlTempC),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.speed, size: 18, color: colors.evTeal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Direct TPMS Tire Pressures', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('All 4 tyres optimal at ~230 kPa (Cold)', style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    Text('230 kPa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.evTeal)),
                    Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Row 2: Traction Battery
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showChargingPortModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.battery_charging_full, size: 18, color: colors.evTeal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('19.27 kWh LFP Traction Battery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${_telemetry.batteryPct}% SoC • ${_telemetry.electricRangeKm} km EV Range • AC Type 2', style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(_telemetry.isCharging ? 'Charging' : 'Ready', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _telemetry.isCharging ? colors.evTeal : colors.textSecondary)),
                    Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Row 3: 1,000 km Service Due
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const CheryServiceCentresScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.tileBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.build_outlined, size: 18, color: colors.petrolAmber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('First Service Milestone: 1,000 km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('Labour & Inspection FOC • Chery Authorised 3S/4S', style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    Text('FOC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.petrolAmber)),
                    Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Switch to Advanced Mode Button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _toggleUiMode(true),
                icon: const Icon(Icons.tune, size: 15, color: Color(0xFF2F81F7)),
                label: const Text(
                  'Show Advanced Telemetry, Graphs & Sensor Diagnostics ➔',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF2F81F7), fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
