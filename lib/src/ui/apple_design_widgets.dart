import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Apple-style interactive pressable widget that physically compresses on touch-down
/// and springs back on release, fulfilling Apple's "Kill Latency" and "Fluid Motion" principles.
class ApplePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration duration;
  final Curve curve;
  final bool enableHaptics;

  const ApplePressable({
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
  State<ApplePressable> createState() => _ApplePressableState();
}

class _ApplePressableState extends State<ApplePressable> with SingleTickerProviderStateMixin {
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

/// Translucent Frosted Glass Sheet Container based on Apple Design materials.
/// Features backdrop blur, light-catching hairline top edge, and refined squircle corners.
class AppleSheetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  const AppleSheetContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 28),
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE611151F) : const Color(0xF2FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0x80FFFFFF),
                width: 1.2,
              ),
              left: BorderSide(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                width: 0.8,
              ),
              right: BorderSide(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Apple Pull Handle Pill
              Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x4DFFFFFF) : const Color(0x33000000),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Tactile Squircle Control Tile modeled after iOS Control Center modules.
class AppleControlTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color activeColor;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onTap;

  const AppleControlTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeColor,
    required this.isSelected,
    this.isBusy = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = colors.isDark;

    return ApplePressable(
      onTap: isBusy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.22 : 0.14)
              : (isDark ? const Color(0xFF1B202C) : const Color(0xFFF1F3F7)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF272F3F) : const Color(0xFFE2E6EE)),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon glyph with subtle circular backing
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? activeColor.withValues(alpha: 0.20)
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
              ),
              child: isBusy
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: activeColor,
                        ),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 22,
                      color: isSelected ? activeColor : colors.textPrimary,
                    ),
            ),
            const SizedBox(height: 10),
            // Title with Apple optical tracking
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.2, // Optical tightening
                color: isSelected ? activeColor : colors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.0,
                color: isSelected ? activeColor.withValues(alpha: 0.85) : colors.textMuted,
              ),
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
