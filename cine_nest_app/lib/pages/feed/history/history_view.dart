import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'history_controller.dart';

/// 观影历史页。
///
/// 卡片布局照搬 Kazumi 的 `BangumiHistoryCardV`（圆角 tonal 卡 + 海报缩略
/// + 标题 + 元信息行 + 相对时间 + 尾部操作）。我们的历史接口只返回
/// `movie_id / title / visited_at` 三个字段、没有封面图，所以缩略图改用
/// 按标题取色的占位海报，视觉上仍成立。
class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(HistoryController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('观影历史')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.historyList.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 72,
                  color: cs.outline.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '还没有观影记录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          );
        }
        return SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: controller.historyList.length,
                itemBuilder: (context, index) {
                  return _HistoryCard(item: controller.historyList[index]);
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 单条历史卡片（对标 Kazumi BangumiHistoryCardV 的水平布局）。
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = (item['title'] as String?)?.trim();
    final displayTitle = (title == null || title.isEmpty) ? '未知影片' : title;
    final visitedAt = item['visited_at'] as String?;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: () => Get.toNamed(
          Routes.movieDetail,
          arguments: {'movieId': item['movie_id']},
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PosterThumb(title: displayTitle),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.movie_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '电影',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: cs.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _relativeTime(visitedAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }

  /// 把 "2026-06-05 20:11:23" 这类时间戳转成相对时间。
  static String _relativeTime(String? raw) {
    if (raw == null || raw.isEmpty) return '未知时间';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }
}

/// 占位海报缩略图：无封面图时，按标题哈希取一个 tonal 底色 + 首字 + 胶片图标。
class _PosterThumb extends StatelessWidget {
  const _PosterThumb({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 按标题稳定取一个色相，生成柔和渐变底，避免一片死板灰。
    final hue = (title.hashCode % 360).abs().toDouble();
    final base = HSLColor.fromAHSL(1, hue, 0.45, 0.55).toColor();
    final initial = title.characters.isEmpty ? '影' : title.characters.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 108,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base, base.withValues(alpha: 0.7)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Icon(
                Icons.local_movies_outlined,
                size: 16,
                color: cs.surface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
