import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../carlinko/vehicle_skin.dart';
import '../carlinko/vehicle_telemetry.dart';
import 'blueprint_car_canvas.dart';

/// Swipeable car card: Vehicle Livery → TPMS top view → 3D Orbit View.
class CarViewCarousel extends StatefulWidget {
  final VehicleTelemetry telemetry;
  final bool isBound;
  final Color accentColor;

  /// The currently-chosen paint, set in Settings/setup — this card only
  /// displays it, it doesn't offer a picker.
  final String selectedSkinKey;

  /// Page to open on (lets the parent restore it after the card is rebuilt).
  final int initialPage;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onCarTap;

  const CarViewCarousel({
    super.key,
    required this.telemetry,
    required this.isBound,
    required this.accentColor,
    required this.selectedSkinKey,
    this.initialPage = 0,
    this.onPageChanged,
    this.onCarTap,
  });

  @override
  State<CarViewCarousel> createState() => _CarViewCarouselState();
}

class _CarViewCarouselState extends State<CarViewCarousel> {
  static const int _pageCount = 3;
  static const int _orbitPage = 2;

  late final PageController _pageController;
  late int _page;
  bool _orbitActive = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _pageCount - 1);
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() {
      _page = i;
      if (i != _orbitPage) _orbitActive = false;
    });
    widget.onPageChanged?.call(i);
  }

  void _goTo(int i) {
    if (_orbitActive) setState(() => _orbitActive = false);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  String get _label => const [
        'VEHICLE LIVERY',
        'TOP VIEW · TPMS COLD',
        '3D ORBIT VIEWER',
      ][_page];

  String get _hint {
    switch (_page) {
      case 0:
        return 'SET IN SETTINGS';
      case 1:
        return 'SPEC 230 KPA';
      default:
        return _orbitActive ? 'DRAG TO ORBIT' : 'TAP TO ORBIT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF12141A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);

    final headerStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      letterSpacing: 1.2,
      color: textMuted,
    );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          // Dynamic header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_label, style: headerStyle.copyWith(fontWeight: FontWeight.w700)),
              Text(
                _hint,
                style: headerStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _orbitActive ? widget.accentColor : textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Swipe zone. Page swipe is locked while the user is orbiting the 3D model.
          SizedBox(
            height: 180,
            child: PageView(
              controller: _pageController,
              physics: _orbitActive ? const NeverScrollableScrollPhysics() : null,
              onPageChanged: _onPageChanged,
              children: [
                _VehicleLiveryPanel(
                  selectedKey: widget.selectedSkinKey,
                  textMuted: textMuted,
                  textPrimary: textPrimary,
                  onTap: widget.onCarTap,
                ),
                BlueprintCarStage(
                  telemetry: widget.telemetry,
                  isBound: widget.isBound,
                  accentColor: widget.accentColor,
                ),
                _OrbitViewerPanel(
                  active: _orbitActive,
                  background: cardBg,
                  accentColor: widget.accentColor,
                  onActivate: () => setState(() => _orbitActive = true),
                  onDeactivate: () => setState(() => _orbitActive = false),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          _PageDots(
            count: _pageCount,
            current: _page,
            activeColor: widget.accentColor,
            inactiveColor: textMuted.withValues(alpha: 0.35),
            onTap: _goTo,
          ),
        ],
      ),
    );
  }
}

// ─── Panel 3: Vehicle Livery ────────────────────────────────────────────────
// Just shows the car in whichever paint is currently selected (plus swatches
// to change it) — not an editing "studio", so the label stays plain.

class _VehicleLiveryPanel extends StatelessWidget {
  final String selectedKey;
  final Color textMuted;
  final Color textPrimary;
  final VoidCallback? onTap;

  const _VehicleLiveryPanel({
    required this.selectedKey,
    required this.textMuted,
    required this.textPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin = getVehicleSkinByKey(selectedKey);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          // Hero render: floating over subtle ambient glow and shadow
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 170,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    skin.assetPath,
                    key: ValueKey(skin.key),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.directions_car_filled_outlined, size: 48, color: textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${skin.name}${skin.isDualTone ? ' · DUAL TONE' : ''}'.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 12, color: textMuted),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'CHOOSE IN SETTINGS',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panel 1: 3D Orbit ──────────────────────────────────────────────────────

class _OrbitViewerPanel extends StatefulWidget {
  final bool active;
  final Color background;
  final Color accentColor;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  const _OrbitViewerPanel({
    required this.active,
    required this.background,
    required this.accentColor,
    required this.onActivate,
    required this.onDeactivate,
  });

  @override
  State<_OrbitViewerPanel> createState() => _OrbitViewerPanelState();
}

class _OrbitViewerPanelState extends State<_OrbitViewerPanel>
    with AutomaticKeepAliveClientMixin {
  // Keep the WebView (and the 24 MB GLB) alive after first load,
  // so swiping back to this panel doesn't reload the model.
  @override
  bool get wantKeepAlive => true;

  // This is now the carousel's first page, so it's what loads the moment the
  // dashboard opens. Defer actually mounting the WebView + 24 MB GLB until
  // the user taps in, rather than eating that cost on every cold open.
  bool _loaded = false;

  void _load() {
    setState(() => _loaded = true);
    widget.onActivate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_loaded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _load,
          child: Container(
            color: widget.background,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.threesixty, size: 34, color: widget.accentColor),
                const SizedBox(height: 8),
                Text(
                  'TAP TO LOAD 3D VIEW',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: widget.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: ModelViewer(
              src: 'assets/models/tiggo7.glb',
              alt: 'Chery Tiggo 7 PHEV 3D',
              ar: false,
              autoRotate: true,
              autoRotateDelay: 1000,
              rotationPerSecond: '18deg',
              cameraControls: true,
              touchAction: TouchAction.panY,
              backgroundColor: widget.background,
            ),
          ),

          // Shield: while not orbiting, the WebView never sees pointers, so
          // horizontal drags go to the PageView and vertical drags to the dashboard.
          if (!widget.active)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onActivate,
              ),
            ),

          Positioned(
            right: 8,
            bottom: 8,
            child: _OrbitChip(
              active: widget.active,
              accentColor: widget.accentColor,
              onTap: widget.active ? widget.onDeactivate : widget.onActivate,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitChip extends StatelessWidget {
  final bool active;
  final Color accentColor;
  final VoidCallback onTap;

  const _OrbitChip({required this.active, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accentColor : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check : Icons.threesixty,
              size: 14,
              color: active ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              active ? 'DONE' : 'ORBIT',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: active ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page dots ──────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onTap;

  const _PageDots({
    required this.count,
    required this.current,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == current;
          return Semantics(
            button: true,
            selected: active,
            label: 'Car view ${i + 1} of $count',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              // 20 px tall, ≥18 px wide hit area around a 6 px dot
              child: SizedBox(
                width: active ? 30 : 18,
                height: 20,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? activeColor : inactiveColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
