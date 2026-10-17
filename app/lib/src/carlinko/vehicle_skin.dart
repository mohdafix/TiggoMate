import 'package:flutter/material.dart';

/// Official Chery Tiggo 7 PHEV (CSH) Malaysian Market Exterior Colors
class VehicleSkinOption {
  final String key;
  final String name;
  final String tag;
  final String assetPath;
  final Color primaryColor;
  final Color? secondaryColor; // For dual-tone (Bloodstone Red with Black Roof)
  final String priceInfo;
  final String description;

  const VehicleSkinOption({
    required this.key,
    required this.name,
    required this.tag,
    required this.assetPath,
    required this.primaryColor,
    this.secondaryColor,
    required this.priceInfo,
    required this.description,
  });

  bool get isDualTone => secondaryColor != null;
}

const List<VehicleSkinOption> kOfficialVehicleSkins = [
  VehicleSkinOption(
    key: 'khaki_white',
    name: 'Khaki White',
    tag: 'Multi-Coat Pearl',
    assetPath: 'assets/images/car_hero_khaki_white.png',
    primaryColor: Color(0xFFF4F5F7),
    priceInfo: 'Standard Factory OEM',
    description: 'Pristine pearl white with subtle metallic flake. Classic, crisp, and high heat-reflective.',
  ),
  VehicleSkinOption(
    key: 'phantom_grey',
    name: 'Phantom Grey',
    tag: 'Metallic Titanium',
    assetPath: 'assets/images/car_hero_phantom_grey.png',
    primaryColor: Color(0xFF4A5260),
    priceInfo: 'Standard Factory OEM',
    description: 'Deep metallic gunmetal grey with dynamic highlights accentuating the Tiggo 7 sculpted shoulder lines.',
  ),
  VehicleSkinOption(
    key: 'bloodstone_red',
    name: 'Bloodstone Red',
    tag: 'Dual-Tone Black Roof',
    assetPath: 'assets/images/car_hero_bloodstone_red.png',
    primaryColor: Color(0xFFB81D2E),
    secondaryColor: Color(0xFF111827),
    priceInfo: 'Premium Dual-Tone (+RM 2,000)',
    description: 'Official Chery dual-tone edition. Rich lustrous crimson body paired with an obsidian black floating roof, pillars, and aerodynamic spoiler.',
  ),
];

VehicleSkinOption getVehicleSkinByKey(String? key) {
  return kOfficialVehicleSkins.firstWhere(
    (skin) => skin.key == key,
    orElse: () => kOfficialVehicleSkins[0],
  );
}
