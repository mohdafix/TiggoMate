import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';
import '../carlinko/vehicle_skin.dart';
import '../theme/accent.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'auth_sheet.dart';

/// Interactive Setup & Onboarding Intro Screen for TiggoMate (DashMate Style)
class SetupIntroScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  final bool isRevisit;

  const SetupIntroScreen({
    super.key,
    required this.onCompleted,
    this.isRevisit = false,
  });

  @override
  State<SetupIntroScreen> createState() => _SetupIntroScreenState();
}

class _SetupIntroScreenState extends State<SetupIntroScreen> {
  late TextEditingController _nameController;
  late TextEditingController _plateController;
  String _selectedModel = 'Chery Tiggo 7 PHEV CSH';
  String _skinKey = 'khaki_white';

  final List<String> _models = [
    'Chery Tiggo 7 PHEV CSH',
    'Chery Tiggo 8 Pro',
    'Chery Tiggo 7 Pro',
    'Chery Omoda 5',
  ];

  AppTokens get t => context.tokens;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Mohd Afix');
    _plateController = TextEditingController(text: 'VRT 3342');
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('tm_owner_name');
      final savedPlate = prefs.getString('tm_car_plate');
      final savedModel = prefs.getString('tm_vehicle_nickname');
      final savedSkin = prefs.getString('tm_vehicle_color_skin');
      if (!mounted) return;
      setState(() {
        if (savedName != null && savedName.isNotEmpty) _nameController.text = savedName;
        if (savedPlate != null && savedPlate.isNotEmpty) _plateController.text = savedPlate;
        if (savedModel != null && savedModel.isNotEmpty) _selectedModel = savedModel;
        if (savedSkin != null && savedSkin.isNotEmpty) _skinKey = savedSkin;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    final name = _nameController.text.trim().isEmpty ? 'Mohd Afix' : _nameController.text.trim();
    final plate = _plateController.text.trim().isEmpty ? 'VRT 3342' : _plateController.text.trim().toUpperCase();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tm_has_completed_setup', true);
      await prefs.setString('tm_owner_name', name);
      await prefs.setString('tm_car_plate', plate);
      await prefs.setString('tm_vehicle_nickname', _selectedModel);
      await prefs.setString('tm_vehicle_color_skin', _skinKey);

      // Initialize guest session in AuthService with configured driver details
      final auth = AuthService();
      if (!auth.currentUser.isAuthenticated) {
        await auth.continueAsGuest(name: name, plate: plate);
      }
    } catch (_) {}

    if (mounted) {
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = getVehicleSkinByKey(_skinKey);
    final themeCtrl = AppThemeController.instance;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Brand Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'T I G G O M A T E',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: t.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SETUP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: t.ink3,
                        ),
                      ),
                    ],
                  ),
                  if (widget.isRevisit)
                    IconButton(
                      icon: Icon(Icons.close, color: t.ink2),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    TextButton(
                      onPressed: _finishSetup,
                      child: Text('Skip', style: TextStyle(color: t.ink3, fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Headline
              Text(
                'Personalize Your Cockpit',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Set up your driver profile and vehicle look before entering the road.',
                style: TextStyle(fontSize: 13, color: t.ink2, height: 1.3),
              ),
              const SizedBox(height: 20),

              // Hero Vehicle Preview Card (changes in real-time with color choice)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: t.border),
                  boxShadow: t.cardShadow,
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft radial background glow
                        Container(
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                t.accent.withValues(alpha: 0.18),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Real Car Hero Image Render
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Image.asset(
                            skin.assetPath,
                            key: ValueKey(skin.assetPath),
                            height: 160,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/car_hero.png',
                              height: 160,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      skin.name + (skin.isDualTone ? ' · Dual-Tone Edition' : ''),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skin.tag,
                      style: TextStyle(fontSize: 12, color: t.ink2),
                    ),
                    const SizedBox(height: 14),

                    // Color Selector Swatches
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: kOfficialVehicleSkins.map((s) {
                        final isSel = s.key == _skinKey;
                        return GestureDetector(
                          onTap: () => setState(() => _skinKey = s.key),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? t.accent : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.primaryColor,
                                border: Border.all(color: t.border),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: t.accent.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSel
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: s.primaryColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Driver & Vehicle Details Group Card
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  children: [
                    // Driver Profile Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: t.ink2, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DRIVER NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: t.ink3)),
                                TextField(
                                  controller: _nameController,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                    border: InputBorder.none,
                                    hintText: 'e.g. Mohd Afix',
                                    hintStyle: TextStyle(color: t.ink3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, indent: 52, color: t.border),

                    // Car Plate Registration
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.badge_outlined, color: t.ink2, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CAR PLATE REGISTRATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: t.ink3)),
                                TextField(
                                  controller: _plateController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                    border: InputBorder.none,
                                    hintText: 'e.g. VRT 3342',
                                    hintStyle: TextStyle(color: t.ink3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, indent: 52, color: t.border),

                    // Vehicle Model Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car_outlined, color: t.ink2, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('VEHICLE MODEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: t.ink3)),
                                const SizedBox(height: 4),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _models.contains(_selectedModel) ? _selectedModel : _models.first,
                                    isDense: true,
                                    icon: Icon(Icons.keyboard_arrow_down, color: t.ink3),
                                    dropdownColor: t.surface,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink),
                                    items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedModel = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cockpit Accent Colour Palette
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cockpit Accent Colour',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.ink),
                        ),
                        ValueListenableBuilder<Accent>(
                          valueListenable: Accent.current,
                          builder: (context, a, child) => Text(
                            a.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Highlights active controls, energy gauges, and telemetry dials.',
                      style: TextStyle(fontSize: 12, color: t.ink2),
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<Accent>(
                      valueListenable: Accent.current,
                      builder: (context, cur, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: Accent.all.map((a) {
                          final isSel = cur.id == a.id;
                          return GestureDetector(
                            onTap: () => Accent.set(a),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.isDark ? a.night : a.day,
                                border: Border.all(
                                  color: isSel ? t.ink : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: (t.isDark ? a.night : a.day).withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSel
                                  ? Icon(
                                      Icons.check,
                                      size: 18,
                                      color: t.isDark ? a.onNight : a.onDay,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Theme Switcher (Tesla Light vs Obsidian Dark)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          themeCtrl.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                          color: t.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              themeCtrl.isDarkMode ? 'Obsidian Dark Theme' : 'Tesla Light Theme',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.ink),
                            ),
                            Text(
                              themeCtrl.isDarkMode ? 'Neon cyberpunk cockpit' : 'Crisp daylight contrast',
                              style: TextStyle(fontSize: 11.5, color: t.ink2),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: themeCtrl.isDarkMode,
                      activeTrackColor: t.accent.withValues(alpha: 0.5),
                      activeThumbColor: t.accent,
                      onChanged: (val) {
                        themeCtrl.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Primary "Start TiggoMate Cockpit" Button
              FilledButton(
                onPressed: _finishSetup,
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: t.accent.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isRevisit ? 'Save Setup Changes' : 'Start TiggoMate Cockpit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: t.onAccent,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: t.onAccent, size: 20),
                  ],
                ),
              ),

              if (!widget.isRevisit) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    AuthSheet.show(
                      context,
                      onProfileUpdated: () {
                        final u = AuthService().currentUser;
                        if (u.isAuthenticated) {
                          _nameController.text = u.displayName;
                          _plateController.text = u.carPlate;
                          _finishSetup();
                        }
                      },
                    );
                  },
                  child: Text(
                    'Have an existing account? Sign In with Cloud',
                    style: TextStyle(fontSize: 12.5, color: t.ink2),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
