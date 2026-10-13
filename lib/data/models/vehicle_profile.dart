import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/constants/vehicle_specs.dart';

/// Configurable vehicle profile for the Malaysian Chery Tiggo 7 PHEV CSH.
@immutable
class VehicleProfile {
  final String manufacturer;
  final String model;
  final String market;
  final String powertrain;
  final String preferredDrivingMode;
  final String vehicleDataConnection;
  final String connectedService;
  final String obdConnection;

  // Editable ownership attributes
  final String nickname;
  final String registrationNumber; // Plate number, e.g. VXX 1234
  final DateTime? purchaseDate;
  final double currentOdometerKm;
  final String tyreBrandAndModel;
  final String tyreSize;
  final int recommendedFrontPressureKpa;
  final int recommendedRearPressureKpa;
  final String ownerName;
  final String? vin;

  const VehicleProfile({
    this.manufacturer = VehicleSpecs.manufacturer,
    this.model = VehicleSpecs.modelName,
    this.market = VehicleSpecs.market,
    this.powertrain = VehicleSpecs.powertrainType,
    this.preferredDrivingMode = VehicleSpecs.defaultPreferredDrivingMode,
    this.vehicleDataConnection = 'Not activated',
    this.connectedService = 'CarLinko',
    this.obdConnection = 'Not configured',
    this.nickname = 'My Tiggo 7 PHEV',
    this.registrationNumber = 'Pending Registration',
    this.purchaseDate,
    this.currentOdometerKm = 0.0,
    this.tyreBrandAndModel = 'Factory Fitted Cooper Evolution CTT',
    this.tyreSize = VehicleSpecs.standardTyreSize,
    this.recommendedFrontPressureKpa =
        VehicleSpecs.recommendedColdPressureFrontKpa,
    this.recommendedRearPressureKpa =
        VehicleSpecs.recommendedColdPressureRearKpa,
    this.ownerName = 'Tiggo 7 Owner',
    this.vin,
  });

  /// Factory constructor for the initial vehicle profile specified in product requirements.
  factory VehicleProfile.initial() {
    return VehicleProfile(
      manufacturer: 'Chery',
      model: 'Tiggo 7 PHEV CSH',
      market: 'Malaysia',
      powertrain: 'Plug-in hybrid',
      preferredDrivingMode: 'AUTO',
      vehicleDataConnection: 'Not activated',
      connectedService: 'CarLinko',
      obdConnection: 'Not configured',
      nickname: 'Tiggo 7 CSH',
      registrationNumber: 'VAB 7707',
      purchaseDate: DateTime(2026, 1, 15),
      currentOdometerKm:
          850.0, // Approaching the 1,000 km CarLinko activation inspection
      tyreBrandAndModel: 'Factory Fitted 225/55 R18',
      tyreSize: '225/55 R18 98V',
      recommendedFrontPressureKpa: 230,
      recommendedRearPressureKpa: 230,
      ownerName: 'Malaysian Owner',
    );
  }

  VehicleProfile copyWith({
    String? manufacturer,
    String? model,
    String? market,
    String? powertrain,
    String? preferredDrivingMode,
    String? vehicleDataConnection,
    String? connectedService,
    String? obdConnection,
    String? nickname,
    String? registrationNumber,
    DateTime? purchaseDate,
    double? currentOdometerKm,
    String? tyreBrandAndModel,
    String? tyreSize,
    int? recommendedFrontPressureKpa,
    int? recommendedRearPressureKpa,
    String? ownerName,
    String? vin,
  }) {
    return VehicleProfile(
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      market: market ?? this.market,
      powertrain: powertrain ?? this.powertrain,
      preferredDrivingMode: preferredDrivingMode ?? this.preferredDrivingMode,
      vehicleDataConnection:
          vehicleDataConnection ?? this.vehicleDataConnection,
      connectedService: connectedService ?? this.connectedService,
      obdConnection: obdConnection ?? this.obdConnection,
      nickname: nickname ?? this.nickname,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      currentOdometerKm: currentOdometerKm ?? this.currentOdometerKm,
      tyreBrandAndModel: tyreBrandAndModel ?? this.tyreBrandAndModel,
      tyreSize: tyreSize ?? this.tyreSize,
      recommendedFrontPressureKpa:
          recommendedFrontPressureKpa ?? this.recommendedFrontPressureKpa,
      recommendedRearPressureKpa:
          recommendedRearPressureKpa ?? this.recommendedRearPressureKpa,
      ownerName: ownerName ?? this.ownerName,
      vin: vin ?? this.vin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'manufacturer': manufacturer,
      'model': model,
      'market': market,
      'powertrain': powertrain,
      'preferredDrivingMode': preferredDrivingMode,
      'vehicleDataConnection': vehicleDataConnection,
      'connectedService': connectedService,
      'obdConnection': obdConnection,
      'nickname': nickname,
      'registrationNumber': registrationNumber,
      'purchaseDate': purchaseDate?.toIso8601String(),
      'currentOdometerKm': currentOdometerKm,
      'tyreBrandAndModel': tyreBrandAndModel,
      'tyreSize': tyreSize,
      'recommendedFrontPressureKpa': recommendedFrontPressureKpa,
      'recommendedRearPressureKpa': recommendedRearPressureKpa,
      'ownerName': ownerName,
      'vin': vin,
    };
  }

  factory VehicleProfile.fromMap(Map<String, dynamic> map) {
    return VehicleProfile(
      manufacturer: map['manufacturer'] as String? ?? VehicleSpecs.manufacturer,
      model: map['model'] as String? ?? VehicleSpecs.modelName,
      market: map['market'] as String? ?? VehicleSpecs.market,
      powertrain: map['powertrain'] as String? ?? VehicleSpecs.powertrainType,
      preferredDrivingMode:
          map['preferredDrivingMode'] as String? ??
          VehicleSpecs.defaultPreferredDrivingMode,
      vehicleDataConnection:
          map['vehicleDataConnection'] as String? ?? 'Not activated',
      connectedService: map['connectedService'] as String? ?? 'CarLinko',
      obdConnection: map['obdConnection'] as String? ?? 'Not configured',
      nickname: map['nickname'] as String? ?? 'My Tiggo 7 PHEV',
      registrationNumber: map['registrationNumber'] as String? ?? '',
      purchaseDate: map['purchaseDate'] != null
          ? DateTime.tryParse(map['purchaseDate'] as String)
          : null,
      currentOdometerKm: (map['currentOdometerKm'] as num?)?.toDouble() ?? 0.0,
      tyreBrandAndModel: map['tyreBrandAndModel'] as String? ?? '',
      tyreSize: map['tyreSize'] as String? ?? VehicleSpecs.standardTyreSize,
      recommendedFrontPressureKpa:
          (map['recommendedFrontPressureKpa'] as num?)?.toInt() ?? 230,
      recommendedRearPressureKpa:
          (map['recommendedRearPressureKpa'] as num?)?.toInt() ?? 230,
      ownerName: map['ownerName'] as String? ?? '',
      vin: map['vin'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory VehicleProfile.fromJson(String source) =>
      VehicleProfile.fromMap(json.decode(source) as Map<String, dynamic>);
}
