import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Reverse-geocodes GPS coordinates to a short, human-readable address via
/// OpenStreetMap's free Nominatim API.
///
/// CarLinko's own account API never returns a street address for a
/// vehicle's position — just raw lat/lon (see VehicleTelemetry.locationName,
/// which otherwise falls back to a generic "Last reported position"). This
/// fills that gap client-side, the same approach the open-source
/// ha-carlinko project uses, rather than something CarLinko itself provides.
class ReverseGeocoder {
  ReverseGeocoder._();

  // Nominatim's usage policy requires a descriptive User-Agent and caps
  // requests at roughly 1/second: https://operations.osmfoundation.org/policies/nominatim/
  static const String _userAgent = 'TiggoMate/1.0 (Chery Tiggo 7 PHEV companion app)';
  static const Duration _minRequestGap = Duration(seconds: 1);

  static DateTime? _lastRequestAt;
  static double? _cachedLat;
  static double? _cachedLon;
  static String? _cachedAddress;

  /// Returns a short street-level address for (lat, lon), or null if it
  /// can't be resolved right now. Caches the last result and skips a fresh
  /// lookup when the car hasn't moved more than ~30 m since then, and when
  /// called again within Nominatim's rate limit (returns the stale cache
  /// instead of refusing outright).
  static Future<String?> lookup(double lat, double lon, {HttpClient? client}) async {
    if (_cachedLat != null &&
        _cachedLon != null &&
        _cachedAddress != null &&
        _distanceMeters(lat, lon, _cachedLat!, _cachedLon!) < 30) {
      return _cachedAddress;
    }

    final now = DateTime.now();
    if (_lastRequestAt != null && now.difference(_lastRequestAt!) < _minRequestGap) {
      return _cachedAddress;
    }
    _lastRequestAt = now;

    final http = client ?? HttpClient();
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2&lat=$lat&lon=$lon&zoom=18&addressdetails=0',
      );
      final req = await http.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set('User-Agent', _userAgent);
      req.headers.set('Accept-Language', 'en');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return null;
      }
      final body = await utf8.decoder.bind(resp).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String?;
      if (displayName == null || displayName.isEmpty) return null;

      // display_name reads like "Jalan X, Taman Y, City, State, Postcode,
      // Country" — the first couple of segments are already enough detail
      // for a compact dashboard readout.
      final parts = displayName.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final short = parts.take(2).join(', ');
      if (short.isEmpty) return null;

      _cachedLat = lat;
      _cachedLon = lon;
      _cachedAddress = short;
      return short;
    } catch (_) {
      return null;
    } finally {
      if (client == null) http.close();
    }
  }

  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusM = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);
}
