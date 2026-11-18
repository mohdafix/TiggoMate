import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/ai_service.dart';
import '../auth/auth_service.dart';
import '../carlinko/vehicle_repository.dart';
import '../carlinko/vehicle_skin.dart';
import '../mytnb/mytnb_api.dart';
import '../theme/accent.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'app_notification.dart';
import 'auth_sheet.dart';
import 'carlinko_connect_dialog.dart';
import 'mytnb_connect_dialog.dart';
import 'setup_intro_screen.dart';
import 'remote_command_diagnostics_sheet.dart';
import '../firebase/firebase_sync_service.dart';
import 'sage_widgets.dart';
import '../service/bluetooth_driving_tracker_service.dart';
import '../service/price_book_service.dart';
import '../service/background_guardian_service.dart';
import '../service/vehicle_alert_notifier.dart';
import '../service/smart_wrist_key_service.dart';

// Re-export AppSettings and SettingsService so existing callers keep working seamlessly
class AppSettings {
  final String ownerName;
  final String carPlateNumber;
  final String vehicleNickname;
  final String aiApiKey;
  final String aiModel;
  final String aiHost;
  final String aiProvider;
  final String carLinkoStatus; // 'Unactivated', 'Active', 'Demo'
  final double tnbTariff;
  final double fuelPrice;
  final String vehicleSkinKey;

  const AppSettings({
    this.ownerName = "Chery Owner",
    this.carPlateNumber = "VAG 7777",
    this.vehicleNickname = "Chery Tiggo 7 PHEV CSH",
    this.aiApiKey = "",
    this.aiModel = "gpt-4o-mini",
    this.aiHost = "http://10.0.2.2:8088",
    this.aiProvider = "OpenRouter",
    this.carLinkoStatus = "Unactivated",
    this.tnbTariff = 0.57,
    this.fuelPrice = 2.05,
    this.vehicleSkinKey = "khaki_white",
  });

  AppSettings copyWith({
    String? ownerName,
    String? carPlateNumber,
    String? vehicleNickname,
    String? aiApiKey,
    String? aiModel,
    String? aiHost,
    String? aiProvider,
    String? carLinkoStatus,
    double? tnbTariff,
    double? fuelPrice,
    String? vehicleSkinKey,
  }) {
    return AppSettings(
      ownerName: ownerName ?? this.ownerName,
      carPlateNumber: carPlateNumber ?? this.carPlateNumber,
      vehicleNickname: vehicleNickname ?? this.vehicleNickname,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
      aiHost: aiHost ?? this.aiHost,
      aiProvider: aiProvider ?? this.aiProvider,
      carLinkoStatus: carLinkoStatus ?? this.carLinkoStatus,
      tnbTariff: tnbTariff ?? this.tnbTariff,
      fuelPrice: fuelPrice ?? this.fuelPrice,
      vehicleSkinKey: vehicleSkinKey ?? this.vehicleSkinKey,
    );
  }
}

class SettingsService {
  static const String _kOwner = "tm_owner_name";
  static const String _kPlate = "tm_car_plate";
  static const String _kNickname = "tm_vehicle_nickname";
  static const String _kApiKey = "tm_ai_api_key";
  static const String _kModel = "tm_ai_model";
  static const String _kHost = "tm_ai_host";
  static const String _kProvider = "tm_ai_provider";
  static const String _kCarLinko = "tm_carlinko_status";
  static const String _kTnbTariff = "tm_tnb_tariff";
  static const String _kFuelPrice = "tm_fuel_price";
  static const String _kSkin = "tm_vehicle_color_skin";

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Fresh install / new device with no local prefs yet: try restoring
    // from Firestore before falling back to hard-coded defaults, so a
    // reinstall doesn't silently lose the saved owner/plate/pricing.
    if (!prefs.containsKey(_kOwner)) {
      try {
        final cloud = await FirebaseSyncService.instance.fetchSettings();
        if (cloud != null) {
          await save(cloud);
          return cloud;
        }
      } catch (_) {}
    }

    return AppSettings(
      ownerName: prefs.getString(_kOwner) ?? "Chery Owner",
      carPlateNumber: prefs.getString(_kPlate) ?? "VAG 7777",
      vehicleNickname: prefs.getString(_kNickname) ?? "Chery Tiggo 7 PHEV CSH",
      aiApiKey: prefs.getString(_kApiKey) ?? "",
      aiModel: prefs.getString(_kModel) ?? "gpt-4o-mini",
      aiHost: prefs.getString(_kHost) ?? "http://10.0.2.2:8088",
      aiProvider: prefs.getString(_kProvider) ?? "OpenRouter",
      carLinkoStatus: prefs.getString(_kCarLinko) ?? "Unactivated",
      tnbTariff: prefs.getDouble(_kTnbTariff) ?? 0.57,
      fuelPrice: prefs.getDouble(_kFuelPrice) ?? 2.05,
      vehicleSkinKey: prefs.getString(_kSkin) ?? "khaki_white",
    );
  }

  static Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOwner, s.ownerName);
    await prefs.setString(_kPlate, s.carPlateNumber);
    await prefs.setString(_kNickname, s.vehicleNickname);
    await prefs.setString(_kApiKey, s.aiApiKey);
    await prefs.setString(_kModel, s.aiModel);
    await prefs.setString(_kHost, s.aiHost);
    await prefs.setString(_kProvider, s.aiProvider);
    await prefs.setString(_kCarLinko, s.carLinkoStatus);
    await prefs.setDouble(_kTnbTariff, s.tnbTariff);
    await prefs.setDouble(_kFuelPrice, s.fuelPrice);
    await prefs.setString(_kSkin, s.vehicleSkinKey);

    // Sync vehicle preferences to Google Cloud Firestore
    unawaited(FirebaseSyncService.instance.syncSettings(s));
  }
}

