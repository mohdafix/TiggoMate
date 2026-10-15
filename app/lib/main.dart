import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/ai/ai_service.dart';
import 'src/carlinko/vehicle_repository.dart';
import 'src/mytnb/mytnb_api.dart';
import 'src/ui/mytnb_connect_dialog.dart';
import 'src/ui/neo_dashboard.dart';
import 'src/ui/chery_service_centres_screen.dart';
import 'src/ui/trips_logbook_screen.dart';

void main() {
  runApp(const TiggoMateApp());
}

class TiggoMateApp extends StatelessWidget {
  const TiggoMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TiggoMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2AA),
          secondary: Color(0xFF2F81F7),
          surface: Color(0xFF131922),
          error: Color(0xFFF85149),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF131922),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF232D3D)),
          ),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ---------------- APP SETTINGS & PROFILE MODEL ----------------

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
    );
  }
}

class SettingsService {
  static const _kOwner = 'tm_owner_name';
  static const _kPlate = 'tm_car_plate';
  static const _kNickname = 'tm_vehicle_nickname';
  static const _kApiKey = 'tm_ai_api_key';
  static const _kModel = 'tm_ai_model';
  static const _kHost = 'tm_ai_host';
  static const _kProvider = 'tm_ai_provider';
  static const _kCarLinko = 'tm_carlinko_status';
  static const _kTnb = 'tm_tnb_tariff';
  static const _kFuel = 'tm_fuel_price';

  static Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings(
        ownerName: prefs.getString(_kOwner) ?? "Chery Owner",
        carPlateNumber: prefs.getString(_kPlate) ?? "VAG 7777",
        vehicleNickname: prefs.getString(_kNickname) ?? "Chery Tiggo 7 PHEV CSH",
        aiApiKey: prefs.getString(_kApiKey) ?? "",
        aiModel: prefs.getString(_kModel) ?? "gpt-4o-mini",
        aiHost: prefs.getString(_kHost) ?? "http://10.0.2.2:8088",
        aiProvider: prefs.getString(_kProvider) ?? "OpenRouter",
        carLinkoStatus: prefs.getString(_kCarLinko) ?? "Unactivated",
        tnbTariff: prefs.getDouble(_kTnb) ?? 0.57,
        fuelPrice: prefs.getDouble(_kFuel) ?? 2.05,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  static Future<void> save(AppSettings s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOwner, s.ownerName);
      await prefs.setString(_kPlate, s.carPlateNumber);
      await prefs.setString(_kNickname, s.vehicleNickname);
      await prefs.setString(_kApiKey, s.aiApiKey);
      await prefs.setString(_kModel, s.aiModel);
      await prefs.setString(_kHost, s.aiHost);
      await prefs.setString(_kProvider, s.aiProvider);
      await prefs.setString(_kCarLinko, s.carLinkoStatus);
      await prefs.setDouble(_kTnb, s.tnbTariff);
      await prefs.setDouble(_kFuel, s.fuelPrice);
    } catch (_) {}
  }
}

