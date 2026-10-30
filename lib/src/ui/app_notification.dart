import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../firebase/firebase_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Notification alert types matching automotive telematics events.
enum NotificationType {
  info,
  success,
  warning,
  error,
}

/// A recorded vehicle alert or telematics notification event.
class VehicleAlertItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final IconData icon;
  bool isRead;

  VehicleAlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.type = NotificationType.info,
    required this.icon,
    this.isRead = false,
  });

  static String _iconToKey(IconData icon) {
    if (icon == Icons.lock_rounded) return 'lock';
    if (icon == Icons.lock_open_rounded) return 'lock_open';
    if (icon == Icons.bolt_rounded) return 'bolt';
    if (icon == Icons.ac_unit_rounded) return 'ac_unit';
    if (icon == Icons.speed_rounded) return 'speed';
    if (icon == Icons.radar_rounded) return 'radar';
    if (icon == Icons.sensor_window_outlined) return 'window';
    if (icon == Icons.directions_car_filled_rounded) return 'car_filled';
    if (icon == Icons.check_circle_rounded) return 'check';
    if (icon == Icons.warning_amber_rounded) return 'warning';
    if (icon == Icons.error_outline_rounded) return 'error';
    if (icon == Icons.copy_rounded) return 'copy';
    if (icon == Icons.palette_outlined) return 'palette';
    return 'car';
  }

  static IconData _keyToIcon(String? key) {
    switch (key) {
      case 'lock':
        return Icons.lock_rounded;
      case 'lock_open':
        return Icons.lock_open_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'ac_unit':
        return Icons.ac_unit_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'radar':
        return Icons.radar_rounded;
      case 'window':
        return Icons.sensor_window_outlined;
      case 'car_filled':
        return Icons.directions_car_filled_rounded;
      case 'check':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      case 'copy':
        return Icons.copy_rounded;
      case 'palette':
        return Icons.palette_outlined;
      default:
        return Icons.directions_car_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'iconKey': _iconToKey(icon),
        'isRead': isRead,
      };

  factory VehicleAlertItem.fromJson(Map<String, dynamic> json) {
    return VehicleAlertItem(
      id: json['id'] as String? ?? UniqueKey().toString(),
      title: json['title'] as String? ?? 'Vehicle Alert',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.info,
      ),
      icon: _keyToIcon(json['iconKey'] as String?),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

/// Central Vehicle Alerts & Telematics History Manager.
class VehicleAlertsManager extends ChangeNotifier {
  static final VehicleAlertsManager instance = VehicleAlertsManager._internal();
  VehicleAlertsManager._internal();

  static const String _kStorageKey = 'tm_vehicle_alerts_history_v1';
  final List<VehicleAlertItem> _alerts = [];
  bool _initialized = false;

  List<VehicleAlertItem> get alerts => List.unmodifiable(_alerts);

  int get unreadCount => _alerts.where((a) => !a.isRead).length;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        _alerts.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _alerts.add(VehicleAlertItem.fromJson(item));
          }
        }
      } else {
        // Pre-seed realistic Tiggo 7 PHEV initial events
        _seedInitialAlerts();
        await _persist();
      }
      notifyListeners();
    } catch (_) {
      if (_alerts.isEmpty) {
        _seedInitialAlerts();
      }
    }
  }

  void _seedInitialAlerts() {
    final now = DateTime.now();
    _alerts.addAll([
      VehicleAlertItem(
        id: 'seed-1',
        title: 'Smart Charging Active',
        message: 'AC home charging active at 3.3 kW. Battery reached 78% SoC (95 km EV range).',
        timestamp: now.subtract(const Duration(minutes: 18)),
        type: NotificationType.success,
        icon: Icons.bolt_rounded,
        isRead: false,
      ),
      VehicleAlertItem(
        id: 'seed-2',
        title: 'Doors Locked & Armed',
        message: 'CarLinko: Proximity auto-lock engaged. All 4 doors secured.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 42)),
        type: NotificationType.info,
        icon: Icons.lock_outline_rounded,
        isRead: true,
      ),
      VehicleAlertItem(
        id: 'seed-3',
        title: 'Cabin Pre-cooling Complete',
        message: 'Climate control reached target 22.0°C. High efficiency heat pump operating normally.',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 10)),
        type: NotificationType.info,
        icon: Icons.ac_unit_rounded,
        isRead: true,
      ),
      VehicleAlertItem(
        id: 'seed-4',
        title: 'TPMS Pressure Check',
        message: 'All 4 tyres optimal at nominal 230 kPa (Front 232 / Rear 228 kPa).',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        type: NotificationType.info,
        icon: Icons.speed_rounded,
        isRead: true,
      ),
    ]);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _alerts.take(50).map((a) => a.toJson()).toList();
      await prefs.setString(_kStorageKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> addAlert(VehicleAlertItem alert) async {
    _alerts.insert(0, alert);
    if (_alerts.length > 50) {
      _alerts.removeRange(50, _alerts.length);
    }
    notifyListeners();
    await _persist();
    unawaited(FirebaseSyncService.instance.syncAlert(alert));
  }

  Future<void> markAllAsRead() async {
    for (final a in _alerts) {
      a.isRead = true;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    _alerts.clear();
    notifyListeners();
    await _persist();
  }
}

/// Unified High-Contrast Automotive Notification Banner & SnackBar Controller.
///
/// Fixes contrast across Obsidian Dark (#090D12) and Tesla Light (#F7F8FA) themes,
/// providing 100% visible, crisp typography and HUD floating banner animations.
class AppNotification {
  static OverlayEntry? _currentEntry;

  static void dismiss() {
    _dismissBanner();
  }

  /// Display a sleek top floating HUD alert banner.
  /// Falls back smoothly to high-contrast SnackBar if overlay is not available.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    NotificationType type = NotificationType.info,
    IconData? icon,
    VoidCallback? onTap,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    // Record into vehicle alert history
    final resolvedIcon = icon ?? _defaultIconFor(type, message);
    final resolvedTitle = title ?? _defaultTitleFor(type, message);

    VehicleAlertsManager.instance.addAlert(
      VehicleAlertItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: resolvedTitle,
        message: message,
        timestamp: DateTime.now(),
        type: type,
        icon: resolvedIcon,
        isRead: false,
      ),
    );

    HapticFeedback.lightImpact();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      // Fallback for tests or contexts lacking Overlay
      _showHighContrastSnackBar(context, message, type: type, icon: resolvedIcon);
      return;
    }

    _dismissBanner();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _HudAlertBannerWidget(
        title: resolvedTitle,
        message: message,
        type: type,
        icon: resolvedIcon,
        isDark: isDark,
        duration: duration,
        onTap: () {
          _dismissBanner();
          onTap?.call();
        },
        onDismiss: _dismissBanner,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _dismissBanner() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  /// Create a high-contrast SnackBar with bulletproof contrast for both Dark and Light themes.
  static SnackBar createHighContrastSnackBar(
    BuildContext context,
    String message, {
    NotificationType type = NotificationType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedIcon = icon ?? _defaultIconFor(type, message);

    // Explicit colors guaranteeing high contrast
    final bg = isDark ? const Color(0xFF161E2E) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final border = isDark ? const Color(0xFF2D3A4F) : const Color(0xFFCBD5E1);
    final accent = _accentColorFor(type, isDark);

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      elevation: isDark ? 6 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border, width: 1.2),
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: duration,
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(resolvedIcon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: text,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showHighContrastSnackBar(
    BuildContext context,
    String message, {
    NotificationType type = NotificationType.info,
    IconData? icon,
  }) {
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          createHighContrastSnackBar(context, message, type: type, icon: icon),
        );
      }
    } catch (_) {}
  }

  static IconData _defaultIconFor(NotificationType type, String message) {
    final lower = message.toLowerCase();
    if (lower.contains('lock') || lower.contains('door')) {
      return lower.contains('unlock') ? Icons.lock_open_rounded : Icons.lock_rounded;
    }
    if (lower.contains('ac ') || lower.contains('climate') || lower.contains('cool') || lower.contains('warm')) {
      return Icons.ac_unit_rounded;
    }
    if (lower.contains('charg') || lower.contains('plug') || lower.contains('kwh') || lower.contains('battery')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('tpms') || lower.contains('tyre') || lower.contains('tire') || lower.contains('pressure')) {
      return Icons.speed_rounded;
    }
    if (lower.contains('radar') || lower.contains('locate') || lower.contains('horn') || lower.contains('flash')) {
      return Icons.radar_rounded;
    }
    if (lower.contains('window') || lower.contains('vent')) {
      return Icons.sensor_window_outlined;
    }
    if (lower.contains('tailgate') || lower.contains('trunk') || lower.contains('boot')) {
      return Icons.directions_car_filled_rounded;
    }

    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.error:
        return Icons.error_outline_rounded;
      case NotificationType.info:
        return Icons.directions_car_rounded;
    }
  }

  static String _defaultTitleFor(NotificationType type, String message) {
    final lower = message.toLowerCase();
    if (lower.contains('lock') || lower.contains('door')) return 'Security System';
    if (lower.contains('climate') || lower.contains('cool') || lower.contains('ac')) return 'Climate Pre-conditioning';
    if (lower.contains('charg') || lower.contains('tnb')) return 'Energy & Charging';
    if (lower.contains('tpms') || lower.contains('tyre')) return 'Tyre Pressure Alert';
    if (lower.contains('window')) return 'Window Control';
    if (lower.contains('tailgate') || lower.contains('trunk')) return 'Power Tailgate';
    if (lower.contains('radar') || lower.contains('locate')) return 'Vehicle Locator';

    switch (type) {
      case NotificationType.success:
        return 'Command Successful';
      case NotificationType.warning:
        return 'Vehicle Attention';
      case NotificationType.error:
        return 'System Notice';
      case NotificationType.info:
        return 'CarLinko Telematics';
    }
  }

  static Color _accentColorFor(NotificationType type, bool isDark) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFFD2F835);
      case NotificationType.warning:
        return const Color(0xFFFF6E40);
      case NotificationType.error:
        return const Color(0xFFFF453A);
      case NotificationType.info:
        return const Color(0xFFD2F835);
    }
  }
}

