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
  static const String defaultBaseUrl = 'http://100.67.48.35:8000';

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

  // ── 成员 C：海报 & 资讯 & 对话（microdesign.v1.1）──
  static const String wsChat = '/ws/chat';

  /// 推荐 Feed（确定性 REST，不走 LLM）：query 可空走热门。返回 RecommendationFeed。
  static const String feedRecommend = '/api/feed/recommend';

  /// 互动海报：Catalog 条目（豆瓣/TMDB）。
  static String posterCatalog(Object provider, Object source) =>
      '/api/poster/catalog/$provider/$source';

  /// 互动海报：资源站条目（无 Catalog ID 时）。
  static String posterResource(Object provider, Object remote) =>
      '/api/poster/$provider/$remote';

  // 资讯
  static const String news = '/api/news';
  static const String newsGenerate = '/api/news/generate';
  static String newsDetail(Object id) => '/api/news/$id';

  /// 资讯生成任务队列（异步生成的状态轮询；后端 codex 实现中）。
  static const String newsTasks = '/api/news/tasks';

  // 对话基础设施
  static const String agentModels = '/api/agent/models';
  static const String chatSessions = '/api/chat/sessions';
  static String chatMessages(Object threadId) =>
      '/api/chat/sessions/$threadId/messages';
  static const String microdesignSchema = '/api/microdesign/schema';

  // 统一播放解析（交 A 的播放器）
  static const String playResolve = '/api/play/resolve';

  // 上传资产（多模态）
  static const String uploads = '/api/uploads';
  static String asset(Object id) => '/api/assets/$id';
}
