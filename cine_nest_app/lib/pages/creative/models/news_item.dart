import 'package:cine_nest/pages/creative/models/content_block.dart';

/// 资讯条目（F12）。
///
/// 一条资讯 = 头部元信息（标题 / 来源 / 时间）+ 一串内容区块 [blocks]。
/// 对应后端 `GET /api/news` 返回的数组元素。
class NewsItem {
  final String id;
  final String title;
  final String source;
  final String publishedAt; // 展示用字符串，如「2 小时前」
  final List<ContentBlock> blocks;

  const NewsItem({
    required this.id,
    required this.title,
    this.source = '',
    this.publishedAt = '',
    this.blocks = const [],
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
    id: json['id']?.toString() ?? '',
    title: json['title'] as String? ?? '',
    source: json['source'] as String? ?? '',
    publishedAt: json['published_at'] as String? ?? '',
    blocks:
        (json['blocks'] as List?)
            ?.map(
              (e) => ContentBlock.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList() ??
        const [],
  );
}
