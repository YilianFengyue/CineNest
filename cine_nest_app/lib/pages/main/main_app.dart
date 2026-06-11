import 'package:cine_nest/pages/creative/chat/chat_page.dart';
import 'package:cine_nest/pages/creative/news/news_page.dart';
import 'package:cine_nest/pages/kazumi_home/kazumi_home_page.dart';
import 'package:cine_nest/pages/settings/settings_page.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:cine_nest/services/agent_memory_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MainNavController extends GetxController {
  static MainNavController get to => Get.find<MainNavController>();
  final RxInt index = 0.obs;
  void go(int i) => index.value = i;

  @override
  void onInit() {
    super.onInit();
    AgentMemoryService().autoSyncIfNeeded();
  }
}

/// 应用主壳：底部导航框架（Day1 共建）。
///
/// 对话 Tab（F9）是全屏体验：它自带 AppBar + 侧边历史抽屉 + 输入框，
/// 像详情页一样不显示底部 4-tab 导航；其余 Tab 挂底部导航。
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static const _tabs = [
    _TabDef('Home', Icons.home_outlined, Icons.home, 'Kazumi 风格首页'),
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
    final nav = Get.isRegistered<MainNavController>()
        ? MainNavController.to
        : Get.put(MainNavController(), permanent: true);

    return Obx(() {
      final index = nav.index.value;
      if (index == 1) return const ChatPage();

      final tab = _tabs[index];

      // Home tab 直接展示 KazumiHomePage（自带 SliverAppBar）
      if (index == 0) {
        return Scaffold(
          body: const KazumiHomePage(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: nav.go,
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

      return Scaffold(
        appBar: AppBar(
          title: Text('CineNest · ${tab.label}'),
          actions: index == 2
              ? [
                  IconButton(
                    tooltip: '论坛',
                    icon: const Icon(Icons.forum_outlined),
                    onPressed: () => Get.toNamed(Routes.forum),
                  ),
                  IconButton(
                    tooltip: '我的收藏',
                    icon: const Icon(Icons.favorite_border),
                    onPressed: () => Get.toNamed(Routes.creativeFavorites),
                  ),
                  IconButton(
                    tooltip: '生成队列',
                    icon: const Icon(Icons.dynamic_feed),
                    onPressed: () => Get.toNamed(Routes.creativeNewsTasks),
                  ),
                ]
              : null,
        ),
        body: _bodyFor(index, tab),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: nav.go,
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
    });
  }

  Widget _bodyFor(int index, _TabDef tab) {
    switch (index) {
      case 0:
        return const KazumiHomePage();
      case 2:
        return const NewsPage();
      case 3:
        return const SettingsPage();
      default:
        return _Placeholder(title: tab.label, hint: tab.hint);
    }
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
