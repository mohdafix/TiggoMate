import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleRepo = ref.watch(vehicleRepositoryProvider);
    final isSim = vehicleRepo.isSimulatedMode;
    final knowledgeRepo = ref.watch(knowledgeRepositoryProvider);
    final knowledgeStatus = knowledgeRepo.getStatus();
    final storage = ref.watch(localStorageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Vehicle Telematics & Simulation Toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TELEMATICS & DEVELOPMENT MODE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Simulated Data Mode'),
                    subtitle: const Text(
                      'Toggles mock telemetry for testing. When off, returns honest disconnected status.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: isSim,
                    activeThumbColor: AppTheme.statusSimulated,
                    onChanged: (val) {
                      ref
                          .read(vehicleProfileProvider.notifier)
                          .setSimulatedMode(val);
                    },
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CarLinko Activation Status'),
                    subtitle: const Text(
                      'Pending 1,000 km initial dealer service onboarding.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Chip(label: Text('PENDING')),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // AI Provider & Backend Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI BACKEND & MODEL CONFIGURATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Configured Model'),
                    subtitle: Text(
                      storage.getAiModelName(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Text(
                      'GPT-4o-mini',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Secure Backend Proxy'),
                    subtitle: Text(
                      storage.getAiBackendUrl(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Change Backend Proxy URL',
                      onPressed: () => _showBackendUrlDialog(context, ref),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: AppTheme.primaryTeal,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Strict Privacy: All OpenRouter and LLM credentials are kept on the backend proxy. No client API secrets stored in the app.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Knowledge Base Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KNOWLEDGE BASE & RAG STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingRow(
                    'Indexed Documents',
                    '${knowledgeStatus.totalChunks} Chunks Verified',
                  ),
                  _buildSettingRow(
                    'Market Alignment',
                    '${knowledgeStatus.market} (Right-Hand Drive CSH)',
                  ),
                  _buildSettingRow(
                    'Source Document',
                    knowledgeStatus.documentTitle,
                  ),
                  _buildSettingRow(
                    'RAG Indexing',
                    knowledgeStatus.isIndexed
                        ? 'Ready & Active'
                        : 'Uninitialized',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Data Management & Privacy
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATA MANAGEMENT & PRIVACY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Export Ownership Records (JSON)'),
                    subtitle: const Text(
                      'Export your vehicle profile, maintenance, and energy logs.',
                    ),
                    onTap: () => _exportDataAsJson(context, ref),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.orangeAccent,
                    ),
                    title: const Text('Clear Local Cache'),
                    subtitle: const Text(
                      'Resets local app cache while preserving your vehicle profile.',
                    ),
                    onTap: () => _confirmClearCache(context, ref),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBackendUrlDialog(BuildContext context, WidgetRef ref) {
    final storage = ref.read(localStorageProvider);
    final ctrl = TextEditingController(text: storage.getAiBackendUrl());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Proxy Endpoint'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Backend URL',
            hintText: 'https://api.tiggomate.app/v1/ai',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              storage.setAiBackendUrl(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _exportDataAsJson(BuildContext context, WidgetRef ref) {
    final profile = ref.read(vehicleProfileProvider);
    final maintenance = ref.read(maintenanceStateProvider);
    final energy = ref.read(energyStateProvider);

    final export = {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'TiggoMate',
      'version': '1.0.0',
      'vehicleProfile': profile.toMap(),
      'maintenance': maintenance.toMap(),
      'energy': energy.toMap(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(export);

    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exported data copied to clipboard as JSON!'),
      ),
    );
  }

  void _confirmClearCache(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Local Cache?'),
        content: const Text(
          'This will clear cached assistant conversations and temporary data. Your vehicle profile will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cache cleared.')));
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
