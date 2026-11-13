import 'src/carlinko/carlinko_api.dart';
import 'src/ui/book_service_appointment_sheet.dart';
import 'src/service/service_appointment_manager.dart';
import 'src/service/location_tracker_service.dart';
import 'src/service/vehicle_alert_notifier.dart';
import 'src/service/bluetooth_driving_tracker_service.dart';
import 'src/service/background_guardian_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/ai/ai_service.dart';
import 'src/carlinko/vehicle_repository.dart';
import 'src/carlinko/carlinko_ble_controller.dart';
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

  // Background GPS tracker & Cloud Notice Sync (~every 15 min, independent of the app being
  // open). No-ops quickly inside the task itself if no car is bound yet.
  unawaited(LocationTrackerService.initializeAndSchedule());

  // Android 13+ requires this prompt before a local notification (door
  // ajar / low 12V alerts) can actually show.
  unawaited(VehicleAlertNotifier.requestPermission());

  // Check 24/7 Background Vehicle Guardian Service
  unawaited(BackgroundGuardianService.instance.isGuardianEnabled().then((enabled) {
    if (enabled) {
      BackgroundGuardianService.instance.setGuardianEnabled(true);
    }
  }));

  unawaited(BluetoothDrivingTrackerService.instance.init());
  unawaited(CarLinkoBleController().init());
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

    // Try to restore a real CarLinko session (saved token) first, so the
    // user isn't forced to log in again every cold start. This runs in the
    // background — don't block the splash screen on a network round trip.
    unawaited(() async {
      final restored = await AppVehicleRepository.instance.restoreSession();
      if (!restored && s.carLinkoStatus == 'Active') {
        // No saved token (e.g. upgrading from a build that never saved
        // one) — fall back to the old cosmetic "pending bind" placeholder.
        try {
          final prefs = await SharedPreferences.getInstance();
          final acc = prefs.getString('tm_carlinko_account') ?? s.ownerName;
          AppVehicleRepository.instance.setPreActivationActive(account: acc);
        } catch (_) {}
      }
    }());

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
        currentOdometerKm: _vehicleRepo.currentTelemetry.odometerKm > 0
            ? _vehicleRepo.currentTelemetry.odometerKm
            : 1420,
        currentBatteryPct: _vehicleRepo.currentTelemetry.batteryPct > 0
            ? _vehicleRepo.currentTelemetry.batteryPct
            : 78,
        myTnbRepo: _myTnbRepo,
      ),
      MaintenanceTab(settings: _settings),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D0F14) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _buildCyberBottomNavItem(0, 'CAR', Icons.directions_car_outlined, Icons.directions_car),
                  _buildCyberBottomNavItem(1, 'ASSISTANT', Icons.chat_bubble_outline, Icons.chat_bubble),
                  _buildCyberBottomNavItem(2, 'LOG', Icons.route_outlined, Icons.route),
                  _buildCyberBottomNavItem(3, 'SERVICE', Icons.build_outlined, Icons.build),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCyberBottomNavItem(int index, String label, IconData unselectedIcon, IconData selectedIcon) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.tokens.accent;
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top active indicator pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 32 : 0,
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              size: 24,
              color: isSelected ? accent : textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.8,
                color: isSelected ? accent : textMuted,
              ),
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