/// Floating HUD Pill Widget with smooth slide-down entrance and high contrast styling.
class _HudAlertBannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final NotificationType type;
  final IconData icon;
  final bool isDark;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _HudAlertBannerWidget({
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    required this.isDark,
    required this.duration,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_HudAlertBannerWidget> createState() => _HudAlertBannerWidgetState();
}

class _HudAlertBannerWidgetState extends State<_HudAlertBannerWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    if (widget.duration > Duration.zero) {
      _autoDismissTimer = Timer(widget.duration, () {
        if (mounted) {
          _handleDismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    _autoDismissTimer?.cancel();
    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 8;
    final isDark = widget.isDark;

    // Cyber Minimalist Alert Banner Styling
    final bg = isDark ? const Color(0xFF12141A) : Colors.white;
    final border = isDark ? const Color(0xFF1E222B) : const Color(0xFFCBD5E1);
    final textTitle = isDark ? Colors.white : const Color(0xFF0F172A);
    final textBody = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final textMeta = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final accent = AppNotification._accentColorFor(widget.type, isDark);

    return Positioned(
      top: topPadding,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _handleDismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Automotive Status Icon Badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        color: accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textTitle,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'CARLINKO',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2.5),
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textBody,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tiggo 7 PHEV • Just now',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.normal,
                              color: textMeta,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dismiss Button
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: textMeta),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _handleDismiss,
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vehicle Alerts & Notification History Modal Bottom Sheet.
class VehicleAlertsSheet extends StatefulWidget {
  const VehicleAlertsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1219) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const VehicleAlertsSheet(),
    );
  }

  @override
  State<VehicleAlertsSheet> createState() => _VehicleAlertsSheetState();
}

class _VehicleAlertsSheetState extends State<VehicleAlertsSheet> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        VehicleAlertsManager.instance.markAllAsRead();
      }
    });
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;
    final manager = VehicleAlertsManager.instance;

    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final allAlerts = manager.alerts;
        final filteredAlerts = allAlerts.where((a) {
          if (_selectedFilter == 'Security') {
            return a.title.contains('Lock') || a.message.contains('door');
          }
          if (_selectedFilter == 'Charging') {
            return a.title.contains('Charg') || a.message.contains('kW') || a.message.contains('SoC');
          }
          if (_selectedFilter == 'Climate') {
            return a.title.contains('Climate') || a.message.contains('cool') || a.message.contains('22');
          }
          return true;
        }).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, color: colors.evTeal, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Vehicle Alerts & History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (allAlerts.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            manager.clearAll();
                          },
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                          label: const Text('Clear', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white60 : Colors.grey.shade700,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Security', 'Charging', 'Climate'].map((filter) {
                        final isSel = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel
                                    ? (isDark ? Colors.black : Colors.white)
                                    : colors.textSecondary,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: isDark ? colors.evTeal : const Color(0xFF111827),
                            backgroundColor: colors.tileBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSel ? Colors.transparent : colors.border,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            onSelected: (val) {
                              if (val) setState(() => _selectedFilter = filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Alerts List
                  Expanded(
                    child: filteredAlerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_off_outlined, size: 40, color: colors.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'No alerts in history',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: filteredAlerts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final item = filteredAlerts[idx];
                              final accent = AppNotification._accentColorFor(item.type, isDark);

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(item.icon, size: 16, color: accent),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                _formatTimeAgo(item.timestamp),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: colors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.message,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.textSecondary,
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
