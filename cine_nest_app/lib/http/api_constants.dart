/// 后端地址常量。
///
/// 对应 PiliPlus 母版的 `lib/http/constants.dart`，但 B站多域名常量已全部剔除，
/// 改为「我们自己的 PC 后端」单一基址。运行期真实基址由 [ConnectionService] 动态提供
/// （用户在设置页填写 PC 的 IP:Port），这里仅保留默认值与各模块的路径前缀。
abstract final class ApiConstants {
  /// 默认后端基址。真实值见 [ConnectionService.baseUrl]（F7 设置页运行期覆盖）。
  ///
  /// 真机/模拟器联调：填 PC 的局域网/热点 IP（PC 上 `uvicorn --host 0.0.0.0`）。
  /// ⚠️ 临时联调值，提交前应改回 `127.0.0.1` 或交由 F7 设置页配置。
  static const String defaultBaseUrl = 'http://100.64.122.30:8000';

  /// 健康检查（F7 连接测试用）。
  static const String health = '/api/health';

  // ── 成员 B：推荐 & 帖子流 & 偏好 ──
  static const String feed = '/api/feed';
  static String movieDetail(Object id) => '/api/movie/$id';
  static const String preferences = '/api/preferences';
  static const String feedback = '/api/feedback';

  // ── 成员 A：视频源 & B站 ──
  static const String sourcesSearch = '/api/sources/search';
  static const String sourcesParse = '/api/sources/parse';
  static const String bilibiliSearch = '/api/bilibili/search';

  // ── 成员 C：海报 & 资讯 & 对话 ──
  static String poster(Object movieId) => '/api/poster/$movieId';
  static const String news = '/api/news';
  static const String wsChat = '/ws/chat';

  /// 推荐 Feed（确定性 REST，不走 LLM）：query 可空走热门。返回 RecommendationFeed。
  static const String feedRecommend = '/api/feed/recommend';
}
