import 'package:cine_nest/pages/creative/chat/models/chat_meta.dart';
import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/utils/placeholder_image.dart';
import 'package:cine_nest/pages/creative/widgets/block_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

/// 对话中的结构化附件卡 —— 渲染 Agent 返回的推荐 feed / 互动海报。
///
/// 读 `kind=recommendation_feed | microdesign_poster` 的 [CustomMessage]，
/// 复用 [BlockRenderer] 把后端 blocks 拼贴成卡片。点击动作经 [onAction] 上抛，
/// 由页面统一分发（打开海报详情 / 解析播放）。
class AttachmentCard extends StatelessWidget {
  const AttachmentCard(this.message, {super.key, this.onAction});

  final CustomMessage message;
  final void Function(MicroAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? const {};
    final kind = meta[ChatMeta.kind] as String?;
    final payload =
        (meta[ChatMeta.payload] as Map?)?.cast<String, dynamic>() ?? const {};

    if (kind == ChatMeta.kindPoster) {
      return _PosterPreview(payload: payload, onAction: onAction);
    }
    if (kind == ChatMeta.kindInteractive) {
      // 交互卡片集合：payload.cards 是一串 block，直接拼贴。
      final cards = ContentBlock.listFrom(payload['cards']);
      if (cards.isEmpty) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(right: 36),
          child: BlockRenderer(blocks: cards, spacing: 12, onAction: onAction),
        ),
      );
    }
    if (kind == ChatMeta.kindNews) {
      // 资讯流：每条 item 的 blocks 各自拼贴。
      final items =
          (payload['items'] as List?)?.whereType<Map>().toList() ?? const [];
      if (items.isEmpty) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(right: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BlockRenderer(
                    blocks: ContentBlock.listFrom(
                      it.cast<String, dynamic>()['blocks'],
                    ),
                    spacing: 10,
                    onAction: onAction,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    // 默认按推荐 feed 渲染。
    final posts =
        (payload['posts'] as List?)?.whereType<Map>().toList() ?? const [];
    if (posts.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PostCard(
                  post: p.cast<String, dynamic>(),
                  onAction: onAction,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 解析后端 actions 数组为 [MicroAction] 列表。
List<MicroAction> _actionsFrom(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => MicroAction.fromJson(e.cast<String, dynamic>()))
      .toList();
}

MicroAction? _firstOfType(List<MicroAction> actions, String type) {
  for (final a in actions) {
    if (a.type == type) return a;
  }
  return null;
}

/// 单张推荐帖子卡 —— 紧凑影视条目卡。
///
/// 直接用 post 顶层字段（封面/标题/评分/资源数/推荐语/类型）拼贴，
/// 左竖封面 + 右信息 + 底部播放/海报按钮。对标 Kazumi 番剧卡的密度与零阴影。
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, this.onAction});

  final Map<String, dynamic> post;
  final void Function(MicroAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = post['title'] as String? ?? '';
    final subtitle = post['subtitle'] as String? ?? '';
    final cover = post['cover_url'] as String? ?? '';
    final rating = (post['rating'] as num?)?.toDouble();
    final reason = post['recommend_reason'] as String? ?? '';
    final sourceCount = (post['source_count'] as num?)?.toInt() ?? 0;
    final genres =
        (post['genres'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final actions = _actionsFrom(post['actions']);
    final openPoster =
        _firstOfType(actions, 'openPoster') ??
        _firstOfType(actions, 'openResourcePoster');
    final play = _firstOfType(actions, 'resolveAndPlay');

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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 84,
                      height: 118,
                      child: CoverImage(url: cover, seed: title),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (rating != null && rating > 0) ...[
                              Icon(
                                Icons.star_rounded,
                                color: Colors.amber.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (sourceCount > 0)
                              Text(
                                '$sourceCount 个资源',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            reason,
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
                              for (final g in genres.take(3))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer.withValues(
                                      alpha: 0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    g,
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
              if (openPoster != null || play != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (play != null)
                      FilledButton.tonalIcon(
                        onPressed: onAction == null
                            ? null
                            : () => onAction!(play.withTitleFallback(title)),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(play.label.isEmpty ? '立即播放' : play.label),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const Spacer(),
                    if (openPoster != null)
                      TextButton(
                        onPressed: onAction == null
                            ? null
                            : () => onAction!(openPoster),
                        child: Text(
                          openPoster.label.isEmpty ? '查看海报' : openPoster.label,
                        ),
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

/// 互动海报预览卡（banner + 评分/标签 + 「查看完整海报」CTA）。
class _PosterPreview extends StatelessWidget {
  const _PosterPreview({required this.payload, this.onAction});

  final Map<String, dynamic> payload;
  final void Function(MicroAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = payload['title'] as String? ?? '';
    final reason = payload['recommend_reason'] as String? ?? '';
    // 仅取头部观感块（banner / rating / tagRow），完整线路在详情页展示。
    final all = ContentBlock.listFrom(payload['blocks']);
    final preview = all
        .where(
          (b) =>
              b.type == ContentBlockType.banner ||
              b.type == ContentBlockType.rating ||
              b.type == ContentBlockType.tagRow,
        )
        .toList();
    final open = _openPosterAction();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 36),
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open != null && onAction != null
                ? () => onAction!(open)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.isNotEmpty) BlockRenderer(blocks: preview),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (open != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: onAction == null
                            ? null
                            : () => onAction!(open),
                        icon: const Icon(Icons.open_in_full_rounded, size: 16),
                        label: const Text('查看完整海报'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 从 PosterSpec 的 catalog 信息合成一个 openPoster 动作（用于跳详情页）。
  MicroAction? _openPosterAction() {
    final catalog = (payload['catalog'] as Map?)?.cast<String, dynamic>();
    if (catalog != null) {
      final provider = catalog['provider_id'] as String?;
      final source = catalog['source_id'] as String?;
      if (provider != null && source != null) {
        return MicroAction(
          type: 'openPoster',
          label: '查看完整海报',
          data: {
            'catalog_provider_id': provider,
            'catalog_source_id': source,
            'media_kind': catalog['media_kind'] ?? 'movie',
          },
        );
      }
    }
    return null;
  }
}
