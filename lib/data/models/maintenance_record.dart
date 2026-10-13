import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Individual maintenance service entry.
@immutable
class ServiceRecord {
  final String id;
  final DateTime date;
  final double mileageKm;
  final String
  serviceType; // e.g., '1,000 km Inspection', '10,000 km Service', 'Brake Fluid'
  final String workshopName;
  final double costRm;
  final String notes;
  final String? invoiceNumber;
  final bool isCarLinkoActivated;

  const ServiceRecord({
    required this.id,
    required this.date,
    required this.mileageKm,
    required this.serviceType,
    required this.workshopName,
    required this.costRm,
    this.notes = '',
    this.invoiceNumber,
    this.isCarLinkoActivated = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'mileageKm': mileageKm,
      'serviceType': serviceType,
      'workshopName': workshopName,
      'costRm': costRm,
      'notes': notes,
      'invoiceNumber': invoiceNumber,
      'isCarLinkoActivated': isCarLinkoActivated,
    };
  }

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    return ServiceRecord(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      mileageKm: (map['mileageKm'] as num).toDouble(),
      serviceType: map['serviceType'] as String,
      workshopName:
          map['workshopName'] as String? ?? 'Chery Authorized Service Center',
      costRm: (map['costRm'] as num).toDouble(),
      notes: map['notes'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String?,
      isCarLinkoActivated: map['isCarLinkoActivated'] as bool? ?? false,
    );
  }
}

/// Tyre rotation and maintenance history.
@immutable
class TyreRecord {
  final String id;
  final DateTime date;
  final double mileageKm;
  final String
  action; // 'Rotation', 'Replacement', 'Alignment', 'Pressure Check'
  final String details;
  final double costRm;

  const TyreRecord({
    required this.id,
    required this.date,
    required this.mileageKm,
    required this.action,
    this.details = '',
    this.costRm = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'mileageKm': mileageKm,
    'action': action,
    'details': details,
    'costRm': costRm,
  };

  factory TyreRecord.fromMap(Map<String, dynamic> map) => TyreRecord(
    id: map['id'] as String,
    date: DateTime.parse(map['date'] as String),
    mileageKm: (map['mileageKm'] as num).toDouble(),
    action: map['action'] as String,
    details: map['details'] as String? ?? '',
    costRm: (map['costRm'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Ownership and regulatory expiry tracking.
@immutable
class RegulatoryExpiry {
  final DateTime? roadTaxExpiry;
  final DateTime? insuranceExpiry;
  final String insuranceProvider;
  final String policyNumber;

  const RegulatoryExpiry({
    this.roadTaxExpiry,
    this.insuranceExpiry,
    this.insuranceProvider = 'Chery Auto Protect / Allianz',
    this.policyNumber = 'POL-7707-CSH',
  });

  Map<String, dynamic> toMap() => {
    'roadTaxExpiry': roadTaxExpiry?.toIso8601String(),
    'insuranceExpiry': insuranceExpiry?.toIso8601String(),
    'insuranceProvider': insuranceProvider,
    'policyNumber': policyNumber,
  };

  factory RegulatoryExpiry.fromMap(Map<String, dynamic> map) =>
      RegulatoryExpiry(
        roadTaxExpiry: map['roadTaxExpiry'] != null
            ? DateTime.tryParse(map['roadTaxExpiry'] as String)
            : null,
        insuranceExpiry: map['insuranceExpiry'] != null
            ? DateTime.tryParse(map['insuranceExpiry'] as String)
            : null,
        insuranceProvider:
            map['insuranceProvider'] as String? ??
            'Chery Auto Protect / Allianz',
        policyNumber: map['policyNumber'] as String? ?? 'POL-7707-CSH',
      );
}

/// Maintenance configuration and aggregate status.
@immutable
class MaintenanceState {
  final int intervalKm; // e.g. 10000 km
  final int intervalMonths; // e.g. 6 months
  final List<ServiceRecord> serviceRecords;
  final List<TyreRecord> tyreRecords;
  final RegulatoryExpiry regulatoryExpiry;

  const MaintenanceState({
    this.intervalKm = 10000,
    this.intervalMonths = 6,
    this.serviceRecords = const [],
    this.tyreRecords = const [],
    this.regulatoryExpiry = const RegulatoryExpiry(),
  });

  /// Calculates next service target given current odometer reading.
  Map<String, dynamic> calculateNextServiceDue(
    double currentOdoKm,
    DateTime? purchaseDate,
  ) {
    if (serviceRecords.isEmpty) {
      // First 1,000 km service milestone
      final remainingKm = (1000 - currentOdoKm).clamp(0, 1000);
      final dueByDate = (purchaseDate ?? DateTime.now()).add(
        const Duration(days: 30),
      );
      return {
        'serviceName': '1,000 km Initial Inspection & CarLinko Activation',
        'targetKm': 1000.0,
        'remainingKm': remainingKm.toDouble(),
        'dueDate': dueByDate,
        'isFirstMilestone': true,
        'isOverdue': currentOdoKm >= 1000 || DateTime.now().isAfter(dueByDate),
      };
    }

    final lastService = serviceRecords.first; // sorted descending
    final targetKm = lastService.mileageKm + intervalKm;
    final remainingKm = targetKm - currentOdoKm;
    final dueDate = lastService.date.add(Duration(days: intervalMonths * 30));

    return {
      'serviceName':
          'Regular Scheduled Service ($intervalKm km / $intervalMonths mo)',
      'targetKm': targetKm,
      'remainingKm': remainingKm,
      'dueDate': dueDate,
      'isFirstMilestone': false,
      'isOverdue': remainingKm <= 0 || DateTime.now().isAfter(dueDate),
    };
  }

  double get totalServiceCostRm =>
      serviceRecords.fold(0.0, (sum, record) => sum + record.costRm) +
      tyreRecords.fold(0.0, (sum, record) => sum + record.costRm);

  Map<String, dynamic> toMap() => {
    'intervalKm': intervalKm,
    'intervalMonths': intervalMonths,
    'serviceRecords': serviceRecords.map((e) => e.toMap()).toList(),
    'tyreRecords': tyreRecords.map((e) => e.toMap()).toList(),
    'regulatoryExpiry': regulatoryExpiry.toMap(),
  };

  factory MaintenanceState.fromMap(Map<String, dynamic> map) =>
      MaintenanceState(
        intervalKm: (map['intervalKm'] as num?)?.toInt() ?? 10000,
        intervalMonths: (map['intervalMonths'] as num?)?.toInt() ?? 6,
        serviceRecords:
            (map['serviceRecords'] as List<dynamic>?)
                ?.map((e) => ServiceRecord.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        tyreRecords:
            (map['tyreRecords'] as List<dynamic>?)
                ?.map((e) => TyreRecord.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        regulatoryExpiry: map['regulatoryExpiry'] != null
            ? RegulatoryExpiry.fromMap(
                map['regulatoryExpiry'] as Map<String, dynamic>,
              )
            : const RegulatoryExpiry(),
      );

  String toJson() => json.encode(toMap());

  factory MaintenanceState.fromJson(String source) =>
      MaintenanceState.fromMap(json.decode(source) as Map<String, dynamic>);
}
