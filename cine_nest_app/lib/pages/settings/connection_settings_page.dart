import 'package:cine_nest/pages/player/views/source_debug_panel.dart';
import 'package:cine_nest/services/connection_service.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// PC 连接子页（F7 重做版）。
///
/// 旧版把英文表单 + 视频源调试一股脑堆在偏好页底部，很乱。这里按
/// Material You 重新组织信息层级：
/// 1. **状态 hero**：一眼看清连没连上，连接中带进度环，配色随状态走 tonal；
/// 2. **地址输入卡**：IP + 端口分列，中文标签，校验错误就地提示；
/// 3. **操作**：保存并测试 / 仅测试；
/// 4. **高级（折叠）**：成员 A 的视频源调试面板，默认收起、弱化存在感。
///
/// 连接逻辑全部复用 [ConnectionService]，未改动。
class ConnectionSettingsPage extends StatefulWidget {
  const ConnectionSettingsPage({super.key});

  @override
  State<ConnectionSettingsPage> createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
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
      setState(() => _inputError = '请输入有效的 PC 地址和端口（1–65535）');
      return;
    }
    setState(() => _inputError = null);
    final service = ConnectionService.to;
    await service.updateAddress(host: host, port: port);
    await service.testConnection();
  }

  @override
  Widget build(BuildContext context) {
    final service = ConnectionService.to;
    return Scaffold(
      appBar: AppBar(title: const Text('PC 连接')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Obx(() => _StatusHero(
                    status: service.status.value,
                    baseUrl: service.baseUrl,
                    detail: service.message.value,
                  )),
              const SizedBox(height: 20),
              _addressCard(context),
              const SizedBox(height: 16),
              _actions(service),
              const SizedBox(height: 28),
              _advanced(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lan_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '后端地址',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'PC 地址',
                      hintText: '192.168.1.100',
                      prefixIcon: const Icon(Icons.computer_rounded),
                      border: border(cs.outlineVariant),
                      enabledBorder: border(cs.outlineVariant),
                      focusedBorder: border(cs.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: '端口',
                      hintText: '8000',
                      border: border(cs.outlineVariant),
                      enabledBorder: border(cs.outlineVariant),
                      focusedBorder: border(cs.primary),
                    ),
                  ),
                ),
              ],
            ),
            if (_inputError != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: cs.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _inputError!,
                      style: TextStyle(color: cs.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions(ConnectionService service) {
    return Obx(() {
      final connecting = service.status.value == ConnStatus.connecting;
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: connecting ? null : _saveAndTest,
              icon: connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: const Text('保存并测试'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: connecting ? null : service.testConnection,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('仅测试'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ],
      );
    });
  }

  Widget _advanced(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // 去掉 ExpansionTile 默认的上下分隔线，更扁平。
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.tune_rounded, color: cs.onSurfaceVariant),
          title: const Text('高级 · 视频源调试'),
          subtitle: Text(
            '成员 A 的资源解析测试工具',
            style: TextStyle(color: cs.outline, fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: const [SourceDebugPanel()],
        ),
      ),
    );
  }
}

/// 连接状态 hero：随状态切 tonal 配色 + 图标 + 文案。
class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.status,
    required this.baseUrl,
    required this.detail,
  });

  final ConnStatus status;
  final String baseUrl;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (Color bg, Color fg, IconData icon, String label) = switch (status) {
      ConnStatus.connected => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          Icons.cloud_done_rounded,
          '已连接',
        ),
      ConnStatus.connecting => (
          cs.secondaryContainer,
          cs.onSecondaryContainer,
          Icons.cloud_sync_rounded,
          '连接中…',
        ),
      ConnStatus.failed => (
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.cloud_off_rounded,
          '连接失败',
        ),
      ConnStatus.disconnected => (
          cs.surfaceContainerHigh,
          cs.onSurfaceVariant,
          Icons.cloud_queue_rounded,
          '未连接',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
                if (status == ConnStatus.connecting)
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  ),
                Icon(icon, color: fg, size: 26),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  baseUrl,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
