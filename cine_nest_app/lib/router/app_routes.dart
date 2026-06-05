part of 'app_pages.dart';

abstract final class Routes {
  static const String home = '/';

  // Member B
  static const String feed = '/feed';
  static const String movieDetail = '/movie-detail';
  static const String preference = '/preference';
  static const String history = '/history';
  static const String collection = '/collection';

  // Member A
  static const String sourcePicker = '/source-picker';
  static const String webviewPlayer = '/webview-player';

  // Member C
  /// F8 互动海报详情页。arguments: `{catalog_provider_id, catalog_source_id, media_kind}`（真）或空（mock）。
  static const String creativePoster = '/creative-poster';

  /// 我的收藏页（资讯 / 海报通用）。
  static const String creativeFavorites = '/creative-favorites';

  /// 资讯生成任务队列页。
  static const String creativeNewsTasks = '/creative-news-tasks';

  static const String settings = '/settings';
}
