import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';
import '../carlinko/vehicle_skin.dart';
import '../theme/accent.dart';
import '../theme/app_tokens.dart';

/// Screen 1: Register Your Car (Cyber Minimalist Automotive Onboarding)
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
  String _selectedModel = 'Tiggo 7 PHEV CSH';
  String _skinKey = 'khaki_white';

  final List<String> _models = [
    'Tiggo 7 PHEV CSH',
    'Tiggo 8 Pro e+',
    'Tiggo 7 Pro',
    'Omoda E5',
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
        if (savedModel != null && savedModel.isNotEmpty) {
          if (_models.contains(savedModel)) {
            _selectedModel = savedModel;
          } else if (savedModel.contains('Tiggo 7')) {
            _selectedModel = 'Tiggo 7 PHEV CSH';
          }
        }
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
      await VehicleSkinManager.instance.setSkin(_skinKey);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgCol = isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF6F8FA);
    final cardCol = isDark ? const Color(0xFF12141A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);
    final limeAccent = context.tokens.accent;

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Step Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TIGGOMATE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: textMuted,
                    ),
                  ),
                  Text(
                    'STEP 1 / 2',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Step Progress Line
              Stack(
                children: [
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: limeAccent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Headline & Subtitle
              Text(
                'Register your car.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Three fields. You can bind CarLinko telemetry later.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              // Car Preview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol, width: 1),
                ),
                child: Column(
                  children: [
                    // Vehicle Image
                    SizedBox(
                      height: 145,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Image.asset(
                            skin.assetPath,
                            key: ValueKey(skin.assetPath),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/car_hero.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Paint Name & Swatches Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAINT',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.4,
                                color: textMuted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              skin.name,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: kOfficialVehicleSkins.map((s) {
                            final isSel = s.key == _skinKey;
                            return GestureDetector(
                              onTap: () => setState(() => _skinKey = s.key),
                              child: Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSel ? limeAccent : Colors.transparent,
                                    width: 1.8,
                                  ),
                                ),
                                child: Container(
                                  width: 28,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: s.primaryColor,
                                    border: Border.all(color: borderCol),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Framed Input Rows
              Container(
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol, width: 1),
                ),
                child: Column(
                  children: [
                    // 01 · DRIVER
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '01 · DRIVER',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _nameController,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'Driver Name',
                              hintStyle: TextStyle(color: textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: borderCol),

                    // 02 · PLATE
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '02 · PLATE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _plateController,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: 'e.g. VRT 3342',
                              hintStyle: TextStyle(color: textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: borderCol),

                    // 03 · MODEL
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '03 · MODEL',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _models.contains(_selectedModel) ? _selectedModel : _models.first,
                              isDense: true,
                              icon: Icon(Icons.keyboard_arrow_down, color: textMuted, size: 20),
                              dropdownColor: cardCol,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
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

              const SizedBox(height: 18),

              // SIGNAL COLOUR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SIGNAL COLOUR',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: textMuted,
                    ),
                  ),
                  ValueListenableBuilder<Accent>(
                    valueListenable: Accent.current,
                    builder: (context, cur, _) => Row(
                      children: Accent.all.map((a) {
                        final isSel = cur.id == a.id;
                        final circleCol = isDark ? a.night : a.day;
                        return GestureDetector(
                          onTap: () {
                            Accent.set(a);
                            setState(() {});
                          },
                          child: Container(
                            margin: const EdgeInsets.only(left: 10),
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? limeAccent : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: circleCol,
                                border: Border.all(color: borderCol, width: 0.8),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // Continue → Button (Cyber Lime solid fill)
              ElevatedButton(
                onPressed: _finishSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: limeAccent,
                  foregroundColor: const Color(0xFF0A0B0E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    SizedBox(width: 24),
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Color(0xFF0A0B0E),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Text('→', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A0B0E))),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: _finishSetup,
                  child: Text(
                    "I'll do this later",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
