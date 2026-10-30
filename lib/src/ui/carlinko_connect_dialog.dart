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
  bool _syncing = false;
  String? _statusMessage;
  bool _isError = false;
  late bool _showLoginForm;

  @override
  void initState() {
    super.initState();
    _showLoginForm = !widget.repository.isCloudConnected;
    _accountController.text = widget.currentAccount;
    _loadSavedAccount();
  }

  Future<void> _loadSavedAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('tm_carlinko_account');
      if (saved != null && saved.isNotEmpty && mounted) {
        if (_accountController.text.isEmpty || _accountController.text == 'Chery Owner') {
          setState(() {
            _accountController.text = saved;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDisconnect() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tm_carlinko_status', 'Unactivated');
      await widget.repository.disconnect();
      if (mounted) {
        setState(() {
          _loading = false;
          _showLoginForm = true;
          _statusMessage = 'Disconnected from CarLinko Cloud.';
          _isError = false;
        });
        widget.onConnected();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Disconnect failed: $e';
          _isError = true;
        });
      }
    }
  }

  Future<void> _handleRefreshSync() async {
    setState(() => _syncing = true);
    try {
      await widget.repository.refresh();
      if (mounted) {
        setState(() {
          _syncing = false;
          _statusMessage = 'Cloud telemetry refreshed successfully!';
          _isError = false;
        });
        widget.onConnected();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _syncing = false;
          _statusMessage = 'Sync failed: $e';
          _isError = true;
        });
      }
    }
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
        setState(() {
          _loading = false;
          _isError = false;
          _showLoginForm = false;
          _statusMessage = widget.repository.isPreActivationMode
              ? 'Connected to CarLinko Cloud! Pending Car Bind (Awaiting 3S/4S Pairing).'
              : 'Connected successfully! Vehicle telemetry synced.';
        });
        widget.onConnected();
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
                ? 'Pre-Activation Notice: Account not active on CarLinko cloud yet. Authorised Chery centres activate telematics during vehicle handover or 1,000 km service.'
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = widget.repository.isCloudConnected;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF12141A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: isConnected && !_showLoginForm
            ? _buildConnectedView(t, isDark)
            : _buildLoginView(t, isDark),
      ),
    );
  }

  Widget _buildConnectedView(AppTokens t, bool isDark) {
    final accountName = widget.repository.connectedAccount ??
        (_accountController.text.isNotEmpty ? _accountController.text : 'Chery Owner');
    final isPreActivation = widget.repository.isPreActivationMode;
    final telemetry = widget.repository.currentTelemetry;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.ok.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.ok.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.cloud_done_rounded, color: t.ok, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CarLinko Telematics Cloud',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: t.ink),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'SESSION CONNECTED & ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: t.ok,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Session Details Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                icon: Icons.account_circle_outlined,
                label: 'Cloud Account',
                value: accountName,
                accentColor: const Color(0xFFD2F835),
                isDark: isDark,
              ),
              Divider(height: 18, color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0)),
              _buildDetailRow(
                icon: Icons.public,
                label: 'Region Gateway',
                value: 'SEA (Malaysia & Thailand)',
                accentColor: isDark ? t.ink2 : const Color(0xFF475569),
                isDark: isDark,
              ),
              Divider(height: 18, color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0)),
              _buildDetailRow(
                icon: Icons.cell_tower,
                label: 'Telematics Pipeline',
                value: isPreActivation
                    ? 'Pending Car Bind (Pairing Required)'
                    : 'Live CAN-Bus Sync',
                accentColor: isPreActivation
                    ? const Color(0xFFFF6E40)
                    : const Color(0xFFD2F835),
                isDark: isDark,
              ),
              Divider(height: 18, color: isDark ? const Color(0xFF1E222B) : const Color(0xFFE2E8F0)),
              _buildDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Last Sync',
                value: telemetry.isBound
                    ? 'Active (${telemetry.lastUpdated.hour.toString().padLeft(2, '0')}:${telemetry.lastUpdated.minute.toString().padLeft(2, '0')})'
                    : 'Awaiting Vehicle Binding',
                accentColor: isDark ? t.ink2 : const Color(0xFF475569),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Pre-Activation Mode Notice
        if (isPreActivation)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFF6E40).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFFF6E40),
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Pending Car Bind: Your CarLinko account is verified. Live CAN-bus telematics and vehicle remote controls will automatically stream once your Chery centre completes vehicle VIN pairing.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF6E40),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        if (_statusMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isError ? Colors.red.withValues(alpha: 0.12) : const Color(0xFFD2F835).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isError ? Colors.red.withValues(alpha: 0.3) : const Color(0xFFD2F835).withValues(alpha: 0.3)),
            ),
            child: Text(
              _statusMessage!,
              style: TextStyle(fontSize: 11.5, color: _isError ? Colors.redAccent : const Color(0xFFD2F835)),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Action Buttons for Connected State
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _syncing ? null : _handleRefreshSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD2F835),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.sync_rounded, size: 18, color: Colors.black),
            label: Text(
              _syncing ? 'SYNCING CHERY CLOUD...' : 'REFRESH CLOUD SYNC',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showLoginForm = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? t.ink2 : const Color(0xFF334155),
                  side: BorderSide(color: isDark ? const Color(0xFF1E222B) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                label: const Text('Switch Account', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _handleDisconnect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF453A),
                  side: BorderSide(color: const Color(0xFFFF453A).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Disconnect', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginView(AppTokens t, bool isDark) {
    return Column(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CarLinko Telematics Cloud',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sign in with your Chery CarLinko credentials',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pre-Activation Notice Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: isDark ? 0.08 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.accent.withValues(alpha: isDark ? 0.25 : 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined, color: t.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chery CarLinko Cloud Standby: Connect with your official CarLinko account. Once your dealer binds the vehicle VIN, live telematics and remote controls automatically sync in real time.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? t.accent.withValues(alpha: 0.9) : const Color(0xFF0F766E),
                    height: 1.35,
                  ),
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
            color: isDark ? const Color(0xFFF1B343).withValues(alpha: 0.1) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFFF1B343).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: isDark ? const Color(0xFFF1B343) : const Color(0xFFB45309),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Single Session Notice: Chery CarLinko permits only one active mobile session. Connecting live here may log out your official phone app.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFFE5B56A) : const Color(0xFF92400E),
                    height: 1.35,
                  ),
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
            labelText: 'CarLinko Account / Registered Email or Phone',
            prefixIcon: Icon(Icons.person_outline, size: 20),
            hintText: 'e.g. linexsg@gmail.com',
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
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _handleConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD2F835),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.cloud_sync_rounded, size: 18, color: Colors.black),
            label: Text(
              _loading ? 'CONNECTING...' : 'BIND CARLINKO CLOUD',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }
}
