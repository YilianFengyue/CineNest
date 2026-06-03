import 'package:cached_network_image/cached_network_image.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/utils/media_url.dart';
import 'package:flutter/material.dart';

/// microdesign v1.1 富交互卡片库（成员 C）。
///
/// 对话富回答 / F8 海报 / F12 资讯复用同一套卡片，数据走 [ContentBlock]。
/// 设计语言遵循 CodeReference 的 Material You：零阴影、tonal 表面、紧凑、纯 `colorScheme`。
/// 多动作统一放在 `data.actions[]`（沿用 [MicroAction]），点击经 [onAction] 上抛页面分发。

/// 解析 data.actions[] → MicroAction 列表。
List<MicroAction> cardActions(ContentBlock block) {
  final raw = block.data['actions'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => MicroAction.fromJson(e.cast<String, dynamic>()))
      .toList();
}

MicroAction? _first(List<MicroAction> actions, String type) {
  for (final a in actions) {
    if (a.type == type) return a;
  }
  return null;
}

Widget _cover(
  BuildContext context,
  String url, {
  double w = 84,
  double h = 118,
  double radius = 12,
}) {
  final cs = Theme.of(context).colorScheme;
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: w,
      height: h,
      child: url.isEmpty
          ? Container(color: cs.surfaceContainerHighest)
          : CachedNetworkImage(
              imageUrl: mediaUrl(url),
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: cs.surfaceContainerHighest),
              errorWidget: (_, _, _) => Container(
                color: cs.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(Icons.movie_outlined, color: cs.outline),
              ),
            ),
    ),
  );
}

Widget _tag(BuildContext context, String text) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: cs.secondaryContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, height: 1, color: cs.onSecondaryContainer),
    ),
  );
}

Widget _scoreStar(BuildContext context, double rating, {String? label}) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 16),
      const SizedBox(width: 2),
      Text(
        rating.toStringAsFixed(1),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: cs.onSurface,
        ),
      ),
      if (label != null && label.isNotEmpty) ...[
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
      ],
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// 1. 可播放电影介绍卡
// ─────────────────────────────────────────────────────────────

