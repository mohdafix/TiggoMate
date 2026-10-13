import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../data/models/maintenance_record.dart';

class AddServiceScreen extends ConsumerStatefulWidget {
  const AddServiceScreen({super.key});

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _mileageCtrl;
  late TextEditingController _typeCtrl;
  late TextEditingController _workshopCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _invoiceCtrl;
  bool _isCarLinkoActivated = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(vehicleProfileProvider);
    _mileageCtrl = TextEditingController(
      text: profile.currentOdometerKm.toStringAsFixed(0),
    );
    _typeCtrl = TextEditingController(text: '1,000 km Initial Inspection');
    _workshopCtrl = TextEditingController(
      text: 'Chery Authorized Service Centre',
    );
    _costCtrl = TextEditingController(text: '0.00');
    _notesCtrl = TextEditingController();
    _invoiceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _mileageCtrl.dispose();
    _typeCtrl.dispose();
    _workshopCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    _invoiceCtrl.dispose();
    super.dispose();
  }

  void _saveRecord() {
    if (!_formKey.currentState!.validate()) return;

    final mileage = double.tryParse(_mileageCtrl.text) ?? 1000.0;
    final cost = double.tryParse(_costCtrl.text) ?? 0.0;

    final record = ServiceRecord(
      id: _uuid.v4(),
      date: DateTime.now(),
      mileageKm: mileage,
      serviceType: _typeCtrl.text.trim(),
      workshopName: _workshopCtrl.text.trim(),
      costRm: cost,
      notes: _notesCtrl.text.trim(),
      invoiceNumber: _invoiceCtrl.text.trim().isNotEmpty
          ? _invoiceCtrl.text.trim()
          : null,
      isCarLinkoActivated: _isCarLinkoActivated,
    );

    ref.read(maintenanceStateProvider.notifier).addServiceRecord(record);

    // If mileage entered is greater than current odo, update current odometer
    final currentOdo = ref.read(vehicleProfileProvider).currentOdometerKm;
    if (mileage > currentOdo) {
      ref.read(vehicleProfileProvider.notifier).updateOdometer(mileage);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service record added successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Service Record'),
        actions: [
          TextButton(
            onPressed: _saveRecord,
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _typeCtrl,
              decoration: const InputDecoration(
                labelText: 'Service Type / Description',
                hintText: 'e.g. 1,000 km Inspection, 10,000 km Oil Change',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mileageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Odometer at Service (km)',
                suffixText: 'km',
              ),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d < 0) return 'Valid mileage required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _workshopCtrl,
              decoration: const InputDecoration(
                labelText: 'Workshop / Chery Service Center',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Service Cost (RM)',
                prefixText: 'RM ',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _invoiceCtrl,
              decoration: const InputDecoration(
                labelText: 'Invoice / Job Sheet Number',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes / Items Checked',
                hintText: 'e.g. Engine oil replaced, hybrid coolant inspected',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('CarLinko Activated During This Service?'),
              subtitle: const Text(
                'Check this if dealer completed telematics SIM registration.',
              ),
              value: _isCarLinkoActivated,
              onChanged: (val) {
                setState(() => _isCarLinkoActivated = val);
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Record Service'),
              onPressed: _saveRecord,
            ),
          ],
        ),
      ),
    );
  }
}
