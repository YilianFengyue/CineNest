/// 对话消息的 metadata 约定（成员 C · F9）。
///
/// flutter_chat_core 的 [CustomMessage] 用 `metadata` 袋子承载我们的业务数据，
/// 这里集中声明键名与取值，避免散落硬编码。
abstract final class ChatMeta {
  /// CustomMessage 的种类判别键。
  static const String kind = 'kind';

  // ── kind 取值 ──
  /// Agent 状态条：思考动画 + 工具来源 chip。
  static const String kindStatus = 'agent_status';

  /// 推荐 feed 附件（多张帖子卡）。值与后端 attachment.type 一致。
  static const String kindRecommendation = 'recommendation_feed';

  /// 互动海报附件（单部作品海报预览）。
  static const String kindPoster = 'microdesign_poster';

  /// 交互卡片集合附件（聊天富媒体卡：可播放卡/轮播/影评/溯源…）。
  static const String kindInteractive = 'interactive_cards';

  /// 资讯流附件。
  static const String kindNews = 'news_feed';

  /// 资讯生成任务 chip（在对话里提交「生成影视资讯」后展示进度入口）。
  static const String kindNewsTask = 'news_task';

  /// AutoGLM 手机子 Agent 任务 chip。
  static const String kindPhoneTask = 'phone_task';

  /// 错误条 + 重试。
  static const String kindError = 'error';

  // ── 字段键 ──
  /// 状态条是否仍在思考（bool）。
  static const String thinking = 'thinking';

  /// 已调用的工具名列表（`List<String>`）。
  static const String tools = 'tools';

  /// 附件负载（后端 RecommendationFeed / PosterSpec 的完整 JSON）。
  static const String payload = 'payload';

  /// 文本（错误条用）。
  static const String text = 'text';
}

/// 对话中的固定参与者 id。
abstract final class ChatUsers {
  /// 当前用户。
  static const String me = 'me';

  /// CineNest 影视 Agent。
  static const String bot = 'cinenest';
}
