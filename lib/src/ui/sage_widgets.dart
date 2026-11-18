import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_tokens.dart';

/// Shared building blocks for the "Sage Cockpit" redesign: soft sage
/// background, deep forest-green primary, white rounded cards, square
/// quick-action tiles, and a floating pill bottom nav.
///
/// These are intentionally separate from the legacy Cyber dashboard
/// widgets so the old look stays available and this redesign can be
/// reviewed/reverted without touching existing screens.

/// A small rounded pill showing a label above a value, e.g. "Range" / "812 km".
class SageStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const SageStatChip({super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: t.accent.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: t.ink3),
                const SizedBox(width: 4),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: t.ink3),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: t.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A square quick-action tile. When [active] is true it fills with the
/// forest-green accent and flips text/icon to white, matching the
/// reference design's "Locked" state. [busy] shows a spinner in place
/// of the icon while a remote command is in flight.
class SageActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  const SageActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.busy = false,
    this.onTap,
  });

  @override
  State<SageActionTile> createState() => _SageActionTileState();
}

class _SageActionTileState extends State<SageActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = widget.active ? t.accent : t.surface2;
    final fg = widget.active ? t.onAccent : t.accent;
    final labelColor = widget.active ? t.onAccent : t.ink2;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.busy)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                )
              else
                Icon(widget.icon, size: 22, color: fg),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: labelColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain white rounded card used across the Sage Cockpit screens.
class SageCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const SageCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: t.accent.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Screen header used by non-home screens in the Kinetic Volt / Obsidian
/// Telemetry cockpit style: back chevron, centred title, optional trailing action.
class SageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  const SageHeader({super.key, required this.title, this.trailing, this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: t.ink, size: 26),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.01,
                color: t.ink,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: trailing ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of filter tabs, e.g. "All / Oil change / Tyres".
class SageFilterTabs extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const SageFilterTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, i) {
          final opt = options[i];
          final isSelected = opt == selected;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  opt,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? t.accent : t.ink2,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 2.5,
                  width: isSelected ? 22 : 0,
                  decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Floating pill bottom nav: the active item expands into a green capsule
/// with icon + label, inactive items are plain circular icon buttons.
class SageNavBar extends StatelessWidget {
  final int currentIndex;
  final List<SageNavItem> items;
  final ValueChanged<int> onTap;

  const SageNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppTokens.rFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < items.length; i++)
            _SageNavEntry(
              item: items[i],
              selected: i == currentIndex,
              onTap: () {
                if (i != currentIndex) HapticFeedback.selectionClick();
                onTap(i);
              },
            ),
        ],
      ),
    );
  }
}

class SageNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const SageNavItem({required this.icon, required this.selectedIcon, required this.label});
}

class _SageNavEntry extends StatelessWidget {
  final SageNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SageNavEntry({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 0),
          width: selected ? null : 48,
          decoration: BoxDecoration(
            color: selected ? t.accent : t.surface2,
            borderRadius: BorderRadius.circular(AppTokens.rFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: selected ? t.onAccent : t.accent,
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.onAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sage Cockpit equivalent of the legacy `ApplePressable`: a pressable
/// wrapper that physically compresses on touch-down and springs back on
/// release. Purely a press-animation mechanism (no Apple-specific
/// styling), renamed so Sage screens don't need to import
/// `apple_design_widgets.dart` at all.
class SagePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration duration;
  final Curve curve;
  final bool enableHaptics;

  const SagePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.95,
    this.duration = const Duration(milliseconds: 110),
    this.curve = Curves.easeOutCubic,
    this.enableHaptics = true,
  });

  @override
  State<SagePressable> createState() => _SagePressableState();
}

class _SagePressableState extends State<SagePressable> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      canRequestFocus: false,
      onHighlightChanged: (isHighlighted) {
        if (widget.onTap == null && widget.onLongPress == null) return;
        if (isHighlighted) {
          if (widget.enableHaptics) HapticFeedback.lightImpact();
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Sage Cockpit equivalent of the legacy `AppleSheetContainer`: a bottom
/// sheet shell with a pull handle, rounded top corners, and a scrollable
/// body capped at a max height. Uses a solid `t.surface` fill rather than
/// frosted glass, matching the rest of the Sage design language.
class SageSheetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  const SageSheetContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 28),
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: t.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: t.isDark ? 0.45 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: height ?? (MediaQuery.of(context).size.height * 0.82),
              ),
              child: SingleChildScrollView(child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sage Cockpit equivalent of the legacy `AppleControlTile`: a rounded
/// control tile that fills solid with the forest-green accent when
/// selected, matching [SageActionTile]'s selected-state treatment.
class SageControlTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onTap;

  /// Fill colour when selected. Defaults to the Sage accent, matching
  /// [SageActionTile]; pass [AppTokens.danger]/[AppTokens.warn] for
  /// destructive or system-state tiles (e.g. "Open windows" vs. sunroof).
  final Color? activeColor;

  const SageControlTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    this.isBusy = false,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selectedColor = activeColor ?? t.accent;
    final fg = isSelected ? t.onAccent : t.ink;
    final subFg = isSelected ? t.onAccent.withValues(alpha: 0.85) : t.ink3;

    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : t.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? selectedColor : t.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? t.onAccent.withValues(alpha: 0.18) : t.resolvedContainerHigh,
              ),
              child: isBusy
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                      ),
                    )
                  : Icon(icon, size: 22, color: fg),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.2,
                color: fg,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: subFg),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Global, persisted switch between the new "Sage Cockpit" dashboard and
/// the legacy Cyber dashboard, so the redesign is fully reversible from
/// Settings without losing any of the existing screen's logic.
class DashboardStyle {
  DashboardStyle._();
  static const String _prefKey = 'tiggomate_dashboard_style_sage';

  /// True = new Sage Cockpit layout, false = legacy Cyber dashboard.
  static final ValueNotifier<bool> useSage = ValueNotifier<bool>(true);
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      useSage.value = prefs.getBool(_prefKey) ?? true;
    } catch (_) {}
  }

  static Future<void> set(bool value) async {
    useSage.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }
}
