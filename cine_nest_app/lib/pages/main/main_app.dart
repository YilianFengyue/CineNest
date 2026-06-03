import 'package:cine_nest/pages/feed/discovery/discovery_view.dart';
import 'package:cine_nest/pages/feed/preference/preference_view.dart';
import 'package:flutter/material.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _index = 0;

  static const _tabs = [
    _TabDef('Home', Icons.movie_outlined, Icons.movie, 'Member B - feed'),
    _TabDef(
      'Chat',
      Icons.chat_bubble_outline,
      Icons.chat_bubble,
      'Member C - chat',
    ),
    _TabDef('News', Icons.article_outlined, Icons.article, 'Member C - news'),
    _TabDef(
      'Settings',
      Icons.settings_outlined,
      Icons.settings,
      'Member A/B - settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const DiscoveryPage(),
          _Placeholder(title: _tabs[1].label, hint: _tabs[1].hint),
          _Placeholder(title: _tabs[2].label, hint: _tabs[2].hint),
          _index == 3
              ? const PreferencePage()
              : _Placeholder(title: _tabs[3].label, hint: _tabs[3].hint),
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
          Text(
            '$title placeholder',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(hint, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
