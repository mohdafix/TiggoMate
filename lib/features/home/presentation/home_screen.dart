import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/assistant_message.dart';
import '../../../data/models/telemetry.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vehicleProfileProvider);
    final telemetryAsync = ref.watch(vehicleTelemetryStreamProvider);
    final maintenanceState = ref.watch(maintenanceStateProvider);
    final chatState = ref.watch(chatProvider);

    final nextDue = maintenanceState.calculateNextServiceDue(
      profile.currentOdometerKm,
      profile.purchaseDate,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.nickname,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '${profile.manufacturer} ${profile.model} (${profile.market})',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Privacy',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: telemetryAsync.when(
        data: (telemetry) => _buildDashboardContent(
          context,
          ref,
          profile,
          telemetry,
          nextDue,
          chatState,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Error loading vehicle telemetry: $err')),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    dynamic profile,
    VehicleTelemetry telemetry,
    Map<String, dynamic> nextDue,
    dynamic chatState,
  ) {
    final isSimulated = telemetry.isSimulatedModeActive;
    final isBatteryAvailable = telemetry.batteryPercentage.isAvailable;
    final isFuelAvailable = telemetry.fuelPercentage.isAvailable;

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh connection status
        ref.invalidate(vehicleConnectionStatusProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Connection & Simulation Banner
          _buildConnectionStatusBanner(context, ref, telemetry, isSimulated),

          const SizedBox(height: 14),

          // Primary Vehicle Gauge & Reading Card
          _buildTelemetryCard(
            context,
            profile,
            telemetry,
            isBatteryAvailable,
            isFuelAvailable,
            isSimulated,
          ),

          const SizedBox(height: 16),

          // Quick Actions Grid
          _buildQuickActions(context, ref),

          const SizedBox(height: 16),

          // Next Service Due Reminder Card
          _buildNextServiceCard(context, nextDue),

          const SizedBox(height: 16),

          // Recent Assistant Conversations
          _buildRecentAssistantSection(context, ref, chatState),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBanner(
    BuildContext context,
    WidgetRef ref,
    VehicleTelemetry telemetry,
    bool isSimulated,
  ) {
    if (isSimulated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.statusSimulated.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.statusSimulated, width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.statusSimulated,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'SIMULATED DATA ACTIVE',
                    style: TextStyle(
                      color: AppTheme.statusSimulated,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Showing mock telemetry for development & UI preview.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(vehicleProfileProvider.notifier)
                    .setSimulatedMode(false);
              },
              child: const Text('Turn Off', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppTheme.statusDisconnected,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CARLINKO: NOT ACTIVATED',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  telemetry.connectionStatusText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            onPressed: () => context.push('/my-car'),
            child: const Text('Details', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard(
    BuildContext context,
    dynamic profile,
    VehicleTelemetry telemetry,
    bool isBatteryAvailable,
    bool isFuelAvailable,
    bool isSimulated,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LAST-KNOWN ODOMETER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatDistance(profile.currentOdometerKm),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    profile.registrationNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTeal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // Battery & Fuel Section
            if (!isBatteryAvailable && !isFuelAvailable) ...[
              // Honest Empty State
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 36,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Live Readings Unavailable',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Battery SOC and petrol level will populate once CarLinko is activated at your 1,000 km service.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Live or Explicitly Simulated Gauges
              Row(
                children: [
                  // Battery Gauge
                  Expanded(
                    child: _buildGaugeItem(
                      icon: Icons.battery_charging_full_rounded,
                      label: 'TRACTION BATTERY',
                      value:
                          '${telemetry.batteryPercentage.value?.toStringAsFixed(0)}%',
                      subtext: telemetry.estimatedElectricRangeKm.isAvailable
                          ? 'Est. ${telemetry.estimatedElectricRangeKm.value?.toStringAsFixed(0)} km EV'
                          : '19.27 kWh Pack',
                      accentColor: AppTheme.primaryTeal,
                      fraction:
                          (telemetry.batteryPercentage.value ?? 0) / 100.0,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Fuel Gauge
                  Expanded(
                    child: _buildGaugeItem(
                      icon: Icons.local_gas_station_rounded,
                      label: 'PETROL LEVEL',
                      value:
                          '${telemetry.fuelPercentage.value?.toStringAsFixed(0)}%',
                      subtext: telemetry.estimatedTotalRangeKm.isAvailable
                          ? 'Est. ${telemetry.estimatedTotalRangeKm.value?.toStringAsFixed(0)} km Total'
                          : '51L Tank',
                      accentColor: Colors.amber,
                      fraction: (telemetry.fuelPercentage.value ?? 0) / 100.0,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeItem({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color accentColor,
    required double fraction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF334155),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtext,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.smart_toy_rounded,
                label: 'Ask AI',
                onTap: () => context.go('/assistant'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.speed_rounded,
                label: 'Record Odo',
                onTap: () => _showRecordOdometerDialog(context, ref),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.local_gas_station_rounded,
                label: 'Add Fuel',
                onTap: () => _showAddFuelDialog(context, ref),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.ev_station_rounded,
                label: 'Add Charge',
                onTap: () => _showAddChargeDialog(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.elevatedCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primaryTeal, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextServiceCard(
    BuildContext context,
    Map<String, dynamic> nextDue,
  ) {
    final remainingKm = (nextDue['remainingKm'] as num).toDouble();
    final isFirst = nextDue['isFirstMilestone'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFirst
                      ? Icons.verified_user_outlined
                      : Icons.build_circle_outlined,
                  color: AppTheme.accentCyan,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextDue['serviceName'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Milestone',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    Text(
                      Formatters.formatDistance(
                        (nextDue['targetKm'] as num).toDouble(),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Remaining',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    Text(
                      '${remainingKm.toStringAsFixed(0)} km',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: remainingKm <= 150
                            ? AppTheme.statusWarning
                            : AppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isFirst) ...[
              const SizedBox(height: 8),
              const Text(
                'Includes dealer onboarding & activation of your CarLinko telematics SIM.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAssistantSection(
    BuildContext context,
    WidgetRef ref,
    dynamic chatState,
  ) {
    final messages = chatState.session.messages as List<AssistantMessage>;
    final recentUserMsg = messages.reversed
        .where((m) => m.role == MessageRole.user)
        .firstOrNull;

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
                  'AI ASSISTANT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/assistant'),
                  child: const Text(
                    'Open Chat',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (recentUserMsg != null) ...[
              Text(
                'Recent: "${recentUserMsg.content}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ] else ...[
              const Text(
                'Ask anything about your Tiggo 7 PHEV driving modes, battery, or service.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text(
                    'AUTO Mode?',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    context.go('/assistant');
                    ref
                        .read(chatProvider.notifier)
                        .sendUserQuery('What does AUTO mode do?');
                  },
                ),
                ActionChip(
                  label: const Text(
                    'Cost for 100 km?',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    context.go('/assistant');
                    ref
                        .read(chatProvider.notifier)
                        .sendUserQuery(
                          'How much does it cost to drive 100 km using electricity versus petrol?',
                        );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Quick Action Dialogs ----------------
  void _showRecordOdometerDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(vehicleProfileProvider).currentOdometerKm;
    final controller = TextEditingController(text: current.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Odometer Reading'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Current Odometer (km)',
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= current) {
                ref.read(vehicleProfileProvider.notifier).updateOdometer(val);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated odometer to $val km')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddFuelDialog(BuildContext context, WidgetRef ref) {
    final litersCtrl = TextEditingController(text: '35.0');
    final priceCtrl = TextEditingController(text: '2.05');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Petrol Fill-up Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: litersCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Fuel Volume (Litres)',
                suffixText: 'L',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price Per Litre (RM)',
                prefixText: 'RM ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final l = double.tryParse(litersCtrl.text);
              final p = double.tryParse(priceCtrl.text);
              if (l != null && p != null) {
                ref.read(toolRegistryProvider).recordFuelEntry({
                  'liters': l,
                  'pricePerLiter': p,
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Recorded $l L fill-up (RM ${(l * p).toStringAsFixed(2)})',
                    ),
                  ),
                );
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _showAddChargeDialog(BuildContext context, WidgetRef ref) {
    final kwhCtrl = TextEditingController(text: '15.4');
    final tariffCtrl = TextEditingController(text: '0.516');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record AC Charging Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kwhCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Energy Charged (kWh)',
                suffixText: 'kWh',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tariffCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Electricity Tariff (RM / kWh)',
                prefixText: 'RM ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final kwh = double.tryParse(kwhCtrl.text);
              final t = double.tryParse(tariffCtrl.text);
              if (kwh != null && t != null) {
                ref.read(toolRegistryProvider).recordChargingSession({
                  'energyKwh': kwh,
                  'tariffPerKwh': t,
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Recorded $kwh kWh charge (RM ${(kwh * t).toStringAsFixed(2)})',
                    ),
                  ),
                );
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }
}
