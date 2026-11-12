import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PriceKind { charge, fuel }

enum ChargeScope { all, ac, dc }

/// A dated electricity tariff (`charge`) or petrol price (`fuel`) period.
/// Inspired by j5-ev-dashboard's dated price book so changing today's rate
/// never retroactively alters past trip or charging cost history.
class PriceRule {
  final String id;
  final PriceKind kind;
  final ChargeScope scope;
  final DateTime effectiveFrom;
  final double pricePerUnit;
  final String label;

  const PriceRule({
    required this.id,
    required this.kind,
    this.scope = ChargeScope.all,
    required this.effectiveFrom,
    required this.pricePerUnit,
    this.label = '',
  });

  DateTime get effectiveDay =>
      DateTime(effectiveFrom.year, effectiveFrom.month, effectiveFrom.day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'scope': scope.name,
        'effectiveFrom': effectiveFrom.toIso8601String(),
        'pricePerUnit': pricePerUnit,
        'label': label,
      };

  factory PriceRule.fromJson(Map<String, dynamic> json) {
    final kindStr = (json['kind'] ?? 'charge').toString().toLowerCase();
    final scopeStr = (json['scope'] ?? 'all').toString().toLowerCase();
    final kind = kindStr == 'fuel' ? PriceKind.fuel : PriceKind.charge;
    final scope = switch (scopeStr) {
      'ac' => ChargeScope.ac,
      'dc' => ChargeScope.dc,
      _ => ChargeScope.all,
    };
    final parsedDate = DateTime.tryParse(json['effectiveFrom']?.toString() ?? '') ??
        DateTime(2025, 1, 1);

    return PriceRule(
      id: json['id']?.toString() ?? 'rule_${parsedDate.millisecondsSinceEpoch}_${kind.name}_${scope.name}',
      kind: kind,
      scope: kind == PriceKind.fuel ? ChargeScope.all : scope,
      effectiveFrom: parsedDate,
      pricePerUnit: (json['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
      label: json['label']?.toString() ?? '',
    );
  }
}

/// Manages dated tariff / fuel periods and optional per-session rate overrides.
class PriceBookService extends ChangeNotifier {
  PriceBookService({
    List<PriceRule>? initialRules,
    Map<String, double>? initialOverrides,
  })  : _rules = List<PriceRule>.from(initialRules ?? _defaultRules()),
        _sessionOverrides = Map<String, double>.from(initialOverrides ?? {}),
        _loaded = initialRules != null;

  static final PriceBookService instance = PriceBookService();

  static const String _kRulesKey = 'tm_price_book_rules_v1';
  static const String _kOverridesKey = 'tm_price_book_overrides_v1';

  Future<void> Function(Map<String, dynamic> payload)? onCloudSync;

  final List<PriceRule> _rules;
  final Map<String, double> _sessionOverrides;
  bool _loaded;

  List<PriceRule> get rules {
    final copy = List<PriceRule>.from(_rules);
    copy.sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return List.unmodifiable(copy);
  }

  Map<String, double> get sessionOverrides => Map.unmodifiable(_sessionOverrides);

  static List<PriceRule> _defaultRules() => [
        PriceRule(
          id: 'default_tnb_ac_2025',
          kind: PriceKind.charge,
          scope: ChargeScope.ac,
          effectiveFrom: DateTime(2025, 1, 1),
          pricePerUnit: 0.57,
          label: 'TNB Residential Base',
        ),
        PriceRule(
          id: 'default_public_dc_2025',
          kind: PriceKind.charge,
          scope: ChargeScope.dc,
          effectiveFrom: DateTime(2025, 1, 1),
          pricePerUnit: 1.30,
          label: 'Public DC Fast Default',
        ),
        PriceRule(
          id: 'default_ron95_2025',
          kind: PriceKind.fuel,
          scope: ChargeScope.all,
          effectiveFrom: DateTime(2025, 1, 1),
          pricePerUnit: 2.05,
          label: 'RON95 Malaysia Default',
        ),
      ];

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawRules = prefs.getString(_kRulesKey);
      if (rawRules != null && rawRules.trim().isNotEmpty) {
        final decoded = json.decode(rawRules);
        if (decoded is List) {
          final parsed = decoded
              .whereType<Map>()
              .map((m) => PriceRule.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          if (parsed.isNotEmpty) {
            _rules
              ..clear()
              ..addAll(parsed);
          }
        }
      }
      final rawOv = prefs.getString(_kOverridesKey);
      if (rawOv != null && rawOv.trim().isNotEmpty) {
        final decoded = json.decode(rawOv);
        if (decoded is Map) {
          _sessionOverrides.clear();
          decoded.forEach((k, v) {
            if (v is num) _sessionOverrides[k.toString()] = v.toDouble();
          });
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('PriceBookService load note: $e');
      _loaded = true;
    }
  }

  Map<String, dynamic> exportJson() => {
        'rules': _rules.map((r) => r.toJson()).toList(),
        'overrides': _sessionOverrides,
      };

  Future<void> importJson(Map<String, dynamic> data, {bool persist = true}) async {
    final rawRules = data['rules'];
    if (rawRules is List) {
      final parsed = rawRules
          .whereType<Map>()
          .map((m) => PriceRule.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (parsed.isNotEmpty) {
        _rules
          ..clear()
          ..addAll(parsed);
      }
    }
    final rawOv = data['overrides'];
    if (rawOv is Map) {
      _sessionOverrides.clear();
      rawOv.forEach((k, v) {
        if (v is num) _sessionOverrides[k.toString()] = v.toDouble();
      });
    }
    _loaded = true;
    if (persist) {
      await _persistLocal();
    }
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRulesKey, json.encode(_rules.map((r) => r.toJson()).toList()));
      await prefs.setString(_kOverridesKey, json.encode(_sessionOverrides));
    } catch (e) {
      debugPrint('PriceBookService persist note: $e');
    }
  }

  Future<void> _saveAndSync() async {
    await _persistLocal();
    final syncFn = onCloudSync;
    if (syncFn != null) {
      try {
        await syncFn(exportJson());
      } catch (e) {
        debugPrint('PriceBookService cloud sync note: $e');
      }
    }
    notifyListeners();
  }

  /// Resolves the RM/kWh tariff effective at [when].
  /// Order: session override -> latest rule at/before [when] (specific AC/DC before `all`) -> earliest matching rule -> [fallback].
  double rateForCharge(
    DateTime when, {
    bool isDc = false,
    String? sessionId,
    double fallback = 0.57,
  }) {
    if (sessionId != null && _sessionOverrides.containsKey(sessionId)) {
      return _sessionOverrides[sessionId]!;
    }
    final desired = isDc ? ChargeScope.dc : ChargeScope.ac;
    final candidates = _rules
        .where((r) => r.kind == PriceKind.charge && (r.scope == desired || r.scope == ChargeScope.all))
        .toList();
    if (candidates.isEmpty) return fallback;

    final effective = candidates.where((r) => !r.effectiveFrom.isAfter(when)).toList();
    if (effective.isNotEmpty) {
      effective.sort((a, b) {
        final cmpDate = b.effectiveFrom.compareTo(a.effectiveFrom);
        if (cmpDate != 0) return cmpDate;
        final aSpec = a.scope == desired ? 1 : 0;
        final bSpec = b.scope == desired ? 1 : 0;
        return bSpec.compareTo(aSpec);
      });
      return effective.first.pricePerUnit;
    }

    // If [when] predates every rule, fall back to the oldest known matching rule.
    candidates.sort((a, b) {
      final cmpDate = a.effectiveFrom.compareTo(b.effectiveFrom);
      if (cmpDate != 0) return cmpDate;
      final aSpec = a.scope == desired ? 1 : 0;
      final bSpec = b.scope == desired ? 1 : 0;
      return bSpec.compareTo(aSpec);
    });
    return candidates.first.pricePerUnit;
  }

  /// Resolves the RM/L petrol price effective at [when].
  double rateForFuel(
    DateTime when, {
    String? sessionId,
    double fallback = 2.05,
  }) {
    if (sessionId != null && _sessionOverrides.containsKey(sessionId)) {
      return _sessionOverrides[sessionId]!;
    }
    final candidates = _rules.where((r) => r.kind == PriceKind.fuel).toList();
    if (candidates.isEmpty) return fallback;

    final effective = candidates.where((r) => !r.effectiveFrom.isAfter(when)).toList();
    if (effective.isNotEmpty) {
      effective.sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
      return effective.first.pricePerUnit;
    }

    candidates.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    return candidates.first.pricePerUnit;
  }

  Future<void> addOrUpdateRule(PriceRule rule) async {
    await ensureLoaded();
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx != -1) {
      _rules[idx] = rule;
    } else {
      _rules.add(rule);
    }
    await _saveAndSync();
  }

  Future<void> deleteRule(String id) async {
    await ensureLoaded();
    _rules.removeWhere((r) => r.id == id);
    await _saveAndSync();
  }

  Future<void> setSessionOverride(String sessionId, double rate) async {
    await ensureLoaded();
    _sessionOverrides[sessionId] = rate;
    await _saveAndSync();
  }

  /// Appends new dated periods whenever Settings rates change, preserving older period history.
  Future<void> recordSettingsRates({
    required double tnbTariff,
    required double fuelPrice,
    DateTime? effectiveFrom,
  }) async {
    await ensureLoaded();
    final now = effectiveFrom ?? DateTime.now();
    bool changed = false;

    final currentAc = rateForCharge(now, isDc: false, fallback: -1);
    if ((currentAc - tnbTariff).abs() > 0.0005) {
      _rules.add(
        PriceRule(
          id: 'ac_${now.millisecondsSinceEpoch}',
          kind: PriceKind.charge,
          scope: ChargeScope.ac,
          effectiveFrom: now,
          pricePerUnit: tnbTariff,
          label: 'TNB AC Rate Update',
        ),
      );
      changed = true;
    }

    final currentFuel = rateForFuel(now, fallback: -1);
    if ((currentFuel - fuelPrice).abs() > 0.0005) {
      _rules.add(
        PriceRule(
          id: 'fuel_${now.millisecondsSinceEpoch}',
          kind: PriceKind.fuel,
          scope: ChargeScope.all,
          effectiveFrom: now,
          pricePerUnit: fuelPrice,
          label: 'RON95 Price Update',
        ),
      );
      changed = true;
    }

    if (changed) {
      await _saveAndSync();
    }
  }
}
