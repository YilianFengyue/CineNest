import 'package:flutter/material.dart';
import 'package:cine_nest/pages/feed/discovery/discovery_view.dart';
import 'package:cine_nest/pages/feed/preference/preference_view.dart';

/// 应用主壳：底部导航框架（Day1 共建）。
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _index = 0;

  static const _tabs = [
    _TabDef('首页', Icons.movie_outlined, Icons.movie, '全球热门探索'),
    _TabDef('对话', Icons.chat_bubble_outline, Icons.chat_bubble, '成员 C · F9 AI 对话'),
    _TabDef('资讯', Icons.article_outlined, Icons.article, '成员 C · F12 影视资讯'),
    _TabDef('设置', Icons.settings_outlined, Icons.settings, '个性化偏好'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          // 只有当索引为 0 时，或者曾经加载过才保持在内存中
          const DiscoveryPage(),
          _Placeholder(title: _tabs[1].label, hint: _tabs[1].hint),
          _Placeholder(title: _tabs[2].label, hint: _tabs[2].hint),
          // 为了防止启动时压力过大，可以考虑延迟加载 PreferencePage
          _index == 3 ? const PreferencePage() : _Placeholder(title: _tabs[3].label, hint: _tabs[3].hint),
        ],
      ),
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
