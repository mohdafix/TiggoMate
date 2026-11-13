import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../carlinko/carlinko_api.dart';
import '../carlinko/vehicle_repository.dart';
import '../theme/app_theme.dart';

/// Interactive Remote Opcode Diagnostics & Live Tester Sheet.
/// Enables Tiggo 7 PHEV owners to fire candidate CAN-bus opcodes,
/// inspect live Chery T-Box response codes, and verify actuation.
class RemoteCommandDiagnosticsSheet extends StatefulWidget {
  final VehicleRepository repository;

  const RemoteCommandDiagnosticsSheet({
    super.key,
    required this.repository,
  });

  static Future<void> show(BuildContext context, {required VehicleRepository repository}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RemoteCommandDiagnosticsSheet(repository: repository),
    );
  }

  @override
  State<RemoteCommandDiagnosticsSheet> createState() => _RemoteCommandDiagnosticsSheetState();
}

class _LogEntry {
  final DateTime time;
  final String label;
  final String opcode;
  final RemoteCommandResult result;

  _LogEntry({
    required this.time,
    required this.label,
    required this.opcode,
    required this.result,
  });
}

class _RemoteCommandDiagnosticsSheetState extends State<RemoteCommandDiagnosticsSheet> {
  final TextEditingController _customHexController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();
  final List<_LogEntry> _logs = [];

  bool _sendWakeupHandshake = true;
  bool _send0x23Init = false;
  bool _isSending = false;
  String? _activeOpcode;

