import 'package:flutter/material.dart';
import '../service/location_tracker_service.dart';
import '../theme/app_tokens.dart';

/// Shows the GPS fixes the background tracker has captured (~every 15 min),
/// mirroring the location-history idea from ha-carlinko: the account API
/// gives raw coordinates regardless of the app's own UI, this is just a
/// place to look at what's been logged.
class LocationHistorySheet extends StatefulWidget {
  const LocationHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF090D12) : const Color(0xFFF7F8FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const LocationHistorySheet(),
    );
  }

  @override
  State<LocationHistorySheet> createState() => _LocationHistorySheetState();
}

class _LocationHistorySheetState extends State<LocationHistorySheet> {
  List<LocationHistoryEntry> _entries = [];
  bool _loading = true;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await LocationTrackerService.loadHistory();
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _trackNow() async {
    setState(() => _capturing = true);
    await LocationTrackerService.captureOnce();
    await _load();
    if (mounted) setState(() => _capturing = false);
  }

  Future<void> _clear() async {
    await LocationTrackerService.clearHistory();
    await _load();
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? const Color(0xFF717684) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0A0B0E);
    final borderCol = isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: borderCol, borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_history, size: 20, color: t.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Location History',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
                if (_entries.isNotEmpty)
                  TextButton(
                    onPressed: _clear,
                    child: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
              ],
            ),
            Text(
              'Captured automatically about every 15 minutes in the background, plus whenever you tap Track Now.',
              style: TextStyle(fontSize: 11.5, color: textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 340,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? Center(
                          child: Text(
                            'No fixes captured yet.\nTap "Track Now" to log the first one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _entries.length,
                          separatorBuilder: (_, _) => Divider(color: borderCol, height: 1),
                          itemBuilder: (ctx, i) {
                            final e = _entries[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.place_outlined, size: 16, color: t.accent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.address ?? '${e.latitude.toStringAsFixed(5)}, ${e.longitude.toStringAsFixed(5)}',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _fmtTime(e.timestamp),
                                          style: TextStyle(fontSize: 11, color: textMuted),
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
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _capturing ? null : _trackNow,
              icon: _capturing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : const Icon(Icons.my_location, size: 18, color: Colors.black87),
              label: Text(_capturing ? 'Tracking…' : 'Track Now', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.accent,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
