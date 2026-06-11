abstract final class ApiConstants {
  /// 默认后端基址。真实值见 [ConnectionService.baseUrl]（F7 设置页运行期覆盖）。
  static const String defaultBaseUrl = 'http://127.0.0.1:8000';

  static const String health = '/api/health';

  // Member B
  static const String feed = '/api/feed';
  static const String discovery = '/api/discovery';
  static String movieDetail(Object id) => '/api/movie/$id';
  static const String preferences = '/api/preferences';
  static const String feedback = '/api/feedback';
  static const String history = '/api/history';
  static const String historyRecord = '/api/history/record';
  static const String collections = '/api/collections';
  static const String collectionsToggle = '/api/collections/toggle';

  // Member A
  static const String sourcesSearch = '/api/sources/search';
  static const String sourcesParse = '/api/sources/parse';
  static const String bilibiliSearch = '/api/bilibili/search';
  static const String localVideos = '/api/local-videos';
  static const String localVideosRescan = '/api/local-videos/rescan';
  static String localVideoStream(Object id) => '/api/local-videos/stream/$id';
  static const String tasteDna = '/api/taste-dna';
  static const String tasteDnaAvatarGenerate = '/api/taste-dna/avatar/generate';
  static const String forumPosts = '/api/forum/posts';
  static String forumPost(Object id) => '/api/forum/posts/$id';
  static String forumPostLike(Object id) => '/api/forum/posts/$id/like';
  static String forumPostComments(Object id) => '/api/forum/posts/$id/comments';

  // Bilibili 伴侣资源
  static const String biliMovieVideos = '/api/bili/movie/videos';

  // Member C
  static const String wsChat = '/ws/chat';

  /// 推荐 Feed（确定性 REST，不走 LLM）：query 可空走热门。返回 RecommendationFeed。
  static const String feedRecommend = '/api/feed/recommend';

  /// MicroDesign 关键词帖子，避免占用 B 的 /api/feed 主路径。
  static const String feedMicrodesign = '/api/feed/microdesign';

  /// 互动海报：兼容旧 movieId 入口。
  static String poster(Object movieId) => '/api/poster/$movieId';

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
  static const String agentMemorySync = '/api/agent/memory/sync';
  static const String agentProfile = '/api/agent/profile';
  static const String agentProfileRebuild = '/api/agent/profile/rebuild';
  static const String agentDebateRecommend = '/api/agent/debate/recommend';
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
