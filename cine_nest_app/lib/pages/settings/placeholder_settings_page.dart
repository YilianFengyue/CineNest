import 'package:flutter/material.dart';

/// 通用「占位」设置子页。
///
/// 照搬 Kazumi 的设置项清单时，有些功能我们还没做（播放设置、视频源规则、
/// 下载管理、界面设置、关于…）。这些先用本页占位，把入口和导航跑通，
/// 后续各成员把真实页面接进来即可——只需把 [SettingsTile.onTap] 里的
/// 目标换成真实页面。
class PlaceholderSettingsPage extends StatelessWidget {
  const PlaceholderSettingsPage({
    super.key,
    required this.title,
    this.icon = Icons.construction_rounded,
    this.note = '该功能正在开发中，敬请期待。',
    this.owner,
  });

  final String title;
  final IconData icon;
  final String note;

  /// 负责人标注（如 'Member A'），仅在占位页提示，方便联调时认领。
  final String? owner;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                note,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (owner != null) ...[
                const SizedBox(height: 8),
                Text(
                  owner!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
