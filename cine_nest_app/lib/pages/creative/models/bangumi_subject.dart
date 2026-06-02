/// Bangumi（番组计划）条目模型（轻量版，只取卡片渲染要用的字段）。
///
/// 对应 `api.bgm.tv` / `next.bgm.tv` 返回的 subject 结构。
/// 数据来源说明：影视/番剧元数据 + 海报来自 Bangumi 公开 API（无需 key）。
class BangumiSubject {
  final int id;
  final String name; // 原名（日文/英文）
  final String nameCn; // 中文名
  final int type; // 1 书 / 2 动画 / 3 音乐 / 4 游戏 / 6 三次元影视
  final String info; // 列表接口的制作信息串（话数 / 日期 / 监督…）
  final String summary; // 简介（详情接口才有）
  final double score; // 评分
  final int rank; // 排名
  final Map<String, String> images; // large/common/medium/small/grid

  const BangumiSubject({
    required this.id,
    this.name = '',
    this.nameCn = '',
    this.type = 0,
    this.info = '',
    this.summary = '',
    this.score = 0,
    this.rank = 0,
    this.images = const {},
  });

  String get displayTitle => nameCn.isNotEmpty ? nameCn : name;

  String get cover =>
      images['large'] ?? images['common'] ?? images['medium'] ?? '';

  factory BangumiSubject.fromJson(Map<String, dynamic> json) {
    final rating = (json['rating'] as Map?)?.cast<String, dynamic>();
    final rawImages = (json['images'] as Map?)?.cast<String, dynamic>();
    return BangumiSubject(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      // 列表接口字段是 nameCN，详情接口是 name_cn，两者都兜
      nameCn:
          json['nameCN'] as String? ?? json['name_cn'] as String? ?? '',
      type: (json['type'] as num?)?.toInt() ?? 0,
      info: json['info'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      score: (rating?['score'] as num?)?.toDouble() ?? 0,
      rank: (rating?['rank'] as num?)?.toInt() ?? 0,
      images: rawImages == null
          ? const {}
          : rawImages.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
  }
}
