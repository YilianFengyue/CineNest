import 'package:cine_nest/pages/creative/chat/chat_page.dart';
import 'package:cine_nest/pages/creative/news/news_page.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 主导航控制器（共建基建）。
///
/// 把"当前 Tab"提升为响应式状态，这样对话页的侧边抽屉也能切回其它 Tab。
class MainNavController extends GetxController {
  static MainNavController get to => Get.find<MainNavController>();
  final RxInt index = 0.obs;
  void go(int i) => index.value = i;
}

/// 应用主壳：底部导航框架（Day1 共建）。
///
/// 设计要点：**对话 Tab（F9）是全屏体验**——它自带 AppBar + 侧边历史抽屉 + 输入框，
/// 像详情页一样不显示底部 4-tab 导航；其余 Tab（首页/资讯/设置）才挂底部导航。
/// 在对话页要切去别的 Tab，走抽屉里的目的地入口（仿 Gemini 的汉堡抽屉）。
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static const _tabs = [
    _TabDef('首页', Icons.movie_outlined, Icons.movie, '成员 B · F1 AI 推荐帖子流'),
    _TabDef('对话', Icons.chat_bubble_outline, Icons.chat_bubble, '成员 C · F9 AI 对话'),
    _TabDef('资讯', Icons.article_outlined, Icons.article, '成员 C · F12 影视资讯'),
    _TabDef('设置', Icons.settings_outlined, Icons.settings, '成员 A/B · F7 连接 / F6 偏好'),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = Get.isRegistered<MainNavController>()
        ? MainNavController.to
        : Get.put(MainNavController(), permanent: true);

    return Obx(() {
      final index = nav.index.value;
      // 对话 Tab 全屏，自带导航 chrome，不套外层 Scaffold / 底部导航。
      if (index == 1) return const ChatPage();

      final tab = _tabs[index];
      return Scaffold(
        appBar: AppBar(
          title: Text('CineNest · ${tab.label}'),
          // 资讯 Tab：右上角放「我的收藏 / 生成队列」入口。
          actions: index == 2
              ? [
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

  /// 资讯(F12) Tab 已接真实页面，其余 Tab 暂留占位待各 Owner 填充。
  Widget _bodyFor(int index, _TabDef tab) {
    switch (index) {
      case 2:
        return const NewsPage();
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
          Text('$title（占位）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(hint, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
