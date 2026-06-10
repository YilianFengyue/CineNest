import 'package:cine_nest/pages/player/views/source_debug_panel.dart';
import 'package:cine_nest/services/connection_service.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConnectionSettingsPanel extends StatefulWidget {
  const ConnectionSettingsPanel({super.key});

  @override
  State<ConnectionSettingsPanel> createState() =>
      _ConnectionSettingsPanelState();
}

class _ConnectionSettingsPanelState extends State<ConnectionSettingsPanel> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: Pref.pcHost);
    _portController = TextEditingController(text: Pref.pcPort.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      setState(() => _inputError = 'Enter a valid PC IP and port.');
      return;
    }

    setState(() => _inputError = null);
    final service = ConnectionService.to;
    await service.updateAddress(host: host, port: port);
    await service.testConnection();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ConnectionService.to;
    final cs = Theme.of(context).colorScheme;

    return Obx(() {
      final status = service.status.value;
      final isConnecting = status == ConnStatus.connecting;
      final statusText = switch (status) {
        ConnStatus.disconnected => 'Disconnected',
        ConnStatus.connecting => 'Connecting...',
        ConnStatus.connected => 'Connected',
        ConnStatus.failed => 'Failed',
      };
      final statusColor = switch (status) {
        ConnStatus.connected => Colors.green,
        ConnStatus.failed => cs.error,
        ConnStatus.connecting => cs.primary,
        ConnStatus.disconnected => cs.onSurfaceVariant,
      };

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PC backend connection',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'PC IP',
                    hintText: '192.168.1.100',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '8000',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (_inputError != null) ...[
            const SizedBox(height: 8),
            Text(_inputError!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 12),
          SelectableText('Current base URL: ${service.baseUrl}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: isConnecting ? null : _saveAndTest,
                icon: isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save and test'),
              ),
              OutlinedButton.icon(
                onPressed: isConnecting ? null : service.testConnection,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Test only'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.circle, size: 12, color: statusColor),
              const SizedBox(width: 8),
              Text(statusText, style: TextStyle(color: statusColor)),
            ],
          ),
          if (service.message.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(service.message.value),
            ),
          const Divider(height: 40),
          const SourceDebugPanel(),
        ],
      );
    });
  }
}
