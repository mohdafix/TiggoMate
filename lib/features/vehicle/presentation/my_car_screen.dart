import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/vehicle_specs.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';

class MyCarScreen extends ConsumerWidget {
  const MyCarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vehicleProfileProvider);
    final energyState = ref.watch(energyStateProvider);
    final isSim = ref.watch(vehicleRepositoryProvider).isSimulatedMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Car'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/edit-profile'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Vehicle Overview Card
          _buildVehicleHeaderCard(context, profile),

          const SizedBox(height: 16),

          // Connectivity & Telematics Status Section
          _buildConnectionCard(context, ref, profile, isSim),

          const SizedBox(height: 16),

          // Tyre & Chassis Specifications Card
          _buildTyreCard(context, profile),

          const SizedBox(height: 16),

          // Powertrain & Hybrid Specifications
          _buildPowertrainSpecsCard(context),

          const SizedBox(height: 16),

          // Energy & Fuel History Summary
          _buildEnergySummaryCard(context, energyState),

          const SizedBox(height: 16),

          // Verified Vehicle Documents
          _buildDocumentsCard(context),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVehicleHeaderCard(BuildContext context, dynamic profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nickname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile.manufacturer} ${profile.model}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    profile.registrationNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _buildDetailRow(
              'Market & Variant',
              '${profile.market} Dedicated PHEV',
            ),
            _buildDetailRow('Powertrain', profile.powertrain),
            _buildDetailRow(
              'Preferred Driving Mode',
              profile.preferredDrivingMode,
            ),
            _buildDetailRow(
              'Current Odometer',
              Formatters.formatDistance(profile.currentOdometerKm),
            ),
            if (profile.purchaseDate != null)
              _buildDetailRow(
                'Registration / Purchase Date',
                Formatters.formatDate(profile.purchaseDate!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(
    BuildContext context,
    WidgetRef ref,
    dynamic profile,
    bool isSim,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CONNECTIVITY & TELEMATICS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.cell_tower_rounded,
                color: isSim
                    ? AppTheme.statusSimulated
                    : AppTheme.statusDisconnected,
              ),
              title: const Text('CarLinko 4G Telematics (Malaysian Spec)'),
              subtitle: Text(
                isSim
                    ? 'Simulated Mode Active (Mock Telemetry)'
                    : 'Pending dealer activation at 1,000 km initial service.',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Chip(
                label: Text(
                  isSim ? 'SIMULATED' : 'NOT ACTIVATED',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Divider(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.bluetooth_searching_rounded,
                color: AppTheme.statusDisconnected,
              ),
              title: const Text('OBD-II Bluetooth Scanner'),
              subtitle: const Text(
                'Not configured. Standard diagnostic adapter pairing optional.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Chip(
                label: Text(
                  'NOT CONFIGURED',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTyreCard(BuildContext context, dynamic profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TYRES & CHASSIS SPECIFICATIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Factory Specification', profile.tyreSize),
            _buildDetailRow('Fitted Model', profile.tyreBrandAndModel),
            _buildDetailRow(
              'Recommended Cold Pressure (Front)',
              '${profile.recommendedFrontPressureKpa} kPa (2.3 bar / 33 psi)',
            ),
            _buildDetailRow(
              'Recommended Cold Pressure (Rear)',
              '${profile.recommendedRearPressureKpa} kPa (2.3 bar / 33 psi)',
            ),
            _buildDetailRow(
              'Fully Loaded Pressure',
              '${VehicleSpecs.recommendedColdPressureLoadedKpa} kPa (2.5 bar / 36 psi)',
            ),
            _buildDetailRow(
              'Rotation Interval',
              'Every ${Formatters.formatDistance(VehicleSpecs.tyreRotationIntervalKm.toDouble())}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowertrainSpecsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VERIFIED POWERTRAIN SPECIFICATIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Engine', VehicleSpecs.engineDisplacement),
            _buildDetailRow(
              'Engine Output',
              '${VehicleSpecs.enginePowerHp} PS / ${VehicleSpecs.engineTorqueNm} Nm',
            ),
            _buildDetailRow('Transmission', VehicleSpecs.transmission),
            _buildDetailRow(
              'System Output',
              '${VehicleSpecs.combinedPowerHp} PS / ${VehicleSpecs.combinedTorqueNm} Nm',
            ),
            _buildDetailRow(
              'Traction Battery',
              '${VehicleSpecs.batteryCapacityKwh} kWh High-Voltage Pack',
            ),
            _buildDetailRow(
              'Pure EV Range',
              'Up to ${VehicleSpecs.electricRangeNedcKm.toStringAsFixed(0)} km NEDC (~${VehicleSpecs.estimatedRealWorldElectricRangeKm.toStringAsFixed(0)} km WLTP)',
            ),
            _buildDetailRow('Charging Inlet', VehicleSpecs.chargingPort),
            _buildDetailRow(
              'Fuel Tank Capacity',
              '${VehicleSpecs.fuelTankCapacityLiters.toStringAsFixed(0)} Litres',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergySummaryCard(BuildContext context, dynamic energyState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ENERGY & FUEL RECORDS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/energy-calculator'),
                  child: const Text(
                    'Calculator & Logs',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    'Recorded Fuel',
                    '${energyState.totalFuelLiters.toStringAsFixed(1)} L',
                    Formatters.formatCurrency(energyState.totalFuelCostRm),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMiniStat(
                    'Recorded Charge',
                    '${energyState.totalChargedKwh.toStringAsFixed(1)} kWh',
                    Formatters.formatCurrency(energyState.totalChargingCostRm),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VERIFIED DOCUMENTATION STATUS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified, color: AppTheme.primaryTeal),
              title: const Text('Malaysian Owner\'s Guide & Hybrid Handbook'),
              subtitle: const Text(
                'Indexed into TiggoMate RAG knowledge engine.',
              ),
              trailing: const Chip(label: Text('ACTIVE')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal),
          ),
        ],
      ),
    );
  }
}