class _AssistantTabState extends State<AssistantTab> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _isListening = false;
  TripRecord? _lastTrip;
  DateTime? _lastServiceDate;
  StreamSubscription? _telemetrySub;

  late final AnimationController _listenPulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  late final AnimationController _thinkingDotsCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    loadLatestSavedTrip().then((t) {
      if (mounted) setState(() => _lastTrip = t);
    });

    _telemetrySub = AppVehicleRepository.instance.telemetryStream.listen((_) {
      if (mounted) setState(() {});
    });
    SharedPreferences.getInstance().then((prefs) {
      final str = prefs.getString('tm_last_service_date');
      if (str != null && str.isNotEmpty && mounted) {
        setState(() => _lastServiceDate = DateTime.tryParse(str));
      }
    });
  }

  @override
  void dispose() {
    _listenPulseCtrl.dispose();
    _thinkingDotsCtrl.dispose();
    _telemetrySub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _listenVoice() async {
    HapticFeedback.mediumImpact();
    setState(() => _isListening = true);

    try {
      final recognized = await VoiceRecognitionService.startListening();
      if (!mounted) return;
      setState(() => _isListening = false);

      if (recognized != null && recognized.trim().isNotEmpty) {
        _controller.text = recognized;
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mic, color: Color(0xFFD2F835), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Heard: "$recognized"')),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF131922),
          ),
        );
        _sendMessage(recognized);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No speech recognized. Tap mic to try again or type below.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice Recognition: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Map<String, dynamic>? _matchActionFromPrompt(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('open') && (lower.contains('window') || lower.contains('tingkap'))) {
      return {
        'id': 'windows_open',
        'title': 'Open All Windows',
        'desc': 'Lowers all 4 power windows for cabin heat escape',
        'icon': Icons.window_outlined,
      };
    } else if (lower.contains('close') && (lower.contains('window') || lower.contains('tingkap'))) {
      return {
        'id': 'windows_close',
        'title': 'Close All Windows',
        'desc': 'Fully closes and seals all 4 windows with anti-pinch protection',
        'icon': Icons.window_rounded,
      };
    } else if (lower.contains('aircond') || lower.contains('ac') || lower.contains('cool') || lower.contains('climate')) {
      if (lower.contains('off') || lower.contains('stop') || lower.contains('tutup')) {
        return {
          'id': 'climate_off',
          'title': 'Turn Off A/C & Climate',
          'desc': 'Shuts down compressor and ventilation fans',
          'icon': Icons.power_settings_new_rounded,
        };
      } else {
        return {
          'id': 'climate_on',
          'title': 'Pre-cool Cabin (22°C)',
          'desc': 'Activates high-voltage A/C compressor and cabin pre-conditioning',
          'icon': Icons.ac_unit_rounded,
        };
      }
    } else if (lower.contains('engine') || lower.contains('enjin')) {
      if (lower.contains('stop') || lower.contains('off') || lower.contains('mati')) {
        return {
          'id': 'engine_stop',
          'title': 'Remote Engine Stop',
          'desc': 'Stops the 1.5T hybrid engine safely',
          'icon': Icons.power_settings_new_rounded,
        };
      } else {
        return {
          'id': 'engine_start',
          'title': 'Remote Engine Pre-Warm',
          'desc': 'Starts 1.5T engine for 10-minute powertrain pre-warming',
          'icon': Icons.key_rounded,
        };
      }
    } else if (lower.contains('lock') || lower.contains('kunci')) {
      if (lower.contains('unlock') || lower.contains('buka')) {
        return {
          'id': 'unlock',
          'title': 'Unlock Doors',
          'desc': 'Unlocks central locking system',
          'icon': Icons.lock_open_rounded,
        };
      } else {
        return {
          'id': 'lock',
          'title': 'Lock Vehicle Doors',
          'desc': 'Secures all doors and arms alarm system',
          'icon': Icons.lock_outline_rounded,
        };
      }
    }
    return null;
  }

  IconData _getIconForAction(String actionId) {
    switch (actionId) {
      case 'windows_open':
      case 'windows_vent':
        return Icons.window_outlined;
      case 'windows_close':
        return Icons.window_rounded;
      case 'climate_on':
        return Icons.ac_unit_rounded;
      case 'climate_off':
        return Icons.power_settings_new_rounded;
      case 'door_lock':
      case 'lock':
        return Icons.lock_outline_rounded;
      case 'door_unlock':
      case 'unlock':
        return Icons.lock_open_rounded;
      case 'sunroof_open':
      case 'sunroof_close':
        return Icons.roofing_rounded;
      case 'trunk_open':
        return Icons.sensor_door_outlined;
      case 'engine_start':
        return Icons.key_rounded;
      case 'engine_stop':
        return Icons.power_settings_new_rounded;
      case 'schedule_charging':
        return Icons.ev_station_rounded;
      case 'check_tnb':
        return Icons.bolt_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.add({"role": "user", "content": text});
      _loading = true;
    });
    _scrollToBottom();

    final telemetry = AppVehicleRepository.instance.currentTelemetry;
    final currentKm = AppVehicleRepository.instance.isVehicleBound && telemetry.odometerKm > 0
        ? telemetry.odometerKm
        : 2197;
    final kmLeft = (10000 - currentKm).clamp(0, 10000);
    final daysLeft = _lastServiceDate != null
        ? (180 - DateTime.now().difference(_lastServiceDate!).inDays).clamp(1, 365)
        : (kmLeft / 52.7).round().clamp(1, 365);
    final nextServiceInfo = 'Next Scheduled Service: Minor Service (10k) in $kmLeft km / ~$daysLeft days';

    final liveEvKm = telemetry.electricRangeKm > 0 ? telemetry.electricRangeKm : (telemetry.batteryPct * 0.85).round();
    final liveFuelKm = telemetry.fuelRangeKm;
    final liveTotalKm = telemetry.totalRangeKm > 0 ? telemetry.totalRangeKm : (liveEvKm + liveFuelKm);

    final liveStatus = [
      'Live Total Combined Range: $liveTotalKm km (EV: $liveEvKm km + Petrol: $liveFuelKm km)',
      'Traction Battery SoC: ${telemetry.batteryPct}% ($liveEvKm km EV range remaining)',
      'Fuel Tank: ${telemetry.fuelCapacityPct}% ($liveFuelKm km petrol range, current consumption: ${telemetry.fuelConsumptionL100km > 0 ? "${telemetry.fuelConsumptionL100km.toStringAsFixed(1)} L/100km" : "7.5 L/100km"})',
      'Doors: ${telemetry.doorsOpen ? "OPEN / AJAR" : "All Doors Closed & Secured"}',
      '12V Auxiliary Battery: ${telemetry.volt12 > 0 ? "${telemetry.volt12.toStringAsFixed(2)}V" : "12.82V (Healthy)"}',
      'Tyre Pressures (Cold Target 230 kPa): FL ${telemetry.tyreFlPressureKpa.round()} kPa, FR ${telemetry.tyreFrPressureKpa.round()} kPa, RL ${telemetry.tyreRlPressureKpa.round()} kPa, RR ${telemetry.tyreRrPressureKpa.round()} kPa',
      'Cabin Climate / AC: ${telemetry.acOn ? "ON (${telemetry.acTemp}°C)" : "OFF"}',
      'Windows: ${telemetry.windowsOpen ? "Open" : "Closed"}',
      'Sunroof: ${telemetry.sunroofOpen ? "Open" : "Closed"}',
      'Transmission State: ${telemetry.isParked ? "Parked (P)" : "Drive / Moving"}',
      if (telemetry.hasLocation && telemetry.locationName.isNotEmpty && telemetry.locationName != 'Pending Car Bind')
        'Current Vehicle GPS: ${telemetry.locationName} (${telemetry.latitude.toStringAsFixed(5)}, ${telemetry.longitude.toStringAsFixed(5)})'
      else
        'Current Vehicle GPS: Pending satellite fix from Chery T-Box',
    ].join('\n- ');

    // 1. Direct Cloud AI Call with FULL Live Telematics Grounding
    if (widget.settings.aiApiKey.trim().isNotEmpty) {
      try {
        final history = <Map<String, String>>[];
        for (final m in _messages.reversed.take(6).toList().reversed) {
          if (m['role'] == 'user' && m['content'] != null) {
            history.add({'role': 'user', 'content': m['content'] as String});
          } else if (m['role'] == 'assistant' && m['content'] != null) {
            history.add({'role': 'assistant', 'content': m['content'] as String});
          }
        }
        if (history.isNotEmpty && history.last['content'] == text) {
          history.removeLast();
        }

        final tripSummary = await getTripSummaryForAi();

        final aiReply = await AiConfigResolver.queryAi(
          prompt: text,
          apiKey: widget.settings.aiApiKey,
          provider: widget.settings.aiProvider,
          modelInput: widget.settings.aiModel,
          customHost: widget.settings.aiHost,
          batteryPct: telemetry.batteryPct > 0 ? telemetry.batteryPct : 78,
          carPlate: widget.settings.carPlateNumber,
          odometerKm: currentKm,
          nextServiceInfo: nextServiceInfo,
          lastServiceInfo: ServiceAppointmentManager.instance.getServiceSummaryForAi(),
          tripInfo: tripSummary,
          liveStatusBlock: liveStatus,
          history: history,
        );

        if (!mounted) return;

        Map<String, dynamic>? action;
        String cleanText = aiReply;

        if (cleanText.isEmpty || cleanText.startsWith('No response generated from')) {
          throw Exception('Empty or unparsed AI response, falling back to grounded telemetry.');
        }

        final actionRegex = RegExp(r'\[ACTION:\s*([a-zA-Z0-9_]+)\s*\|\s*([^|]+)\s*\|\s*([^\]]+)\]');
        final match = actionRegex.firstMatch(aiReply);
        if (match != null) {
          final actId = match.group(1)!.trim();
          action = {
            'id': actId,
            'title': match.group(2)!.trim(),
            'desc': match.group(3)!.trim(),
            'icon': _getIconForAction(actId),
          };
          cleanText = aiReply.replaceFirst(match.group(0)!, '').trim();
        } else {
          action = _matchActionFromPrompt(text);
        }

        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': cleanText,
            'citations': [
              {"document": "Live AI (${widget.settings.aiModel.isNotEmpty ? widget.settings.aiModel : 'Claude'})", "section": "Live Telematics Grounded", "page": 1}
            ],
            'action': action,
          });
          _loading = false;
        });
        _scrollToBottom();
        return;
      } catch (e) {
        debugPrint('Direct AI Engine Call failed, falling back to Grounded Offline Telematics: $e');
      }
    }

    // 2. Offline Grounded Telematics & Knowledge Base Fallback
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final q = text.toLowerCase();
    String answer;
    List<Map<String, dynamic>> citations = [];
    Map<String, dynamic>? action = _matchActionFromPrompt(text);

    if (q.contains("battery") || q.contains("soc") || q.contains("charge") || q.contains("range") || q.contains("bateri")) {
      answer = "### Vehicle Battery & Range Telematics\n\n"
          "- **Traction Battery SoC:** **${telemetry.batteryPct}%** (~${(telemetry.batteryPct * 0.85).round()} km EV range)\n"
          "- **Fuel Tank:** **${telemetry.fuelCapacityPct}%** (~${telemetry.fuelRangeKm > 0 ? telemetry.fuelRangeKm : 740} km petrol range)\n"
          "- **12V Auxiliary Battery:** **${telemetry.volt12 > 0 ? "${telemetry.volt12.toStringAsFixed(2)}V" : "12.82V (Healthy)"}**\n\n"
          "Your 18.3 kWh LFP pack supports 6.6 kW AC charging (~2.8 hrs 0-100%).";
      citations = [{"document": "Vehicle BMS Telematics", "section": "High-Voltage System", "page": 1}];
    } else if (q.contains("tyre") || q.contains("tire") || q.contains("pressure") || q.contains("tpms") || q.contains("tayar")) {
      answer = "### Direct TPMS Tyre Pressure Telematics\n\n"
          "Target cold pressure: **230 kPa (2.3 bar / 33.4 psi)**\n\n"
          "- **Front Left (FL):** **${telemetry.tyreFlPressureKpa.round()} kPa** (${telemetry.tyreFlPressureKpa >= 220 && telemetry.tyreFlPressureKpa <= 245 ? 'Optimal ✓' : 'Inspect'})\n"
          "- **Front Right (FR):** **${telemetry.tyreFrPressureKpa.round()} kPa** (${telemetry.tyreFrPressureKpa >= 220 && telemetry.tyreFrPressureKpa <= 245 ? 'Optimal ✓' : 'Inspect'})\n"
          "- **Rear Left (RL):** **${telemetry.tyreRlPressureKpa.round()} kPa** (${telemetry.tyreRlPressureKpa >= 220 && telemetry.tyreRlPressureKpa <= 245 ? 'Optimal ✓' : 'Inspect'})\n"
          "- **Rear Right (RR):** **${telemetry.tyreRrPressureKpa.round()} kPa** (${telemetry.tyreRrPressureKpa >= 220 && telemetry.tyreRrPressureKpa <= 245 ? 'Optimal ✓' : 'Inspect'})";
      citations = [{"document": "Direct TPMS Sensors", "section": "Chassis Telematics", "page": 1}];
    } else if (q.contains("odometer") || q.contains("mileage") || q.contains("distance") || q.contains("batu")) {
      answer = "### Current Vehicle Mileage\n\n"
          "- **Current Odometer:** **$currentKm km**\n"
          "- **Next Service:** **Minor Service (10k)** in **$kmLeft km** (~**$daysLeft days**)\n"
          "- **Total Lifetime Fuel Avg:** **${telemetry.fuelConsumptionL100km > 0 ? "${telemetry.fuelConsumptionL100km.toStringAsFixed(1)} L/100km" : "6.10 L/100km"}**";
      citations = [{"document": "Instrument Cluster Telematics", "section": "Odometer & Trip", "page": 1}];
    } else if (q.contains("door") || q.contains("pintu") || q.contains("lock") || q.contains("window") || q.contains("status") || q.contains("ajar")) {
      answer = "### Body & Security Status\n\n"
          "- **Doors:** ${telemetry.doorsOpen ? '**DOOR AJAR ⚠️**' : '**All Doors Closed & Locked ✓**'}\n"
          "- **Windows:** ${telemetry.windowsOpen ? '**Open**' : '**Closed & Sealed ✓**'}\n"
          "- **Sunroof:** ${telemetry.sunroofOpen ? '**Open**' : '**Closed ✓**'}\n"
          "- **Parking State:** ${telemetry.isParked ? '**Parked (P)**' : '**In Motion**'}"
          "${telemetry.locationName.isNotEmpty ? '\n- **Location:** ${telemetry.locationName}' : ''}";
      citations = [{"document": "BCM Security Telematics", "section": "Perimeter Monitoring", "page": 1}];
    } else if (q.contains("12v") || q.contains("voltage") || q.contains("voltan")) {
      answer = "### 12V Auxiliary Battery Telematics\n\n"
          "- **Current Voltage:** **${telemetry.volt12 > 0 ? "${telemetry.volt12.toStringAsFixed(2)}V" : "12.82V"}**\n"
          "- **Threshold:** Alerts trigger below **12.00V**.\n"
          "- **Health Status:** ${telemetry.volt12 >= 12.2 ? '**Healthy & Fully Operational ✓**' : '**Charge Advised (take a short drive)**'}";
      citations = [{"document": "Vehicle Power Management", "section": "12V Low Voltage Rail", "page": 1}];
    } else if (q.contains("location") || q.contains("where is") || q.contains("lokasi") || q.contains("find car") || q.contains("kedudukan")) {
      final locText = telemetry.locationName.isNotEmpty && telemetry.locationName != 'Pending Car Bind'
          ? telemetry.locationName
          : (telemetry.latitude != 0.0 ? '${telemetry.latitude.toStringAsFixed(5)}, ${telemetry.longitude.toStringAsFixed(5)}' : 'Locating via GPS...');
      answer = "### Vehicle Location & GPS Telematics\n\n"
          "- **Address:** **$locText**\n"
          "${telemetry.latitude != 0.0 ? '- **Coordinates:** **${telemetry.latitude.toStringAsFixed(5)}, ${telemetry.longitude.toStringAsFixed(5)}**\n' : ''}"
          "- **Status:** ${telemetry.isParked ? 'Parked safely' : 'Vehicle is in transit'}\n\n"
          "> **Radar:** Tap **Radar** from the Car dashboard to view live distance, compass bearing, and nearby DC fast chargers.";
      citations = [{"document": "Vehicle GPS & Telematics", "section": "Navigation & Positioning", "page": 1}];
    } else if (q.contains("auto") || q.contains("engine start") || q.contains("petrol engine") || q.contains("ev mode") || q.contains("hev")) {
      answer = "### Understanding AUTO Mode & Hybrid Logic\n\nIn **AUTO Mode**, your Tiggo 7 PHEV acts primarily as a pure electric vehicle in city traffic:\n\n- **Electric First:** The dual electric motors drive the wheels silently using the 18.3 kWh battery.\n- **Engine Engagement:** The 1.5L Turbo engine only starts when:\n  1. Battery SOC drops below ~20-25%.\n  2. You apply heavy throttle for swift overtaking (kickdown).\n  3. Highway cruising speeds (>85 km/h) where direct engine drive via the 3-speed DHT 3rd gear is most efficient.\n\n> **Tip:** If your battery is well charged and you drive moderately, it is completely normal for the petrol engine to stay silent for weeks in city commutes!";
      citations = [{"document": "Chery Tiggo 7 PHEV Owner's Manual", "section": "Powertrain & Drive Modes", "page": 142}];
    } else if (q.contains("service") || q.contains("schedule") || q.contains("price") || q.contains("pricing") || q.contains("maintenance")) {
      answer = "### Chery Tiggo 7 PHEV CSH Service Schedule Overview\n\nKey points from the official 27 August 2026 schedule:\n\n- **1,000 km:** 1st Inspection — **FOC**\n- **10,000 km:** Oil Service — **RM 407.50** (Due in **$kmLeft km** / **~$daysLeft days**)\n- **20,000 km:** Oil + Air Filter — **RM 444.60 (Free Labour)**\n- **30,000 km:** Oil + Spark Plugs — **RM 715.90**\n- **40,000 km:** Major Service (Trans Oil, Coolant, Brake Fluid) — **RM 1,085.60 (Free Labour)**\n- **60,000 km:** Major Service (Air Filter + Plugs) — **RM 753.00 (Free Labour)**\n- **Free Labour Milestones:** 1k, 20k, 40k, 60k, 80k, and 100k km!\n\n> **Manual Citation:** *Chery Tiggo 7 PHEV CSH Service Schedule & Pricing Guide*, 27 August 2026.";
      citations = [{"document": "Chery Tiggo 7 PHEV CSH Service Schedule", "section": "Overview", "page": 1}];
    } else if (q.contains("last trip") || q.contains("latest trip") || q.contains("trip") || q.contains("perjalanan") || q.contains("drive") || q.contains("logbook")) {
      final trips = await loadRecentTrips(limit: 5);
      if (!mounted) return;
      if (trips.isEmpty) {
        answer = 'You have no trips logged yet. Record a drive, let Auto-Trip detect when connected, or tap **+ Add Trip** in the **LOG** tab.';
      } else {
        final lastTrip = trips.first;
        final energy = [
          if (lastTrip.electricKwh > 0) '${lastTrip.electricKwh.toStringAsFixed(1)} kWh EV',
          if (lastTrip.petrolLitres > 0) '${lastTrip.petrolLitres.toStringAsFixed(1)} L of petrol',
        ].join(' and ');
        answer = 'Last trip was **${lastTrip.title} (${lastTrip.distanceKm.toStringAsFixed(1)} km)**. '
            'Driven ${lastTrip.evRatio.round()}% on EV${energy.isEmpty ? '' : ' using $energy'}. '
            'Duration: ${lastTrip.durationMinutes} min (Avg ${lastTrip.avgSpeedKmh.toStringAsFixed(0)} km/h). '
            'Total cost: **RM ${lastTrip.costRm.toStringAsFixed(2)}**.';
      }
      citations = [{"document": "Trips Logbook", "section": "Recent Drives", "page": 1}];
    } else if (q.contains("cost") || q.contains("petrol") || q.contains("saving")) {
      answer = "### Tiggo 7 PHEV Energy & Running Cost Breakdown (100 km Baseline)\n\n- **Home AC Electricity:** 12.25 kWh @ RM ${widget.settings.tnbTariff.toStringAsFixed(2)}/kWh (TNB) = **RM ${(12.25 * widget.settings.tnbTariff).toStringAsFixed(2)}**\n- **Petrol:** 1.56 L @ RM ${widget.settings.fuelPrice.toStringAsFixed(2)}/L = **RM ${(1.56 * widget.settings.fuelPrice).toStringAsFixed(2)}**\n- **Total PHEV Cost:** **RM ${(12.25 * widget.settings.tnbTariff + 1.56 * widget.settings.fuelPrice).toStringAsFixed(2)} / 100 km**\n- **Pure Petrol SUV Benchmark:** 7.8 L/100km = **RM ${(7.8 * widget.settings.fuelPrice).toStringAsFixed(2)}**\n\n🎉 **Savings:** You save **~36.3%** on fuel & electricity costs!";
      citations = [{"document": "TNB Residential Tariff Schedule & KPDN RON95 Gazette", "section": "Energy Economics", "page": 1}];
    } else if (q.contains("highway") || q.contains("plus") || q.contains("battery preservation")) {
      answer = "### Highway Battery Management Strategy (e.g. PLUS Highway)\n\nWhen embarking on a long interstate journey:\n\n1. **Switch to HEV or AUTO at On-Ramp:** Avoid running pure EV at 110–120 km/h, which depletes the battery rapidly due to aerodynamic drag.\n2. **Hold SOC for City Driving:** Direct engine drive in 3DHT 3rd gear is thermally optimal on highways. Save battery power for dense traffic in Kuala Lumpur, Penang, or Johor Bahru.\n3. **Reserve Charge:** Keep battery above 30% to guarantee instant dual-motor torque for high-speed overtaking.";
      citations = [{"document": "Chery Tiggo 7 PHEV Owner's Manual", "section": "CSH Hybrid Strategy", "page": 156}];
    } else if (q.contains("window") || q.contains("tingkap")) {
      answer = action != null && action['id'] == 'windows_open'
          ? "I have prepared the command to lower all 4 power windows to release cabin heat. Tap execute below."
          : "I have prepared the command to close and seal all 4 windows. Tap execute below.";
      citations = [{"document": "CarLinko Telematics System", "section": "Body Control", "page": 1}];
    } else if (q.contains("aircond") || q.contains("climate") || q.contains("cool")) {
      answer = "Prepared climate command for your Tiggo 7 PHEV (${widget.settings.carPlateNumber}). The high-voltage compressor will cool the cabin before you board.";
      citations = [{"document": "CarLinko Telematics System", "section": "Thermal Comfort", "page": 1}];
    } else {
      answer = "I understand you are asking about: \"$text\".\n\nYour Chery Tiggo 7 PHEV CSH is equipped with an intelligent dedicated hybrid system (3DHT, 240 kW / 545 Nm, 18.3 kWh battery).\n\n"
          "- **Current Odometer:** **$currentKm km**\n"
          "- **Battery SoC:** **${telemetry.batteryPct}%**\n"
          "- **Tyres:** **FL ${telemetry.tyreFlPressureKpa.round()} kPa | FR ${telemetry.tyreFrPressureKpa.round()} kPa**\n"
          "- **Doors:** ${telemetry.doorsOpen ? 'Door Ajar ⚠️' : 'Closed & Secured ✓'}\n"
          "- **Next Service:** $nextServiceInfo";
      citations = [{"document": "Chery Tiggo 7 PHEV Telematics", "section": "Vehicle Live State", "page": 1}];
    }

    setState(() {
      _messages.add({
        "role": "assistant",
        "content": answer,
        "citations": citations,
        "action": action,
      });
      _loading = false;
    });
    _scrollToBottom();
  }


  void _showHabitsDetail(BuildContext context, bool isDark) {
    final bgCol = isDark ? const Color(0xFF131922) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final accent = context.tokens.accent;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgCol,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Driving Habits & Efficiency',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your Chery Tiggo 7 PHEV driving telemetry across logged trips in Malaysia.',
              style: TextStyle(fontSize: 13, color: textMuted),
            ),
            const SizedBox(height: 16),
            if (_lastTrip != null) ...[
              Text(
                'Latest Trip: ${_lastTrip!.title}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Distance: ${_lastTrip!.distanceKm.toStringAsFixed(1)} km · EV Ratio: ${_lastTrip!.evRatio.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12.5, color: textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Cost: RM ${_lastTrip!.costRm.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12.5, color: accent, fontWeight: FontWeight.bold),
              ),
            ] else ...[
              Text(
                'No trips recorded yet. Log your drives from the LOG tab to calculate your PHEV electric vs petrol savings.',
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color cardCol,
    required Color borderCol,
    required Color textPrimary,
    required Color textMuted,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardCol,
    required Color borderCol,
    required Color textPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol, width: 1.0),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF6F8FA);
    final cardCol = isDark ? const Color(0xFF131922) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);
    final accent = context.tokens.accent;

    final telemetry = AppVehicleRepository.instance.currentTelemetry;

    final String lastTripText = _lastTrip != null && _lastTrip!.distanceKm > 0
        ? '${_lastTrip!.title} (${_lastTrip!.distanceKm.toStringAsFixed(1)} km)'
        : 'No trips logged yet';

    final String conditionText;
    if (telemetry.doorsOpen) {
      conditionText = 'Door Ajar';
    } else if (telemetry.volt12 > 0 && telemetry.volt12 < 12.0) {
      conditionText = 'Low 12V (${telemetry.volt12.toStringAsFixed(1)}V)';
    } else if (telemetry.isParked) {
      conditionText = 'Parked & Secure';
    } else {
      conditionText = 'All Systems Normal';
    }

    final currentKm = AppVehicleRepository.instance.isVehicleBound && telemetry.odometerKm > 0
        ? telemetry.odometerKm
        : 2197;
    final kmLeft = (10000 - currentKm).clamp(0, 10000);
    final daysLeft = _lastServiceDate != null
        ? (180 - DateTime.now().difference(_lastServiceDate!).inDays).clamp(1, 365)
        : (kmLeft / 52.7).round().clamp(1, 365);
    final reminderText = 'Minor Service (10k) in $kmLeft km / ~$daysLeft days';

    final String habitsText = _lastTrip != null && _lastTrip!.distanceKm > 0
        ? '${_lastTrip!.evRatio.round()}% EV Driving'
        : 'No trips logged yet';

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Bar matching Screenshot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0B0E) : Colors.white,
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'TiggoMate AI Copilot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.settings.aiApiKey.trim().isNotEmpty
                              ? 'Live • ${widget.settings.aiModel}'
                              : 'Live • claude-haiku-4.5',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.onOpenSettings,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131922) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderCol),
                          ),
                          child: Icon(Icons.tune, color: accent, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Main Scrollable Content
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // 2x2 Insight Cards Grid (Screenshot elements 1-4)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildInsightCard(
                              icon: Icons.route_outlined,
                              iconColor: const Color(0xFF2DD4BF),
                              title: 'LAST TRIP',
                              value: lastTripText,
                              cardCol: cardCol,
                              borderCol: borderCol,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                              onTap: () => _sendMessage('What was my last trip?'),
                            ),
                            const SizedBox(width: 10),
                            _buildInsightCard(
                              icon: Icons.favorite_border_rounded,
                              iconColor: const Color(0xFFFB923C),
                              title: 'CONDITION',
                              value: conditionText,
                              cardCol: cardCol,
                              borderCol: borderCol,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                              onTap: () => _sendMessage('What is the vehicle status?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildInsightCard(
                              icon: Icons.calendar_today_outlined,
                              iconColor: const Color(0xFF60A5FA),
                              title: 'REMINDER',
                              value: reminderText,
                              cardCol: cardCol,
                              borderCol: borderCol,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                              onTap: () => _sendMessage('When is my next service?'),
                            ),
                            const SizedBox(width: 10),
                            _buildInsightCard(
                              icon: Icons.trending_up_rounded,
                              iconColor: const Color(0xFFA78BFA),
                              title: 'HABITS',
                              value: habitsText,
                              cardCol: cardCol,
                              borderCol: borderCol,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                              onTap: () => _showHabitsDetail(context, isDark),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tiggo AI Copilot Online Welcome Banner Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.auto_awesome, color: accent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tiggo AI Copilot Online',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Chery Tiggo 7 PHEV Intelligent Assistant',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ask about your Tiggo 7, or instruct me to control it directly.',
                          style: TextStyle(
                            fontSize: 13,
                            color: textPrimary.withValues(alpha: 0.88),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Action Guidance Chips
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildInstructionChip(
                          label: 'Pre-cool cabin to 22°C',
                          onTap: () => _sendMessage('turn on aircond to 22°C'),
                          isDark: isDark,
                          cardCol: cardCol,
                          borderCol: borderCol,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 8),
                        _buildInstructionChip(
                          label: 'Open all windows',
                          onTap: () => _sendMessage('open all window'),
                          isDark: isDark,
                          cardCol: cardCol,
                          borderCol: borderCol,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 8),
                        _buildInstructionChip(
                          label: 'When is my next service?',
                          onTap: () => _sendMessage('When is my 1,000 km CarLinko inspection due?'),
                          isDark: isDark,
                          cardCol: cardCol,
                          borderCol: borderCol,
                          textPrimary: textPrimary,
                        ),
                        const SizedBox(width: 8),
                        _buildInstructionChip(
                          label: 'Calculate 100 km charging cost vs petrol',
                          onTap: () => _sendMessage('Calculate 100 km charging cost vs petrol'),
                          isDark: isDark,
                          cardCol: cardCol,
                          borderCol: borderCol,
                          textPrimary: textPrimary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Conversation Messages
                  ..._messages.map((msg) {
                    final isUser = msg["role"] == "user";
                    final citations = msg["citations"] as List<dynamic>?;
                    final action = msg["action"] as Map<String, dynamic>?;

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                        decoration: BoxDecoration(
                          color: isUser
                              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
                              : cardCol,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(16),
                            bottomLeft: !isUser ? const Radius.circular(2) : const Radius.circular(16),
                          ),
                          border: Border.all(
                            color: isUser
                                ? (isDark ? const Color(0xFF334155) : const Color(0xFF1E293B))
                                : borderCol,
                            width: 1.0,
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
                            if (action != null) ...[
                              const SizedBox(height: 10),
                              _ActionExecutionCard(
                                actionId: action['id'] as String? ?? 'action',
                                title: action['title'] as String? ?? 'Action',
                                description: action['desc'] as String? ?? '',
                                icon: (action['icon'] as IconData?) ?? Icons.bolt_rounded,
                                onExecute: (id) async {
  final opcode = id == 'windows_open'
      ? CarLinkoOpcodes.windowsOpen
      : id == 'windows_close'
          ? CarLinkoOpcodes.windowsClose
          : id == 'climate_on'
              ? CarLinkoOpcodes.acOn
              : id == 'climate_off'
                  ? CarLinkoOpcodes.acOff
                  : id == 'engine_start'
                      ? CarLinkoOpcodes.engineStart
                      : id == 'engine_stop'
                          ? CarLinkoOpcodes.engineStop
                          : id == 'lock'
                              ? CarLinkoOpcodes.lock
                              : CarLinkoOpcodes.unlock;
  await AppVehicleRepository.instance.sendRemoteCommand(opcode);
},
                                cardCol: isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF1F5F9),
                                borderCol: borderCol,
                                limeAccent: accent,
                                textPrimary: textPrimary,
                                textMuted: textMuted,
                              ),
                            ],
                            if (citations != null && citations.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.35),
                                    width: 1.0,
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
                  }),

                  // Reasoning animation
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _ThinkingDots(animation: _thinkingDotsCtrl, color: accent),
                          const SizedBox(width: 10),
                          Text(
                            'AI Copilot is reasoning...',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 3. Chat Input Bar matching Screenshot
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0B0E) : Colors.white,
                border: Border(top: BorderSide(color: borderCol)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131922) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isListening ? const Color(0xFFFF5252) : borderCol,
                          width: _isListening ? 1.5 : 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? 'Listening... Speak command now'
                              : 'Ask about your Tiggo 7...',
                          hintStyle: TextStyle(
                            color: _isListening
                                ? const Color(0xFFFF5252)
                                : (isDark ? const Color(0xFF525A6C) : const Color(0xFF9CA3AF)),
                            fontSize: 13,
                            fontWeight: _isListening ? FontWeight.w600 : FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Voice Mic Button with wave animation
                  InkWell(
                    onTap: _listenVoice,
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: AnimatedBuilder(
                        animation: _listenPulseCtrl,
                        builder: (context, _) {
                          final t = _listenPulseCtrl.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_isListening) ...[
                                _PulseRing(progress: t, color: const Color(0xFFFF5252)),
                                _PulseRing(progress: (t + 0.5) % 1.0, color: const Color(0xFFFF5252)),
                              ],
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _isListening
                                      ? const Color(0xFFFF5252)
                                      : (isDark ? const Color(0xFF1E2636) : const Color(0xFFE2E8F0)),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isListening ? const Color(0xFFFF5252) : borderCol,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                                    size: 20,
                                    color: _isListening ? Colors.white : accent,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Neon Lime Send Button matching Screenshot
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFF0A0B0E)),
                      onPressed: () => _sendMessage(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _ActionExecutionCard extends StatefulWidget {
  final String actionId;
  final String title;
  final String description;
  final IconData icon;
  final Function(String id)? onExecute;
  final Color cardCol;
  final Color borderCol;
  final Color limeAccent;
  final Color textPrimary;
  final Color textMuted;

  const _ActionExecutionCard({
    required this.actionId,
    required this.title,
    required this.description,
    required this.icon,
    this.onExecute,
    required this.cardCol,
    required this.borderCol,
    required this.limeAccent,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  State<_ActionExecutionCard> createState() => _ActionExecutionCardState();
}

class _ActionExecutionCardState extends State<_ActionExecutionCard> {
  bool _executed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.cardCol,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _executed ? const Color(0xFF10B981) : widget.limeAccent.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (_executed ? const Color(0xFF10B981) : widget.limeAccent).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _executed ? Icons.check_circle_outline_rounded : widget.icon,
                  size: 18,
                  color: _executed ? const Color(0xFF10B981) : widget.limeAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: widget.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: TextStyle(fontSize: 11, color: widget.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _executed
                  ? null
                  : () {
                      HapticFeedback.heavyImpact();
                      widget.onExecute?.call(widget.actionId);
                      setState(() => _executed = true);
                    },
              icon: Icon(
                _executed ? Icons.check : Icons.send_rounded,
                size: 15,
                color: _executed ? Colors.white70 : const Color(0xFF0A0B0E),
              ),
              label: Text(
                _executed ? 'Executed ✓ (Transmitted to CarLinko T-Box)' : 'Confirm & Execute Action',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _executed ? Colors.white70 : const Color(0xFF0A0B0E),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _executed ? const Color(0xFF10B981) : widget.limeAccent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final double progress;
  final Color color;

  const _PulseRing({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final size = 38.0 + (progress * 20.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity), width: 1.5),
      ),
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _ThinkingDots({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return SizedBox(
          width: 28,
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final phase = (animation.value + (i * 0.33)) % 1.0;
              final bounce = (1.0 - (2 * phase - 1).abs()).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5 + (0.5 * bounce)),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        );
      },
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
                const Text('0–100% full charge in ~2.8 hours on AC Wallbox (18.3 kWh pack)', style: TextStyle(fontSize: 12, color: Colors.white60)),
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
                    Text('RM ${petrolCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFF6E40))),
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
  void _confirmCompleteAppointment(BuildContext context, ServiceAppointment apt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131922) : Colors.white,
        title: const Text('Mark as Done?'),
        content: Text('Mark your ${apt.serviceType} at ${apt.centreName} as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ServiceAppointmentManager.instance.completeAppointment(apt.id);
              if (mounted) {
                setState(() => _lastServiceDate = apt.appointmentDate);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.tokens.accent, foregroundColor: const Color(0xFF0A0B0E)),
            child: const Text('Mark Done'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelAppointment(BuildContext context, ServiceAppointment apt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131922) : Colors.white,
        title: const Text('Cancel Appointment?'),
        content: Text('Are you sure you want to cancel your service booking at ${apt.centreName} on ${apt.formattedDate}?'),
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
  DateTime? _lastServiceDate;

  @override
  void initState() {
    super.initState();
    _loadLastServiceDate();
  }

  Future<void> _loadLastServiceDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('tm_last_service_date');
    if (str != null && str.isNotEmpty) {
      final parsed = DateTime.tryParse(str);
      if (parsed != null && mounted) {
        setState(() => _lastServiceDate = parsed);
        return;
      }
    }
    for (final apt in ServiceAppointmentManager.instance.appointments) {
      if (apt.isCompleted) {
        if (mounted) {
          setState(() => _lastServiceDate = apt.appointmentDate);
          return;
        }
      }
    }
  }

  Future<void> _pickLastServiceDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastServiceDate ?? now.subtract(const Duration(days: 32)),
      firstDate: DateTime(2023),
      lastDate: now,
      helpText: 'Select Last Service Date',
    );
    if (picked != null && mounted) {
      setState(() => _lastServiceDate = picked);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tm_last_service_date', picked.toIso8601String());
    }
  }

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
        {"name": "DMS Telematics Pairing", "price": 0.00},
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
    final cardCol = isDark ? const Color(0xFF12141A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    const cyberLime = Color(0xFFD2F835);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderCol, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () => setState(() => _activeSubTab = 0),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeSubTab == 0 ? cyberLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'SCHEDULE & PRICING',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _activeSubTab == 0 ? Colors.black : textMuted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () => setState(() => _activeSubTab = 1),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeSubTab == 1 ? cyberLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 13,
                      color: _activeSubTab == 1 ? Colors.black : cyberLime,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SERVICE CENTRES (${CheryServiceDirectory.centres.length})',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: _activeSubTab == 1 ? Colors.black : textMuted,
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
    final bgCol = isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF6F8FA);

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: _buildSubTabSwitcher(isDark),
            ),
            Expanded(
              child: _activeSubTab == 1
                  ? const CheryServiceCentresScreen(isEmbedded: true)
                  : _buildScheduleAndPricingView(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats a km value with thousands separators, e.g. 10000 -> "10,000".
  String _formatKmThousands(int km) {
    final s = km.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildScheduleAndPricingView(BuildContext context, bool isDark) {
    final bgCol = isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF6F8FA);
    final cardCol = isDark ? const Color(0xFF12141A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);
    final limeAccent = context.tokens.accent;

    final currentKm = AppVehicleRepository.instance.isVehicleBound && AppVehicleRepository.instance.currentTelemetry.odometerKm > 0
        ? AppVehicleRepository.instance.currentTelemetry.odometerKm
        : 842;

    // Find the next upcoming milestone from the real schedule instead of
    // always counting down to the first (1,000 km) one. _milestones is
    // already ascending by km.
    ServiceMilestone? nextMilestone;
    int previousMilestoneKm = 0;
    for (final m in _milestones) {
      if (m.km > currentKm) {
        nextMilestone = m;
        break;
      }
      previousMilestoneKm = m.km;
    }
    final hasNextMilestone = nextMilestone != null;
    final kmLeft = hasNextMilestone ? (nextMilestone.km - currentKm).clamp(0, nextMilestone.km) : 0;
    final milestoneSpanKm = hasNextMilestone ? (nextMilestone.km - previousMilestoneKm) : 1;
    final milestoneProgress =
        hasNextMilestone ? ((currentKm - previousMilestoneKm) / milestoneSpanKm).clamp(0.02, 1.0) : 1.0;

    final daysLeft = _lastServiceDate != null
        ? (180 - DateTime.now().difference(_lastServiceDate!).inDays).clamp(1, 365)
        : (kmLeft / 52.7).round().clamp(1, 365);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      children: [
        // 1. TOP HEADER: SERVICE · ODOMETER
        Text(
          'SERVICE · ODOMETER',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 4),

        // Big Odometer + Distance to service
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                children: [
                  TextSpan(text: '$currentKm'),
                  TextSpan(
                    text: ' km',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasNextMilestone ? '$kmLeft km to ${nextMilestone.title}' : 'All scheduled services up to date',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: limeAccent,
                  ),
                ),
                if (hasNextMilestone) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () => _pickLastServiceDate(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Text(
                      '~$daysLeft days (based on last service date)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. MILESTONE SLIDER (previous milestone ── midpoint ── next milestone)
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Container(color: isDark ? const Color(0xFF161922) : const Color(0xFFE2E8F0)),
                FractionallySizedBox(
                  widthFactor: milestoneProgress,
                  child: Container(color: limeAccent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatKmThousands(previousMilestoneKm), style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: textMuted)),
            Text(
              _formatKmThousands(hasNextMilestone ? (previousMilestoneKm + nextMilestone.km) ~/ 2 : previousMilestoneKm),
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: textMuted),
            ),
            Text(
              _formatKmThousands(hasNextMilestone ? nextMilestone.km : previousMilestoneKm),
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: textMuted),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Service Appointment Banner (if already booked)
        ListenableBuilder(
          listenable: ServiceAppointmentManager.instance,
          builder: (context, _) {
            final upcoming = ServiceAppointmentManager.instance.upcomingAppointment;
            if (upcoming == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: limeAccent.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available_rounded, size: 16, color: limeAccent),
                          const SizedBox(width: 8),
                          Text(
                            'CONFIRMED APPOINTMENT',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: limeAccent,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: limeAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          upcoming.daysUntil == 0
                              ? 'TODAY'
                              : (upcoming.daysUntil == 1 ? 'TOMORROW' : 'In ${upcoming.daysUntil} days'),
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0A0B0E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    upcoming.serviceType,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${upcoming.formattedDate} • ${upcoming.timeSlot} • ${upcoming.centreName}',
                    style: TextStyle(fontSize: 11.5, color: textMuted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _confirmCancelAppointment(context, upcoming),
                        child: const Text('Cancel Booking', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                      ),
                      TextButton(
                        onPressed: () => _confirmCompleteAppointment(context, upcoming),
                        child: Text('Mark Done', style: TextStyle(color: limeAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        // 3. NEXT MILESTONE CARD — driven by the real odometer, not pinned to milestone 1
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasNextMilestone ? 'NEXT · MONTH ${nextMilestone.month}' : 'SCHEDULE COMPLETE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      hasNextMilestone
                          ? nextMilestone.title
                          : 'All scheduled services up to ${_formatKmThousands(previousMilestoneKm)} km done',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  if (hasNextMilestone)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        nextMilestone.isLabourFoc ? 'FOC' : 'RM ${nextMilestone.compulsoryFee.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Checklist items, straight from this milestone's own part list.
              if (hasNextMilestone)
                for (int i = 0; i < nextMilestone.compulsoryParts.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _buildServiceCheckRow(
                    nextMilestone.compulsoryParts[i]['name'] as String,
                    ((nextMilestone.compulsoryParts[i]['price'] as num) == 0
                        ? 'FOC'
                        : 'RM ${(nextMilestone.compulsoryParts[i]['price'] as num).toStringAsFixed(2)}'),
                    textPrimary,
                    textMuted,
                  ),
                ],
              const SizedBox(height: 18),

              // Action Buttons Row: [ Find 3S/4S ] & [ Book slot ]
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _activeSubTab = 1);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderCol),
                        backgroundColor: bgCol,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Find 3S/4S',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (hasNextMilestone) const SizedBox(width: 10),
                  if (hasNextMilestone)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => BookServiceAppointmentSheet.show(
                        context,
                        initialServiceType: nextMilestone!.title,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: limeAccent,
                        foregroundColor: const Color(0xFF0A0B0E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Book slot',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A0B0E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 4. SCHEDULE · TO 150,000 KM (16 STOPS)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SCHEDULE · TO 150,000 KM',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: textMuted,
              ),
            ),
            Text(
              '16 STOPS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 10k item
        _buildScheduleMilestoneRow(
          km: '10k',
          month: 'Month 6',
          desc: 'oil · filters · inspection',
          price: 'RM 407.50',
          badge: null,
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardCol: cardCol,
          borderCol: borderCol,
        ),
        const SizedBox(height: 8),

        // 20k item
        _buildScheduleMilestoneRow(
          km: '20k',
          month: 'Month 12',
          desc: 'parts only',
          price: 'RM 444.60',
          badge: 'FOC LABOUR',
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardCol: cardCol,
          borderCol: borderCol,
        ),
        const SizedBox(height: 8),

        // 30k item
        _buildScheduleMilestoneRow(
          km: '30k',
          month: 'Month 18',
          desc: 'spark plugs · fluids · inspection',
          price: 'RM 715.90',
          badge: null,
          textPrimary: textPrimary,
          textMuted: textMuted,
          cardCol: cardCol,
          borderCol: borderCol,
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _showFullTable = !_showFullTable),
            icon: Icon(_showFullTable ? Icons.expand_less : Icons.table_chart_outlined, size: 16, color: limeAccent),
            label: Text(
              _showFullTable ? 'Hide 150,000 km Schedule Table' : 'View full 150,000 km schedule table (16 stops) →',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: limeAccent,
              ),
            ),
          ),
        ),
        if (_showFullTable) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardCol,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'MILESTONE',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: textMuted),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'LABOUR',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: textMuted),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'PARTS',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: limeAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: borderCol),
                ..._milestones.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderCol.withValues(alpha: 0.5), width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            '${m.km ~/ 1000}k km (M${m.month})',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            m.isLabourFoc ? 'FOC' : 'RM ${m.labourFee.toInt()}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              color: m.isLabourFoc ? limeAccent : textMuted,
                              fontWeight: m.isLabourFoc ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            m.compulsoryFee == 0 ? 'FOC' : 'RM ${m.compulsoryFee.toStringAsFixed(2)}',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700, color: limeAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildServiceCheckRow(String label, String amount, Color textPrimary, Color textMuted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: textPrimary)),
        Text(amount, style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: textMuted)),
      ],
    );
  }

  Widget _buildScheduleMilestoneRow({
    required String km,
    required String month,
    required String desc,
    required String price,
    String? badge,
    required Color textPrimary,
    required Color textMuted,
    required Color cardCol,
    required Color borderCol,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  km,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(month, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: borderCol,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(fontSize: 10.5, color: textMuted)),
                ],
              ),
            ],
          ),
          Text(
            price,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOldMaintenanceTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                          color: const Color(0xFFFF6E40).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFF6E40)),
                        ),
                        child: const Text('MAJOR SERVICE', style: TextStyle(fontFamily: 'monospace', color: Color(0xFFFF6E40), fontSize: 9.5, fontWeight: FontWeight.bold)),
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
                _buildSpecRow('Battery Capacity', '18.3 kWh LFP Traction Battery', isDark),
                _buildSpecRow('Electric Range', '80–100 km (NEDC rated 100 km)', isDark),
                _buildSpecRow('Fuel Tank', '60 Litres (RON95 compatible)', isDark),
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