  @override
  void dispose() {
    _customHexController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _fireOpcode(String opcode, String label) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _activeOpcode = opcode;
    });

    try {
      final res = await widget.repository.sendRemoteCommandWithResult(
        opcode,
        sendWakeupHandshake: _sendWakeupHandshake,
        send0x23Init: _send0x23Init,
      );

      if (mounted) {
        setState(() {
          _logs.insert(
            0,
            _LogEntry(
              time: DateTime.now(),
              label: label,
              opcode: opcode,
              result: res,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _activeOpcode = null;
        });
      }
    }
  }

  void _copyAllLogs() {
    if (_logs.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('--- TiggoMate Remote Opcode Diagnostic Log ---');
    buffer.writeln('Date: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Vehicle ID: ${widget.repository.vehicleId ?? "Unbound"}');
    buffer.writeln('VIN: ${widget.repository.vin ?? "MISSING"}');
    buffer.writeln('User ID: ${widget.repository.userId ?? "MISSING"}');
    buffer.writeln('Device SN: ${widget.repository.deviceSn ?? "MISSING"}');
    buffer.writeln('77 Wakeup Init: $_sendWakeupHandshake | Legacy 2301: $_send0x23Init');
    buffer.writeln('----------------------------------------------');
    for (final l in _logs) {
      final t = '${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}:${l.time.second.toString().padLeft(2, '0')}.${l.time.millisecond.toString().padLeft(3, '0')}';
      buffer.writeln('[$t] ${l.label} (${l.opcode}) -> [${l.result.code}] ${l.result.message} (${l.result.latencyMs}ms)');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostic logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBound = widget.repository.isVehicleBound;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131822) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? const Color(0xFF263238) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.evTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.troubleshoot_rounded, color: colors.evTeal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remote Opcode Diagnostics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBound
                            ? 'Vehicle: ${widget.repository.vehicleId}'
                            : '⚠️ Pending Car Bind (Mock / Offline)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isBound ? colors.evTeal : colors.petrolAmber,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: colors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Handshake Config Section
                _buildHandshakeCard(colors, isDark),
                const SizedBox(height: 14),

                // Live Log Console
                _buildLogConsole(colors, isDark),
                const SizedBox(height: 16),

                // Custom Opcode Hex Input
                _buildCustomHexInput(colors, isDark),
                const SizedBox(height: 16),

                // Opcode Groups
                _buildGroupHeader('Climate Control Candidates', Icons.ac_unit_rounded, colors),
                _buildOpcodeGrid([
                  _OpcodeButton('A/C ON', CarLinkoOpcodes.acOn, colors.evTeal),
                  _OpcodeButton('A/C OFF', CarLinkoOpcodes.acOff, Colors.grey),
                  _OpcodeButton('A/C OFF (Alt)', CarLinkoOpcodes.acOffAlt, Colors.blueGrey),
                  _OpcodeButton('A/C 22.0°C', CarLinkoOpcodes.acTemperature(22.0), Colors.lightGreenAccent),
                  _OpcodeButton('Quick Cool ON', CarLinkoOpcodes.quickCool, Colors.cyan),
                  _OpcodeButton('Quick Cool OFF', CarLinkoOpcodes.quickCoolOff, Colors.cyan.shade800),
                  _OpcodeButton('Quick Heat ON', CarLinkoOpcodes.quickHeat, Colors.orange),
                  _OpcodeButton('Quick Heat OFF', CarLinkoOpcodes.quickHeatOff, Colors.deepOrange.shade800),
                  _OpcodeButton('Driver Vent L1', CarLinkoOpcodes.driverSeatVentL1, Colors.lightBlueAccent),
                  _OpcodeButton('Driver Vent L2', CarLinkoOpcodes.driverSeatVentL2, Colors.lightBlueAccent),
                  _OpcodeButton('Driver Vent L3', CarLinkoOpcodes.driverSeatVentL3, Colors.blueAccent),
                  _OpcodeButton('Driver Vent OFF', CarLinkoOpcodes.driverSeatVentOff, Colors.blueGrey),
                  _OpcodeButton('Pass Vent L1', CarLinkoOpcodes.passengerSeatVentL1, Colors.lightBlue),
                  _OpcodeButton('Pass Vent OFF', CarLinkoOpcodes.passengerSeatVentOff, Colors.blueGrey),
                  _OpcodeButton('Driver Heat L1', CarLinkoOpcodes.driverSeatHeatL1, Colors.deepOrangeAccent),
                  _OpcodeButton('Driver Heat OFF', CarLinkoOpcodes.driverSeatHeatOff, Colors.blueGrey),
                  _OpcodeButton('Front Defrost', CarLinkoOpcodes.defogOn, Colors.teal),
                  _OpcodeButton('Defrost OFF', CarLinkoOpcodes.defogOff, Colors.blueGrey),
                  _OpcodeButton('Air Purifier ON', CarLinkoOpcodes.airPurifyOn, Colors.tealAccent),
                  _OpcodeButton('Air Purifier OFF', CarLinkoOpcodes.airPurifyOff, Colors.blueGrey),
                  _OpcodeButton('Steering Heat', CarLinkoOpcodes.steeringHeatOn, Colors.amber),
                  _OpcodeButton('Perm / Wake 7801', CarLinkoOpcodes.perm7801, Colors.purpleAccent),
                ]),
                const SizedBox(height: 16),

                _buildGroupHeader('Windows & Sunroof', Icons.window_rounded, colors),
                _buildOpcodeGrid([
                  _OpcodeButton('Windows Vent (20mm)', CarLinkoOpcodes.windowsVent, Colors.lightBlue),
                  _OpcodeButton('Windows Open', CarLinkoOpcodes.windowsOpen, Colors.indigo),
                  _OpcodeButton('Windows Close', CarLinkoOpcodes.windowsClose, Colors.blueGrey),
                  _OpcodeButton('Sunroof Open', CarLinkoOpcodes.sunroofOpen, Colors.amber),
                  _OpcodeButton('Sunroof Tilt', CarLinkoOpcodes.sunroofTilt, Colors.orange),
                  _OpcodeButton('Sunroof Close', CarLinkoOpcodes.sunroofClose, Colors.grey),
                  _OpcodeButton('Curtain Close (00)', '740F00', Colors.purple),
                  _OpcodeButton('Curtain Open (01)', '740F01', Colors.purpleAccent),
                ]),
                const SizedBox(height: 16),

                _buildGroupHeader('Engine & Hybrid Pre-conditioning', Icons.electric_bolt_rounded, colors),
                _buildOpcodeGrid([
                  _OpcodeButton('Engine Start', CarLinkoOpcodes.engineStart, Colors.green),
                  _OpcodeButton('Engine Stop', CarLinkoOpcodes.engineStop, Colors.redAccent),
                  _OpcodeButton('Stop Charging', CarLinkoOpcodes.stopCharging, Colors.amber.shade800),
                ]),
                const SizedBox(height: 16),

                _buildGroupHeader('Doors & Tailgate', Icons.lock_clock_rounded, colors),
                _buildOpcodeGrid([
                  _OpcodeButton('Lock Doors', CarLinkoOpcodes.lock, Colors.blue),
                  _OpcodeButton('Unlock Doors', CarLinkoOpcodes.unlock, Colors.orange),
                  _OpcodeButton('Tailgate Open', CarLinkoOpcodes.trunkOpen, Colors.deepPurple),
                  _OpcodeButton('Tailgate Close', CarLinkoOpcodes.trunkClose, Colors.purple),
                  _OpcodeButton('Find Car (Horn/Flash)', CarLinkoOpcodes.findCar, Colors.amber),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandshakeCard(AppColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2633) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colors.evTeal),
              const SizedBox(width: 6),
              Text(
                'Handshake & Crypto Configuration',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VIN: ${widget.repository.vin ?? "MISSING"}',
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: widget.repository.vin != null ? colors.textPrimary : Colors.redAccent),
                    ),
                    Text(
                      'UID: ${widget.repository.userId ?? "MISSING"}',
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: widget.repository.userId != null ? colors.textPrimary : Colors.redAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'T-Box: ${widget.repository.deviceSn ?? "MISSING"}',
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: colors.textMuted),
                    ),
                    Text(
                      widget.repository.vin != null && widget.repository.userId != null ? 'AES-128-ECB Active' : 'Cleartext (Missing params)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.repository.vin != null && widget.repository.userId != null ? colors.evTeal : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send "77" Wakeup Init',
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    ),
                    Text(
                      'Official Chery app & j5-ev-dashboard flow: fires 77 + 600ms wake delay',
                      style: TextStyle(fontSize: 10, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _sendWakeupHandshake,
                activeColor: colors.evTeal,
                onChanged: (v) => setState(() => _sendWakeupHandshake = v),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prepend "2301" Handshake',
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    ),
                    Text(
                      'Legacy 0x23 protocol (optional)',
                      style: TextStyle(fontSize: 10, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _send0x23Init,
                activeColor: colors.evTeal,
                onChanged: (v) => setState(() => _send0x23Init = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogConsole(AppColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F141C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2838) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSending ? Colors.amber : const Color(0xFF39FF14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live CAN Response Console',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_logs.isNotEmpty) ...[
                    GestureDetector(
                      onTap: _copyAllLogs,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Copy',
                          style: TextStyle(fontSize: 11, color: colors.evTeal, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _logs.clear()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Clear',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      _isSending
                          ? 'Transmitting command to T-Box…'
                          : 'Tap an opcode button below to test.\nLive Chery cloud response will appear here.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: _logs.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final isSuccess = log.result.success;
                      final t = '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}:${log.time.second.toString().padLeft(2, '0')}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[$t] ',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSuccess
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.result.code ?? (isSuccess ? '0000' : 'ERR'),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSuccess ? const Color(0xFF39FF14) : Colors.redAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${log.label} [${log.opcode}] -> ${log.result.message ?? (isSuccess ? "Accepted" : "Failed")} (${log.result.latencyMs}ms)',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  color: isSuccess ? Colors.white : Colors.red.shade200,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHexInput(AppColors colors, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _customHexController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'e.g. 741001 or 742001',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 12),
              labelText: 'Custom Hex Opcode',
              labelStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isSending
              ? null
              : () {
                  final hex = _customHexController.text.trim().replaceAll(' ', '');
                  if (hex.isNotEmpty) {
                    _fireOpcode(hex, 'Custom Hex');
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.evTeal,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSending && _activeOpcode == _customHexController.text.trim()
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('Send Hex', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildGroupHeader(String title, IconData icon, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colors.evTeal),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcodeGrid(List<_OpcodeButton> buttons) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons.map((b) {
        final isBusy = _isSending && _activeOpcode == b.opcode;
        return ActionChip(
          avatar: isBusy
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
              Text(
                b.opcode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          backgroundColor: b.color.withValues(alpha: 0.25),
          side: BorderSide(color: b.color.withValues(alpha: 0.6)),
          onPressed: _isSending ? null : () => _fireOpcode(b.opcode, b.label),
        );
      }).toList(),
    );
  }
}

class _OpcodeButton {
  final String label;
  final String opcode;
  final Color color;

  _OpcodeButton(this.label, this.opcode, this.color);
}
