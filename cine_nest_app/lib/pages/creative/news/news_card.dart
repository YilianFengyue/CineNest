import 'package:cine_nest/pages/creative/models/news_item.dart';
import 'package:cine_nest/pages/creative/widgets/block_renderer.dart';
import 'package:flutter/material.dart';

/// 单条资讯卡（F12）。
///
/// 外壳是 Material 3 filled card（零阴影 + tonal 表面 + 中圆角），
/// 标题 + [BlockRenderer] 拼贴内容 + 来源/时间页脚。
class NewsCard extends StatelessWidget {
  const NewsCard(this.item, {super.key});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {}, // TODO: 资讯详情页（后续）
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              BlockRenderer(blocks: item.blocks),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.public, size: 13, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                    item.source,
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  const Spacer(),
                  if (item.publishedAt.isNotEmpty)
                    Text(
                      item.publishedAt,
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
