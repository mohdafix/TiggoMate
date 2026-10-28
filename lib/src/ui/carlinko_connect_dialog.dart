import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../theme/app_tokens.dart';

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

  void _handleUseMock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tm_carlinko_status', 'Demo');
    } catch (_) {}

    if (widget.repository is AppVehicleRepository) {
      (widget.repository as AppVehicleRepository).useMockMode();
    } else {
      widget.repository.disconnect();
    }
    widget.onConnected();
    if (mounted) Navigator.of(context).pop();
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

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tm_carlinko_status', 'Active');
        await prefs.setString('tm_carlinko_account', acc);
      } catch (_) {}

      if (mounted) {
        final isPreActivation = (widget.repository is AppVehicleRepository &&
                (widget.repository as AppVehicleRepository).isPreActivation) ||
            (widget.repository is LiveCarLinkoRepository &&
                (widget.repository as LiveCarLinkoRepository).isPreActivation);

        setState(() {
          _loading = false;
          _isError = false;
          _statusMessage = isPreActivation
              ? 'Connected to CarLinko Cloud! Pre-Activation mode is active — telematics will auto-pair once your Chery 3S/4S centre links your VIN.'
              : 'Connected successfully! Vehicle telemetry synced.';
        });
        widget.onConnected();
        Future.delayed(const Duration(milliseconds: 1400), () {
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
    final t = context.tokens;

    return Dialog(
      backgroundColor: const Color(0xFF131922),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.cell_tower, color: t.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CarLinko Telematics Cloud',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pre-Activation Notice Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_outlined, color: t.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pre-Activation Mode Active: Chery CarLinko telematics is activated by your authorised Chery 3S/4S centre during the 1,000 km initial vehicle service. Until activation, TiggoMate runs in high-fidelity Simulation Mode.',
                      style: TextStyle(fontSize: 11, color: t.accent.withValues(alpha: 0.9), height: 1.35),
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
                hintText: '+60123456789 or email',
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
              isExpanded: true,
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
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError
                      ? Colors.red.withValues(alpha: 0.12)
                      : t.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isError
                        ? Colors.red.withValues(alpha: 0.3)
                        : t.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isError ? Icons.error_outline : Icons.check_circle_outline,
                      size: 18,
                      color: _isError ? Colors.redAccent : t.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isError ? Colors.redAccent : t.accent,
                          height: 1.35,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _handleConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _loading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: t.onAccent),
                      )
                    : const Icon(Icons.cloud_sync_rounded, size: 18),
                label: Text(
                  _loading ? 'Connecting...' : 'Connect Cloud',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _handleUseMock,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.ink2,
                      side: BorderSide(color: t.border),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.speed, size: 16),
                    label: const Text('Use Simulation Mode', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
