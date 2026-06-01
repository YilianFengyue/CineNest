import 'package:cine_nest/pages/main/main_app.dart';
import 'package:get/get.dart';

part 'app_routes.dart';

/// 全局路由表（移植自 PiliPlus 的 `lib/router/app_pages.dart`）。
///
/// 约定：
///   · 路由名常量统一声明在 [Routes]（见 app_routes.dart part）。
///   · 各模块 Owner 把自己的页面追加到 [AppPages.getPages]，互不交叉修改根节点。
///   · 母版用「main() 中 Get.lazyPut 全局 Service + 页面内 Get.find」的方式管理依赖，
///     无独立 Binding；本项目沿用，复杂模块可自行加 binding。
abstract final class AppPages {
  static final List<GetPage> getPages = [
    GetPage(name: Routes.home, page: () => const MainApp()),

    // ── 成员 B（feed）：/movie-detail/:movieId, /preference, /history ──
    // GetPage(name: Routes.movieDetail, page: () => const MovieDetailPage()),

    // ── 成员 A（player）：/player, /webview-player ──
    // GetPage(name: Routes.player, page: () => const PlayerPage()),

    // ── 成员 C（creative）：内嵌于 Tab，无独立路由或按需追加 ──

    // ── settings：A 负责连接、B 负责偏好 ──
    // GetPage(name: Routes.settings, page: () => const SettingsPage()),
  ];
}