/// Modern DashMate-styled Setup & Settings Screen for TiggoMate (Phone Form-Factor)
class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSave;
  final MyTnbRepository myTnbRepo;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSave,
    required this.myTnbRepo,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ownerController;
  late TextEditingController _nicknameController;
  late TextEditingController _plateController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late TextEditingController _hostController;
  late TextEditingController _tnbController;
  late TextEditingController _fuelController;
  late String _provider;
  late String _carLinkoStatus;
  String _vehicleSkinKey = 'khaki_white';
  bool _is24Hour = true;
  bool _useKmh = true;
  bool _isTestingAi = false;
  bool _vehicleAnomalyAlert = true;
  bool _batteryAnomalyAlert = true;
  int _unreadCloudNotices = 0;
  bool _isIgnoringBattery = false;
  bool _isXiaomi = false;
  bool _isGuardianEnabled = true;
  bool _isWristKeyEnabled = true;

  AppTokens get t => context.tokens;

  final List<String> _popularModels = [
    "gpt-4o-mini",
    "openai/gpt-4o-mini",
    "google/gemini-2.0-flash-lite",
    "anthropic/claude-3.5-haiku",
    "llama-3.1-8b-instant",
  ];

  @override
  void initState() {
    super.initState();
    _ownerController = TextEditingController(text: widget.settings.ownerName);
    _nicknameController = TextEditingController(text: widget.settings.vehicleNickname);
    _plateController = TextEditingController(text: widget.settings.carPlateNumber);
    _apiKeyController = TextEditingController(text: widget.settings.aiApiKey);
    _modelController = TextEditingController(text: widget.settings.aiModel);
    _hostController = TextEditingController(text: widget.settings.aiHost);
    _tnbController = TextEditingController(text: widget.settings.tnbTariff.toStringAsFixed(2));
    _fuelController = TextEditingController(text: widget.settings.fuelPrice.toStringAsFixed(2));
    _provider = widget.settings.aiProvider;
    _carLinkoStatus = widget.settings.carLinkoStatus;
    _vehicleSkinKey = widget.settings.vehicleSkinKey.isNotEmpty
        ? widget.settings.vehicleSkinKey
        : VehicleSkinManager.instance.currentSkinKey;

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      PriceBookService.instance.onCloudSync = FirebaseSyncService.instance.syncPriceBook;
      await PriceBookService.instance.ensureLoaded();
      unawaited(() async {
        final cloudPb = await FirebaseSyncService.instance.fetchPriceBook();
        if (cloudPb != null) {
          await PriceBookService.instance.importJson(cloudPb);
        }
      }());
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _vehicleSkinKey = prefs.getString('tm_vehicle_color_skin') ?? VehicleSkinManager.instance.currentSkinKey;
        _is24Hour = prefs.getBool('tm_clock_24h') ?? true;
        _useKmh = prefs.getBool('tm_speed_kmh') ?? true;
      });
      if (AppVehicleRepository.instance.isCloudConnected &&
          AppVehicleRepository.instance.vehicleId != null) {
        final cfgFuture = AppVehicleRepository.instance.getTerminalNoticeConfig();
        final unreadFuture = AppVehicleRepository.instance.getUnreadNoticeCount();
        final cfg = await cfgFuture;
        final unread = await unreadFuture;
        if (!mounted) return;
        setState(() {
          if (cfg.containsKey('enableVehicleAnomalyWarning')) {
            _vehicleAnomalyAlert = cfg['enableVehicleAnomalyWarning'] == true;
          }
          if (cfg.containsKey('enableBatteryAnomalyWarning')) {
            _batteryAnomalyAlert = cfg['enableBatteryAnomalyWarning'] == true;
          }
          _unreadCloudNotices = unread;
        });
      }
    } catch (_) {}

    try {
      final isIgnoring = await BackgroundGuardianService.instance.isIgnoringBatteryOptimizations();
      final isXiaomi = await BackgroundGuardianService.instance.isXiaomiDevice();
      final isGuardian = await BackgroundGuardianService.instance.isGuardianEnabled();
      if (mounted) {
        setState(() {
          _isIgnoringBattery = isIgnoring;
          _isXiaomi = isXiaomi;
          _isGuardianEnabled = isGuardian;
          _isWristKeyEnabled = SmartWristKeyService.isEnabled;
        });
      }
    } catch (_) {}
  }

  Future<void> _showCloudActivitySheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CloudActivitySheet(repository: AppVehicleRepository.instance),
    );
  }

  Future<void> _showPriceBookSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PriceBookSheet(
        onRatesUpdated: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _showBackgroundPushDialog() async {
    final t = context.tokens;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: t.ink3.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.notifications_active_rounded, color: t.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '24/7 Background Push & Alerts',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: t.ink),
                        ),
                        Text(
                          'Receive alarms & warnings without opening app',
                          style: TextStyle(fontSize: 11.5, color: t.ink2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isIgnoringBattery ? t.ok.withValues(alpha: 0.12) : const Color(0xFFFF9100).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isIgnoringBattery ? t.ok.withValues(alpha: 0.4) : const Color(0xFFFF9100).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isIgnoringBattery ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: _isIgnoringBattery ? t.ok : const Color(0xFFFF9100),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isIgnoringBattery
                            ? 'Battery Optimization: Unrestricted\nAndroid will not freeze TiggoMate in background.'
                            : 'Battery Optimization: Restricted\nAndroid may delay or block alerts when app is closed.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isIgnoringBattery ? t.ok : const Color(0xFFFF9100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Action 1: Request ignore battery optimizations
              if (!_isIgnoringBattery) ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    await BackgroundGuardianService.instance.requestIgnoreBatteryOptimizations();
                    final updated = await BackgroundGuardianService.instance.isIgnoringBatteryOptimizations();
                    setSheetState(() => _isIgnoringBattery = updated);
                    if (mounted) setState(() => _isIgnoringBattery = updated);
                  },
                  icon: const Icon(Icons.battery_charging_full_rounded, size: 18),
                  label: const Text('1. Allow Background Running (No Restrictions)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Action 2: Xiaomi / HyperOS Autostart
              if (_isXiaomi) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 16, color: t.accent),
                          const SizedBox(width: 6),
                          Text(
                            'Xiaomi HyperOS / MIUI Setup',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. Turn ON "Autostart"\n2. In "Battery saver", select "No restrictions"',
                        style: TextStyle(fontSize: 11.5, color: t.ink2, height: 1.4),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await BackgroundGuardianService.instance.openAutostartSettings();
                  },
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Open HyperOS / MIUI Autostart Settings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.ink,
                    side: BorderSide(color: t.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Action 3: Send Test Notification
              OutlinedButton.icon(
                onPressed: () async {
                  await VehicleAlertNotifier.raiseSystemNotification(
                    id: 9999,
                    title: 'TiggoMate 24/7 Guardian Active',
                    message: '✓ Background push notifications are active! You will receive alerts without opening the app.',
                    icon: Icons.notifications_active_rounded,
                  );
                  if (!context.mounted) return;
                  AppNotification.show(
                    context,
                    message: '🔔 Test notification sent to status bar!',
                    type: NotificationType.success,
                  );
                },
                icon: const Icon(Icons.notifications_outlined, size: 18),
                label: const Text('Send Test Status Bar Alert'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.ink,
                  side: BorderSide(color: t.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _nicknameController.dispose();
    _plateController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _hostController.dispose();
    _tnbController.dispose();
    _fuelController.dispose();
    super.dispose();
  }

  void _save() {
    final plate = _plateController.text.trim().toUpperCase();
    final updated = widget.settings.copyWith(
      ownerName: _ownerController.text.trim().isEmpty ? "Chery Owner" : _ownerController.text.trim(),
      vehicleNickname: _nicknameController.text.trim().isEmpty ? "Chery Tiggo 7 PHEV CSH" : _nicknameController.text.trim(),
      carPlateNumber: plate.isEmpty ? "VAG 7777" : plate,
      aiApiKey: _apiKeyController.text.trim(),
      aiModel: _modelController.text.trim().isEmpty ? "gpt-4o-mini" : _modelController.text.trim(),
      aiHost: _hostController.text.trim().isEmpty ? "http://10.0.2.2:8088" : _hostController.text.trim(),
      aiProvider: _provider,
      carLinkoStatus: _carLinkoStatus,
      tnbTariff: double.tryParse(_tnbController.text.trim()) ?? 0.57,
      fuelPrice: double.tryParse(_fuelController.text.trim()) ?? 2.05,
      vehicleSkinKey: _vehicleSkinKey,
    );
    VehicleSkinManager.instance.setSkin(_vehicleSkinKey);
    PriceBookService.instance.onCloudSync = FirebaseSyncService.instance.syncPriceBook;
    unawaited(
      PriceBookService.instance.recordSettingsRates(
        tnbTariff: updated.tnbTariff,
        fuelPrice: updated.fuelPrice,
      ),
    );
    widget.onSave(updated);
    Navigator.of(context).pop(updated);
    AppNotification.show(
      context,
      message: 'Settings saved successfully!',
      type: NotificationType.success,
      icon: Icons.check_circle_rounded,
    );
  }

  void _openMyTnbDialog() {
    showDialog(
      context: context,
      builder: (context) => MyTnbConnectDialog(
        repository: widget.myTnbRepo,
        currentTariff: double.tryParse(_tnbController.text) ?? 0.57,
        onTariffUpdated: (rate, account) {
          setState(() {
            _tnbController.text = rate.toStringAsFixed(3);
          });
        },
      ),
    );
  }

  Future<void> _testAiConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      AppNotification.show(
        context,
        message: 'Please enter an AI API Key first.',
        type: NotificationType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() => _isTestingAi = true);
    final res = await AiConfigResolver.testConnection(
      apiKey: key,
      provider: _provider,
      modelInput: _modelController.text,
      customHost: _hostController.text,
    );

    if (!mounted) return;
    setState(() => _isTestingAi = false);

    if (res.ok) {
      AppNotification.show(
        context,
        message: 'AI Connected: ${res.message} (${res.latencyMs}ms)',
        type: NotificationType.success,
        icon: Icons.auto_awesome_rounded,
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: t.danger, size: 20),
              const SizedBox(width: 8),
              Text('Connection Failed', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(res.message, style: TextStyle(color: t.ink2, fontSize: 13, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  // --- DashMate Group Container & Row Builders ---

  Widget _group(String title, List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) out.add(Divider(height: 1, indent: 56, color: t.border));
      out.add(rows[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink)),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.resolvedContainerLow,
            borderRadius: BorderRadius.circular(AppTokens.rXl),
            border: Border.all(color: t.border),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(children: out),
          ),
        ),
      ],
    );
  }

  Widget _inputRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: t.ink2, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.ink3)),
                TextField(
                  controller: controller,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
                  textCapitalization: textCapitalization,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(color: t.ink3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    Key? key,
    required Widget leading,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: key,
        leading: leading,
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12.5, color: t.ink2)),
        trailing: trailing ?? Icon(Icons.chevron_right, color: t.ink3, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _switchRow(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        secondary: Icon(icon, color: t.ink2, size: 22),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12.5, color: t.ink2)),
        activeTrackColor: t.accent.withValues(alpha: 0.5),
        activeThumbColor: t.accent,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  // --- Modal Pickers ---

  void _showSkinPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.resolvedContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tiggo Exterior Paint Skin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink)),
              const SizedBox(height: 4),
              Text('Synchronizes the 2D hero image and 3D exterior viewer.', style: TextStyle(fontSize: 13, color: t.ink2)),
              const SizedBox(height: 14),
              for (final skin in kOfficialVehicleSkins) ...[
                ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: skin.key == _vehicleSkinKey ? t.accent : t.border, width: 2),
                    ),
                    child: ClipOval(
                      child: skin.isDualTone
                          ? Stack(
                              children: [
                                Container(color: skin.primaryColor),
                                Align(alignment: Alignment.topCenter, child: Container(height: 14, color: skin.secondaryColor)),
                              ],
                            )
                          : Container(color: skin.primaryColor),
                    ),
                  ),
                  title: Text(skin.name, style: TextStyle(fontWeight: FontWeight.w600, color: t.ink)),
                  subtitle: Text('${skin.tag} · ${skin.priceInfo}', style: TextStyle(fontSize: 12, color: t.ink2)),
                  trailing: skin.key == _vehicleSkinKey ? Icon(Icons.check, color: t.accent) : null,
                  onTap: () async {
                    setState(() => _vehicleSkinKey = skin.key);
                    Navigator.pop(ctx);
                    await VehicleSkinManager.instance.setSkin(skin.key);
                    widget.onSave(widget.settings.copyWith(vehicleSkinKey: skin.key));
                  },
                ),
                Divider(height: 1, indent: 56, color: t.border),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeModePicker() {
    final themeCtrl = AppThemeController.instance;
    final cur = themeCtrl.themeMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.resolvedContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme Appearance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink)),
              const SizedBox(height: 4),
              Text('Choose your preferred dashboard cockpit aesthetic.', style: TextStyle(fontSize: 13, color: t.ink2)),
              const SizedBox(height: 12),
              for (final mode in const [
                [ThemeMode.dark, 'Obsidian Dark', 'High-contrast cyberpunk PHEV cockpit with neon glow'],
                [ThemeMode.light, 'Tesla Light', 'Pure minimalist white studio daylight contrast'],
                [ThemeMode.system, 'System Automatic', 'Mirrors your mobile phone day/night schedule'],
              ])
                ListTile(
                  leading: Icon(
                    mode[0] == ThemeMode.dark
                        ? Icons.nightlight_round
                        : (mode[0] == ThemeMode.light ? Icons.wb_sunny_rounded : Icons.brightness_auto),
                    color: t.ink2,
                  ),
                  title: Text(mode[1] as String, style: TextStyle(fontWeight: FontWeight.w600, color: t.ink)),
                  subtitle: Text(mode[2] as String, style: TextStyle(fontSize: 12, color: t.ink2)),
                  trailing: cur == mode[0] ? Icon(Icons.check, color: t.accent) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      themeCtrl.setThemeMode(mode[0] as ThemeMode);
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiProviderPicker() {
    const providers = ['Auto-Detect', 'OpenRouter', 'Direct OpenAI', 'Google Gemini', 'Groq', 'Custom Backend'];
    showModalBottomSheet(
      context: context,
      backgroundColor: t.resolvedContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Service Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink)),
              const SizedBox(height: 4),
              Text('Select backend engine for Chery Tiggo AI Copilot.', style: TextStyle(fontSize: 13, color: t.ink2)),
              const SizedBox(height: 12),
              for (final p in providers)
                ListTile(
                  title: Text(p, style: TextStyle(fontWeight: FontWeight.w600, color: t.ink)),
                  trailing: _provider == p ? Icon(Icons.check, color: t.accent) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _provider = p);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBluetoothDevicePicker() async {
    final devices = await BluetoothDrivingTrackerService.instance.getPairedDevices();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: t.resolvedContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl))),
      builder: (ctx) {
        final currentCustom = BluetoothDrivingTrackerService.instance.customCarBtName;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vehicle Bluetooth Device', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink)),
                  const SizedBox(height: 4),
                  Text('Select your Chery Tiggo Infotainment or CarLinko BLE device to trigger automatic tracking.', style: TextStyle(fontSize: 13, color: t.ink2)),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.auto_mode_rounded),
                    title: Text('Auto-detect (Default)', style: TextStyle(fontWeight: FontWeight.w600, color: t.ink)),
                    subtitle: Text('Matches any Chery, Tiggo, Jaecoo, Omoda or CarLinko device', style: TextStyle(fontSize: 12, color: t.ink2)),
                    trailing: currentCustom == null ? Icon(Icons.check, color: t.accent) : null,
                    onTap: () async {
                      await BluetoothDrivingTrackerService.instance.setCustomCarBtName(null);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
                  if (devices.isNotEmpty) ...[
                    const Divider(),
                    Text('Paired Devices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.ink3)),
                    const SizedBox(height: 4),
                    ...devices.map((d) {
                      final name = d['name'] ?? 'Unknown';
                      final isSel = currentCustom != null && currentCustom.toLowerCase() == name.toLowerCase();
                      return ListTile(
                        leading: const Icon(Icons.bluetooth_rounded),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: t.ink)),
                        subtitle: Text(d['address'] ?? '', style: TextStyle(fontSize: 12, color: t.ink2)),
                        trailing: isSel ? Icon(Icons.check, color: t.accent) : null,
                        onTap: () async {
                          await BluetoothDrivingTrackerService.instance.setCustomCarBtName(name);
                          if (ctx.mounted) Navigator.pop(ctx);
                          setState(() {});
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCarLinkoStatusPicker() {
    const states = [
      ['Active', 'Live Connected Vehicle', 'Real telemetry broadcast with active cloud sync'],
      ['Unactivated', 'Pending Car Bind', 'Awaiting dealer VIN binding on delivery or handover'],
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: t.resolvedContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.r2Xl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Telematics Connection State', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink)),
              const SizedBox(height: 12),
              for (final s in states)
                ListTile(
                  title: Text(s[1], style: TextStyle(fontWeight: FontWeight.w600, color: t.ink)),
                  subtitle: Text(s[2], style: TextStyle(fontSize: 12, color: t.ink2)),
                  trailing: _carLinkoStatus == s[0] ? Icon(Icons.check, color: t.accent) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _carLinkoStatus = s[0]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSkin = getVehicleSkinByKey(_vehicleSkinKey);
    final themeCtrl = AppThemeController.instance;
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Settings & Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: t.ink)),
        backgroundColor: t.bg,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _save,
              icon: Icon(Icons.check, size: 16, color: t.onAccent),
              label: Text('Save', style: TextStyle(color: t.onAccent, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Group 1: Driver & Vehicle Appearance
          _group('Driver & Car Look', [
            _buildSettingTile(
              leading: Icon(Icons.auto_awesome_rounded, color: t.accent, size: 22),
              title: 'Cockpit Setup Wizard',
              subtitle: 'Re-run initial car & driver onboarding',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SetupIntroScreen(
                      isRevisit: true,
                      onCompleted: () {
                        Navigator.pop(context);
                        _loadPreferences();
                      },
                    ),
                  ),
                );
              },
            ),
            _inputRow(
              icon: Icons.person_outline,
              label: 'Driver Profile Name',
              controller: _ownerController,
              hintText: 'e.g. Mohd Afix',
            ),
            _inputRow(
              icon: Icons.drive_file_rename_outline,
              label: 'Vehicle Nickname',
              controller: _nicknameController,
              hintText: 'e.g. Chery Tiggo 7 PHEV CSH',
            ),
            _inputRow(
              icon: Icons.badge_outlined,
              label: 'Car Plate Registration',
              controller: _plateController,
              hintText: 'e.g. VAG 7777',
              textCapitalization: TextCapitalization.characters,
            ),
            _buildSettingTile(
              leading: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentSkin.primaryColor,
                  border: Border.all(color: t.border),
                ),
              ),
              title: 'Exterior Paint Skin',
              subtitle: '${currentSkin.name} · ${currentSkin.tag}',
              onTap: _showSkinPicker,
            ),
            ValueListenableBuilder<Accent>(
              valueListenable: Accent.current,
              builder: (context, a, _) => _buildSettingTile(
                leading: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.isDark ? a.night : a.day,
                  ),
                ),
                title: 'Accent colour',
                subtitle: '${a.name} · dynamic highlights',
                onTap: () => Accent.showPicker(context),
              ),
            ),
            _buildSettingTile(
              leading: Icon(Icons.brightness_medium_outlined, color: t.ink2, size: 22),
              title: 'Appearance & Theme',
              subtitle: themeCtrl.themeMode == ThemeMode.dark
                  ? 'Obsidian Dark'
                  : (themeCtrl.themeMode == ThemeMode.light ? 'Tesla Light' : 'System Automatic'),
              onTap: _showThemeModePicker,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: DashboardStyle.useSage,
              builder: (context, useSage, _) => _switchRow(
                Icons.dashboard_customize_outlined,
                'Sage Cockpit dashboard',
                useSage ? 'New sage-green layout' : 'Legacy Cyber layout',
                useSage,
                (val) => DashboardStyle.set(val),
              ),
            ),
            _switchRow(Icons.access_time, '24-hour clock', _is24Hour ? '13:00' : '1:00 PM', _is24Hour, (val) async {
              setState(() => _is24Hour = val);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('tm_clock_24h', val);
              } catch (_) {}
            }),
            _switchRow(Icons.speed, 'Speed unit', _useKmh ? 'km/h' : 'mph', _useKmh, (val) async {
              setState(() => _useKmh = val);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('tm_speed_kmh', val);
              } catch (_) {}
            }),
          ]),

          // Group 2: Chery Tiggo Telematics (CarLinko)
          _group('Chery Tiggo Telematics', [
            _buildSettingTile(
              leading: Icon(Icons.cell_tower, color: t.ink2, size: 22),
              title: 'Telematics Connection State',
              subtitle: _carLinkoStatus == 'Active'
                  ? 'Active (Live Connected Vehicle)'
                  : 'Pending Car Bind (Awaiting Vehicle Pairing)',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_carLinkoStatus == 'Active' ? t.ok : Colors.orangeAccent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _carLinkoStatus == 'Active' ? 'ACTIVE' : 'PENDING BIND',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _carLinkoStatus == 'Active' ? t.ok : Colors.orangeAccent,
                  ),
                ),
              ),
              onTap: _showCarLinkoStatusPicker,
            ),
            _buildSettingTile(
              leading: Icon(
                AppVehicleRepository.instance.isCloudConnected ? Icons.cloud_done : Icons.link,
                color: AppVehicleRepository.instance.isCloudConnected ? t.ok : t.ink2,
                size: 22,
              ),
              title: AppVehicleRepository.instance.isCloudConnected
                  ? 'CarLinko Cloud Session'
                  : 'Connect CarLinko Account',
              subtitle: AppVehicleRepository.instance.isCloudConnected
                  ? 'Active Account: ${AppVehicleRepository.instance.connectedAccount ?? "Verified Session"}'
                  : 'Pair Malaysia VIN & CarLinko credentials',
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final savedAccount = prefs.getString('tm_carlinko_account') ??
                    AppVehicleRepository.instance.connectedAccount ??
                    '';
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => CarlinkoConnectDialog(
                    repository: AppVehicleRepository.instance,
                    currentAccount: savedAccount,
                    onConnected: () => setState(() => _carLinkoStatus = 'Active'),
                  ),
                );
              },
            ),
            _buildSettingTile(
              leading: Icon(Icons.troubleshoot_rounded, color: t.accent, size: 22),
              title: 'Advanced CAN Lab & Remote Diagnostics',
              subtitle: 'Test candidate opcodes, AES-128 handshake & inspect live T-Box frames',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  'LAB',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: t.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              onTap: () {
                RemoteCommandDiagnosticsSheet.show(
                  context,
                  repository: AppVehicleRepository.instance,
                );
              },
            ),
            _buildSettingTile(
              leading: Icon(Icons.history_rounded, color: t.ink2, size: 22),
              title: 'Cloud Operation Log & Notices',
              subtitle: _unreadCloudNotices > 0
                  ? '$_unreadCloudNotices unread CarLinko cloud notice(s)'
                  : 'Official T-Box remote command history & cloud alerts',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_unreadCloudNotices > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unreadCloudNotices',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Icon(Icons.chevron_right_rounded, color: t.ink3, size: 20),
                ],
              ),
              onTap: _showCloudActivitySheet,
            ),
            _switchRow(
              Icons.warning_amber_rounded,
              'Vehicle Anomaly Cloud Alerts',
              'CarLinko push warning for unexpected movement or door/intrusion events',
              _vehicleAnomalyAlert,
              (val) async {
                setState(() => _vehicleAnomalyAlert = val);
                final ok = await AppVehicleRepository.instance.setAlertSwitch(
                  configName: 'VEHICLE_ANOMALY',
                  enabled: val,
                );
                if (!ok && mounted) {
                  setState(() => _vehicleAnomalyAlert = !val);
                }
              },
            ),
            _switchRow(
              Icons.battery_alert_rounded,
              'Battery Anomaly Cloud Alerts',
              'CarLinko push warning for HV/12V battery or charging fault events',
              _batteryAnomalyAlert,
              (val) async {
                setState(() => _batteryAnomalyAlert = val);
                final ok = await AppVehicleRepository.instance.setAlertSwitch(
                  configName: 'BATTERY_ANOMALY',
                  enabled: val,
                );
                if (!ok && mounted) {
                  setState(() => _batteryAnomalyAlert = !val);
                }
              },
            ),
          ]),

          // 24/7 Background Push & Vehicle Guardian
          _group('24/7 Background Push & Alert Guardian', [
            _switchRow(
              Icons.shield_rounded,
              '24/7 Vehicle Guardian Mode',
              'Ensures door/window security, low 12V battery, charging status, and cloud notices trigger without opening the app.',
              _isGuardianEnabled,
              (val) async {
                setState(() => _isGuardianEnabled = val);
                await BackgroundGuardianService.instance.setGuardianEnabled(
                  val,
                  vehicleName: widget.settings.vehicleNickname.isNotEmpty
                      ? widget.settings.vehicleNickname
                      : 'Chery Tiggo 7 PHEV',
                );
              },
            ),
            _buildSettingTile(
              leading: Icon(
                Icons.battery_saver_rounded,
                color: _isIgnoringBattery ? t.ok : const Color(0xFFFF9100),
                size: 22,
              ),
              title: 'Background Push & Autostart Permissions',
              subtitle: _isIgnoringBattery
                  ? '🟢 Unrestricted: Android will not freeze background alerts'
                  : '⚠️ Android / HyperOS may freeze alerts when app closed • Tap to allow',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (_isIgnoringBattery ? t.ok : const Color(0xFFFF9100)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isIgnoringBattery ? 'ACTIVE' : 'ACTION REQUIRED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: _isIgnoringBattery ? t.ok : const Color(0xFFFF9100),
                  ),
                ),
              ),
              onTap: _showBackgroundPushDialog,
            ),
          ]),

          // Smartwatch & Wrist Key (Huawei Fit / Wear OS)
          _group('Smartwatch & Wrist Key (Huawei Fit / Wear OS)', [
            _switchRow(
              Icons.watch_rounded,
              'Wrist Quick Key Notification',
              'Mirrors interactive controls (Unlock, Lock, A/C, Trunk) to your Huawei Watch Fit, GT, Wear OS, and status bar.',
              _isWristKeyEnabled,
              (val) async {
                setState(() => _isWristKeyEnabled = val);
                await SmartWristKeyService.setEnabled(val);
                if (val) {
                  await SmartWristKeyService.updateWristKey(AppVehicleRepository.instance.currentTelemetry);
                }
              },
            ),
          ]),

          // Bluetooth Auto-Drive & Parking Tracker
          _group('Bluetooth Drive & Parking Tracker', [
            _switchRow(
              Icons.bluetooth_searching_rounded,
              'Auto Drive & Parking Tracker',
              'Auto-starts live telematics when connected; captures parking GPS & saves trip upon engine shutoff.',
              BluetoothDrivingTrackerService.instance.isEnabled,
              (val) async {
                await BluetoothDrivingTrackerService.instance.setEnabled(val);
                setState(() {});
              },
            ),
            _buildSettingTile(
              leading: Icon(
                Icons.bluetooth_connected_rounded,
                color: BluetoothDrivingTrackerService.instance.isCarConnected ? t.ok : t.ink2,
                size: 22,
              ),
              title: 'Paired Vehicle Bluetooth Device',
              subtitle: BluetoothDrivingTrackerService.instance.isCarConnected
                  ? 'Connected: ${BluetoothDrivingTrackerService.instance.connectedCarName}'
                  : (BluetoothDrivingTrackerService.instance.customCarBtName != null &&
                          BluetoothDrivingTrackerService.instance.customCarBtName!.isNotEmpty
                      ? 'Target: ${BluetoothDrivingTrackerService.instance.customCarBtName}'
                      : 'Auto-detect (Chery / Tiggo / Jaecoo / Omoda / CarLinko)'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (BluetoothDrivingTrackerService.instance.isCarConnected ? t.ok : t.ink3).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  BluetoothDrivingTrackerService.instance.isCarConnected ? 'CONNECTED' : 'AUTO',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: BluetoothDrivingTrackerService.instance.isCarConnected ? t.ok : t.ink2,
                  ),
                ),
              ),
              onTap: _showBluetoothDevicePicker,
            ),
          ]),

          // Group 3: Energy Economics & Fuel Tariffs
          _group('Energy & Fuel Tariffs', [
            ValueListenableBuilder<MyTnbAccount?>(
              valueListenable: widget.myTnbRepo.selectedAccountNotifier,
              builder: (context, account, _) {
                final isLinked = account != null;
                return _buildSettingTile(
                  leading: Icon(Icons.bolt, color: const Color(0xFFFF5252), size: 22),
                  title: 'myTNB Smart Meter Portal',
                  subtitle: isLinked
                      ? '${account.accountDesc} · RM ${account.effectiveTariff.toStringAsFixed(3)}/kWh'
                      : 'Connect myTNB for live residential tariffs',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isLinked ? t.ok : t.ink3).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isLinked ? (account.isSmartMeter ? 'SMART METER' : 'CONNECTED') : 'NOT CONNECTED',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isLinked ? t.ok : t.ink2,
                      ),
                    ),
                  ),
                  onTap: _openMyTnbDialog,
                );
              },
            ),
            _inputRow(
              icon: Icons.electric_meter_outlined,
              label: 'TNB Electricity Tariff (RM/kWh)',
              controller: _tnbController,
              hintText: '0.57',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            _inputRow(
              icon: Icons.local_gas_station_outlined,
              label: 'RON95 Petrol Price (RM/L)',
              controller: _fuelController,
              hintText: '2.05',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            _buildSettingTile(
              leading: Icon(Icons.timeline_rounded, color: t.accent, size: 22),
              title: 'Dated Tariff & Fuel Price History',
              subtitle: '${PriceBookService.instance.rules.length} active/historical rate period(s) preserved',
              trailing: Icon(Icons.chevron_right_rounded, color: t.ink3, size: 20),
              onTap: _showPriceBookSheet,
            ),
          ]),

          // Group 4: AI Assistant Configuration
          _group('AI Assistant & API', [
            _buildSettingTile(
              leading: Icon(Icons.hub_outlined, color: t.ink2, size: 22),
              title: 'AI Service Provider',
              subtitle: _provider,
              onTap: _showAiProviderPicker,
            ),
            _buildSettingTile(
              leading: Icon(Icons.psychology_outlined, color: t.ink2, size: 22),
              title: 'AI Model Identifier',
              subtitle: _modelController.text,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: t.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
                    title: Text('Select or Enter Model', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 17)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _modelController,
                          style: TextStyle(color: t.ink, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g. gpt-4o-mini',
                            filled: true,
                            fillColor: t.surface2,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Presets:', style: TextStyle(fontSize: 12, color: t.ink2)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _popularModels.map((m) {
                            final isSel = _modelController.text == m;
                            return ChoiceChip(
                              label: Text(m, style: TextStyle(fontSize: 11, color: isSel ? t.onAccent : t.ink)),
                              selected: isSel,
                              selectedColor: t.accent,
                              backgroundColor: t.surface2,
                              onSelected: (_) {
                                setState(() => _modelController.text = m);
                                Navigator.pop(ctx);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Done', style: TextStyle(color: t.accent))),
                    ],
                  ),
                );
              },
            ),
            _inputRow(
              icon: Icons.key_outlined,
              label: 'AI API Key (sk-... / AIzaSy...)',
              controller: _apiKeyController,
              hintText: 'sk-or-v1-... / sk-proj-... / AIzaSy...',
            ),
            _buildSettingTile(
              leading: _isTestingAi
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.accent))
                  : Icon(Icons.network_check, color: t.accent, size: 22),
              title: 'Test AI Connection',
              subtitle: _isTestingAi ? 'Pinging endpoint...' : 'Verify API key response & latency',
              onTap: _isTestingAi ? () {} : _testAiConnection,
            ),
            _inputRow(
              icon: Icons.dns_outlined,
              label: 'Backend Server URL',
              controller: _hostController,
              hintText: 'http://10.0.2.2:8088',
            ),
          ]),

          // Group 5: Account & Cloud Sync
          _group('Account & Cloud Sync', [
            _buildSettingTile(
              leading: Icon(Icons.cloud_done_outlined, color: t.ink2, size: 22),
              title: 'Account & Cloud Backup',
              subtitle: user.isAuthenticated ? '${user.displayName} · ${user.email}' : 'Browsing as Guest Driver',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (user.isAuthenticated ? t.ok : Colors.orangeAccent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.isAuthenticated ? 'SYNCED' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: user.isAuthenticated ? t.ok : Colors.orangeAccent,
                  ),
                ),
              ),
              onTap: () {
                if (user.isAuthenticated) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: t.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.border)),
                      title: Text('Sign Out?', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
                      content: Text('Do you want to sign out of ${user.email}?', style: TextStyle(color: t.ink2)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: t.ink2))),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: t.danger),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await AuthService().signOut();
                            setState(() {});
                          },
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                } else {
                  AuthSheet.show(
                    context,
                    onProfileUpdated: () {
                      setState(() {
                        final u = AuthService().currentUser;
                        _ownerController.text = u.displayName;
                        _plateController.text = u.carPlate;
                      });
                    },
                  );
                }
              },
            ),
          ]),

          const SizedBox(height: 24),

          // DashMate-style Legal & Version Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: t.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Legal Disclaimer / Penafian',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: t.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'TiggoMate is an independent, unofficial vehicle companion designed for Malaysian Chery Tiggo 7 & 8 PHEV/ICE owners. Not affiliated with Chery Malaysia or CarLinko. Live smart charging and trips calculations are estimates based on your configured tariffs.',
                  style: TextStyle(fontSize: 12, color: t.ink3, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              'TiggoMate 2.0 (CSH Edition)\nCrafted for Malaysian Chery Owners',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.ink3, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudActivitySheet extends StatefulWidget {
  final VehicleRepository repository;

  const _CloudActivitySheet({required this.repository});

  @override
  State<_CloudActivitySheet> createState() => _CloudActivitySheetState();
}

class _CloudActivitySheetState extends State<_CloudActivitySheet> {
  bool _loading = true;
  int _tab = 0; // 0 = Operations, 1 = Cloud Notices
  List<Map<String, dynamic>> _ops = [];
  List<Map<String, dynamic>> _notices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final opsFuture = widget.repository.getOperatingRecord();
    final noticesFuture = widget.repository.getCloudNotifications(page: 1, size: 30);
    final ops = await opsFuture;
    final notices = await noticesFuture;
    if (!mounted) return;
    setState(() {
      _ops = ops;
      _notices = notices;
      _loading = false;
    });
  }

  String _pick(Map<String, dynamic> row, List<String> keys, {String fallback = ''}) {
    for (final k in keys) {
      final v = row[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = _tab == 0 ? _ops : _notices;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.ink3.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
            child: Row(
              children: [
                Icon(Icons.cloud_queue_rounded, color: t.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CarLinko Cloud Log & Notices',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: t.ink),
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  icon: Icon(Icons.refresh_rounded, color: t.ink2, size: 20),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: t.ink3, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('Command History (${_ops.length})'),
                    selected: _tab == 0,
                    onSelected: (_) => setState(() => _tab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text('Cloud Notices (${_notices.length})'),
                    selected: _tab == 1,
                    onSelected: (_) => setState(() => _tab = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: Text(
                          widget.repository.isCloudConnected
                              ? 'No CarLinko cloud records found yet.'
                              : 'Connect CarLinko account to view cloud logs.',
                          style: TextStyle(color: t.ink3, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => Divider(color: t.border, height: 12),
                        itemBuilder: (_, idx) {
                          final row = items[idx];
                          final title = _pick(
                            row,
                            ['operatingName', 'operateName', 'title', 'noticeTitle', 'typeName', 'data'],
                            fallback: _tab == 0 ? 'Remote Command' : 'Vehicle Notice',
                          );
                          final subtitle = _pick(
                            row,
                            ['operatingResult', 'resultMsg', 'content', 'noticeContent', 'remark', 'msg'],
                          );
                          final ts = _pick(row, ['createTime', 'operateTime', 'noticeTime', 'updateTime', 'time']);
                          final okFlag = row['status'] ?? row['operatingStatus'];

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: t.accent.withValues(alpha: 0.14),
                              child: Icon(
                                _tab == 0 ? Icons.settings_remote_rounded : Icons.notifications_active_outlined,
                                size: 17,
                                color: t.accent,
                              ),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (subtitle.isNotEmpty)
                                  Text(subtitle, style: TextStyle(fontSize: 12, color: t.ink2)),
                                if (ts.isNotEmpty)
                                  Text(ts, style: TextStyle(fontSize: 10.5, color: t.ink3)),
                              ],
                            ),
                            trailing: okFlag != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (okFlag == 1 || okFlag == true || okFlag == '00'
                                              ? t.ok
                                              : Colors.orangeAccent)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      okFlag.toString(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: okFlag == 1 || okFlag == true || okFlag == '00'
                                            ? t.ok
                                            : Colors.orangeAccent,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PriceBookSheet extends StatefulWidget {
  final VoidCallback onRatesUpdated;

  const _PriceBookSheet({required this.onRatesUpdated});

  @override
  State<_PriceBookSheet> createState() => _PriceBookSheetState();
}

class _PriceBookSheetState extends State<_PriceBookSheet> {
  Future<void> _showAddRuleDialog() async {
    var kind = PriceKind.charge;
    var scope = ChargeScope.ac;
    var effectiveDate = DateTime.now();
    final priceCtrl = TextEditingController(text: '0.57');
    final labelCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final t = context.tokens;
          return AlertDialog(
            backgroundColor: t.surface,
            title: Text('Add Dated Rate Rule', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Charging (kWh)'),
                          selected: kind == PriceKind.charge,
                          onSelected: (_) => setDialogState(() {
                            kind = PriceKind.charge;
                            priceCtrl.text = '0.57';
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Petrol (L)'),
                          selected: kind == PriceKind.fuel,
                          onSelected: (_) => setDialogState(() {
                            kind = PriceKind.fuel;
                            scope = ChargeScope.all;
                            priceCtrl.text = '2.05';
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (kind == PriceKind.charge) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ChargeScope>(
                      initialValue: scope,
                      decoration: const InputDecoration(labelText: 'Charger Type'),
                      items: const [
                        DropdownMenuItem(value: ChargeScope.ac, child: Text('Home / AC')),
                        DropdownMenuItem(value: ChargeScope.dc, child: Text('Public / DC Fast')),
                        DropdownMenuItem(value: ChargeScope.all, child: Text('All Charging')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => scope = v);
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Effective From', style: TextStyle(fontSize: 12, color: t.ink2)),
                    subtitle: Text(
                      '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.ink),
                    ),
                    trailing: Icon(Icons.calendar_today_rounded, color: t.accent, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: effectiveDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => effectiveDate = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: kind == PriceKind.charge ? 'Rate (RM / kWh)' : 'Price (RM / L)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label (optional)',
                      hintText: 'e.g. TNB AFA Adjustment',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final rate = double.tryParse(priceCtrl.text.trim());
      if (rate != null && rate > 0) {
        await PriceBookService.instance.addOrUpdateRule(
          PriceRule(
            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
            kind: kind,
            scope: kind == PriceKind.fuel ? ChargeScope.all : scope,
            effectiveFrom: effectiveDate,
            pricePerUnit: rate,
            label: labelCtrl.text.trim().isEmpty
                ? (kind == PriceKind.fuel ? 'RON95 Period' : 'EV Tariff Period')
                : labelCtrl.text.trim(),
          ),
        );
        if (mounted) {
          setState(() {});
          widget.onRatesUpdated();
        }
      }
    }
    priceCtrl.dispose();
    labelCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rules = PriceBookService.instance.rules;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: t.ink3.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
            child: Row(
              children: [
                Icon(Icons.timeline_rounded, color: t.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dated Tariff & Fuel Price Book',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: t.ink)),
                      Text('Preserves historical trip & charge costs across rate changes',
                          style: TextStyle(fontSize: 11, color: t.ink3)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddRuleDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Divider(color: t.border, height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              separatorBuilder: (_, _) => Divider(color: t.border, height: 12),
              itemBuilder: (_, idx) {
                final r = rules[idx];
                final dateStr =
                    '${r.effectiveFrom.year}-${r.effectiveFrom.month.toString().padLeft(2, '0')}-${r.effectiveFrom.day.toString().padLeft(2, '0')}';
                final isFuel = r.kind == PriceKind.fuel;
                final unit = isFuel ? '/L' : '/kWh';
                final tag = isFuel ? 'FUEL' : r.scope.name.toUpperCase();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: (isFuel ? Colors.orangeAccent : t.accent).withValues(alpha: 0.14),
                    child: Icon(
                      isFuel ? Icons.local_gas_station_outlined : Icons.bolt_rounded,
                      size: 17,
                      color: isFuel ? Colors.orangeAccent : t.accent,
                    ),
                  ),
                  title: Text(
                    'RM ${r.pricePerUnit.toStringAsFixed(r.pricePerUnit == 1.3 ? 2 : 3)}$unit • ${r.label.isNotEmpty ? r.label : tag}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: t.ink),
                  ),
                  subtitle: Text('Effective from $dateStr • $tag', style: TextStyle(fontSize: 11.5, color: t.ink3)),
                  trailing: rules.length > 1
                      ? IconButton(
                          icon: Icon(Icons.delete_outline, color: t.ink3, size: 18),
                          onPressed: () async {
                            await PriceBookService.instance.deleteRule(r.id);
                            if (mounted) {
                              setState(() {});
                              widget.onRatesUpdated();
                            }
                          },
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
