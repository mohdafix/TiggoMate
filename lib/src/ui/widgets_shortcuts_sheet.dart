import 'package:flutter/material.dart';
import '../widgets/home_widget_service.dart';

/// Modal sheet showcasing Android Home Screen Widget preview and
/// App Launcher Quick Action Shortcuts.
class WidgetsShortcutsSheet extends StatefulWidget {
  final int batterySoc;
  final int batteryRange;
  final int fuelLevel;
  final int fuelRange;
  final int totalRange;
  final bool isLocked;
  final bool isCharging;
  final bool isClimateOn;
  final void Function(String actionUri)? onActionTriggered;

  const WidgetsShortcutsSheet({
    super.key,
    this.batterySoc = 78,
    this.batteryRange = 95,
    this.fuelLevel = 82,
    this.fuelRange = 870,
    this.totalRange = 965,
    this.isLocked = true,
    this.isCharging = false,
    this.isClimateOn = false,
    this.onActionTriggered,
  });

  static Future<void> show(
    BuildContext context, {
    int batterySoc = 78,
    int batteryRange = 95,
    int fuelLevel = 82,
    int fuelRange = 870,
    int totalRange = 965,
    bool isLocked = true,
    bool isCharging = false,
    bool isClimateOn = false,
    void Function(String actionUri)? onActionTriggered,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WidgetsShortcutsSheet(
        batterySoc: batterySoc,
        batteryRange: batteryRange,
        fuelLevel: fuelLevel,
        fuelRange: fuelRange,
        totalRange: totalRange,
        isLocked: isLocked,
        isCharging: isCharging,
        isClimateOn: isClimateOn,
        onActionTriggered: onActionTriggered,
      ),
    );
  }

  @override
  State<WidgetsShortcutsSheet> createState() => _WidgetsShortcutsSheetState();
}

class _WidgetsShortcutsSheetState extends State<WidgetsShortcutsSheet> {
  bool _isSyncing = false;
  String? _syncMessage;

  Future<void> _syncToNative() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });

    final ok = await HomeWidgetService.instance.syncWidgetTelemetry(
      batterySoc: widget.batterySoc,
      batteryRange: widget.batteryRange,
      fuelLevel: widget.fuelLevel,
      fuelRange: widget.fuelRange,
      totalRange: widget.totalRange,
      isLocked: widget.isLocked,
      isCharging: widget.isCharging,
      isClimateOn: widget.isClimateOn,
    );

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncMessage = ok
            ? 'Widget synchronized successfully!'
            : 'Synchronized with Android SharedPreferences';
      });
    }
  }

  void _triggerAction(String uri) {
    widget.onActionTriggered?.call(uri);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2AA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.widgets_outlined, color: Color(0xFF00D2AA), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Widgets & Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Android Home Screen & Launcher Integration',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SECTION 1: HOME SCREEN WIDGET PREVIEW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HOME SCREEN WIDGET PREVIEW (4×2)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                  InkWell(
                    onTap: _isSyncing ? null : _syncToNative,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sync,
                            size: 14,
                            color: const Color(0xFF00D2AA),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isSyncing ? 'Syncing...' : 'Sync Now',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00D2AA),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Live Widget Rendering Box (Mirrors tiggomate_widget.xml)
              _buildWidgetVisualPreview(context, isDark),

              if (_syncMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _syncMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // SECTION 2: LAUNCHER APP SHORTCUTS
              Text(
                'APP LAUNCHER SHORTCUTS (LONG-PRESS ICON)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 12),

              _buildShortcutTile(
                context: context,
                icon: Icons.lock_outline,
                iconColor: const Color(0xFF00D2AA),
                title: widget.isLocked ? 'Unlock Vehicle' : 'Lock Vehicle',
                subtitle: '🔒 Lock / Unlock Chery Tiggo 7 PHEV doors',
                actionUri: 'tiggomate://action/lock',
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              _buildShortcutTile(
                context: context,
                icon: Icons.ac_unit,
                iconColor: const Color(0xFF38BDF8),
                title: widget.isClimateOn ? 'Turn Off Climate' : 'Pre-cool Cabin (22.0°C)',
                subtitle: '❄️ Rapid cooling before boarding in hot Malaysian sun',
                actionUri: 'tiggomate://action/climate',
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              _buildShortcutTile(
                context: context,
                icon: Icons.bolt,
                iconColor: const Color(0xFFF59E0B),
                title: 'Smart Charging Optimizer',
                subtitle: '⚡ Schedule off-peak charging & TNB tariff calculations',
                actionUri: 'tiggomate://action/charging',
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              _buildShortcutTile(
                context: context,
                icon: Icons.radar,
                iconColor: const Color(0xFF00D2AA),
                title: 'Find My Car (Radar HUD)',
                subtitle: '📍 360° Circular Radar locator & parking distance',
                actionUri: 'tiggomate://action/radar',
                isDark: isDark,
              ),
              const SizedBox(height: 8),

              _buildShortcutTile(
                context: context,
                icon: Icons.speed,
                iconColor: const Color(0xFF10B981),
                title: 'Drive Mode HUD',
                subtitle: '🚗 Real-time EV vs 1.5T HEV trip recorder & speedometer',
                actionUri: 'tiggomate://action/drive',
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Instructions callout
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'To add to your phone screen: Return to your Android home screen, touch & hold an empty space, tap "Widgets", and select "TiggoMate". Long-press the TiggoMate app icon anytime to access quick shortcuts.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidgetVisualPreview(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D2AA).withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Widget Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.directions_car, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Tiggo 7 PHEV',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.isCharging
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF00D2AA),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isCharging
                          ? '⚡ Charging'
                          : (widget.isLocked ? '🔒 Locked' : '🔓 Unlocked'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: widget.isCharging
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF00D2AA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Middle Dual Powertrain Row
          Row(
            children: [
              // Battery
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${widget.batterySoc}%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00D2AA),
                      ),
                    ),
                    Text(
                      '${widget.batteryRange} km EV',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // Total Combined Range Badge
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${widget.totalRange} km',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        'Combined Range',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fuel
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${widget.fuelLevel}%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF9F1C),
                      ),
                    ),
                    Text(
                      '${widget.fuelRange} km Fuel',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Widget Action Buttons
          Row(
            children: [
              _buildWidgetActionBtn(
                label: widget.isLocked ? '🔓 Unlock' : '🔒 Lock',
                color: Colors.white,
                onTap: () => _triggerAction('tiggomate://action/lock'),
              ),
              const SizedBox(width: 6),
              _buildWidgetActionBtn(
                label: widget.isClimateOn ? '❄️ Off' : '❄️ 22°C',
                color: const Color(0xFF38BDF8),
                onTap: () => _triggerAction('tiggomate://action/climate'),
              ),
              const SizedBox(width: 6),
              _buildWidgetActionBtn(
                label: '⚡ Charge',
                color: const Color(0xFFF59E0B),
                onTap: () => _triggerAction('tiggomate://action/charging'),
              ),
              const SizedBox(width: 6),
              _buildWidgetActionBtn(
                label: '🚗 HUD',
                color: const Color(0xFF10B981),
                onTap: () => _triggerAction('tiggomate://action/drive'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetActionBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String actionUri,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: textMuted),
        ),
        trailing: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: iconColor.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            minimumSize: const Size(60, 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _triggerAction(actionUri),
          child: Text(
            'Test',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iconColor),
          ),
        ),
      ),
    );
  }
}
