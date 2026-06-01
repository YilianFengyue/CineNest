import 'package:flutter/material.dart';

/// 应用主壳：底部导航框架（Day1 共建）。
///
/// 这里只搭「导航骨架」，每个 Tab 的真实页面由各模块 Owner 后续填充：
///   · 首页(F1 帖子流) → 成员 B   · 对话(F9) → 成员 C
///   · 资讯(F12) → 成员 C         · 设置(F7 连接 / F6 偏好) → 成员 A·B
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _index = 0;

  static const _tabs = [
    _TabDef('首页', Icons.movie_outlined, Icons.movie, '成员 B · F1 AI 推荐帖子流'),
    _TabDef('对话', Icons.chat_bubble_outline, Icons.chat_bubble, '成员 C · F9 AI 对话'),
    _TabDef('资讯', Icons.article_outlined, Icons.article, '成员 C · F12 影视资讯'),
    _TabDef('设置', Icons.settings_outlined, Icons.settings, '成员 A/B · F7 连接 / F6 偏好'),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];
    return Scaffold(
      appBar: AppBar(title: Text('CineNest · ${tab.label}')),
      body: _Placeholder(title: tab.label, hint: tab.hint),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String hint;
  const _TabDef(this.label, this.icon, this.activeIcon, this.hint);
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction, size: 48, color: cs.primary),
          const SizedBox(height: 12),
          Text('$title（占位）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(hint, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
