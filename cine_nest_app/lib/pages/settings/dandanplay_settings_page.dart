import 'package:cine_nest/services/dandanplay_service.dart';
import 'package:cine_nest/services/logvar_danmu_service.dart';
import 'package:cine_nest/utils/storage_pref.dart';
import 'package:flutter/material.dart';

class DanmakuSettingsPage extends StatefulWidget {
  const DanmakuSettingsPage({super.key});

  @override
  State<DanmakuSettingsPage> createState() => _DanmakuSettingsPageState();
}

class _DanmakuSettingsPageState extends State<DanmakuSettingsPage> {
  late String _source;

  late final TextEditingController _appIdCtrl;
  late final TextEditingController _appSecretCtrl;
  bool _obscureSecret = true;

  late final TextEditingController _logvarUrlCtrl;
  late final TextEditingController _logvarTokenCtrl;
  bool _obscureToken = true;

  late final TextEditingController _testKeywordCtrl;
  bool _saved = false;
  bool _testing = false;
  String _debugOutput = '';

  @override
  void initState() {
    super.initState();
    _source = Pref.danmakuSource;
    _appIdCtrl = TextEditingController(text: Pref.dandanAppId);
    _appSecretCtrl = TextEditingController(text: Pref.dandanAppSecret);
    _logvarUrlCtrl = TextEditingController(text: Pref.logvarBaseUrl);
    _logvarTokenCtrl = TextEditingController(text: Pref.logvarToken);
    _testKeywordCtrl = TextEditingController(text: '你的名字');
  }

  @override
  void dispose() {
    _appIdCtrl.dispose();
    _appSecretCtrl.dispose();
    _logvarUrlCtrl.dispose();
    _logvarTokenCtrl.dispose();
    _testKeywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await Pref.setDanmakuSource(_source);
    if (_source == 'dandanplay') {
      await Pref.setDandanAppId(_appIdCtrl.text.trim());
      await Pref.setDandanAppSecret(_appSecretCtrl.text.trim());
    } else {
      await Pref.setLogvarBaseUrl(_logvarUrlCtrl.text.trim());
      await Pref.setLogvarToken(_logvarTokenCtrl.text.trim());
    }
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _runTest() async {
    await _save();
    setState(() {
      _testing = true;
      _debugOutput = '正在测试...';
    });
    try {
      final DanmakuSource svc = _source == 'dandanplay'
          ? DanDanPlayService()
          : LogvarDanmuService();
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
          // ── 说明卡 ──
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
                    '播放视频时自动按片名匹配弹幕库，支持动漫、电影、电视剧。\n'
                    '可选择不同的弹幕数据源。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 源选择 ──
          Text('弹幕源',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'logvar',
                  label: Text('LogVar 聚合'),
                  icon: Icon(Icons.cloud_outlined),
                ),
                ButtonSegment(
                  value: 'dandanplay',
                  label: Text('弹弹Play'),
                  icon: Icon(Icons.api_outlined),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (v) {
                setState(() {
                  _source = v.first;
                  _saved = false;
                  _debugOutput = '';
                });
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── 源配置区 ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _source == 'logvar'
                ? _buildLogvarSection(theme, cs)
                : _buildDandanSection(theme, cs),
          ),

          const SizedBox(height: 16),

          // ── 保存 ──
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(_saved ? Icons.check : Icons.save_outlined),
            label: Text(_saved ? '已保存' : '保存'),
          ),

          const Divider(height: 40),

          // ── 调试测试 ──
          Text('调试测试',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '输入片名测试 API 连通性、搜索匹配和弹幕拉取',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
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
                onPressed: _testing ? null : _runTest,
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

          // ── 获取说明 ──
          Text('如何获取？',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            _source == 'logvar'
                ? '1. 自建或使用已有的 LogVar 弹幕聚合服务\n'
                    '2. 服务地址格式: https://你的域名 或 http://IP:端口\n'
                    '3. 如果服务设置了 TOKEN，填入 Token 字段\n'
                    '4. 聚合 360、人人、韩剧等多源弹幕，无需单独 API Key'
                : '1. 访问 www.dandanplay.com 注册开发者账号\n'
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

  // ── LogVar 配置区 ──
  Widget _buildLogvarSection(ThemeData theme, ColorScheme cs) {
    return Column(
      key: const ValueKey('logvar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(
          label: 'Base URL',
          ok: Pref.logvarBaseUrl.isNotEmpty,
          detail: Pref.logvarBaseUrl.isEmpty ? '未配置' : Pref.logvarBaseUrl,
        ),
        const SizedBox(height: 4),
        _StatusRow(
          label: 'Token',
          ok: Pref.logvarToken.isNotEmpty,
          detail: Pref.logvarToken.isEmpty ? '选填，未设置' : '已配置',
          optional: true,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _logvarUrlCtrl,
          decoration: InputDecoration(
            labelText: 'Base URL',
            hintText: 'https://你的域名 或 http://IP:端口',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.link_outlined),
            filled: true,
            fillColor: cs.surfaceContainerLow,
          ),
          onChanged: (_) => setState(() => _saved = false),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _logvarTokenCtrl,
          obscureText: _obscureToken,
          decoration: InputDecoration(
            labelText: 'Token (选填)',
            hintText: '如果服务配置了 TOKEN，在此填写',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            filled: true,
            fillColor: cs.surfaceContainerLow,
            suffixIcon: IconButton(
              icon: Icon(_obscureToken
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
          ),
          onChanged: (_) => setState(() => _saved = false),
        ),
      ],
    );
  }

  // ── 弹弹Play 配置区 ──
  Widget _buildDandanSection(ThemeData theme, ColorScheme cs) {
    return Column(
      key: const ValueKey('dandanplay'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(
          label: 'App ID',
          ok: Pref.dandanAppId.isNotEmpty,
          detail: Pref.dandanAppId.isEmpty ? '未配置' : Pref.dandanAppId,
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
        TextField(
          controller: _appSecretCtrl,
          obscureText: _obscureSecret,
          decoration: InputDecoration(
            labelText: 'App Secret',
            hintText: '弹弹Play 开发者 App Secret',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key_outlined),
            filled: true,
            fillColor: cs.surfaceContainerLow,
            suffixIcon: IconButton(
              icon: Icon(_obscureSecret
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _obscureSecret = !_obscureSecret),
            ),
          ),
          onChanged: (_) => setState(() => _saved = false),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.ok,
    required this.detail,
    this.optional = false,
  });

  final String label;
  final bool ok;
  final String detail;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final IconData icon;
    final Color color;
    if (ok) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (optional) {
      icon = Icons.info_outline;
      color = cs.primary;
    } else {
      icon = Icons.cancel;
      color = cs.error;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
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
