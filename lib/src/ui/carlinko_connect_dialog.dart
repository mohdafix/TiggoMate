import 'package:flutter/material.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';

class CarlinkoConnectDialog extends StatefulWidget {
  final VehicleRepository repository;
  final String currentAccount;
  final VoidCallback onConnected;

  const CarlinkoConnectDialog({
    super.key,
    required this.repository,
    required this.currentAccount,
    required this.onConnected,
  });

  @override
  State<CarlinkoConnectDialog> createState() => _CarlinkoConnectDialogState();
}

class _CarlinkoConnectDialogState extends State<CarlinkoConnectDialog> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  String _region = carLinkoDefaultRegion;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _accountController.text = widget.currentAccount;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleUseMock() {
    if (widget.repository is AppVehicleRepository) {
      (widget.repository as AppVehicleRepository).useMockMode();
    } else {
      widget.repository.disconnect();
    }
    widget.onConnected();
    Navigator.of(context).pop();
  }

  Future<void> _handleConnect() async {
    final acc = _accountController.text.trim();
    final pwd = _passwordController.text;

    if (acc.isEmpty || pwd.isEmpty) {
      setState(() {
        _isError = true;
        _statusMessage = 'Please enter both CarLinko account and password.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = 'Connecting to Chery CarLinko cloud (Region: ${_region.toUpperCase()})...';
      _isError = false;
    });

    try {
      await widget.repository.connect(
        account: acc,
        password: pwd,
        region: _region,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Connected successfully! Vehicle telemetry synced.';
          _isError = false;
        });
        widget.onConnected();
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isError = true;
          if (e is CarLinkoException) {
            final isUnactivated = e.code == '10001' ||
                e.code == 'USER_NOT_FOUND' ||
                e.code == 'AUTH_FAILED';
            _statusMessage = isUnactivated
                ? 'Pre-Activation Notice: Account not active on CarLinko cloud yet. Authorised Chery centres activate telematics during the 1,000 km initial service. You can continue using Simulation Mode.'
                : 'CarLinko Cloud Error (${e.code ?? "failed"}): ${e.message}';
          } else {
            _statusMessage = 'Connection error: $e';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131922),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D2AA).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cell_tower, color: Color(0xFF00D2AA), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'CarLinko Telematics Cloud',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pre-Activation Notice Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D2AA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.verified_outlined, color: Color(0xFF00D2AA), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pre-Activation Mode Active: Chery CarLinko telematics is activated by your authorised Chery 3S/4S centre during the 1,000 km initial vehicle service. Until activation, TiggoMate runs in high-fidelity Simulation Mode.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF99F6E4), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Single Session Warning Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1B343).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1B343).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFF1B343), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Single Session Notice: Chery CarLinko permits only one active mobile session. Connecting live here may log out your official phone app.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFE5B56A), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account field
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: 'Account / Registered Phone Number',
                prefixIcon: Icon(Icons.person_outline, size: 20),
                hintText: '+60123456789',
              ),
            ),
            const SizedBox(height: 12),

            // Password field
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'CarLinko Password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Region Dropdown
            DropdownButtonFormField<String>(
              initialValue: _region,
              decoration: const InputDecoration(
                labelText: 'CarLinko Cloud Region',
                prefixIcon: Icon(Icons.public, size: 20),
              ),
              items: const [
                DropdownMenuItem(value: 'sea', child: Text('SEA (Malaysia & Thailand)')),
                DropdownMenuItem(value: 'ap', child: Text('Asia-Pacific (AP)')),
                DropdownMenuItem(value: 'me', child: Text('Middle East (ME)')),
                DropdownMenuItem(value: 'ru', child: Text('Eurasia (RU)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _region = val);
              },
            ),
            const SizedBox(height: 16),

            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isError
                      ? Colors.red.withValues(alpha: 0.12)
                      : const Color(0xFF00D2AA).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isError ? Colors.redAccent : const Color(0xFF00D2AA),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _handleUseMock,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00D2AA),
                    side: const BorderSide(color: Color(0xFF00D2AA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.speed, size: 16),
                  label: const Text('Use Simulation Mode'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _handleConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D2AA),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                            )
                          : const Icon(Icons.login, size: 18),
                      label: Text(_loading ? 'Connecting...' : 'Connect Cloud'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