// ---------------- SETTINGS & PROFILE SCREEN ----------------

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
  bool _obscureApiKey = true;

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
    );
    widget.onSave(updated);
    Navigator.of(context).pop(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: Color(0xFF00D2AA),
        behavior: SnackBarBehavior.floating,
      ),
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

  bool _isTestingAi = false;

  Future<void> _testAiConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an AI API Key first.'),
          backgroundColor: Color(0xFFF85149),
          behavior: SnackBarBehavior.floating,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${res.message} (${res.latencyMs}ms)'),
          backgroundColor: const Color(0xFF00D2AA),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131922),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFF85149)),
              SizedBox(width: 8),
              Text('AI Connection Test Failed', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Text(
            res.message,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Color(0xFF00D2AA))),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, color: Color(0xFF00D2AA), size: 18),
            label: const Text('Save', style: TextStyle(color: Color(0xFF00D2AA), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Vehicle & Owner Profile
          _buildSectionHeader('VEHICLE & OWNER PROFILE', Icons.directions_car_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _ownerController,
                    decoration: const InputDecoration(
                      labelText: 'Owner / Driver Name',
                      hintText: 'e.g. Alex',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Nickname',
                      hintText: 'e.g. Chery Tiggo 7 PHEV CSH',
                      prefixIcon: Icon(Icons.drive_file_rename_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Car Plate Registration Number',
                      hintText: 'e.g. VAG 7777',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      helperText: 'Displayed on Home card and included in AI context',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: AI Assistant & API Keys
          _buildSectionHeader('AI ASSISTANT & API CONFIGURATION', Icons.auto_awesome),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: ['Auto-Detect', 'OpenRouter', 'Direct OpenAI', 'Google Gemini', 'Groq', 'Custom Backend'].contains(_provider)
                        ? _provider
                        : 'Auto-Detect',
                    decoration: const InputDecoration(
                      labelText: 'AI Service Provider',
                      prefixIcon: Icon(Icons.hub_outlined, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Auto-Detect', child: Text('Auto-Detect (Based on API Key)')),
                      DropdownMenuItem(value: 'OpenRouter', child: Text('OpenRouter (Direct Mobile AI)')),
                      DropdownMenuItem(value: 'Direct OpenAI', child: Text('Direct OpenAI (api.openai.com)')),
                      DropdownMenuItem(value: 'Google Gemini', child: Text('Google Gemini (AIzaSy...)')),
                      DropdownMenuItem(value: 'Groq', child: Text('Groq (Fast Inference)')),
                      DropdownMenuItem(value: 'Custom Backend', child: Text('Custom Backend Server')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _provider = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: 'AI API Key',
                      hintText: 'sk-or-v1-... / sk-proj-... / AIzaSy...',
                      prefixIcon: const Icon(Icons.key_outlined, size: 20),
                      helperText: 'Auto-routes: sk-or- ➔ OpenRouter, sk-proj- ➔ OpenAI, AIzaSy ➔ Gemini',
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'AI Model Identifier',
                      hintText: 'gpt-4o-mini',
                      prefixIcon: Icon(Icons.psychology_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Quick Model Presets:', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _popularModels.map((m) {
                      final isSelected = _modelController.text == m;
                      return ChoiceChip(
                        label: Text(m, style: TextStyle(fontSize: 10.5, color: isSelected ? const Color(0xFF00D2AA) : Colors.white70)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF00D2AA).withValues(alpha: 0.15),
                        backgroundColor: const Color(0xFF090D12),
                        side: BorderSide(color: isSelected ? const Color(0xFF00D2AA) : const Color(0xFF232D3D)),
                        onSelected: (_) => setState(() => _modelController.text = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // Test AI Connection Button
                  OutlinedButton.icon(
                    onPressed: _isTestingAi ? null : _testAiConnection,
                    icon: _isTestingAi
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D2AA)))
                        : const Icon(Icons.network_check, size: 16, color: Color(0xFF00D2AA)),
                    label: Text(
                      _isTestingAi ? 'Testing Connection...' : 'Test AI Connection',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF00D2AA), fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00D2AA)),
                      minimumSize: const Size(double.infinity, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Backend Server URL',
                      hintText: 'http://10.0.2.2:8088',
                      prefixIcon: Icon(Icons.dns_outlined, size: 20),
                      helperText: 'Used for telemetry sync and local server queries',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Telematics & Connection Status
          _buildSectionHeader('CARLINKO TELEMATICS', Icons.wifi_tethering),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _carLinkoStatus,
                    decoration: const InputDecoration(
                      labelText: 'Telematics Connection State',
                      prefixIcon: Icon(Icons.cell_tower, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Unactivated',
                        child: Text('Unactivated (1,000 km Inspection Due)'),
                      ),
                      DropdownMenuItem(
                        value: 'Active',
                        child: Text('Active (Live Connected CarLinko)'),
                      ),
                      DropdownMenuItem(
                        value: 'Demo',
                        child: Text('Demo Mode (Simulated Data)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _carLinkoStatus = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _carLinkoStatus == 'Active'
                        ? 'Vehicle displays LIVE TELEMATICS status with active sync.'
                        : 'Displays honest SIMULATED / UNACTIVATED provenance label.',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Energy Economics & Fuel Tariffs
          _buildSectionHeader('MALAYSIAN ENERGY & FUEL TARIFFS', Icons.bolt),
          Card(
            color: const Color(0xFF131922),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ValueListenableBuilder<MyTnbAccount?>(
                valueListenable: widget.myTnbRepo.selectedAccountNotifier,
                builder: (context, account, _) {
                  final isLinked = account != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.bolt, color: Color(0xFFFF5252), size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'myTNB Smart Meter Portal',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isLinked
                                  ? const Color(0xFF00D2AA).withValues(alpha: 0.15)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isLinked ? const Color(0xFF00D2AA) : Colors.white24,
                              ),
                            ),
                            child: Text(
                              isLinked ? (account.isSmartMeter ? 'SMART METER' : 'CONNECTED') : 'NOT CONNECTED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isLinked ? const Color(0xFF00D2AA) : Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (isLinked) ...[
                        Text(
                          '${account.accountDesc} (CA: ${account.accountNumber})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Month Usage: ${account.currentUsageKwh.toStringAsFixed(1)} kWh • Dynamic Tariff: RM ${account.effectiveTariff.toStringAsFixed(3)}/kWh • Bill: RM ${account.currentCharges.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openMyTnbDialog,
                                icon: const Icon(Icons.tune, size: 14, color: Color(0xFF00D2AA)),
                                label: const Text('Manage / Refresh', style: TextStyle(fontSize: 11.5, color: Color(0xFF00D2AA))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF00D2AA)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'Connect your myTNB login to automatically fetch half-hourly smart meter readings and live residential tariff tiers.',
                          style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _openMyTnbDialog,
                          icon: const Icon(Icons.sync, size: 16, color: Colors.black87),
                          label: const Text('Connect myTNB Smart Meter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D2AA),
                            minimumSize: const Size(double.infinity, 38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tnbController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'TNB Tariff (RM/kWh)',
                        prefixText: 'RM ',
                        helperText: 'Default: 0.57',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fuelController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'RON95 Price (RM/L)',
                        prefixText: 'RM ',
                        helperText: 'Default: 2.05',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline, color: Colors.black87),
            label: const Text('Save Settings', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D2AA),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),

          // Reset to Defaults
          TextButton(
            onPressed: () {
              setState(() {
                _ownerController.text = "Chery Owner";
                _nicknameController.text = "Chery Tiggo 7 PHEV CSH";
                _plateController.text = "VAG 7777";
                _apiKeyController.text = "";
                _modelController.text = "gpt-4o-mini";
                _hostController.text = "http://10.0.2.2:8088";
                _provider = "OpenRouter";
                _carLinkoStatus = "Unactivated";
                _tnbController.text = "0.57";
                _fuelController.text = "2.05";
              });
            },
            child: const Text('Reset to Factory Defaults', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00D2AA)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- MAIN NAVIGATION ----------------

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  AppSettings _settings = const AppSettings();
  final VehicleRepository _vehicleRepo = MockVehicleRepository();
  final MyTnbRepository _myTnbRepo = MyTnbRepository();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _vehicleRepo.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await SettingsService.load();
    await _myTnbRepo.init();
    if (mounted) {
      setState(() {
        _settings = s;
        _loading = false;
      });
    }
  }

  void _openSettings() async {
    final updated = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          settings: _settings,
          myTnbRepo: _myTnbRepo,
          onSave: (s) async {
            setState(() => _settings = s);
            await SettingsService.save(s);
          },
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _settings = updated);
      await SettingsService.save(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D2AA)),
        ),
      );
    }

    final pages = [
      NeoDashboard(
        repository: _vehicleRepo,
        ownerName: _settings.ownerName,
        carPlateNumber: _settings.carPlateNumber,
        vehicleNickname: _settings.vehicleNickname,
        tnbTariff: _settings.tnbTariff,
        fuelPrice: _settings.fuelPrice,
        onOpenSettings: _openSettings,
        onOpenAssistant: () => setState(() => _currentIndex = 1),
      ),
      AssistantTab(
        settings: _settings,
        onOpenSettings: _openSettings,
      ),
      TripsLogbookScreen(
        tnbTariff: _settings.tnbTariff,
        fuelPrice: _settings.fuelPrice,
        currentOdometerKm: 1420,
        currentBatteryPct: 78,
        myTnbRepo: _myTnbRepo,
      ),
      MaintenanceTab(settings: _settings),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: const Color(0xFF0D1117),
        indicatorColor: const Color(0xFF00D2AA).withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car, color: Color(0xFF00D2AA)),
            label: 'Vehicle',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF00D2AA)),
            label: 'Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route, color: Color(0xFF00D2AA)),
            label: 'Trips & Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build, color: Color(0xFF00D2AA)),
            label: 'Service',
          ),
        ],
      ),
    );
  }
}

// ---------------- TAB 1: VEHICLE DASHBOARD ----------------
class DashboardTab extends StatefulWidget {
  final AppSettings settings;
  final Function(int) onNavigateToTab;
  final VoidCallback onOpenSettings;
  const DashboardTab({
    required this.settings,
    required this.onNavigateToTab,
    required this.onOpenSettings,
    super.key,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final VehicleRepository _repo = MockVehicleRepository();

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NeoDashboard(
      repository: _repo,
      ownerName: widget.settings.ownerName,
      carPlateNumber: widget.settings.carPlateNumber,
      vehicleNickname: widget.settings.vehicleNickname,
      tnbTariff: widget.settings.tnbTariff,
      fuelPrice: widget.settings.fuelPrice,
      onOpenSettings: widget.onOpenSettings,
      onOpenAssistant: () => widget.onNavigateToTab(1),
    );
  }

}

// ---------------- TAB 2: AI ASSISTANT ----------------

/// Renders markdown formatted messages with headings, bold, italic,
/// bullet lists, numbered lists, blockquotes, code chips, and code blocks.
class MarkdownMessageView extends StatelessWidget {
  final String content;
  final TextStyle baseStyle;
  final Color accentColor;

  const MarkdownMessageView({
    super.key,
    required this.content,
    this.baseStyle = const TextStyle(fontSize: 13.5, height: 1.45, color: Colors.white),
    this.accentColor = const Color(0xFF00D2AA),
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<Widget> _parseBlocks(String text) {
    final widgets = <Widget>[];
    final lines = text.split('\n');
    bool inCodeBlock = false;
    final codeBlockLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Code block handling
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(_buildCodeBlock(codeBlockLines.join('\n')));
          codeBlockLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(line);
        continue;
      }

      // Empty line / paragraph break
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Headings
      if (trimmed.startsWith('#### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            trimmed.substring(5).trim(),
            style: baseStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ));
      } else if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            trimmed.substring(4).trim(),
            style: baseStyle.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            trimmed.substring(3).trim(),
            style: baseStyle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            trimmed.substring(2).trim(),
            style: baseStyle.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ));
      }
      // Blockquote
      else if (trimmed.startsWith('> ')) {
        final quoteContent = trimmed.substring(2).trim();
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: accentColor, width: 3)),
          ),
          child: RichText(
            text: TextSpan(
              children: _parseInlineMarkdown(
                quoteContent,
                baseStyle.copyWith(fontSize: 12.5, color: Colors.white70),
              ),
            ),
          ),
        ));
      }
      // Bullet list (- or *)
      else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final itemText = trimmed.substring(2).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 8, left: 2),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: _parseInlineMarkdown(itemText, baseStyle),
                  ),
                ),
              ),
            ],
          ),
        ));
      }
      // Numbered list (e.g. 1. , 2. )
      else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
        final numStr = match?.group(1) ?? '1';
        final itemText = match?.group(2) ?? '';
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '$numStr.',
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: _parseInlineMarkdown(itemText, baseStyle),
                  ),
                ),
              ),
            ],
          ),
        ));
      }
      // Regular paragraph line
      else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: RichText(
            text: TextSpan(
              children: _parseInlineMarkdown(line, baseStyle),
            ),
          ),
        ));
      }
    }

    if (inCodeBlock && codeBlockLines.isNotEmpty) {
      widgets.add(_buildCodeBlock(codeBlockLines.join('\n')));
    }

    return widgets;
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF232D3D)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF00D2AA),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _parseInlineMarkdown(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|__(.+?)__|`([^`\n]+)`|\*([^*\n]+?)\*)',
      dotAll: true,
    );

    int lastIndex = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: style,
        ));
      }

      final fullMatch = match.group(0)!;
      if (fullMatch.startsWith('***') && fullMatch.endsWith('***')) {
        spans.add(TextSpan(
          text: match.group(2) ?? '',
          style: style.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if ((fullMatch.startsWith('**') && fullMatch.endsWith('**')) ||
                 (fullMatch.startsWith('__') && fullMatch.endsWith('__'))) {
        final inner = match.group(3) ?? match.group(4) ?? '';
        spans.add(TextSpan(
          text: inner,
          style: style.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF232D3D),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              match.group(5) ?? '',
              style: style.copyWith(
                fontFamily: 'monospace',
                fontSize: (style.fontSize ?? 13.5) * 0.9,
                color: const Color(0xFF00D2AA),
              ),
            ),
          ),
        ));
      } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
        spans.add(TextSpan(
          text: match.group(6) ?? '',
          style: style.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return spans;
  }
}

class AssistantTab extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onOpenSettings;
  const AssistantTab({
    super.key,
    required this.settings,
    required this.onOpenSettings,
  });

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [
    {
      "role": "assistant",
      "content": "Hello! I am your AI assistant for the **Chery Tiggo 7 PHEV CSH** in Malaysia.\n\nI can explain hybrid driving modes (AUTO, EV, HEV), assist with your upcoming 1,000 km CarLinko inspection, calculate TNB charging costs, or guide you on highway battery preservation.",
      "citations": []
    }
  ];
  bool _loading = false;

  final List<String> _suggestions = [
    "Why hasn't my petrol engine started in AUTO mode?",
    "When is my 1,000 km CarLinko inspection due?",
    "How much is my 20,000 km & 40,000 km service?",
    "When do I replace 3DHT transmission oil & spark plugs?",
    "Calculate 100 km charging cost vs petrol"
  ];

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.add({"role": "user", "content": text});
      _loading = true;
    });
    _scrollToBottom();

    // 1. Direct Cloud AI call if API key is provided
    if (widget.settings.aiApiKey.trim().isNotEmpty) {
      final config = AiConfigResolver.resolve(
        apiKey: widget.settings.aiApiKey,
        provider: widget.settings.aiProvider,
        modelInput: widget.settings.aiModel,
        customHost: widget.settings.aiHost,
      );

      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        final request = await client.postUrl(Uri.parse(config.endpoint));
        config.headers.forEach((k, v) => request.headers.set(k, v));

        final systemPrompt = "You are TiggoMate AI, personal vehicle assistant for the Chery Tiggo 7 PHEV CSH in Malaysia.\n"
            "Owner: ${widget.settings.ownerName}, Vehicle Plate: ${widget.settings.carPlateNumber}, Nickname: ${widget.settings.vehicleNickname}.\n"
            "Vehicle Specs: 1.5L Turbo + 3-speed Dedicated Hybrid Transmission (3DHT) + Dual Electric Motors, 240 kW (326 PS) / 545 Nm system torque.\n"
            "Tyres & Wheels: 225/55 R19 99V tyres, 19-inch Aero Alloy Wheels (5x108 PCD). Cold Tyre Pressure: 230 kPa (2.3 bar / 33.4 psi) on all 4 tyres. Spare tyre: tyre repair sealant kit + 12V air compressor under boot luggage floor.\n"
            "19.27 kWh LFP battery pack (80-100 km EV range), 51L petrol tank (~792-965 km combined range). Type 2 AC charging (3.3 kW, ~5.5 hours 0-100%). AUTO mode prioritizes EV until battery drops below ~20-25% SOC or hard acceleration.\n"
            "Engine Oil: Fully Synthetic C5 0W-20 (4.7L, RM 270.00). Spark plugs: replaced every 30,000 km (RM 308.40). Major powertrain fluids: 40,000 km (3DHT transmission oil RM 399.20, coolant RM 141.80, brake fluid RM 100.00).\n"
            "Official Service Milestones (27 Aug 2026): 1k km (FOC), 10k km (RM 407.50), 20k km (RM 444.60, FOC labour), 30k km (RM 715.90), "
            "40k km (RM 1,085.60, FOC labour), 60k km (RM 753.00, FOC labour), 120k km (RM 1,644.00 major overhaul). Free labour at 1k, 20k, 40k, 60k, 80k, 100k km. TNB: RM ${widget.settings.tnbTariff}/kWh, RON95: RM ${widget.settings.fuelPrice}/L.\n"
            "Warranty: 7 Years / 150,000 km vehicle warranty, 8 Years / 160,000 km battery & hybrid system warranty (1-to-1 replacement if SOH < 70%).\n"
            "Always be helpful, concise, format answers in markdown with bolding and bullet lists, and answer directly based on Chery Tiggo 7 PHEV Malaysian specs.";

        // Notice: _messages already contains the user message from line 1259, so we pass _messages directly!
        final conversation = [
          {"role": "system", "content": systemPrompt},
          ..._messages.map((m) => {"role": m["role"], "content": m["content"]}),
        ];

        final payload = jsonEncode({
          "model": config.model,
          "messages": conversation,
          "temperature": 0.5,
          "max_tokens": 1024,
        });

        final utf8Payload = utf8.encode(payload);
        request.headers.contentLength = utf8Payload.length;
        request.add(utf8Payload);
        final res = await request.close();
        final rawBody = await res.transform(utf8.decoder).join();

        if (res.statusCode == 200) {
          final data = jsonDecode(rawBody);
          final replyContent = data["choices"]?[0]?["message"]?["content"];
          if (replyContent != null && replyContent.toString().trim().isNotEmpty) {
            setState(() {
              _messages.add({
                "role": "assistant",
                "content": replyContent.toString().trim(),
                "citations": [
                  {"document": "${config.providerName} (${config.model})", "section": "Live Cloud AI", "page": 1}
                ],
              });
              _loading = false;
            });
            _scrollToBottom();
            return;
          }
        } else {
          // Parse exact error from provider
          String errorDesc = "HTTP ${res.statusCode}";
          try {
            final data = jsonDecode(rawBody);
            if (data is Map && data.containsKey("error")) {
              final errObj = data["error"];
              if (errObj is Map && errObj.containsKey("message")) {
                errorDesc = errObj["message"].toString();
              } else {
                errorDesc = errObj.toString();
              }
            } else if (data is Map && data.containsKey("message")) {
              errorDesc = data["message"].toString();
            }
          } catch (_) {}

          setState(() {
            _messages.add({
              "role": "assistant",
              "content": "⚠️ **Live Cloud AI Failed (${config.providerName})**\n\n"
                  "**Error (${res.statusCode}):** $errorDesc\n\n"
                  "💡 *Tip:* Test your key in **Settings ➔ AI Configuration ➔ Test AI Connection**.\n\n"
                  "---\n"
                  "*(Local Vehicle Handbook Response Below)*",
              "citations": [
                {"document": "${config.providerName} Error", "section": "API Diagnostic", "page": 1}
              ],
            });
          });
        }
      } catch (e) {
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "⚠️ **Cloud Connection Error (${config.providerName})**\n\n"
                "**Details:** $e\n\n"
                "---\n"
                "*(Local Vehicle Handbook Response Below)*",
            "citations": [
              {"document": "Network Diagnostics", "section": "Connection Error", "page": 1}
            ],
          });
        });
      }
    }

    // 2. Local grounded fallback with comprehensive Chery Tiggo 7 PHEV specifications
    await Future.delayed(const Duration(milliseconds: 400));
    String answer = "";
    List<dynamic> citations = [];

    String q = text.toLowerCase();
    if (q.contains("tyre") || q.contains("tire") || q.contains("pressure") || q.contains("wheel") || q.contains("rim") || q.contains("tpms") || q.contains("tayar")) {
      answer = "### Chery Tiggo 7 PHEV CSH — Tyre & Wheel Specifications\n\n"
          "- **Standard Tyre Size:** **225/55 R19 99V**\n"
          "- **Wheel Rim:** **19-inch Multi-Spoke Aero Alloy Wheels** (PCD: **5x108**)\n"
          "- **Recommended Cold Tyre Pressure:** **230 kPa (2.3 bar / 33.4 psi)** on all 4 wheels\n"
          "- **High-Speed / Heavy Load (>160 km/h):** **250 kPa (2.5 bar / 36.3 psi)**\n"
          "- **TPMS Type:** Direct Real-Time Sensor Telemetry (reads live individual tyre kPa & temperature on cluster and in TiggoMate app)\n"
          "- **Spare Tyre:** Temporary Tyre Repair Sealant Kit with 12V High-Output Compressor located beneath the boot floor\n\n"
          "> **Manual Citation:** *Chery Tiggo 7 PHEV Malaysian Market Guide & Owner's Handbook*, Section: *Wheels & Tyres*, Page 184.";
      citations = [{"document": "Chery Tiggo 7 PHEV Malaysian Market Guide", "section": "Wheels & Tyres", "page": 184}];
    } else if (q.contains("battery") || q.contains("kwh") || q.contains("capacity") || q.contains("range") || (q.contains("charge") && !q.contains("cost"))) {
      answer = "### Chery Tiggo 7 PHEV CSH — Battery & Electric Driving Range\n\n"
          "- **Traction Battery:** **19.27 kWh LFP (Lithium Iron Phosphate)** High-Safety Blade Cells\n"
          "- **Pure Electric Driving Range:** **80 – 100 km (NEDC)** / **~80 km (WLTP)**\n"
          "- **Total Combined Hybrid Range:** **~965+ km** (51L fuel tank + 19.27 kWh battery)\n"
          "- **AC Charging Port:** **Type 2 Mennekes** (supports 3.3 kW single phase AC, ~5.5 hours 0-100%)\n"
          "- **Recommended Charging Habit:** Daily AC charging at home (TNB off-peak 10:00 PM – 08:00 AM @ RM 0.28/kWh = ~RM 4.20 full top-up)\n"
          "- **Battery Warranty:** **8 Years / 160,000 km** with 1-to-1 replacement if State of Health (SOH) drops below 70%\n\n"
          "> **Manual Citation:** *Chery Tiggo 7 PHEV Malaysian Market Guide*, Section: *High Voltage Hybrid System*, Page 42.";
      citations = [{"document": "Chery Tiggo 7 PHEV Malaysian Market Guide", "section": "High Voltage Battery", "page": 42}];
    } else if (q.contains("warranty") || q.contains("guarantee") || q.contains("jaminan")) {
      answer = "### Chery Malaysia Official Warranty Coverage\n\n"
          "- **General Vehicle Warranty:** **7 Years or 150,000 km** (bumper-to-bumper manufacturer warranty)\n"
          "- **Hybrid Battery & Power Electronics:** **8 Years or 160,000 km** (1-to-1 replacement if SOH drops below 70%)\n"
          "- **Free Labour Vouchers:** Applicable at 1k, 20k, 40k, 60k, 80k, and 100k km scheduled service intervals\n"
          "- **24/7 Chery Roadside Assistance:** Toll-Free **1800-88-2868** throughout Peninsular & East Malaysia\n\n"
          "> **Manual Citation:** *Chery Malaysia Warranty Booklet & Service Terms*, 2026 Edition.";
      citations = [{"document": "Chery Malaysia Warranty Terms", "section": "Warranty Coverage", "page": 1}];
    } else if (q.contains("oil") && !q.contains("trans") && !q.contains("3dht") && !q.contains("gearbox")) {
      answer = "### Chery Tiggo 7 PHEV Engine Oil Specification\n\n"
          "- **Specification:** Fully Synthetic **C5 0W-20** (Low SAPS for high-efficiency turbocharged hybrid engines)\n"
          "- **Capacity:** **4.7 Litres** with oil filter replacement\n"
          "- **Official Service Cost:** **RM 270.00** (Engine Oil C5 0W-20 4.7L) + RM 34.00 (Filter) + RM 3.50 (Washer) = **RM 307.50**\n"
          "- **Replacement Interval:** Every **10,000 km or 6 Months**\n\n"
          "> **Manual Citation:** *Chery Tiggo 7 PHEV CSH Service Schedule & Pricing Guide*, 27 August 2026.";
      citations = [{"document": "Chery Tiggo 7 PHEV CSH Service Schedule", "section": "Engine Lubrication", "page": 1}];
    } else if (q.contains("power") || q.contains("torque") || q.contains("hp") || q.contains("ps") || q.contains("dht") || q.contains("spec") || q.contains("speed")) {
      answer = "### Chery Tiggo 7 PHEV CSH — Powertrain & Performance Specs\n\n"
          "- **Engine:** 1.5L Turbocharged 4-cylinder Hybrid Petrol Engine (156 PS / 230 Nm)\n"
          "- **Electric Drive:** Dual Electric Motors integrated with **3-speed DHT (Dedicated Hybrid Transmission)**\n"
          "- **Combined System Output:** **240 kW (326 PS) / 545 Nm Torque**\n"
          "- **0-100 km/h Acceleration:** **~7.5 seconds**\n"
          "- **Fuel Tank:** 51 Litres (RON 95 minimum)\n"
          "- **Driving Modes:** EV Mode (Pure Electric), HEV Mode (Series/Parallel Hybrid), AUTO Mode (Intelligent Energy Management)\n\n"
          "> **Manual Citation:** *Chery Tiggo 7 PHEV Malaysian Market Guide*, Section: *Technical Specifications*, Page 12.";
      citations = [{"document": "Chery Tiggo 7 PHEV Malaysian Market Guide", "section": "Technical Specifications", "page": 12}];
    } else if (q.contains("engine") || q.contains("start") || q.contains("auto")) {
      answer = "### Why the Petrol Engine Has Not Started\n\nIn your **Chery Tiggo 7 PHEV CSH**, the default driving mode is **AUTO Mode**. In AUTO mode, the 1.5L turbocharged petrol engine does **not** start immediately when driving off or cruising.\n\n- **Current Battery SOC:** 78%\n- **Engine Trigger Threshold:** The vehicle preserves fuel and drives purely on electric motors until battery SOC drops below ~20-25%, or sudden heavy acceleration (kickdown) is demanded.\n\n> **Manual Citation:** *Chery Tiggo 7 PHEV Malaysian Market Guide & Owner's Handbook*, Section: *Driving Modes*, Page 28.";
      citations = [{"document": "Chery Tiggo 7 PHEV Malaysian Market Guide", "section": "Driving Modes", "page": 28}];
    } else if (q.contains("1000") || q.contains("1,000") || (q.contains("inspection") && !q.contains("40") && !q.contains("20"))) {
      answer = "### 1,000 km Free Inspection & CarLinko Activation\n\nYour CarLinko telematics service is **pending activation** at your **1,000 km / 1-Month First Free Inspection**.\n\n- **Due at:** 1,000 km (160 km remaining)\n- **Cost:** **FOC (Free of Charge)**\n- **Dealer Tasks:** DMS pairing with VIN, 3DHT & BMS hybrid diagnostic scan, high-voltage orange harness torque check, factory tyre pressure check.\n\n> **Manual Citation:** *Chery Tiggo 7 PHEV CSH Service Schedule & Pricing Guide*, 27 August 2026.";
      citations = [{"document": "Chery Tiggo 7 PHEV CSH Service Schedule", "section": "1,000 km Milestone", "page": 1}];
    } else if (q.contains("20000") || q.contains("20,000") || q.contains("20k")) {
      answer = "### 20,000 km / Month 12 Service Pricing\n\nFor your 20,000 km milestone, the compulsory service fee is **RM 444.60**:\n\n- **Labour Fee:** **FREE (FOC Voucher)**\n- **Engine Oil C5 0W-20 (4.7L):** RM 270.00\n- **Engine Oil Filter:** RM 34.00\n- **Engine Oil Washer:** RM 3.50\n- **Element Air Filter:** RM 137.10\n- **Compulsory Total:** **RM 444.60**\n- **Recommended Addition:** Wiper Blades (R & L) at RM 178.30 (Total: **RM 622.90**)\n\n> **Manual Citation:** *Chery Tiggo 7 PHEV CSH Service Schedule & Pricing Guide*, 27 August 2026.";
      citations = [{"document": "Chery Tiggo 7 PHEV CSH Service Schedule", "section": "20,000 km Milestone", "page": 1}];
    } else if (q.contains("40000") || q.contains("40,000") || q.contains("40k")) {
      answer = "### 40,000 km / Month 24 Major Hybrid Service Pricing\n\nYour 40,000 km milestone is a **Major Service** with **FREE Labour (FOC)**:\n\n- **Labour Fee:** **FREE (FOC Voucher)**\n- **Engine Oil C5 0W-20 (4.7L):** RM 270.00\n- **Engine Oil Filter & Washer:** RM 37.50\n- **Element Air Filter:** RM 137.10\n- **Transmission Oil (3.5L):** RM 399.20\n- **Coolant (4L):** RM 141.80\n- **Brake Fluid (0.85L):** RM 100.00\n- **Compulsory Total:** **RM 1,085.60**\n- **Recommended Additions:** Transmission Filter (RM 68.60) + Wiper Blades (RM 178.30) = **RM 1,332.50**\n\n> **Manual Citation:** *Chery Tiggo 7 PHEV CSH Service Schedule & Pricing Guide*, 27 August 2026.";
      citations = [{"document": "Chery Tiggo 7 PHEV CSH Service Schedule", "section": "40,000 km Milestone", "page": 1}];
    } else if (q.contains("spark") || q.contains("plug")) {
      answer = "### Spark Plug Replacement Interval & Cost\n\nIn your **Chery Tiggo 7 PHEV CSH**, spark plugs are replaced every **30,000 km**:\n\n- **Replacement Milestones:** 30k, 60k, 90k, 120k, and 150k km\n- **Part Cost:** **RM 308.40** per set\n- **Compulsory Service Totals:**\n  - 30,000 km: **RM 715.90** (includes oil + plugs + RM 100 labour)\n  - 60,000 km: **RM 753.00** (FOC Labour! includes oil + air filter + plugs)\n  - 120,000 km: **RM 1,644.00** (Full major overhaul)\n\n> **Manual Citation:** *Chery Tiggo 7 PHEV CSH Service Schedule & Pricing Guide*, 27 August 2026.";
      citations = [{"document": "Chery Tiggo 7 PHEV CSH Service Schedule", "section": "Spark Plugs", "page": 1}];
    } else if (q.contains("transmission") || q.contains("3dht") || q.contains("gearbox") || q.contains("coolant") || q.contains("brake fluid")) {
      answer = "### Transmission Oil, Coolant & Brake Fluid Schedule\n\nUnder Chery Malaysia's official PHEV schedule, major powertrain fluids are replaced every **40,000 km / 24 Months**:\n\n- **Transmission Oil (3.5L):** **RM 399.20** (for 3-speed Dedicated Hybrid Transmission)\n- **Engine Coolant (4L):** **RM 141.80**\n- **Brake Fluid (0.85L):** **RM 100.00**\n- **Optional Transmission Filter:** **RM 68.60**\n- **Due at:** 40,000 km, 80,000 km, and 120,000 km\n\n> **Manual Citation:** *Chery Tiggo 7 PHEV CSH Service Schedule & Pricing Guide*, 27 August 2026.";
      citations = [{"document": "Chery Tiggo 7 PHEV CSH Service Schedule", "section": "Fluid Replacement Intervals", "page": 1}];
    } else if (q.contains("service") || q.contains("schedule") || q.contains("price") || q.contains("pricing") || q.contains("maintenance")) {
      answer = "### Chery Tiggo 7 PHEV CSH Service Schedule Overview\n\nKey points from the official 27 August 2026 schedule:\n\n- **1,000 km:** 1st Inspection — **FOC**\n- **10,000 km:** Oil Service — **RM 407.50**\n- **20,000 km:** Oil + Air Filter — **RM 444.60 (Free Labour)**\n- **30,000 km:** Oil + Spark Plugs — **RM 715.90**\n- **40,000 km:** Major Service (Trans Oil, Coolant, Brake Fluid) — **RM 1,085.60 (Free Labour)**\n- **60,000 km:** Major Service (Air Filter + Plugs) — **RM 753.00 (Free Labour)**\n- **Free Labour Milestones:** 1k, 20k, 40k, 60k, 80k, and 100k km!\n\n> **Manual Citation:** *Chery Tiggo 7 PHEV CSH Service Schedule & Pricing Guide*, 27 August 2026.";
      citations = [{"document": "Chery Tiggo 7 PHEV CSH Service Schedule", "section": "Overview", "page": 1}];
    } else if (q.contains("cost") || q.contains("petrol") || q.contains("saving")) {
      answer = "### Tiggo 7 PHEV Energy & Running Cost Breakdown (100 km Baseline)\n\n- **Home AC Electricity:** 12.25 kWh @ RM 0.57/kWh (TNB) = **RM 6.98**\n- **Petrol:** 1.56 L @ RM 2.05/L = **RM 3.20**\n- **Total PHEV Cost:** **RM 10.18 / 100 km** (RM 0.102 / km)\n- **Pure Petrol SUV Benchmark:** 7.8 L/100km = **RM 15.99**\n\n🎉 **Savings:** You save **RM 5.81 per 100 km (~36.3% savings)**!";
      citations = [{"document": "TNB Residential Tariff Schedule & KPDN RON95 Gazette", "section": "Energy Economics", "page": 1}];
    } else {
      answer = "In your **Chery Tiggo 7 PHEV CSH**, power is delivered through the **3-speed DHT** paired with a 1.5T turbocharged engine and dual electric motors (240 kW / 545 Nm system output). Ask me about tyre size (225/55 R19), AUTO/EV/HEV modes, 1,000 km inspection, warranty, service schedules, or charging!";
    }

    setState(() {
      _messages.add({
        "role": "assistant",
        "content": answer,
        "citations": citations,
      });
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF131922),
            border: Border(bottom: BorderSide(color: Color(0xFF232D3D))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: Color(0xFF00D2AA), size: 18),
                  SizedBox(width: 8),
                  Text('TiggoMate AI Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2AA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.settings.aiApiKey.trim().isNotEmpty
                          ? 'Live • ${widget.settings.aiModel}'
                          : 'Grounded RAG',
                      style: const TextStyle(color: Color(0xFF00D2AA), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onOpenSettings,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF182230),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF232D3D)),
                      ),
                      child: const Icon(Icons.tune, color: Color(0xFF00D2AA), size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Message List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, idx) {
              final msg = _messages[idx];
              final isUser = msg["role"] == "user";
              final citations = msg["citations"] as List<dynamic>?;

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF2F81F7) : const Color(0xFF182230),
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(16),
                      bottomLeft: !isUser ? const Radius.circular(2) : const Radius.circular(16),
                    ),
                    border: isUser ? null : Border.all(color: const Color(0xFF232D3D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownMessageView(
                        content: msg["content"] ?? "",
                        baseStyle: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: isUser ? Colors.white : Colors.white.withValues(alpha: 0.95),
                        ),
                        accentColor: isUser ? Colors.white : const Color(0xFF00D2AA),
                      ),
                      if (citations != null && citations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2AA).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: const Border(left: BorderSide(color: Color(0xFF00D2AA), width: 3)),
                          ),
                          child: Text(
                            "📖 Citation: ${citations[0]['document']} (p. ${citations[0]['page']})",
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF00D2AA), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(color: Color(0xFF00D2AA), backgroundColor: Colors.transparent),
          ),

        // Quick Suggestion Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              return ActionChip(
                label: Text(_suggestions[idx], style: const TextStyle(fontSize: 11, color: Colors.white70)),
                backgroundColor: const Color(0xFF182230),
                side: const BorderSide(color: Color(0xFF232D3D)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => _sendMessage(_suggestions[idx]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Chat Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF131922),
            border: Border(top: BorderSide(color: Color(0xFF232D3D))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ask about your Tiggo 7...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF090D12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFF232D3D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFF00D2AA)),
                    ),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send, size: 18),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF00D2AA), foregroundColor: Colors.black87),
                onPressed: () => _sendMessage(_controller.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- TAB 3: CHARGING & ENERGY ----------------
class EnergyTab extends StatelessWidget {
  final AppSettings settings;
  const EnergyTab({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final double homeAcCost = 84.5 * settings.tnbTariff;
    final double petrolCost = 28.7 * settings.fuelPrice;
    final double totalCost = homeAcCost + petrolCost;
    const double iceEquivalent = 165.40;
    final double savings = iceEquivalent - totalCost;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Charging & Energy Economics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),

        // AC Wallbox Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('AC TYPE 2 CHARGING RATE', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Up to 6.6 kW', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA))),
                SizedBox(height: 4),
                Text('0–100% full charge in ~2.8 hours on AC Wallbox (19.27 kWh pack)', style: TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Spending Breakdown Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('30-DAY RUNNING COSTS (ESTIMATED)', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('⚡ Home AC (TNB RM ${settings.tnbTariff.toStringAsFixed(2)}/kWh)', style: const TextStyle(fontSize: 13)),
                    Text('RM ${homeAcCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('⛽ Petrol (RON95 RM ${settings.fuelPrice.toStringAsFixed(2)}/L)', style: const TextStyle(fontSize: 13)),
                    Text('RM ${petrolCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2F81F7))),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFF232D3D)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Hybrid Monthly Spend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('RM ${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Estimated ICE equivalent: RM ${iceEquivalent.toStringAsFixed(2)} (RM ${savings.toStringAsFixed(2)} monthly savings)',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF00D2AA)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Recent Sessions
        const Text('Recent Charging Sessions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSessionTile('Home Wallbox AC', 'Yesterday 21:15 • +12.4 kWh (20% → 85%)', 'RM 7.87'),
        _buildSessionTile('Home Wallbox AC', '3 days ago 19:40 • +14.8 kWh (18% → 95%)', 'RM 9.35'),
        _buildSessionTile('Mall Destination AC', '5 days ago 13:10 • +8.6 kWh (42% → 86%)', 'RM 10.32'),
      ],
    );
  }

  Widget _buildSessionTile(String title, String sub, String cost) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF090D12),
          child: Icon(Icons.ev_station, color: Color(0xFF00D2AA), size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        trailing: Text(cost, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00D2AA), fontSize: 14)),
      ),
    );
  }
}

// ---------------- TAB 4: SERVICE & MAINTENANCE ----------------

class ServiceMilestone {
  final int month;
  final int km;
  final String title;
  final double compulsoryFee;
  final double recommendedFee;
  final bool isLabourFoc;
  final double labourFee;
  final bool isMajor;
  final List<Map<String, dynamic>> compulsoryParts;
  final List<Map<String, dynamic>> recommendedParts;

  const ServiceMilestone({
    required this.month,
    required this.km,
    required this.title,
    required this.compulsoryFee,
    required this.recommendedFee,
    required this.isLabourFoc,
    required this.labourFee,
    this.isMajor = false,
    required this.compulsoryParts,
    this.recommendedParts = const [],
  });
}

class MaintenanceTab extends StatefulWidget {
  final AppSettings settings;
  const MaintenanceTab({super.key, required this.settings});

  @override
  State<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<MaintenanceTab> {
  int _activeSubTab = 0; // 0: Schedule & Pricing, 1: Chery Service Centres
  int _selectedMilestoneIndex = 0; // Default to 1,000 km or upcoming
  int _filterIndex = 0; // 0: All, 1: Free Labour, 2: Major
  bool _showFullTable = false;

  static const List<Map<String, dynamic>> _baseOilPackage = [
    {"name": "Engine Oil C5 0W-20 (4.7L)", "price": 270.00},
    {"name": "Engine Oil Filter", "price": 34.00},
    {"name": "Engine Oil Washer", "price": 3.50},
  ];

  final List<ServiceMilestone> _milestones = [
    const ServiceMilestone(
      month: 1,
      km: 1000,
      title: "1st Inspection & Telematics",
      compulsoryFee: 0.00,
      recommendedFee: 0.00,
      isLabourFoc: true,
      labourFee: 0.00,
      compulsoryParts: [
        {"name": "DMS CarLinko Telematics Pairing", "price": 0.00},
        {"name": "3DHT & BMS Hybrid Diagnostic Scan", "price": 0.00},
        {"name": "High-Voltage Orange Harness Torque Check", "price": 0.00},
        {"name": "Tyre Pressure & Torque Inspection (230 kPa)", "price": 0.00},
      ],
    ),
    const ServiceMilestone(
      month: 6,
      km: 10000,
      title: "Minor Service (10k)",
      compulsoryFee: 407.50,
      recommendedFee: 407.50,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Labour Fee", "price": 100.00},
      ],
    ),
    const ServiceMilestone(
      month: 12,
      km: 20000,
      title: "Service 2 (20k • Free Labour)",
      compulsoryFee: 444.60,
      recommendedFee: 622.90,
      isLabourFoc: true,
      labourFee: 0.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Element Air Filter", "price": 137.10},
        {"name": "Labour Fee (FOC Voucher)", "price": 0.00},
      ],
      recommendedParts: [
        {"name": "Wiper Blade (R & L)", "price": 178.30},
      ],
    ),
    const ServiceMilestone(
      month: 18,
      km: 30000,
      title: "Service 3 (30k • Spark Plugs)",
      compulsoryFee: 715.90,
      recommendedFee: 745.40,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Spark Plugs (Set)", "price": 308.40},
        {"name": "Labour Fee", "price": 100.00},
      ],
      recommendedParts: [
        {"name": "Fuel Filter", "price": 29.50},
      ],
    ),
    const ServiceMilestone(
      month: 24,
      km: 40000,
      title: "Major Hybrid Service (40k)",
      compulsoryFee: 1085.60,
      recommendedFee: 1332.50,
      isLabourFoc: true,
      labourFee: 0.00,
      isMajor: true,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Element Air Filter", "price": 137.10},
        {"name": "Brake Fluid (0.85L)", "price": 100.00},
        {"name": "Transmission Oil (3.5L Dedicated Hybrid)", "price": 399.20},
        {"name": "Coolant (4L)", "price": 141.80},
        {"name": "Labour Fee (FOC Voucher)", "price": 0.00},
      ],
      recommendedParts: [
        {"name": "Transmission Filter", "price": 68.60},
        {"name": "Wiper Blade (R & L)", "price": 178.30},
      ],
    ),
    const ServiceMilestone(
      month: 30,
      km: 50000,
      title: "Minor Service (50k)",
      compulsoryFee: 407.50,
      recommendedFee: 407.50,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Labour Fee", "price": 100.00},
      ],
    ),
    const ServiceMilestone(
      month: 36,
      km: 60000,
      title: "Major Service 6 (60k)",
      compulsoryFee: 753.00,
      recommendedFee: 2085.50,
      isLabourFoc: true,
      labourFee: 0.00,
      isMajor: true,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Element Air Filter", "price": 137.10},
        {"name": "Spark Plugs (Set)", "price": 308.40},
        {"name": "Labour Fee (FOC Voucher)", "price": 0.00},
      ],
      recommendedParts: [
        {"name": "Charcoal Canister Filter", "price": 90.70},
        {"name": "Fuel Filter", "price": 29.50},
        {"name": "Brake Pad (Front)", "price": 593.30},
        {"name": "Brake Pad (Rear)", "price": 440.70},
        {"name": "Wiper Blade (R & L)", "price": 178.30},
      ],
    ),
    const ServiceMilestone(
      month: 42,
      km: 70000,
      title: "Minor Service (70k)",
      compulsoryFee: 407.50,
      recommendedFee: 407.50,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Labour Fee", "price": 100.00},
      ],
    ),
    const ServiceMilestone(
      month: 48,
      km: 80000,
      title: "Major Hybrid Service (80k)",
      compulsoryFee: 1085.60,
      recommendedFee: 1332.50,
      isLabourFoc: true,
      labourFee: 0.00,
      isMajor: true,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Element Air Filter", "price": 137.10},
        {"name": "Brake Fluid (0.85L)", "price": 100.00},
        {"name": "Transmission Oil (3.5L Dedicated Hybrid)", "price": 399.20},
        {"name": "Coolant (4L)", "price": 141.80},
        {"name": "Labour Fee (FOC Voucher)", "price": 0.00},
      ],
      recommendedParts: [
        {"name": "Transmission Filter", "price": 68.60},
        {"name": "Wiper Blade (R & L)", "price": 178.30},
      ],
    ),
    const ServiceMilestone(
      month: 54,
      km: 90000,
      title: "Service 9 (90k • Spark Plugs)",
      compulsoryFee: 715.90,
      recommendedFee: 745.40,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Spark Plugs (Set)", "price": 308.40},
        {"name": "Labour Fee", "price": 100.00},
      ],
      recommendedParts: [
        {"name": "Fuel Filter", "price": 29.50},
      ],
    ),
    const ServiceMilestone(
      month: 60,
      km: 100000,
      title: "Service 10 (100k • Free Labour)",
      compulsoryFee: 444.60,
      recommendedFee: 622.90,
      isLabourFoc: true,
      labourFee: 0.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Element Air Filter", "price": 137.10},
        {"name": "Labour Fee (FOC Voucher)", "price": 0.00},
      ],
      recommendedParts: [
        {"name": "Wiper Blade (R & L)", "price": 178.30},
      ],
    ),
    const ServiceMilestone(
      month: 66,
      km: 110000,
      title: "Minor Service (110k)",
      compulsoryFee: 407.50,
      recommendedFee: 407.50,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Labour Fee", "price": 100.00},
      ],
    ),
    const ServiceMilestone(
      month: 72,
      km: 120000,
      title: "Major Overhaul (120k • 6-Year)",
      compulsoryFee: 1644.00,
      recommendedFee: 3045.10,
      isLabourFoc: false,
      labourFee: 250.00,
      isMajor: true,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Element Air Filter", "price": 137.10},
        {"name": "Spark Plugs (Set)", "price": 308.40},
        {"name": "Brake Fluid (0.85L)", "price": 100.00},
        {"name": "Transmission Oil (3.5L Dedicated Hybrid)", "price": 399.20},
        {"name": "Coolant (4L)", "price": 141.80},
        {"name": "Labour Fee (Comprehensive)", "price": 250.00},
      ],
      recommendedParts: [
        {"name": "Transmission Filter", "price": 68.60},
        {"name": "Charcoal Canister Filter", "price": 90.70},
        {"name": "Fuel Filter", "price": 29.50},
        {"name": "Brake Pad (Front)", "price": 593.30},
        {"name": "Brake Pad (Rear)", "price": 440.70},
        {"name": "Wiper Blade (R & L)", "price": 178.30},
      ],
    ),
    const ServiceMilestone(
      month: 78,
      km: 130000,
      title: "Minor Service (130k)",
      compulsoryFee: 407.50,
      recommendedFee: 407.50,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Labour Fee", "price": 100.00},
      ],
    ),
    const ServiceMilestone(
      month: 84,
      km: 140000,
      title: "Service 14 (140k)",
      compulsoryFee: 544.60,
      recommendedFee: 722.90,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Element Air Filter", "price": 137.10},
        {"name": "Labour Fee", "price": 100.00},
      ],
      recommendedParts: [
        {"name": "Wiper Blade (R & L)", "price": 178.30},
      ],
    ),
    const ServiceMilestone(
      month: 90,
      km: 150000,
      title: "Service 15 (150k • Spark Plugs)",
      compulsoryFee: 715.90,
      recommendedFee: 745.40,
      isLabourFoc: false,
      labourFee: 100.00,
      compulsoryParts: [
        ..._baseOilPackage,
        {"name": "Spark Plugs (Set)", "price": 308.40},
        {"name": "Labour Fee", "price": 100.00},
      ],
      recommendedParts: [
        {"name": "Fuel Filter", "price": 29.50},
      ],
    ),
  ];

  Widget _buildSubTabSwitcher() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF131922),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF232D3D)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _activeSubTab = 0),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeSubTab == 0 ? const Color(0xFF00D2AA) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Schedule & Pricing',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _activeSubTab == 0 ? Colors.black : Colors.white70,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _activeSubTab = 1),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeSubTab == 1 ? const Color(0xFF00D2AA) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 13,
                      color: _activeSubTab == 1 ? Colors.black : const Color(0xFF00D2AA),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Service Centres (${CheryServiceDirectory.centres.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _activeSubTab == 1 ? Colors.black : Colors.white70,
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

  @override
  Widget build(BuildContext context) {
    if (_activeSubTab == 1) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildSubTabSwitcher(),
          ),
          const Expanded(
            child: CheryServiceCentresScreen(isEmbedded: true),
          ),
        ],
      );
    }

    final filteredMilestones = _milestones.where((m) {
      if (_filterIndex == 1) return m.isLabourFoc;
      if (_filterIndex == 2) return m.isMajor;
      return true;
    }).toList();

    // Ensure selected index is clamped
    if (_selectedMilestoneIndex >= _milestones.length) {
      _selectedMilestoneIndex = 0;
    }
    final selected = _milestones[_selectedMilestoneIndex];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubTabSwitcher(),
        const SizedBox(height: 14),

        // Title Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Service Schedule & Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Chery Tiggo 7 PHEV CSH • ${widget.settings.carPlateNumber} • ${widget.settings.ownerName}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00D2AA).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('27 Aug 2026 Gazette', style: TextStyle(color: Color(0xFF00D2AA), fontSize: 9.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Upcoming 1,000 km Milestone Reminder Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1B343).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1B343).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('1,000 km / 1-Month Inspection', style: TextStyle(color: Color(0xFFF1B343), fontWeight: FontWeight.bold, fontSize: 14.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1B343),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('160 km Left', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Current Odometer: 840 km • Due soon at 1,000 km', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              const SizedBox(height: 10),
              const Text(
                '• Dealer DMS telematics pairing & CarLinko activation\n• 3DHT hybrid transmission & battery management diagnostic scan\n• High-voltage orange harness torque check\n• Factory tyre torque & cold pressure verification (230 kPa)',
                style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.5),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Compulsory Cost: FREE (FOC)', style: TextStyle(color: Color(0xFF00D2AA), fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('Next: 10,000 km (RM 407.50)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _activeSubTab = 1),
                  icon: const Icon(Icons.location_on, size: 14, color: Color(0xFFF1B343)),
                  label: const Text(
                    'Find 3S/4S Service Centre for 1,000 km Activation',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFF1B343), fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF1B343)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter Chips
        Row(
          children: [
            _buildFilterChip('All (16)', 0),
            const SizedBox(width: 8),
            _buildFilterChip('Free Labour (6 FOC)', 1),
            const SizedBox(width: 8),
            _buildFilterChip('Major Services (4)', 2),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Milestone Carousel
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filteredMilestones.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final m = filteredMilestones[index];
              final origIndex = _milestones.indexOf(m);
              final isSelected = origIndex == _selectedMilestoneIndex;

              return InkWell(
                onTap: () => setState(() => _selectedMilestoneIndex = origIndex),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 124,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00D2AA).withValues(alpha: 0.15) : const Color(0xFF131922),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00D2AA) : const Color(0xFF232D3D),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${m.km ~/ 1000}k km',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF00D2AA) : Colors.white,
                              ),
                            ),
                          ),
                          if (m.isLabourFoc)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D2AA).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('FOC', style: TextStyle(color: Color(0xFF00D2AA), fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Mth ${m.month}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                      const SizedBox(height: 2),
                      Text(
                        m.compulsoryFee == 0 ? 'FOC' : 'RM ${m.compulsoryFee.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Selected Milestone Detail Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Milestone Title & Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selected.km.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} km Service',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text('Month ${selected.month} • ${selected.title}', style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
                        ],
                      ),
                    ),
                    if (selected.isLabourFoc)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2AA).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00D2AA)),
                        ),
                        child: const Text('FREE LABOUR', style: TextStyle(color: Color(0xFF00D2AA), fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else if (selected.isMajor)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2F81F7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2F81F7)),
                        ),
                        child: const Text('MAJOR SERVICE', style: TextStyle(color: Color(0xFF2F81F7), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Pricing Summary Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF232D3D)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('COMPULSORY FEE', style: TextStyle(fontSize: 9.5, color: Colors.white54, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              selected.compulsoryFee == 0 ? 'FOC' : 'RM ${selected.compulsoryFee.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA)),
                            ),
                            Text(
                              selected.isLabourFoc ? 'Labour FOC (Included)' : 'Labour: RM ${selected.labourFee.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 42, color: const Color(0xFF232D3D)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RECOMMENDED TOTAL', style: TextStyle(fontSize: 9.5, color: Colors.white54, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              selected.recommendedFee == 0 ? 'FOC' : 'RM ${selected.recommendedFee.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Text('Includes optional wear items', style: TextStyle(fontSize: 10, color: Colors.white38)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Compulsory Parts Breakdown
                const Text('COMPULSORY PARTS & SERVICES', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                ...selected.compulsoryParts.map((p) => _buildPartRow(p["name"], p["price"] as double, isCompulsory: true)),

                if (selected.recommendedParts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('RECOMMENDED ADDITIONAL ITEMS', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  ...selected.recommendedParts.map((p) => _buildPartRow(p["name"], p["price"] as double, isCompulsory: false)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Toggle Full Schedule View Button
        OutlinedButton.icon(
          onPressed: () => setState(() => _showFullTable = !_showFullTable),
          icon: Icon(_showFullTable ? Icons.expand_less : Icons.table_chart_outlined, size: 18),
          label: Text(_showFullTable ? 'Hide 150,000 km Schedule Table' : 'View Full 150,000 km Schedule Table (16 Milestones)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00D2AA),
            side: const BorderSide(color: Color(0xFF232D3D)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        if (_showFullTable) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Expanded(flex: 3, child: Text('Milestone', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70))),
                        Expanded(flex: 2, child: Text('Labour', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70))),
                        Expanded(flex: 3, child: Text('Compulsory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA)))),
                        Expanded(flex: 3, child: Text('Recommended', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF232D3D)),
                  // Rows
                  ..._milestones.map((m) {
                    final isHighlighted = _milestones.indexOf(m) == _selectedMilestoneIndex;
                    return InkWell(
                      onTap: () => setState(() => _selectedMilestoneIndex = _milestones.indexOf(m)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isHighlighted ? const Color(0xFF00D2AA).withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text('${m.km ~/ 1000}k km (M${m.month})', style: TextStyle(fontSize: 11, fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                m.isLabourFoc ? 'FOC' : 'RM ${m.labourFee.toInt()}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: m.isLabourFoc ? const Color(0xFF00D2AA) : Colors.white60,
                                  fontWeight: m.isLabourFoc ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                m.compulsoryFee == 0 ? 'FOC' : 'RM ${m.compulsoryFee.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00D2AA)),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                m.recommendedFee == 0 ? 'FOC' : 'RM ${m.recommendedFee.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Official Chery Schedule Notes & Guidelines
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('OFFICIAL CHERY SERVICE GUIDELINES', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                SizedBox(height: 10),
                Text('• Price reference as of 27 August 2026.', style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4)),
                SizedBox(height: 4),
                Text('• Replacement item is based on month or mileage, whichever comes first.', style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4)),
                SizedBox(height: 4),
                Text('• Free Labour (FOC): Month 1 (1k km), Month 12 (20k km), Month 24 (40k km), Month 36 (60k km), Month 48 (80k km), and Month 60 (100k km).', style: TextStyle(fontSize: 11.5, color: Color(0xFF00D2AA), height: 1.4, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('• Wheel alignment and balancing is recommended every 10,000 km.', style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4)),
                SizedBox(height: 4),
                Text('• Complimentary car wash is carried out after the service/repair process.', style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4)),
                SizedBox(height: 4),
                Text('• Free service offers exclude recommended wear items and wear labour.', style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Vehicle Warranty & Specifications Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OFFICIAL VEHICLE SPECIFICATIONS', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                _buildSpecRow('Model', 'Chery Tiggo 7 PHEV CSH (RHD)'),
                _buildSpecRow('Powertrain', '1.5L Turbo + Dual Motors (CSH)'),
                _buildSpecRow('System Output', '240 kW (326 PS) / 545 Nm'),
                _buildSpecRow('Transmission', '3-speed Dedicated Hybrid (3DHT)'),
                _buildSpecRow('Battery Capacity', '19.27 kWh (usable ~18.3 kWh)'),
                _buildSpecRow('Electric Range', '80–100 km (NEDC rated 100 km)'),
                _buildSpecRow('Fuel Tank', '51 Litres (RON95 compatible)'),
                _buildSpecRow('Target Cold Tyre Pressure', '230 kPa (2.3 bar / 33.4 psi)'),
                _buildSpecRow('Vehicle Warranty', '7 Years / 150,000 km'),
                _buildSpecRow('Battery Warranty', '8 Years / 160,000 km'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _filterIndex == index;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? const Color(0xFF00D2AA) : Colors.white70)),
      selected: isSelected,
      selectedColor: const Color(0xFF00D2AA).withValues(alpha: 0.15),
      backgroundColor: const Color(0xFF131922),
      side: BorderSide(color: isSelected ? const Color(0xFF00D2AA) : const Color(0xFF232D3D)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) => setState(() => _filterIndex = index),
    );
  }

  Widget _buildPartRow(String name, double price, {required bool isCompulsory}) {
    final isFoc = price == 0.00;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isCompulsory ? Icons.check_circle_outline : Icons.add_circle_outline,
                  size: 14,
                  color: isCompulsory ? const Color(0xFF00D2AA) : Colors.white38,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompulsory ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            isFoc ? 'FREE (FOC)' : 'RM ${price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isFoc ? const Color(0xFF00D2AA) : (isCompulsory ? Colors.white : Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

