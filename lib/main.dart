import 'src/ui/book_service_appointment_sheet.dart';
import 'src/service/service_appointment_manager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/ai/ai_service.dart';
import 'src/carlinko/vehicle_repository.dart';
import 'src/carlinko/vehicle_skin.dart';
import 'src/mytnb/mytnb_api.dart';

import 'src/ui/neo_dashboard.dart';
import 'src/ui/chery_service_centres_screen.dart';
import 'src/ui/trips_logbook_screen.dart';
import 'src/auth/auth_service.dart';
import 'src/ui/login_screen.dart';

import 'src/theme/app_theme.dart';

import 'src/ui/app_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/ui/setup_intro_screen.dart';
import 'src/ui/settings_screen.dart';
import 'src/theme/accent.dart';
import 'src/theme/app_tokens.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning (offline fallback active): $e');
  }

  try {
    await AppThemeController.instance.init();
    await Accent.load();
    await VehicleSkinManager.instance.init();
  } catch (e) {
    debugPrint('AppThemeController.init warning: $e');
  }

  try {
    await VehicleAlertsManager.instance.init();
  await ServiceAppointmentManager.instance.load();
  } catch (e) {
    debugPrint('VehicleAlertsManager.init warning: $e');
  }

  runApp(const TiggoMateApp());
}

class TiggoMateApp extends StatelessWidget {
  const TiggoMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppThemeController.instance, Accent.current]),
      builder: (context, _) {
        final curAccent = Accent.current.value;
        return MaterialApp(
          title: 'TiggoMate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(curAccent),
          darkTheme: AppTheme.dark(curAccent),
          themeMode: AppThemeController.instance.themeMode,
          home: const AppRootGate(),
        );
      },
    );
  }
}

class AppRootGate extends StatefulWidget {
  const AppRootGate({super.key});

  @override
  State<AppRootGate> createState() => _AppRootGateState();
}

class _AppRootGateState extends State<AppRootGate> {
  final _authService = AuthService();
  bool _initialized = false;
  bool _hasChosenAuth = false;
  bool _hasCompletedSetup = false;

  @override
  void initState() {
    super.initState();
    _initGate();
    _authService.authStateChanges.listen((user) {
      if (mounted) {
        setState(() {
          _hasChosenAuth = user.isAuthenticated || !user.isGuest;
        });
      }
    });
  }

