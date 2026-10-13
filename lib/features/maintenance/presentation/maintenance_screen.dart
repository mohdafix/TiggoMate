import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/maintenance_record.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vehicleProfileProvider);
    final maintenanceState = ref.watch(maintenanceStateProvider);
    final nextDue = maintenanceState.calculateNextServiceDue(
      profile.currentOdometerKm,
      profile.purchaseDate,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance & Service'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Configure Intervals',
            onPressed: () => _showConfigureIntervalsDialog(
              context,
              ref,
              maintenanceState.intervalKm,
              maintenanceState.intervalMonths,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Service'),
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.black,
        onPressed: () => context.push('/add-service'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Next Service Due Banner
          _buildNextDueBanner(context, nextDue),

          const SizedBox(height: 16),

          // Total Service Cost & Stats
          _buildCostSummary(context, maintenanceState),

          const SizedBox(height: 16),

          // Road Tax & Insurance Expiry
          _buildRegulatoryExpiryCard(
            context,
            ref,
            maintenanceState.regulatoryExpiry,
          ),

          const SizedBox(height: 16),

          // Tyre Rotation & Replacement History
          _buildTyreMaintenanceSection(context, ref, maintenanceState),

          const SizedBox(height: 16),

          // Service History Log
          _buildServiceHistorySection(context, maintenanceState),

          const SizedBox(height: 80), // Padding for FAB
        ],
      ),
    );
  }

  Widget _buildNextDueBanner(
    BuildContext context,
    Map<String, dynamic> nextDue,
  ) {
    final remainingKm = (nextDue['remainingKm'] as num).toDouble();
    final isFirst = nextDue['isFirstMilestone'] as bool? ?? false;
    final dueDate = nextDue['dueDate'] as DateTime?;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.elevatedCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: remainingKm <= 150
              ? AppTheme.statusWarning
              : AppTheme.primaryTeal,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFirst ? Icons.stars_rounded : Icons.schedule_rounded,
                color: remainingKm <= 150
                    ? AppTheme.statusWarning
                    : AppTheme.primaryTeal,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nextDue['serviceName'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Target Milestone',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    Formatters.formatDistance(
                      (nextDue['targetKm'] as num).toDouble(),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
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
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    '${remainingKm.toStringAsFixed(0)} km',
                    style: TextStyle(
                      fontSize: 18,
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
          if (dueDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Estimated due by: ${Formatters.formatDate(dueDate)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
          if (isFirst) ...[
            const Divider(height: 20),
            const Text(
              '⚠️ Critical: Dealers activate the vehicle 4G telematics SIM during this visit. Ask your service advisor to confirm CarLinko activation.',
              style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostSummary(BuildContext context, MaintenanceState state) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCarbon,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL SERVICE SPENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatCurrency(state.totalServiceCostRm),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCarbon,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPLETED SERVICES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.serviceRecords.length} Records',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegulatoryExpiryCard(
    BuildContext context,
    WidgetRef ref,
    RegulatoryExpiry expiry,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'ROAD TAX & INSURANCE EXPIRY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  tooltip: 'Update Expiry Dates',
                  onPressed: () =>
                      _showUpdateExpiryDialog(context, ref, expiry),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Road Tax Expiry',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        expiry.roadTaxExpiry != null
                            ? Formatters.formatDate(expiry.roadTaxExpiry!)
                            : 'Not Recorded',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Insurance Expiry',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        expiry.insuranceExpiry != null
                            ? Formatters.formatDate(expiry.insuranceExpiry!)
                            : 'Not Recorded',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTyreMaintenanceSection(
    BuildContext context,
    WidgetRef ref,
    MaintenanceState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'TYRE ROTATION & ALIGNMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add Entry',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _showAddTyreRecordDialog(context, ref),
                ),
              ],
            ),
            if (state.tyreRecords.isEmpty) ...[
              const Text(
                'No tyre rotations logged. Recommended every 10,000 km.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ] else ...[
              ...state.tyreRecords.map((t) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tire_repair, size: 20),
                  title: Text(
                    '${t.action} at ${Formatters.formatDistance(t.mileageKm)}',
                  ),
                  subtitle: Text(
                    '${Formatters.formatDate(t.date)} • ${t.details}',
                  ),
                  trailing: t.costRm > 0
                      ? Text(Formatters.formatCurrency(t.costRm))
                      : null,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceHistorySection(
    BuildContext context,
    MaintenanceState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SERVICE HISTORY LOG',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        if (state.serviceRecords.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCarbon,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Center(
              child: Text(
                'No service records recorded yet.\nTap "Add Service" below when you complete your 1,000 km inspection.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ] else ...[
          ...state.serviceRecords.map((record) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          record.serviceType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(record.costRm),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Formatters.formatDate(record.date)} • ${Formatters.formatDistance(record.mileageKm)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      record.workshopName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    if (record.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        record.notes,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                    if (record.isCarLinkoActivated) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CarLinko eSIM Activated',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  void _showConfigureIntervalsDialog(
    BuildContext context,
    WidgetRef ref,
    int currentKm,
    int currentMonths,
  ) {
    final kmCtrl = TextEditingController(text: currentKm.toString());
    final moCtrl = TextEditingController(text: currentMonths.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure Service Intervals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Distance Interval (km)',
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: moCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Time Interval (Months)',
                suffixText: 'Months',
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
              final k = int.tryParse(kmCtrl.text);
              final m = int.tryParse(moCtrl.text);
              if (k != null && m != null) {
                ref
                    .read(maintenanceStateProvider.notifier)
                    .updateIntervals(k, m);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUpdateExpiryDialog(
    BuildContext context,
    WidgetRef ref,
    RegulatoryExpiry current,
  ) {
    DateTime roadTax =
        current.roadTaxExpiry ?? DateTime.now().add(const Duration(days: 365));
    DateTime ins =
        current.insuranceExpiry ??
        DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Regulatory Expiry Dates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Road Tax Expiry'),
                subtitle: Text(Formatters.formatDate(roadTax)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: roadTax,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => roadTax = picked);
                },
              ),
              ListTile(
                title: const Text('Insurance Expiry'),
                subtitle: Text(Formatters.formatDate(ins)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: ins,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => ins = picked);
                },
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
                ref
                    .read(maintenanceStateProvider.notifier)
                    .updateRegulatoryExpiry(
                      RegulatoryExpiry(
                        roadTaxExpiry: roadTax,
                        insuranceExpiry: ins,
                      ),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTyreRecordDialog(BuildContext context, WidgetRef ref) {
    final actionCtrl = TextEditingController(text: 'Tyre Rotation');
    final detailsCtrl = TextEditingController(
      text: 'Rotated front to rear cross',
    );
    final currentOdo = ref.read(vehicleProfileProvider).currentOdometerKm;
    final odoCtrl = TextEditingController(text: currentOdo.toStringAsFixed(0));
    final costCtrl = TextEditingController(text: '30.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Tyre Maintenance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: actionCtrl,
              decoration: const InputDecoration(
                labelText: 'Action (e.g. Rotation, Alignment)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: odoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mileage (km)',
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsCtrl,
              decoration: const InputDecoration(labelText: 'Details / Notes'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cost (RM)',
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
              final odo = double.tryParse(odoCtrl.text) ?? currentOdo;
              final cost = double.tryParse(costCtrl.text) ?? 0.0;
              ref
                  .read(maintenanceStateProvider.notifier)
                  .addTyreRecord(
                    TyreRecord(
                      id: const Uuid().v4(),
                      date: DateTime.now(),
                      mileageKm: odo,
                      action: actionCtrl.text.trim(),
                      details: detailsCtrl.text.trim(),
                      costRm: cost,
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