class PlayableMovieCard extends StatelessWidget {
  const PlayableMovieCard(this.block, {super.key, this.onAction});
  final ContentBlock block;
  final void Function(MicroAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rating = block.number('rating');
    final genres = block.strList('genres');
    final summary = block.str('summary');
    final year = block.str('year');
    final sourceCount = block.integer('source_count');
    final actions = cardActions(block);
    final play = _first(actions, 'resolveAndPlay');
    final openPoster =
        _first(actions, 'openPoster') ?? _first(actions, 'openResourcePoster');

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openPoster != null && onAction != null
            ? () => onAction!(openPoster)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cover(context, block.str('cover')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.str('title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (rating > 0)
                              _scoreStar(
                                context,
                                rating,
                                label: block.str('rating_label'),
                              ),
                            if (rating > 0 && year.isNotEmpty)
                              const SizedBox(width: 8),
                            if (year.isNotEmpty)
                              Text(
                                year,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (genres.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final g in genres.take(3)) _tag(context, g),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (play != null || openPoster != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (play != null)
                      FilledButton.tonalIcon(
                        onPressed:
                            onAction == null ? null : () => onAction!(play),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(play.label.isEmpty ? '立即播放' : play.label),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const Spacer(),
                    if (sourceCount > 0)
                      Text(
                        '$sourceCount 个资源',
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2. 电影海报轮播组
// ─────────────────────────────────────────────────────────────

class MovieCarouselCard extends StatelessWidget {
  const MovieCarouselCard(this.block, {super.key, this.onAction});
  final ContentBlock block;
  final void Function(MicroAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = block.str('title');
    final items = (block.data['items'] as List?)?.whereType<Map>().toList() ??
        const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final m = items[i].cast<String, dynamic>();
              final rating = (m['rating'] as num?)?.toDouble() ?? 0;
              final action = m['action'] is Map
                  ? MicroAction.fromJson(
                      (m['action'] as Map).cast<String, dynamic>())
                  : null;
              return SizedBox(
                width: 108,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: action != null && onAction != null
                      ? () => onAction!(action)
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          _cover(
                            context,
                            m['cover'] as String? ?? '',
                            w: 108,
                            h: 150,
                          ),
                          if (rating > 0)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded,
                                        size: 12,
                                        color: Colors.amber.shade400),
                                    const SizedBox(width: 2),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['title'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if ((m['year'] as String?)?.isNotEmpty ?? false)
                        Text(
                          m['year'] as String,
                          style: TextStyle(fontSize: 11, color: cs.outline),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 3. 影评 / 评价引用卡
// ─────────────────────────────────────────────────────────────

class ReviewQuoteCard extends StatelessWidget {
  const ReviewQuoteCard(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final quote = block.str('quote');
    final author = block.str('author');
    final source = block.str('source');
    final rating = block.number('rating');
    if (quote.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (author.isNotEmpty || source.isNotEmpty || rating > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (rating > 0) ...[
                        _scoreStar(context, rating),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          [author, source]
                              .where((e) => e.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 4. 来源溯源卡
// ─────────────────────────────────────────────────────────────

class SourceTraceCard extends StatelessWidget {
  const SourceTraceCard(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final query = block.str('query');
    final items = (block.data['items'] as List?)?.whereType<Map>().toList() ??
        const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                query.isEmpty ? '检索来源' : '“$query” 检索来源',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final raw in items)
                _traceChip(context, raw.cast<String, dynamic>()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _traceChip(BuildContext context, Map<String, dynamic> m) {
    final cs = Theme.of(context).colorScheme;
    final status = m['status'] as String? ?? 'ok';
    final ok = status == 'ok';
    final count = (m['count'] as num?)?.toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? cs.secondaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.remove_circle_outline,
            size: 13,
            color: ok ? cs.onSecondaryContainer : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            m['label'] as String? ?? (m['key'] as String? ?? ''),
            style: TextStyle(
              fontSize: 12,
              color: ok ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
          ),
          if (ok && count != null) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 5. 资讯卡
// ─────────────────────────────────────────────────────────────

class NewsCardBlock extends StatelessWidget {
  const NewsCardBlock(this.block, {super.key, this.onAction});
  final ContentBlock block;
  final void Function(MicroAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cover = block.str('cover');
    final tags = block.strList('tags');
    final summary = block.str('summary');
    final action = block.action;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action != null && !action.isEmpty && onAction != null
            ? () => onAction!(action)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.str('title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (cover.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: mediaUrl(cover),
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: cs.surfaceContainerHighest),
                      errorWidget: (_, _, _) =>
                          Container(color: cs.surfaceContainerHighest),
                    ),
                  ),
                ),
              ],
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final t in tags) _tag(context, t)],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.public, size: 13, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                    block.str('source'),
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  const Spacer(),
                  if (block.str('published_at').isNotEmpty)
                    Text(
                      block.str('published_at'),
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

// ─────────────────────────────────────────────────────────────
// 6. 图集（横滑 / 网格）
// ─────────────────────────────────────────────────────────────

class MediaGalleryCard extends StatelessWidget {
  const MediaGalleryCard(this.block, {super.key});
  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final urls = block.strList('urls');
    if (urls.isEmpty) return const SizedBox.shrink();
    final title = block.str('title');
    final grid = block.str('layout') == 'grid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (grid)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: urls.length,
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: mediaUrl(urls[i]),
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: cs.surfaceContainerHighest),
                errorWidget: (_, _, _) =>
                    Container(color: cs.surfaceContainerHighest),
              ),
            ),
          )
        else
          SizedBox(
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
                    width: 92,
                    color: cs.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 7. 视频解说卡
// ─────────────────────────────────────────────────────────────

class VideoExplainCard extends StatelessWidget {
  const VideoExplainCard(this.block, {super.key, this.onAction});
  final ContentBlock block;
  final void Function(MicroAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final up = block.str('up');
    final duration = block.str('duration');
    final playCount = block.str('play_count');
    final action = block.action;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action != null && !action.isEmpty && onAction != null
            ? () => onAction!(action)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 128,
                  height: 76,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      block.str('cover').isEmpty
                          ? Container(color: cs.surfaceContainerHighest)
                          : CachedNetworkImage(
                              imageUrl: mediaUrl(block.str('cover')),
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: cs.surfaceContainerHighest),
                              errorWidget: (_, _, _) => Container(
                                color: cs.surfaceContainerHighest,
                                child: Icon(Icons.movie_outlined,
                                    color: cs.outline),
                              ),
                            ),
                      Center(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(5),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (up.isNotEmpty) ...[
                          Icon(Icons.account_circle_outlined,
                              size: 13, color: cs.outline),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              up,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: cs.outline),
                            ),
                          ),
                        ],
                        if (up.isNotEmpty && playCount.isNotEmpty)
                          const SizedBox(width: 10),
                        if (playCount.isNotEmpty) ...[
                          Icon(Icons.play_circle_outline,
                              size: 13, color: cs.outline),
                          const SizedBox(width: 3),
                          Text(
                            playCount,
                            style: TextStyle(fontSize: 12, color: cs.outline),
                          ),
                        ],
                      ],
                    ),
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
