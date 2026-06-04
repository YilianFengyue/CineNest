part of 'app_pages.dart';

/// 路由名常量（移植自 PiliPlus 风格）。各模块 Owner 在此追加自己的路由名。
abstract final class Routes {
  static const String home = '/';

  // 成员 B
  static const String movieDetail = '/movie-detail'; // 跳转时拼 /movie-detail/:movieId
  static const String preference = '/preference';
  static const String history = '/history';

  // 成员 A
  static const String player = '/player';
  static const String webviewPlayer = '/webview-player';

  // 成员 C
  /// F8 互动海报详情页。arguments: `{catalog_provider_id, catalog_source_id, media_kind}`（真）或空（mock）。
  static const String creativePoster = '/creative-poster';

  /// 我的收藏页（资讯 / 海报通用）。
  static const String creativeFavorites = '/creative-favorites';

  /// 资讯生成任务队列页。
  static const String creativeNewsTasks = '/creative-news-tasks';

  // settings
  static const String settings = '/settings';
}
