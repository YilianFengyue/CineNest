import 'package:cine_nest/services/dandanplay_service.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:flutter/material.dart';

/// 弹弹Play API 密钥配置 + 调试测试页。
class DanDanPlaySettingsPage extends StatefulWidget {
  const DanDanPlaySettingsPage({super.key});

  @override
  State<DanDanPlaySettingsPage> createState() => _DanDanPlaySettingsPageState();
}

class _DanDanPlaySettingsPageState extends State<DanDanPlaySettingsPage> {
  late final TextEditingController _appIdCtrl;
  late final TextEditingController _appSecretCtrl;
  late final TextEditingController _testKeywordCtrl;
  bool _obscure = true;
  bool _saved = false;
  bool _testing = false;
  String _debugOutput = '';

  @override
  void initState() {
    super.initState();
    _appIdCtrl = TextEditingController(text: Pref.dandanAppId);
    _appSecretCtrl = TextEditingController(text: Pref.dandanAppSecret);
    _testKeywordCtrl = TextEditingController(text: '你的名字');
  }

  @override
  void dispose() {
    _appIdCtrl.dispose();
    _appSecretCtrl.dispose();
    _testKeywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final appId = _appIdCtrl.text.trim();
    final appSecret = _appSecretCtrl.text.trim();
    await Pref.setDandanAppId(appId);
    await Pref.setDandanAppSecret(appSecret);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _runDebugTest() async {
    // 先保存当前输入的 key
    await _save();
    setState(() {
      _testing = true;
      _debugOutput = '正在测试...';
    });
    try {
      final svc = DanDanPlayService();
      final result = await svc.debugTest(_testKeywordCtrl.text.trim());
      if (mounted) setState(() => _debugOutput = result);
    } catch (e) {
      if (mounted) setState(() => _debugOutput = '测试异常: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('弹幕设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 说明卡
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: cs.onPrimaryContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '弹幕数据来自弹弹Play开放平台。\n'
                    '播放视频时将自动按片名匹配弹幕库，'
                    '支持动漫、电影、电视剧。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 状态指示
          _StatusRow(
            label: 'App ID',
            ok: Pref.dandanAppId.isNotEmpty,
            detail: Pref.dandanAppId.isEmpty
                ? '未配置'
                : Pref.dandanAppId,
          ),
          const SizedBox(height: 4),
          _StatusRow(
            label: 'App Secret',
            ok: Pref.dandanAppSecret.isNotEmpty,
            detail: Pref.dandanAppSecret.isEmpty
                ? '未配置'
                : '已配置 (${Pref.dandanAppSecret.length} 字符)',
          ),

          const SizedBox(height: 16),

          // AppId
          TextField(
            controller: _appIdCtrl,
            decoration: InputDecoration(
              labelText: 'App ID',
              hintText: '弹弹Play 开发者 App ID',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.badge_outlined),
              filled: true,
              fillColor: cs.surfaceContainerLow,
            ),
            onChanged: (_) => setState(() => _saved = false),
          ),

          const SizedBox(height: 16),

          // AppSecret
          TextField(
            controller: _appSecretCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'App Secret',
              hintText: '弹弹Play 开发者 App Secret',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key_outlined),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (_) => setState(() => _saved = false),
          ),

          const SizedBox(height: 16),

          // 保存按钮
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(_saved ? Icons.check : Icons.save_outlined),
            label: Text(_saved ? '已保存' : '保存'),
          ),

          const Divider(height: 40),

          // ── 调试测试区 ──
          Text(
            '调试测试',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '输入片名测试 API 连通性、搜索匹配和弹幕拉取',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testKeywordCtrl,
                  decoration: const InputDecoration(
                    hintText: '测试关键字，如 "你的名字"',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: _testing ? null : _runDebugTest,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bug_report_outlined, size: 18),
                label: const Text('测试'),
              ),
            ],
          ),

          if (_debugOutput.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _debugOutput,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: cs.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ],

          const Divider(height: 40),

          // 申请说明
          Text(
            '如何获取？',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '1. 访问 www.dandanplay.com 注册开发者账号\n'
            '2. 进入开发者中心 → 应用管理 → 创建应用\n'
            '3. 审核通过后获取 App ID 和 App Secret\n'
            '4. 填入上方表单并保存',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.ok,
    required this.detail,
  });

  final String label;
  final bool ok;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: ok ? Colors.green : cs.error,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        Expanded(
          child: Text(
            detail,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
