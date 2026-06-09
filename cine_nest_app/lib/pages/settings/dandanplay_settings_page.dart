import 'package:cine_nest/utils/storage_pref.dart';
import 'package:flutter/material.dart';

/// 弹弹Play API 密钥配置页。
class DanDanPlaySettingsPage extends StatefulWidget {
  const DanDanPlaySettingsPage({super.key});

  @override
  State<DanDanPlaySettingsPage> createState() => _DanDanPlaySettingsPageState();
}

class _DanDanPlaySettingsPageState extends State<DanDanPlaySettingsPage> {
  late final TextEditingController _appIdCtrl;
  late final TextEditingController _appSecretCtrl;
  bool _obscure = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _appIdCtrl = TextEditingController(text: Pref.dandanAppId);
    _appSecretCtrl = TextEditingController(text: Pref.dandanAppSecret);
  }

  @override
  void dispose() {
    _appIdCtrl.dispose();
    _appSecretCtrl.dispose();
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
                Icon(Icons.info_outline, color: cs.onPrimaryContainer, size: 20),
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

          const SizedBox(height: 24),

          // 保存按钮
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(_saved ? Icons.check : Icons.save_outlined),
            label: Text(_saved ? '已保存' : '保存'),
          ),

          const SizedBox(height: 32),

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
