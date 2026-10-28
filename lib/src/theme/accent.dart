import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_tokens.dart';

/// The user-customizable accent colour (DashMate design system).
class Accent {
  final String id;
  final String name;
  final Color day, onDay, night, onNight;
  const Accent(this.id, this.name, this.day, this.onDay, this.night, this.onNight);

  static const all = <Accent>[
    Accent('teal', 'Teal', Color(0xFF0F766E), Colors.white, Color(0xFF2DD4BF), Color(0xFF042F2E)),
    Accent('blue', 'Blue', Color(0xFF1D4ED8), Colors.white, Color(0xFF60A5FA), Color(0xFF0B1B3F)),
    Accent('indigo', 'Indigo', Color(0xFF4338CA), Colors.white, Color(0xFF818CF8), Color(0xFF1E1B4B)),
    Accent('purple', 'Purple', Color(0xFF7E22CE), Colors.white, Color(0xFFC084FC), Color(0xFF2E1065)),
    Accent('pink', 'Pink', Color(0xFFBE185D), Colors.white, Color(0xFFF472B6), Color(0xFF500724)),
    Accent('red', 'Red', Color(0xFFB91C1C), Colors.white, Color(0xFFF87171), Color(0xFF450A0A)),
    Accent('orange', 'Orange', Color(0xFFC2410C), Colors.white, Color(0xFFFB923C), Color(0xFF431407)),
    Accent('amber', 'Amber', Color(0xFFA16207), Colors.white, Color(0xFFFBBF24), Color(0xFF422006)),
  ];

  static Accent byId(String? id) => all.firstWhere((a) => a.id == id, orElse: () => all.first);

  static const String _kAccentPrefKey = 'tm_accent_color_id';

  /// The current choice; listeners rebuild when it changes.
  static final current = ValueNotifier<Accent>(all.first);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kAccentPrefKey);
      if (id != null) {
        current.value = byId(id);
      }
    } catch (_) {}
  }

  static Future<void> set(Accent a) async {
    current.value = a;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccentPrefKey, a.id);
    } catch (_) {}
  }

  /// Accent colour: a bottom sheet row of swatches.
  static void showPicker(BuildContext context) {
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ValueListenableBuilder<Accent>(
            valueListenable: Accent.current,
            builder: (ctx, cur, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Accent Colour', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink)),
                const SizedBox(height: 4),
                Text('Used for active highlights and dashboard accents.',
                    style: TextStyle(fontSize: 13, color: t.ink2)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final a in Accent.all)
                      GestureDetector(
                        onTap: () {
                          Accent.set(a);
                          Navigator.pop(ctx);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.isDark ? a.night : a.day,
                                border: Border.all(
                                  color: cur.id == a.id ? t.ink : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: cur.id == a.id
                                  ? Icon(Icons.check, color: t.isDark ? a.onNight : a.onDay)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(a.name, style: TextStyle(fontSize: 12, color: t.ink2)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