  Future<void> _initGate() async {
    try {
      await _authService.initialize();
      final prefs = await SharedPreferences.getInstance();
      final setupDone = prefs.getBool('tm_has_completed_setup') ?? false;
      final chosen = await _authService.hasChosenAuth();
      if (mounted) {
        setState(() {
          _hasCompletedSetup = setupDone;
          _hasChosenAuth = chosen;
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint('Gate initialization error: $e');
      if (mounted) {
        setState(() {
          _hasCompletedSetup = false;
          _hasChosenAuth = true;
          _initialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary),
        ),
      );
    }

    if (!_hasCompletedSetup) {
      return SetupIntroScreen(
        onCompleted: () {
          setState(() {
            _hasCompletedSetup = true;
            _hasChosenAuth = true;
          });
        },
      );
    }

    if (!_hasChosenAuth) {
      return LoginScreen(
        onAuthenticated: () {
          setState(() {
            _hasChosenAuth = true;
          });
        },
      );
    }

    return const MainNavigationScreen();
  }
}

// Settings & AppSettings now modularly imported from lib/src/ui/settings_screen.dart

// ---------------- MAIN NAVIGATION ----------------

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  AppSettings _settings = const AppSettings();
  final VehicleRepository _vehicleRepo = AppVehicleRepository.instance;
  final MyTnbRepository _myTnbRepo = MyTnbRepository();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    VehicleSkinManager.instance.addListener(_handleGlobalSkinChanged);
    _loadSettings();
  }

  void _handleGlobalSkinChanged() {
    final newSkin = VehicleSkinManager.instance.currentSkinKey;
    if (mounted && _settings.vehicleSkinKey != newSkin) {
      setState(() {
        _settings = _settings.copyWith(vehicleSkinKey: newSkin);
      });
      SettingsService.save(_settings);
    }
  }

  @override
  void dispose() {
    VehicleSkinManager.instance.removeListener(_handleGlobalSkinChanged);
    _vehicleRepo.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await VehicleSkinManager.instance.init();
    final s = await SettingsService.load();
    await _myTnbRepo.init();
    if (s.carLinkoStatus == 'Active') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final acc = prefs.getString('tm_carlinko_account') ?? s.ownerName;
        AppVehicleRepository.instance.setPreActivationActive(account: acc);
      } catch (_) {}
    }
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
    final curSkin = VehicleSkinManager.instance.currentSkinKey;
    if (updated != null && mounted) {
      setState(() => _settings = updated.copyWith(vehicleSkinKey: curSkin));
      await SettingsService.save(_settings);
    } else if (mounted && _settings.vehicleSkinKey != curSkin) {
      setState(() => _settings = _settings.copyWith(vehicleSkinKey: curSkin));
      await SettingsService.save(_settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: context.tokens.accent),
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
        vehicleSkinKey: _settings.vehicleSkinKey,
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0D1219)
              : Colors.white,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E2636)
                  : const Color(0xFFE2E8F0),
              width: AppDesignTokens.borderWidth,
            ),
          ),
        ),
        child: NavigationBar(
          height: 64,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.directions_car_outlined, size: 22),
              selectedIcon: Icon(
                Icons.directions_car,
                size: 22,
                color: context.tokens.accent,
              ),
              label: 'Vehicle',
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline, size: 22),
              selectedIcon: Icon(
                Icons.chat_bubble,
                size: 22,
                color: context.tokens.accent,
              ),
              label: 'Assistant',
            ),
            NavigationDestination(
              icon: const Icon(Icons.route_outlined, size: 22),
              selectedIcon: Icon(
                Icons.route,
                size: 22,
                color: context.tokens.accent,
              ),
              label: 'Trips & Log',
            ),
            NavigationDestination(
              icon: const Icon(Icons.build_outlined, size: 22),
              selectedIcon: Icon(
                Icons.build,
                size: 22,
                color: context.tokens.accent,
              ),
              label: 'Service',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- TAB 1: VEHICLE DASHBOARD ----------------
class DashboardTab extends StatelessWidget {
  final AppSettings settings;
  final Function(int) onNavigateToTab;
  final VoidCallback onOpenSettings;
  final VehicleRepository? repository;
  const DashboardTab({
    required this.settings,
    required this.onNavigateToTab,
    required this.onOpenSettings,
    this.repository,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return NeoDashboard(
      repository: repository ?? AppVehicleRepository.instance,
      ownerName: settings.ownerName,
      carPlateNumber: settings.carPlateNumber,
      vehicleNickname: settings.vehicleNickname,
      tnbTariff: settings.tnbTariff,
      fuelPrice: settings.fuelPrice,
      vehicleSkinKey: settings.vehicleSkinKey,
      onOpenSettings: onOpenSettings,
      onOpenAssistant: () => onNavigateToTab(1),
    );
  }
}

// ---------------- TAB 2: AI ASSISTANT ----------------

/// Renders markdown formatted messages with headings, bold, italic,
/// bullet lists, numbered lists, blockquotes, code chips, and code blocks.
class MarkdownMessageView extends StatelessWidget {
  final String content;
  final TextStyle baseStyle;
  final Color? accentColor;

  const MarkdownMessageView({
    super.key,
    required this.content,
    this.baseStyle = const TextStyle(fontSize: 13.5, height: 1.45, color: Colors.white),
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? context.tokens.accent;
    final blocks = _parseBlocks(content, effectiveAccent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<Widget> _parseBlocks(String text, Color accentColor) {
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
          widgets.add(_buildCodeBlock(codeBlockLines.join('\n'), accentColor));
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
              color: baseStyle.color,
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
              color: baseStyle.color,
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
              color: baseStyle.color,
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
              color: baseStyle.color,
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
                baseStyle.copyWith(fontSize: 12.5, color: baseStyle.color?.withValues(alpha: 0.8)),
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
      widgets.add(_buildCodeBlock(codeBlockLines.join('\n'), accentColor));
    }

    return widgets;
  }

  Widget _buildCodeBlock(String code, Color accentColor) {
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
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: accentColor,
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
              color: (baseStyle.color ?? Colors.white).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              match.group(5) ?? '',
              style: style.copyWith(
                fontFamily: 'monospace',
                fontSize: (style.fontSize ?? 13.5) * 0.9,
                color: accentColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.tokens.accent;
    final onAccent = context.tokens.onAccent;

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131922) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: accent, size: 18),
                  const SizedBox(width: 8),
                  const Text('TiggoMate AI Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.settings.aiApiKey.trim().isNotEmpty
                          ? 'Live • ${widget.settings.aiModel}'
                          : 'Grounded RAG',
                      style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onOpenSettings,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF182230) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                      ),
                      child: Icon(Icons.tune, color: accent, size: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    color: isUser
                        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF131922) : Colors.white),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard).copyWith(
                      bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(AppDesignTokens.radiusCard),
                      bottomLeft: !isUser ? const Radius.circular(2) : const Radius.circular(AppDesignTokens.radiusCard),
                    ),
                    border: Border.all(
                      color: isUser
                          ? (isDark ? const Color(0xFF334155) : const Color(0xFF1E293B))
                          : (isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0)),
                      width: AppDesignTokens.borderWidth,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownMessageView(
                        content: msg["content"] ?? "",
                        baseStyle: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: isUser
                              ? Colors.white
                              : (isDark ? Colors.white.withValues(alpha: 0.95) : const Color(0xFF111827)),
                        ),
                        accentColor: isUser ? Colors.white : accent,
                      ),
                      if (citations != null && citations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0B1017) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
                            border: Border(
                              left: BorderSide(color: accent, width: 3),
                              top: BorderSide(color: isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0)),
                              right: BorderSide(color: isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0)),
                              bottom: BorderSide(color: isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_rounded, size: 12, color: accent),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  "📖 Citation: ${citations[0]['document']} (p. ${citations[0]['page']})",
                                  style: TextStyle(fontSize: 10.5, color: accent, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: LinearProgressIndicator(color: accent, backgroundColor: Colors.transparent),
          ),

        // Quick Suggestion Chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              return ActionChip(
                label: Text(
                  _suggestions[idx],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),
                backgroundColor: isDark ? const Color(0xFF131922) : const Color(0xFFF1F5F9),
                side: BorderSide(color: isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusPill)),
                onPressed: () => _sendMessage(_suggestions[idx]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Chat Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1219) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask about your Tiggo 7...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF070B0F) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusPill),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusPill),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusPill),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: AppDesignTokens.minTouchTarget,
                height: AppDesignTokens.minTouchTarget,
                child: IconButton.filled(
                  icon: const Icon(Icons.send, size: 18),
                  style: IconButton.styleFrom(backgroundColor: accent, foregroundColor: onAccent),
                  onPressed: () => _sendMessage(_controller.text),
                ),
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
    final accent = context.tokens.accent;

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
              children: [
                const Text('AC TYPE 2 CHARGING RATE', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Up to 6.6 kW', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accent)),
                const SizedBox(height: 4),
                const Text('0–100% full charge in ~2.8 hours on AC Wallbox (19.27 kWh pack)', style: TextStyle(fontSize: 12, color: Colors.white60)),
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
                    Text('RM ${homeAcCost.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
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
                  style: TextStyle(fontSize: 11, color: accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Recent Sessions
        const Text('Recent Charging Sessions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSessionTile('Home Wallbox AC', 'Yesterday 21:15 • +12.4 kWh (20% → 85%)', 'RM 7.87', accent),
        _buildSessionTile('Home Wallbox AC', '3 days ago 19:40 • +14.8 kWh (18% → 95%)', 'RM 9.35', accent),
        _buildSessionTile('Mall Destination AC', '5 days ago 13:10 • +8.6 kWh (42% → 86%)', 'RM 10.32', accent),
      ],
    );
  }

  Widget _buildSessionTile(String title, String sub, String cost, Color accent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF090D12),
          child: Icon(Icons.ev_station, color: accent, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        trailing: Text(cost, style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 14)),
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
  void _confirmCancelAppointment(BuildContext context, ServiceAppointment apt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131922) : Colors.white,
        title: const Text('Cancel Appointment?'),
        content: Text('Are you sure you want to cancel your service booking at ' + apt.centreName + ' on ' + apt.formattedDate + '?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ServiceAppointmentManager.instance.cancelAppointment(apt.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

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

  Widget _buildSubTabSwitcher(bool isDark) {
    final accent = context.tokens.accent;
    final onAccent = context.tokens.onAccent;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
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
                  color: _activeSubTab == 0 ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Schedule & Pricing',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _activeSubTab == 0 ? onAccent : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
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
                  color: _activeSubTab == 1 ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 13,
                      color: _activeSubTab == 1 ? onAccent : accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Service Centres (${CheryServiceDirectory.centres.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _activeSubTab == 1 ? onAccent : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_activeSubTab == 1) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildSubTabSwitcher(isDark),
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
    final accent = context.tokens.accent;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubTabSwitcher(isDark),
        const SizedBox(height: 14),

        // Title Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Schedule & Pricing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chery Tiggo 7 PHEV CSH • ${widget.settings.carPlateNumber} • ${widget.settings.ownerName}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('27 Aug 2026 Gazette', style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Upcoming 1,000 km Milestone Reminder Banner (Clean, non-redundant)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFFF1B343).withValues(alpha: 0.08) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFFF1B343).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFFF1B343) : const Color(0xFFD97706)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.build_circle_outlined, size: 18, color: isDark ? const Color(0xFFF1B343) : const Color(0xFFB45309)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'NEXT DUE: 1,000 KM INSPECTION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: isDark ? const Color(0xFFF1B343) : const Color(0xFFB45309),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFFF1B343) : const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '160 km Left',
                            style: TextStyle(
                              color: isDark ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'CarLinko Telematics Activation & 3DHT Diagnostic Scan (FOC)',
                      style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF4B5563), fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => setState(() => _activeSubTab = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFFF1B343) : const Color(0xFFD97706)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isDark ? const Color(0xFFF1B343) : const Color(0xFFD97706)).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Find 3S/4S',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFF1B343) : const Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 14, color: isDark ? const Color(0xFFF1B343) : const Color(0xFFB45309)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

// Service Appointment / Milestone Reminder Area
        ListenableBuilder(
          listenable: ServiceAppointmentManager.instance,
          builder: (context, _) {
            final upcoming = ServiceAppointmentManager.instance.upcomingAppointment;
            if (upcoming != null) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1E1B) : const Color(0xFFE6FFFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.6)),
                ),
                child: Column(
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
                                color: const Color(0xFF00D2AA).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF00D2AA)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CONFIRMED SERVICE APPOINTMENT',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                                color: isDark ? const Color(0xFF00D2AA) : const Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2AA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            upcoming.daysUntil == 0
                                ? 'TODAY'
                                : (upcoming.daysUntil == 1 ? 'TOMORROW' : 'In ${upcoming.daysUntil} days'),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      upcoming.serviceType,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
                        const SizedBox(width: 5),
                        Text(
                          '${upcoming.formattedDate} • ${upcoming.timeSlot}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF374151)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 12, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${upcoming.centreName} (${upcoming.centreAddress})',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF6B7280)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, size: 12, color: Color(0xFF00D2AA)),
                        const SizedBox(width: 5),
                        Text(
                          'Reminder: ${upcoming.formattedReminder}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF00D2AA), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (upcoming.notes.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Notes: "${upcoming.notes}"',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => ServiceAppointmentManager.instance.launchDeviceCalendar(upcoming),
                          icon: const Icon(Icons.calendar_month_rounded, size: 12, color: Color(0xFF00D2AA)),
                          label: const Text('Add to Calendar', style: TextStyle(fontSize: 11, color: Color(0xFF00D2AA), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00D2AA)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => BookServiceAppointmentSheet.show(context, existingAppointment: upcoming),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Reschedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _confirmCancelAppointment(context, upcoming),
                          child: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            // Default Milestone reminder banner with direct "Book Service" button
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFFF1B343).withValues(alpha: 0.08) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFFF1B343).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFFF1B343) : const Color(0xFFD97706)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.build_circle_outlined, size: 20, color: isDark ? const Color(0xFFF1B343) : const Color(0xFFB45309)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'NEXT DUE: 1,000 KM INSPECTION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isDark ? const Color(0xFFF1B343) : const Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFFF1B343) : const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '160 km Left',
                                style: TextStyle(
                                  color: isDark ? Colors.black87 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'CarLinko Telematics Activation & 3DHT Diagnostic Scan (FOC)',
                          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF4B5563), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => BookServiceAppointmentSheet.show(
                          context,
                          initialServiceType: '1,000 km 1st Inspection & Activation (FOC)',
                        ),
                        icon: const Icon(Icons.event_available_rounded, size: 12),
                        label: const Text('Book', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D2AA),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => setState(() => _activeSubTab = 1),
                        child: Text(
                          'Find 3S/4S >',
                          style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFFF1B343) : const Color(0xFFB45309), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All (16)', 0, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Free Labour (6 FOC)', 1, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Major Services (4)', 2, isDark),
            ],
          ),
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
                    color: isSelected
                        ? accent.withValues(alpha: isDark ? 0.15 : 0.12)
                        : (isDark ? const Color(0xFF131922) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? accent
                          : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
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
                                color: isSelected
                                    ? accent
                                    : (isDark ? Colors.white : const Color(0xFF111827)),
                              ),
                            ),
                          ),
                          if (m.isLabourFoc)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('FOC', style: TextStyle(color: accent, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Mth ${m.month}', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF))),
                      const SizedBox(height: 2),
                      Text(
                        m.compulsoryFee == 0 ? 'FOC' : 'RM ${m.compulsoryFee.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : const Color(0xFF0F766E))
                              : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
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
                          Text(
                            'Month ${selected.month} • ${selected.title}',
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    if (selected.isLabourFoc)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent),
                        ),
                        child: Text('FREE LABOUR', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
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
                    color: isDark ? const Color(0xFF090D12) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COMPULSORY FEE',
                              style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selected.compulsoryFee == 0 ? 'FOC' : 'RM ${selected.compulsoryFee.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: accent),
                            ),
                            Text(
                              selected.isLabourFoc ? 'Labour FOC (Included)' : 'Labour: RM ${selected.labourFee.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 42, color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RECOMMENDED TOTAL',
                              style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white54 : const Color(0xFF6B7280), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selected.recommendedFee == 0 ? 'FOC' : 'RM ${selected.recommendedFee.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              'Includes optional wear items',
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Compulsory Parts Breakdown
                Text(
                  'COMPULSORY PARTS & SERVICES',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...selected.compulsoryParts.map((p) => _buildPartRow(p["name"], p["price"] as double, isCompulsory: true, isDark: isDark)),

                if (selected.recommendedParts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'RECOMMENDED ADDITIONAL ITEMS',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...selected.recommendedParts.map((p) => _buildPartRow(p["name"], p["price"] as double, isCompulsory: false, isDark: isDark)),
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
            foregroundColor: accent,
            side: BorderSide(color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
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
                      color: isDark ? const Color(0xFF090D12) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Milestone',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Labour',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('Compulsory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
                  // Rows
                  ..._milestones.map((m) {
                    final isHighlighted = _milestones.indexOf(m) == _selectedMilestoneIndex;
                    return InkWell(
                      onTap: () => setState(() => _selectedMilestoneIndex = _milestones.indexOf(m)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isHighlighted ? accent.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${m.km ~/ 1000}k km (M${m.month})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                m.isLabourFoc ? 'FOC' : 'RM ${m.labourFee.toInt()}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: m.isLabourFoc
                                      ? accent
                                      : (isDark ? Colors.white60 : const Color(0xFF4B5563)),
                                  fontWeight: m.isLabourFoc ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                m.compulsoryFee == 0 ? 'FOC' : 'RM ${m.compulsoryFee.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                m.recommendedFee == 0 ? 'FOC' : 'RM ${m.recommendedFee.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                ),
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
              children: [
                Text(
                  'OFFICIAL CHERY SERVICE GUIDELINES',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text('• Price reference as of 27 August 2026.', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF374151), height: 1.4)),
                const SizedBox(height: 4),
                Text('• Replacement item is based on month or mileage, whichever comes first.', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF374151), height: 1.4)),
                const SizedBox(height: 4),
                Text('• Free Labour (FOC): Month 1 (1k km), Month 12 (20k km), Month 24 (40k km), Month 36 (60k km), Month 48 (80k km), and Month 60 (100k km).', style: TextStyle(fontSize: 11.5, color: accent, height: 1.4, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('• Wheel alignment and balancing is recommended every 10,000 km.', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF374151), height: 1.4)),
                const SizedBox(height: 4),
                Text('• Complimentary car wash is carried out after the service/repair process.', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF374151), height: 1.4)),
                const SizedBox(height: 4),
                Text('• Free service offers exclude recommended wear items and wear labour.', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF374151), height: 1.4)),
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
                Text(
                  'OFFICIAL VEHICLE SPECIFICATIONS',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSpecRow('Model', 'Chery Tiggo 7 PHEV CSH (RHD)', isDark),
                _buildSpecRow('Powertrain', '1.5L Turbo + Dual Motors (CSH)', isDark),
                _buildSpecRow('System Output', '240 kW (326 PS) / 545 Nm', isDark),
                _buildSpecRow('Transmission', '3-speed Dedicated Hybrid (3DHT)', isDark),
                _buildSpecRow('Battery Capacity', '19.27 kWh (usable ~18.3 kWh)', isDark),
                _buildSpecRow('Electric Range', '80–100 km (NEDC rated 100 km)', isDark),
                _buildSpecRow('Fuel Tank', '51 Litres (RON95 compatible)', isDark),
                _buildSpecRow('Target Cold Tyre Pressure', '230 kPa (2.3 bar / 33.4 psi)', isDark),
                _buildSpecRow('Vehicle Warranty', '7 Years / 150,000 km', isDark),
                _buildSpecRow('Battery Warranty', '8 Years / 160,000 km', isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index, bool isDark) {
    final isSelected = _filterIndex == index;
    final accent = context.tokens.accent;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected
              ? accent
              : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
        ),
      ),
      selected: isSelected,
      selectedColor: accent.withValues(alpha: isDark ? 0.15 : 0.12),
      backgroundColor: isDark ? const Color(0xFF131922) : const Color(0xFFF3F4F6),
      side: BorderSide(
        color: isSelected
            ? accent
            : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE5E7EB)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) => setState(() => _filterIndex = index),
    );
  }

  Widget _buildPartRow(String name, double price, {required bool isCompulsory, required bool isDark}) {
    final isFoc = price == 0.00;
    final accent = context.tokens.accent;
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
                  color: isCompulsory
                      ? accent
                      : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompulsory
                          ? (isDark ? Colors.white : const Color(0xFF111827))
                          : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
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
              color: isFoc
                  ? accent
                  : (isCompulsory
                      ? (isDark ? Colors.white : const Color(0xFF111827))
                      : (isDark ? Colors.white70 : const Color(0xFF4B5563))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String val, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF6B7280))),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

