import 'package:flutter/material.dart';
import 'package:cine_nest/utils/storage.dart';
import 'package:cine_nest/utils/storage_key.dart';

class PlaybackSettingsPage extends StatefulWidget {
  const PlaybackSettingsPage({super.key});

  @override
  State<PlaybackSettingsPage> createState() => _PlaybackSettingsPageState();
}

class _PlaybackSettingsPageState extends State<PlaybackSettingsPage> {
  late String _mode;
  late TextEditingController _customCtrl;

  static const _defaultProxy = 'https://tmdb-proxy.lapu2023.workers.dev';

  @override
  void initState() {
    super.initState();
    _mode = GStorage.setting.get(SettingBoxKey.tmdbMode, defaultValue: 'proxy') as String;
    final saved = GStorage.setting.get(SettingBoxKey.tmdbCustomProxy, defaultValue: '') as String;
    _customCtrl = TextEditingController(text: saved);
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _setMode(String mode) {
    setState(() => _mode = mode);
    GStorage.setting.put(SettingBoxKey.tmdbMode, mode);
  }

  void _saveCustomUrl(String url) {
    GStorage.setting.put(SettingBoxKey.tmdbCustomProxy, url.trim());
  }

  String get _activeUrl {
    switch (_mode) {
      case 'direct':
        return 'https://api.themoviedb.org/3';
      case 'custom':
        final c = _customCtrl.text.trim();
        return c.isEmpty ? _defaultProxy : c;
      default:
        return _defaultProxy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('播放设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── TMDB 源管理 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Row(
              children: [
                Icon(Icons.dns_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text('TMDB 源管理',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),

          _ModeCard(
            title: '官方直连',
            subtitle: 'api.themoviedb.org（需要科学上网）',
            icon: Icons.public_rounded,
            selected: _mode == 'direct',
            onTap: () => _setMode('direct'),
          ),
          const SizedBox(height: 8),

          _ModeCard(
            title: 'Cloudflare 代理',
            subtitle: _defaultProxy.replaceFirst('https://', ''),
            icon: Icons.cloud_rounded,
            selected: _mode == 'proxy',
            onTap: () => _setMode('proxy'),
          ),
          const SizedBox(height: 8),

          _ModeCard(
            title: '自定义代理',
            subtitle: '输入自建反代地址',
            icon: Icons.edit_rounded,
            selected: _mode == 'custom',
            onTap: () => _setMode('custom'),
          ),

          // 自定义输入框
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _mode == 'custom'
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                    child: TextField(
                      controller: _customCtrl,
                      onChanged: _saveCustomUrl,
                      decoration: InputDecoration(
                        labelText: '代理地址',
                        hintText: 'https://your-proxy.workers.dev',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.link_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _customCtrl.clear();
                            _saveCustomUrl('');
                          },
                        ),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // 当前生效提示
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '当前生效: ${_activeUrl.replaceFirst('https://', '')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '切换后重启 App 或重新进入首页即生效',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.5)
          : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? cs.onPrimaryContainer
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.7)
                            : cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? cs.primary : cs.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
