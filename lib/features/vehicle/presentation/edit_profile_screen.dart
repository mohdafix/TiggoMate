import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nicknameCtrl;
  late TextEditingController _regCtrl;
  late TextEditingController _odometerCtrl;
  late TextEditingController _tyreModelCtrl;
  late TextEditingController _tyreSizeCtrl;
  late TextEditingController _frontPressureCtrl;
  late TextEditingController _rearPressureCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _modeCtrl;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(vehicleProfileProvider);
    _nicknameCtrl = TextEditingController(text: profile.nickname);
    _regCtrl = TextEditingController(text: profile.registrationNumber);
    _odometerCtrl = TextEditingController(
      text: profile.currentOdometerKm.toStringAsFixed(0),
    );
    _tyreModelCtrl = TextEditingController(text: profile.tyreBrandAndModel);
    _tyreSizeCtrl = TextEditingController(text: profile.tyreSize);
    _frontPressureCtrl = TextEditingController(
      text: profile.recommendedFrontPressureKpa.toString(),
    );
    _rearPressureCtrl = TextEditingController(
      text: profile.recommendedRearPressureKpa.toString(),
    );
    _ownerNameCtrl = TextEditingController(text: profile.ownerName);
    _modeCtrl = TextEditingController(text: profile.preferredDrivingMode);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _regCtrl.dispose();
    _odometerCtrl.dispose();
    _tyreModelCtrl.dispose();
    _tyreSizeCtrl.dispose();
    _frontPressureCtrl.dispose();
    _rearPressureCtrl.dispose();
    _ownerNameCtrl.dispose();
    _modeCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final current = ref.read(vehicleProfileProvider);
    final odo =
        double.tryParse(_odometerCtrl.text) ?? current.currentOdometerKm;
    final fp =
        int.tryParse(_frontPressureCtrl.text) ??
        current.recommendedFrontPressureKpa;
    final rp =
        int.tryParse(_rearPressureCtrl.text) ??
        current.recommendedRearPressureKpa;

    final updated = current.copyWith(
      nickname: _nicknameCtrl.text.trim(),
      registrationNumber: _regCtrl.text.trim().toUpperCase(),
      currentOdometerKm: odo,
      tyreBrandAndModel: _tyreModelCtrl.text.trim(),
      tyreSize: _tyreSizeCtrl.text.trim(),
      recommendedFrontPressureKpa: fp,
      recommendedRearPressureKpa: rp,
      ownerName: _ownerNameCtrl.text.trim(),
      preferredDrivingMode: _modeCtrl.text.trim(),
    );

    ref.read(vehicleProfileProvider.notifier).updateProfile(updated);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vehicle profile updated successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Vehicle Profile'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
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
            const Text(
              'IDENTIFICATION & OWNERSHIP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nicknameCtrl,
              decoration: const InputDecoration(labelText: 'Vehicle Nickname'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _regCtrl,
              decoration: const InputDecoration(
                labelText: 'Registration Identifier (Plate No.)',
                hintText: 'e.g., VAB 7707',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerNameCtrl,
              decoration: const InputDecoration(labelText: 'Owner Name'),
            ),
            const SizedBox(height: 20),
            const Text(
              'ODOMETER & DRIVING SETTINGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _odometerCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Current Odometer (km)',
                suffixText: 'km',
              ),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d < 0) return 'Enter a valid positive mileage';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modeCtrl,
              decoration: const InputDecoration(
                labelText: 'Preferred Driving Mode',
                hintText: 'AUTO, EV, or HEV',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'TYRES & INFLATION PRESSURE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _tyreSizeCtrl,
              decoration: const InputDecoration(
                labelText: 'Tyre Specification',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tyreModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Fitted Tyre Brand/Model',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _frontPressureCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Front Pressure (kPa)',
                      suffixText: 'kPa',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rearPressureCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rear Pressure (kPa)',
                      suffixText: 'kPa',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Save Changes'),
              onPressed: _saveProfile,
            ),
          ],
        ),
      ),
    );
  }
}
