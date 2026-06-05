import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/utils/media_url.dart';
import 'package:flutter/material.dart';

/// 微组件库 —— 每个 Widget 消费一个 [ContentBlock]，自解析 `data` 渲染。
///
/// 设计遵循 CodeReference（PiliPlus / Kazumi）的 Material You 语言：
/// 零阴影、tonal 表面（xxxContainer）、紧凑间距、字号克制、次要文字用 outline。
/// 全程走 `Theme.of(context).colorScheme`，不写死颜色，配合 app 的动态取色。

/// 互动海报顶部大图 —— 背景图 + 底部渐变 + 标题/副标题叠字。
///
/// F8 海报头部用它通栏铺满；零阴影、圆角、文字叠在渐变蒙层上保证可读。
/// `style`（neon/contrast/warm）后续可驱动渐变配色，这里先用主色调渐变。
class BannerBlock extends StatelessWidget {
  const BannerBlock(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final image = block.str('image');
    final title = block.str('title');
    final subtitle = block.str('subtitle');
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: mediaUrl(image),
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: cs.surfaceContainerHighest),
                errorWidget: (_, _, _) => Container(
                  color: cs.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(Icons.movie_outlined, color: cs.outline, size: 32),
                ),
              )
            else
              Container(color: cs.surfaceContainerHighest),
            // 底部到顶部的渐变蒙层，保证叠字可读。
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                  stops: [0.0, 0.62],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 小标题。
class HeadingBlock extends StatelessWidget {
  const HeadingBlock(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      block.str('text'),
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// 正文段落。
class TextBlock extends StatelessWidget {
  const TextBlock(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      block.str('text'),
      style: theme.textTheme.bodyMedium?.copyWith(
        height: 1.55,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 标签行 —— tonal chip，对标 PiliPlus 强调块的 secondaryContainer 用法。
class TagRowBlock extends StatelessWidget {
  const TagRowBlock(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tags = block.strList('tags');
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
      ],
    );
  }
}

/// 横向图片滑窗 —— 剧照 / 海报组。
class ImageSwiperBlock extends StatelessWidget {
  const ImageSwiperBlock(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final urls = block.strList('urls');
    if (urls.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: mediaUrl(urls[i]),
            width: 92,
            height: 124,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                Container(color: cs.surfaceContainerHighest),
            errorWidget: (_, _, _) => Container(
              color: cs.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                color: cs.outline,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 视频条 —— 封面 + 播放角标 + 标题 + 播放量。
///
/// F12 资讯里的解说视频、F8 海报里的「banner 播放电影」都复用它，
/// [onTap] 后续接成员 A 的播放器路由 `/player`。
class VideoBarBlock extends StatelessWidget {
  const VideoBarBlock(this.block, {super.key, this.onTap});
  final ContentBlock block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final duration = block.str('duration');
    final playCount = block.str('play_count');
    final episodeCount = block.integer('episode_count');
    // 页脚副信息：资讯条用播放量，海报线路用集数。
    final (IconData?, String) footer = playCount.isNotEmpty
        ? (Icons.play_circle_outline, playCount)
        : episodeCount > 1
        ? (Icons.video_library_outlined, '共 $episodeCount 集')
        : (null, '');
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: mediaUrl(block.str('cover')),
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: cs.surfaceContainerHighest),
                        errorWidget: (_, _, _) => Container(
                          color: cs.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(Icons.movie_outlined, color: cs.outline),
                        ),
                      ),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.36),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      if (duration.isNotEmpty)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              duration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.str('title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    if (footer.$2.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(footer.$1, size: 13, color: cs.outline),
                          const SizedBox(width: 3),
                          Text(
                            footer.$2,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1,
                              color: cs.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 海报条 —— 左竖海报 + 右（评分 / 简介 / 标签），影视条目卡。
///
/// 对标 Kazumi `bean/card/bangumi_card.dart` 的经典布局：海报比例约 0.7，
/// 信息密度高、零阴影、tonal chip。番剧资讯条目、F8 海报头部都复用它。
class PosterRowBlock extends StatelessWidget {
  const PosterRowBlock(this.block, {super.key, this.onTap});
  final ContentBlock block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final score = block.number('score');
    final summary = block.str('summary');
    final tags = block.strList('tags');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 124,
                child: CachedNetworkImage(
                  imageUrl: mediaUrl(block.str('cover')),
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: cs.surfaceContainerHighest),
                  errorWidget: (_, _, _) => Container(
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(Icons.movie_outlined, color: cs.outline),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (score > 0) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          score.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Bangumi',
                          style: TextStyle(fontSize: 11, color: cs.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (summary.isNotEmpty)
                    Text(
                      summary,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 评分条。
class RatingBlock extends StatelessWidget {
  const RatingBlock(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = block.number('score');
    final label = block.str('label', '评分');
    return Row(
      children: [
        Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 20),
        const SizedBox(width: 4),
        Text(
          score.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 1,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: cs.outline)),
      ],
    );
  }
}
