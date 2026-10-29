import 'package:flutter/material.dart';
import '../mytnb/mytnb_api.dart';

class MyTnbConnectDialog extends StatefulWidget {
  final MyTnbRepository repository;
  final double currentTariff;
  final void Function(double updatedTariff, MyTnbAccount? account) onTariffUpdated;
  final bool showDemoMode;

  const MyTnbConnectDialog({
    super.key,
    required this.repository,
    required this.currentTariff,
    required this.onTariffUpdated,
    this.showDemoMode = false,
  });

  @override
  State<MyTnbConnectDialog> createState() => _MyTnbConnectDialogState();
}

class _MyTnbConnectDialogState extends State<MyTnbConnectDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final session = widget.repository.sessionNotifier.value;
    if (session != null) {
      _emailController.text = session.email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({bool isDemo = false}) async {
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;

    if (!isDemo && (email.isEmpty || pwd.isEmpty)) {
      setState(() {
        _errorMessage = 'Please enter both your myTNB email and password.';
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = isDemo
          ? 'Connecting to Demo Smart Meter (Bandar Baru Bangi)...'
          : 'Connecting to myTNB authentication servers...';
    });

    try {
      final account = await widget.repository.login(
        email: isDemo ? 'demo@mytnb.com.my' : email,
        password: isDemo ? 'demo' : pwd,
        isDemo: isDemo,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Connected! Smart Meter readings synced.';
        });

        if (account != null) {
          widget.onTariffUpdated(account.effectiveTariff, account);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          if (e is MyTnbGeoBlockedException) {
            _errorMessage = e.message;
          } else if (e is MyTnbAuthException) {
            _errorMessage = e.message;
          } else {
            _errorMessage = 'Connection error: $e. Please verify your credentials and network connection.';
          }
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Refreshing smart meter telemetry...';
    });

    try {
      final account = await widget.repository.refreshReading();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Smart Meter telemetry up to date!';
        });
        if (account != null) {
          widget.onTariffUpdated(account.effectiveTariff, account);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
          _errorMessage = 'Failed to refresh: $e';
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await widget.repository.logout();
    if (mounted) {
      setState(() {
        _statusMessage = 'Disconnected from myTNB.';
      });
      widget.onTariffUpdated(0.57, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131922) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ValueListenableBuilder<MyTnbAccount?>(
        valueListenable: widget.repository.selectedAccountNotifier,
        builder: (context, account, _) {
          final session = widget.repository.sessionNotifier.value;
          final isLoggedIn = session != null && account != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.bolt, color: Color(0xFFFF5252), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'myTNB Smart Meter',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            isLoggedIn ? 'Live Credential Sync Active' : 'Direct Credential Sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLoggedIn
                                  ? const Color(0xFF00D2AA)
                                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (isLoggedIn)
                  _buildConnectedView(account, session, isDark)
                else
                  _buildLoginForm(isDark),

                // Status Message / Error Banner
                if (_statusMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2AA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00D2AA).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF00D2AA), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF00D2AA)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF85149).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF85149).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFF85149), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFF85149)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectedView(MyTnbAccount account, MyTnbSession session, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linked Account Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1219) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: account.isSmartMeter
                  ? const Color(0xFF00D2AA).withValues(alpha: 0.3)
                  : (isDark ? const Color(0xFF232D3D) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      account.accountDesc.isNotEmpty ? account.accountDesc : 'TNB Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: account.isSmartMeter
                          ? const Color(0xFF00D2AA).withValues(alpha: 0.2)
                          : (isDark ? Colors.white12 : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: account.isSmartMeter
                            ? const Color(0xFF00D2AA)
                            : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          account.isSmartMeter ? Icons.sensors : Icons.speed,
                          size: 11,
                          color: account.isSmartMeter
                              ? const Color(0xFF00D2AA)
                              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          account.isSmartMeter ? 'SMART METER' : 'STANDARD METER',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: account.isSmartMeter
                                ? const Color(0xFF00D2AA)
                                : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'CA No: ${account.accountNumber} • ${account.ownerName}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              if (account.address.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  account.address,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Telemetry Grid
        Row(
          children: [
            Expanded(
              child: _buildTelemetryStat(
                'MONTH CONSUMPTION',
                '${account.currentUsageKwh.toStringAsFixed(1)} kWh',
                Icons.electric_bolt,
                const Color(0xFF00D2AA),
                isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTelemetryStat(
                'CURRENT BILL',
                'RM ${account.currentCharges.toStringAsFixed(2)}',
                Icons.receipt_long,
                const Color(0xFFFF9F1C),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTelemetryStat(
                'EFFECTIVE TARIFF',
                'RM ${account.effectiveTariff.toStringAsFixed(3)}/kWh',
                Icons.analytics_outlined,
                const Color(0xFF58A6FF),
                isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTelemetryStat(
                'PROJECTED BILL',
                'RM ${account.projectedCostRm.toStringAsFixed(2)}',
                Icons.trending_up,
                isDark ? Colors.white70 : const Color(0xFF475569),
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Reading timestamp pill
        Row(
          children: [
            Icon(Icons.access_time, size: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Telemetry: ${account.lastReadingTime}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ),
            if (account.isDemo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('DEMO MODE', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 18),

        // Apply Tariff Button
        ElevatedButton.icon(
          onPressed: () {
            widget.onTariffUpdated(account.effectiveTariff, account);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.check, color: Colors.black87, size: 18),
          label: Text(
            'Apply Live Tariff (RM ${account.effectiveTariff.toStringAsFixed(3)}/kWh)',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D2AA),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),

        // Refresh & Disconnect Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleRefresh,
                icon: Icon(
                  Icons.refresh,
                  size: 16,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
                label: Text(
                  'Refresh',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? const Color(0xFF232D3D) : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleLogout,
                icon: const Icon(Icons.logout, size: 16, color: Color(0xFFF85149)),
                label: const Text('Sign Out', style: TextStyle(color: Color(0xFFF85149), fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? const Color(0xFF232D3D) : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryStat(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1219) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF232D3D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.5,
                  color: isDark ? Colors.white38 : const Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign in with your myTNB account (from www.mytnb.com.my or the myTNB mobile app) to automatically link your smart meter readings and domestic tariff tier.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Email Field
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'myTNB Email Address',
            labelStyle: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.email_outlined,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              size: 18,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0D1219) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF232D3D) : const Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF00D2AA)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Password Field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'myTNB Password',
            labelStyle: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              size: 18,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF0D1219) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF232D3D) : const Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF00D2AA)),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Connect Button
        ElevatedButton(
          onPressed: _isLoading ? null : () => _handleLogin(isDemo: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D2AA),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
              : const Text('Direct myTNB Sign In', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        if (widget.showDemoMode) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : () => _handleLogin(isDemo: true),
            icon: const Icon(Icons.smart_toy_outlined, color: Color(0xFF58A6FF), size: 16),
            label: const Text('Use Demo Smart Meter (Test Mode)', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              side: BorderSide(
                color: isDark ? const Color(0xFF232D3D) : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Security Footnote
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 13, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Direct SSL handshake with myTNB servers. Your credentials are sent directly to myTNB authentication endpoints and are never stored on external cloud servers.',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
