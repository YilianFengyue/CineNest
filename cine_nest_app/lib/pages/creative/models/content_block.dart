/// 内容区块（Micro Design 微组件拼贴系统的数据原子）。
///
/// 后端（成员 C 的 `/api/news`、`/api/poster`）返回 `blocks: [{type, data}, ...]`，
/// 前端 `BlockRenderer` 按 [type] 分发到对应微组件并纵向拼贴。
///
/// 这套结构三处复用，互不重复造轮子：
///   · F12 资讯流  —— 每条资讯 = 一串 blocks
///   · F8 互动海报 —— 一部电影 = banner + 解说 + 影评 + 图组 等 blocks
///   · F9 对话推荐 —— 聊天气泡内嵌 blocks 推荐卡
///
/// 分发渲染模式参考 PiliPlus 动态流的 `pages/dynamics/widgets/content_panel.dart`。
enum ContentBlockType {
  heading, // 小标题
  text, // 正文段落
  tagRow, // 标签行（类型 / 关键词）
  imageSwiper, // 横向图片滑窗
  videoBar, // 视频条（封面 + 标题 + 播放量，可挂播放）
  posterRow, // 海报条（左竖海报 + 右评分/简介/标签，影视条目卡）
  rating, // 评分
  unknown; // 未知 —— 前向兼容后端新增类型，渲染时静默跳过

  static ContentBlockType parse(String? name) =>
      values.firstWhere((e) => e.name == name, orElse: () => unknown);
}

/// 单个内容区块：一个 [type] + 一袋自由 [data]。
///
/// data 不固定 schema，由各微组件自行解析自己关心的字段，
/// 这样后端给区块加字段时前端无需改模型。
class ContentBlock {
  final ContentBlockType type;
  final Map<String, dynamic> data;

  const ContentBlock(this.type, [this.data = const {}]);

  factory ContentBlock.fromJson(Map<String, dynamic> json) => ContentBlock(
    ContentBlockType.parse(json['type'] as String?),
    (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
  );

  Map<String, dynamic> toJson() => {'type': type.name, 'data': data};

  // ── 便捷构造（本地拼装 / 假数据用）──
  factory ContentBlock.heading(String text) =>
      ContentBlock(ContentBlockType.heading, {'text': text});

  factory ContentBlock.text(String text) =>
      ContentBlock(ContentBlockType.text, {'text': text});

  factory ContentBlock.tags(List<String> tags) =>
      ContentBlock(ContentBlockType.tagRow, {'tags': tags});

  factory ContentBlock.images(List<String> urls) =>
      ContentBlock(ContentBlockType.imageSwiper, {'urls': urls});

  factory ContentBlock.video({
    required String title,
    required String cover,
    String? playCount,
    String? duration,
  }) => ContentBlock(ContentBlockType.videoBar, {
    'title': title,
    'cover': cover,
    if (playCount != null) 'play_count': playCount,
    if (duration != null) 'duration': duration,
  });

  factory ContentBlock.posterRow({
    required String cover,
    double? score,
    String? summary,
    List<String>? tags,
  }) => ContentBlock(ContentBlockType.posterRow, {
    'cover': cover,
    if (score != null) 'score': score,
    if (summary != null) 'summary': summary,
    if (tags != null) 'tags': tags,
  });

  factory ContentBlock.rating(double score, {String? label}) =>
      ContentBlock(ContentBlockType.rating, {
        'score': score,
        if (label != null) 'label': label,
      });

  // ── 取值便捷 ──
  String str(String key, [String fallback = '']) =>
      data[key] as String? ?? fallback;

  List<String> strList(String key) =>
      (data[key] as List?)?.map((e) => e.toString()).toList() ?? const [];

  double number(String key, [double fallback = 0]) =>
      (data[key] as num?)?.toDouble() ?? fallback;
}
