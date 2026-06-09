/// 内容区块（Micro Design 微组件拼贴系统的数据原子）。
///
/// 后端（`/api/feed/recommend`、`/api/poster/catalog/...`、Agent attachment）统一返回
/// `blocks: [{type, data, action?}, ...]`，前端 `BlockRenderer` 按 [type] 分发到对应微组件
/// 并纵向拼贴。协议版本 `microdesign.v1`。
///
/// 这套结构四处复用，互不重复造轮子：
///   · F12 资讯流  —— 每条资讯 = 一串 blocks
///   · F8 互动海报 —— 一部电影 = banner + 评分 + 标签 + 简介 + 线路 等 blocks
///   · F9 对话推荐 —— 聊天气泡内嵌 blocks 推荐卡 / 海报预览
///   · B 首页 feed —— posterRow 帖子卡
///
/// 分发渲染模式参考 PiliPlus 动态流的 `pages/dynamics/widgets/content_panel.dart`。
enum ContentBlockType {
  // ── v1 基础块 ──
  banner, // 互动海报顶部大图（背景图 + 标题/副标题叠字）
  heading, // 小标题
  text, // 正文段落
  tagRow, // 标签行（类型 / 关键词）
  imageSwiper, // 横向图片滑窗（剧照 / AI 生图）
  videoBar, // 视频条 / 可播放线路（封面 + 标题 + 时长·播放量·集数，可挂播放）
  posterRow, // 海报条（左竖海报 + 右评分/简介/标签，影视条目卡）
  rating, // 评分
  // ── v1.1 富交互卡（对话/海报/资讯复用）──
  playableMovieCard, // 可播放电影介绍卡（封面 + 标题/评分/类型/推荐语 + 播放/海报按钮）
  movieCarousel, // 电影海报轮播组（横向多张可点海报）
  reviewQuoteCard, // 影评 / 评价引用卡
  sourceTraceCard, // 来源溯源卡（Agent 查了哪些源、命中数）
  newsCard, // 资讯卡（标题 + 摘要 + 来源/时间 + 封面）
  mediaGallery, // 图集（剧照 / 海报，横滑或网格）
  videoExplainCard, // 视频解说卡（封面 + 标题 + UP + 时长/播放量）
  unknown; // 未知 —— 前向兼容后端新增类型，渲染时静默跳过

  static ContentBlockType parse(String? name) =>
      values.firstWhere((e) => e.name == name, orElse: () => unknown);
}

/// 区块附带的白名单动作（对应后端 `MicroDesignAction`）。
///
/// 后端约定：Flutter 只处理白名单 [type]，不解析自然语言。当前三种：
///   · `openPoster`         —— 打开 Catalog 互动海报（data: catalog_provider_id / catalog_source_id / media_kind）
///   · `openResourcePoster` —— 打开资源站海报（data: provider_id / remote_id）
///   · `resolveAndPlay`     —— 解析并播放（data: provider_id / remote_id / line_name? / episode_name? / play_url?）
class MicroAction {
  final String type;
  final String label;
  final Map<String, dynamic> data;

  const MicroAction({
    required this.type,
    this.label = '',
    this.data = const {},
  });

  factory MicroAction.fromJson(Map<String, dynamic> json) => MicroAction(
    type: json['type'] as String? ?? '',
    label: json['label'] as String? ?? '',
    data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
  );

  Map<String, dynamic> toJson() => {'type': type, 'label': label, 'data': data};

  String str(String key, [String fallback = '']) =>
      data[key] as String? ?? fallback;

  bool get isEmpty => type.isEmpty;

  /// 给播放动作补片名兜底。旧后端/历史消息可能没有 `data.title`，
  /// 但本地聚合器播放入口需要片名去搜源。
  MicroAction withTitleFallback(String title) {
    final value = title.trim();
    if (value.isEmpty || str('title').isNotEmpty) return this;
    return MicroAction(
      type: type,
      label: label,
      data: {...data, 'title': value},
    );
  }
}

/// 单个内容区块：一个 [type] + 一袋自由 [data] + 可选 [action]。
///
/// data 不固定 schema，由各微组件自行解析自己关心的字段，
/// 这样后端给区块加字段时前端无需改模型。
class ContentBlock {
  final ContentBlockType type;
  final Map<String, dynamic> data;

  /// 点击该区块要执行的动作（videoBar 常带，其余多为 null）。
  final MicroAction? action;

  const ContentBlock(this.type, [this.data = const {}, this.action]);

  factory ContentBlock.fromJson(Map<String, dynamic> json) => ContentBlock(
    ContentBlockType.parse(json['type'] as String?),
    (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    json['action'] is Map
        ? MicroAction.fromJson((json['action'] as Map).cast<String, dynamic>())
        : null,
  );

  /// 从后端 blocks 数组批量解析。
  static List<ContentBlock> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ContentBlock.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': data,
    if (action != null) 'action': action!.toJson(),
  };

  // ── 便捷构造（本地拼装 / 假数据用）──
  factory ContentBlock.banner({
    required String image,
    required String title,
    String? subtitle,
    String? poster,
    String? style,
  }) => ContentBlock(ContentBlockType.banner, {
    'image': image,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (poster != null) 'poster': poster,
    if (style != null) 'style': style,
  });

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
    String? playUrl,
    int? episodeCount,
  }) => ContentBlock(ContentBlockType.videoBar, {
    'title': title,
    'cover': cover,
    if (playCount != null) 'play_count': playCount,
    if (duration != null) 'duration': duration,
    if (playUrl != null) 'play_url': playUrl,
    if (episodeCount != null) 'episode_count': episodeCount,
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

  factory ContentBlock.rating(double score, {String? label}) => ContentBlock(
    ContentBlockType.rating,
    {'score': score, if (label != null) 'label': label},
  );

  // ── 取值便捷 ──
  String str(String key, [String fallback = '']) =>
      data[key] as String? ?? fallback;

  List<String> strList(String key) =>
      (data[key] as List?)?.map((e) => e.toString()).toList() ?? const [];

  double number(String key, [double fallback = 0]) =>
      (data[key] as num?)?.toDouble() ?? fallback;

  int integer(String key, [int fallback = 0]) =>
      (data[key] as num?)?.toInt() ?? fallback;
}
